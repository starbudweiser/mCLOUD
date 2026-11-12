// mCLOUD — montage des comptes : serveur WebDAV local (rclone serve) monté par macOS (NetFS), sans macFUSE.
// Garde-fous de connexion : sonde régulière, remontage automatique (panne, veille du Mac, retour du réseau).
import AppKit
import Foundation
import Network
import NetFS

enum MountState: Equatable { case off, starting, on(String), healing, error(String) }

@MainActor
final class Mounter: ObservableObject {
    static let shared = Mounter()
    @Published private(set) var states: [UUID: MountState] = [:]
    private var procs: [UUID: Process] = [:]
    private var lastErr: [UUID: String] = [:]
    private var wanted: Set<UUID> = []
    private var fails: [UUID: Int] = [:]
    private var attempts: [UUID: Int] = [:]
    private var monitor: NWPathMonitor?
    private var online = true
    private var loop: Task<Void, Never>?

    func state(_ a: Account) -> MountState { states[a.id] ?? .off }
    var anyActive: Bool { states.values.contains { if case .off = $0 { return false }; return true } }

    // MARK: Montage

    /// Cible rclone et variables d'environnement d'un compte (chiffrement par-dessus le compte, mot de passe jamais écrit sur disque).
    static func spec(_ a: Account) async -> (target: String, env: [String: String])? {
        guard a.encrypted else { return ("\(a.remote):", [:]) }
        guard let pw = Keychain.get(a.id.uuidString), let ob = await Rclone.obscure(pw) else { return nil }
        return ("mccrypt:", ["RCLONE_CONFIG_MCCRYPT_TYPE": "crypt", "RCLONE_CONFIG_MCCRYPT_REMOTE": "\(a.remote):mcloud-crypt",
                             "RCLONE_CONFIG_MCCRYPT_PASSWORD": ob, "RCLONE_CONFIG_MCCRYPT_FILENAME_ENCRYPTION": "standard"])
    }

    func mount(_ a: Account) async {
        guard procs[a.id] == nil, !a.pending else { return }
        wanted.insert(a.id)
        states[a.id] = .starting
        guard let spec = await Self.spec(a) else { states[a.id] = .error("Keychain"); return }
        let port = Self.freePort(), pass = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let vol = a.volumeName
        let cache = Rclone.cacheDir.appendingPathComponent(a.id.uuidString)
        let p = Process(), err = Pipe()
        p.executableURL = Rclone.bin
        p.arguments = ["--config", Rclone.conf.path, "serve", "webdav", spec.target, "--addr", "127.0.0.1:\(port)", "--baseurl", "/\(vol)",
                       "--user", "mcloud", "--pass", pass, ] + Self.cacheArgs(a) + ["--cache-dir", cache.path, "--dir-cache-time", "5m",
                       "--low-level-retries", "20", "--retries", "5", "--log-level", "ERROR"]
        p.environment = Rclone.environment(spec.env)
        p.standardOutput = FileHandle.nullDevice; p.standardError = err
        err.fileHandleForReading.readabilityHandler = { [id = a.id] h in
            let s = String(decoding: h.availableData, as: UTF8.self)
            if !s.isEmpty { Task { @MainActor in Mounter.shared.lastErr[id] = Rclone.lastLine(s) } }
        }
        p.terminationHandler = { [id = a.id] proc in
            Task { @MainActor in Mounter.shared.processEnded(id, proc) }
        }
        do { try p.run() } catch { states[a.id] = .error(error.localizedDescription); return }
        procs[a.id] = p
        guard await Self.waitForPort(port) else { stop(a.id); states[a.id] = .error(lastErr[a.id] ?? "rclone"); return }
        let path = await Self.netMount(port: port, vol: vol, pass: pass)
        if let path { states[a.id] = .on(path); fails[a.id] = 0; attempts[a.id] = 0 }
        else { stop(a.id); states[a.id] = .error(lastErr[a.id] ?? "NetFS") }
    }

    /// Réglages du cache selon le mode : « minimal » ne garde sur le disque que les fichiers en cours d'envoi (quelques Mo, vidés à la fin).
    static func cacheArgs(_ a: Account) -> [String] {
        switch a.cacheMode {
        case "offline": return ["--vfs-cache-mode", "full", "--vfs-cache-max-size", "\(a.cacheGB)G", "--vfs-cache-max-age", "\(a.cacheDays * 24)h"]
        case "balanced": return ["--vfs-cache-mode", "full", "--vfs-cache-max-size", "2G", "--vfs-cache-max-age", "6h"]
        default: return ["--vfs-cache-mode", "writes", "--vfs-cache-max-size", "256M", "--vfs-cache-max-age", "5m"]
        }
    }

    private func purgeCache(_ a: Account) {
        if a.cacheMode == "minimal" { try? FileManager.default.removeItem(at: Rclone.cacheDir.appendingPathComponent(a.id.uuidString)) }
    }

    func unmount(_ a: Account) async {
        wanted.remove(a.id)
        if case .on(let path) = state(a) { await Self.eject(path) }
        stop(a.id)
        try? await Task.sleep(nanoseconds: 500_000_000)
        purgeCache(a)
        states[a.id] = .off
    }

    func unmountAll() async { for a in Store.shared.accounts where wanted.contains(a.id) || procs[a.id] != nil { await unmount(a) } }

