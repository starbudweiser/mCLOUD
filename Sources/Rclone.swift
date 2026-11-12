// mCLOUD — moteur rclone embarqué : lancement des commandes, création des comptes.
import Foundation

enum Rclone {
    static var bin: URL { Bundle.main.resourceURL!.appendingPathComponent("rclone") }
    static var supportDir: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "fr.stephan.mcloud")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        return d
    }
    static var conf: URL { supportDir.appendingPathComponent("rclone.conf") }
    static var cacheDir: URL { supportDir.appendingPathComponent("cache") }

    static func environment(_ extra: [String: String] = [:]) -> [String: String] {
        var e = ProcessInfo.processInfo.environment
        e["RCLONE_CONFIG"] = conf.path
        e["HOME"] = NSHomeDirectory()
        for (k, v) in extra { e[k] = v }
        return e
    }

    /// Lance une commande rclone et attend sa fin (ou `timeout` secondes).
    static func run(_ args: [String], env: [String: String] = [:], input: String? = nil, timeout: TimeInterval = 120) async -> (code: Int32, out: String) {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let p = Process(), out = Pipe(), inp = Pipe()
                p.executableURL = bin
                p.arguments = ["--config", conf.path] + args
                p.environment = environment(env)
                p.standardOutput = out; p.standardError = out
                p.standardInput = input == nil ? FileHandle.nullDevice : inp
                do { try p.run() } catch { cont.resume(returning: (-1, error.localizedDescription)); return }
                if let input { inp.fileHandleForWriting.write(Data(input.utf8)); try? inp.fileHandleForWriting.close() }
                let kill = DispatchWorkItem { if p.isRunning { p.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: kill)
                let data = out.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                kill.cancel()
                cont.resume(returning: (p.terminationStatus, String(decoding: data, as: UTF8.self)))
            }
        }
    }

    static func version() async -> String {
        let r = await run(["version"], timeout: 15)
        let first = r.out.split(separator: "\n").first.map(String.init) ?? ""
        return first.replacingOccurrences(of: "rclone ", with: "").trimmingCharacters(in: .whitespaces)
    }

    static func obscure(_ plain: String) async -> String? {
        let r = await run(["obscure", "-"], input: plain, timeout: 15)
        return r.code == 0 ? r.out.trimmingCharacters(in: .whitespacesAndNewlines) : nil
    }

    struct SetupError: LocalizedError { let message: String; var errorDescription: String? { message } }

    /// Crée la définition du compte dans rclone.conf. `ask` répond aux questions en plusieurs temps (code de vérification).
    static func createRemote(name: String, provider: Provider, values: [String: String], ask: @escaping (String) async -> String?) async throws {
        var kv: [String] = []
        for (k, v) in provider.fixed { kv += [k, v] }
        for f in provider.fields { if let v = values[f.key], !v.isEmpty { kv += [f.key, v] } }
        var args = ["config", "create", name, provider.type] + kv + ["--obscure"]
        if provider.twoFactor { args.append("--non-interactive") }
        var r = await run(args, timeout: provider.oauth ? 300 : 120)
        var rounds = 0
        while provider.twoFactor, rounds < 6, let st = state(from: r.out), !st.state.isEmpty {
            rounds += 1
            guard let answer = await ask(st.help) else { _ = await run(["config", "delete", name], timeout: 15); throw SetupError(message: "—") }
            r = await run(["config", "update", name, "--continue", "--state", st.state, "--result", answer, "--non-interactive", "--obscure"], timeout: 120)
        }
        if r.code != 0 { _ = await run(["config", "delete", name], timeout: 15); throw SetupError(message: lastLine(r.out)) }
        let probe = await run(["lsd", "\(name):", "--max-depth", "0", "--timeout", "30s"], timeout: 90)
        if probe.code != 0 { _ = await run(["config", "delete", name], timeout: 15); throw SetupError(message: lastLine(probe.out)) }
    }

    static func deleteRemote(_ name: String) async { _ = await run(["config", "delete", name], timeout: 15) }

    private static func state(from out: String) -> (state: String, help: String)? {
        guard let s = out.firstIndex(of: "{"), let d = String(out[s...]).data(using: .utf8),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let st = j["State"] as? String else { return nil }
        let opt = j["Option"] as? [String: Any]
        return (st, (opt?["Help"] as? String) ?? "")
    }

    static func lastLine(_ s: String) -> String {
        let l = s.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return String((l.last(where: { $0.contains("rror") }) ?? l.last ?? "").suffix(300))
    }
}