    private func stop(_ id: UUID) {
        if let p = procs.removeValue(forKey: id) { p.terminationHandler = nil; if p.isRunning { p.terminate() } }
    }

    private func processEnded(_ id: UUID, _ proc: Process) {
        guard procs[id] === proc else { return }
        procs[id] = nil
        if wanted.contains(id), let a = Store.shared.accounts.first(where: { $0.id == id }) { Task { await heal(a) } }
    }

    // MARK: Garde-fous

    /// Remonte un compte voulu mais tombé : attentes de 2, 5, 15, 30 puis 60 s entre les essais.
    func heal(_ a: Account) async {
        guard wanted.contains(a.id) else { return }
        if case .healing = state(a) { return }
        states[a.id] = .healing
        if case .on(let path) = state(a) { await Self.eject(path) }
        stop(a.id)
        let n = attempts[a.id, default: 0]; attempts[a.id] = n + 1
        try? await Task.sleep(nanoseconds: UInt64([2, 5, 15, 30, 60][min(n, 4)]) * 1_000_000_000)
        guard wanted.contains(a.id) else { return }
        states[a.id] = .off
        await mount(a)
        if case .error = state(a), wanted.contains(a.id), n < 8 { states[a.id] = .off; await heal(a) }
    }

    func startMonitoring() {
        guard monitor == nil else { return }
        let m = NWPathMonitor()
        m.pathUpdateHandler = { path in
            Task { @MainActor in
                let was = Mounter.shared.online
                Mounter.shared.online = path.status == .satisfied
                if !was, Mounter.shared.online { await Mounter.shared.recheck() }
            }
        }
        m.start(queue: .global(qos: .utility))
        monitor = m
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in try? await Task.sleep(nanoseconds: 5_000_000_000); await Mounter.shared.recheck() }
        }
        loop = Task { @MainActor in
            while !Task.isCancelled { try? await Task.sleep(nanoseconds: 180 * 1_000_000_000); await self.recheck() }
        }
    }

    /// Sonde chaque compte monté ; deux échecs de suite (hors panne de réseau) déclenchent un remontage.
    func recheck() async {
        for a in Store.shared.accounts where wanted.contains(a.id) {
            guard case .on(let path) = state(a) else { continue }
            if procs[a.id] == nil || !FileManager.default.fileExists(atPath: path) { await heal(a); continue }
            guard online, let spec = await Self.spec(a) else { continue }
            let r = await Rclone.run(["lsd", spec.target, "--max-depth", "0", "--timeout", "20s", "--contimeout", "10s", "--retries", "1"], env: spec.env, timeout: 60)
            if r.code == 0 { fails[a.id] = 0; continue }
            switch Veille.classify(r.out) {
            case .network, .config: fails[a.id, default: 0] += 1
            case .auth:
                Veille.shared.record(.user, service: Providers.find(a.provider)?.name ?? a.name, title: L("w.auth", a.name), detail: Rclone.lastLine(r.out))
                states[a.id] = .error(L("watch.kind.user")); continue
            case .api, .other:
                fails[a.id, default: 0] += 1
                Veille.shared.record(.code, service: Providers.find(a.provider)?.name ?? a.name, title: L("w.api", a.name), detail: Rclone.lastLine(r.out))
            }
            if fails[a.id, default: 0] >= 2 { fails[a.id] = 0; await heal(a) }
        }
    }

    /// Au lancement : remonte les comptes marqués « au démarrage ».
    func mountAtLaunch() async { for a in Store.shared.accounts where a.atLogin { await mount(a) } }

    // MARK: Outils bas niveau

    nonisolated static func freePort() -> Int {
        let s = socket(AF_INET, SOCK_STREAM, 0); defer { close(s) }
        var addr = sockaddr_in(); addr.sin_family = sa_family_t(AF_INET); addr.sin_addr.s_addr = inet_addr("127.0.0.1"); addr.sin_port = 0
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(s, $0, &len) } }
        return Int(UInt16(bigEndian: addr.sin_port))
    }

    nonisolated static func waitForPort(_ port: Int) async -> Bool {
        for _ in 0..<60 {
            let s = socket(AF_INET, SOCK_STREAM, 0)
            var addr = sockaddr_in(); addr.sin_family = sa_family_t(AF_INET); addr.sin_addr.s_addr = inet_addr("127.0.0.1")
            addr.sin_port = UInt16(port).bigEndian; addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            let ok = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } } == 0
            close(s)
            if ok { return true }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return false
    }

    /// Monte le serveur local par NetFS (sans fenêtre) : le disque apparaît dans le Finder sous /Volumes.
    nonisolated static func netMount(port: Int, vol: String, pass: String) async -> String? {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let url = URL(string: "http://127.0.0.1:\(port)/\(vol)") else { cont.resume(returning: nil); return }
                let opts = NSMutableDictionary()
                opts[kNAUIOptionKey as String] = kNAUIOptionNoUI as String
                var mp: Unmanaged<CFArray>?
                let r = NetFSMountURLSync(url as CFURL, nil, "mcloud" as CFString, pass as CFString, opts, nil, &mp)
                let paths = mp?.takeRetainedValue() as? [String]
                cont.resume(returning: (r == 0 || r == EEXIST) ? paths?.first : nil)
            }
        }
    }

    nonisolated static func eject(_ path: String) async {
        await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil"); p.arguments = ["unmount", "force", path]
                p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
                try? p.run(); p.waitUntilExit(); cont.resume()
            }
        }
    }
}
