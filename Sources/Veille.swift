// mCLOUD — veille interne silencieuse : surveille le moteur rclone et la santé de chaque compte, et signale ici toute
// évolution d'un service en ligne qui demande une correction du code. Aucune fenêtre, aucune notification : un compteur
// dans la barre de menus et un rapport lisible (veille.md) que l'on peut transmettre tel quel pour corriger.
import Foundation

@MainActor
final class Veille: ObservableObject {
    static let shared = Veille()
    enum Kind: String, Codable { case code, user, info }
    enum Cause { case network, auth, api, other }

    struct Finding: Codable, Identifiable {
        var id = UUID()
        var date = Date()
        var kind: Kind
        var service: String
        var title: String
        var detail: String
        var url: String?
        var read = false
    }
    private struct Saved: Codable { var last: Date?; var findings: [Finding] }

    @Published private(set) var findings: [Finding] = []
    @Published private(set) var last: Date?
    @Published private(set) var running = false
    private var timer: Timer?
    var unread: Int { findings.filter { !$0.read && $0.kind != .info }.count }
    var reportURL: URL { Rclone.supportDir.appendingPathComponent("veille.md") }
    private var file: URL { Rclone.supportDir.appendingPathComponent("veille.json") }

    init() {
        if let d = try? Data(contentsOf: file), let s = try? JSONDecoder().decode(Saved.self, from: d) { findings = s.findings; last = s.last }
    }

    /// Une veille par jour, vérifiée toutes les 10 minutes ; la première 30 secondes après le lancement.
    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 600, repeats: true) { _ in Task { @MainActor in Veille.shared.tick() } }
        t.tolerance = 60
        RunLoop.main.add(t, forMode: .common)
        timer = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { Veille.shared.tick() }
    }
    private func tick() { if last == nil || Date().timeIntervalSince(last!) > 24 * 3600 { Task { await run() } } }

    func run() async {
        guard !running else { return }
        running = true
        await checkEngine()
        await probeAccounts()
        last = Date(); running = false
        persist()
    }

    // MARK: Moteur : notes de version de rclone

    private func checkEngine() async {
        let current = await Rclone.version()
        if current.isEmpty { record(.code, service: "rclone", title: L("w.engine.dead"), detail: ""); return }
        guard let url = URL(string: "https://api.github.com/repos/rclone/rclone/releases?per_page=10") else { return }
        var req = URLRequest(url: url); req.timeoutInterval = 20
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200,
              let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        let used = Set(Store.shared.accounts.map(\.provider)).compactMap { Providers.find($0) }
        var newest = ""
        for rel in list.reversed() {
            guard let tag = rel["tag_name"] as? String, VersionCompare.isNewer(tag, than: current), (rel["prerelease"] as? Bool) != true else { continue }
            newest = tag
            let body = (rel["body"] as? String) ?? "", link = rel["html_url"] as? String
            for p in used {
                let hits = Self.relevantLines(body, keywords: p.keywords)
                if !hits.isEmpty { record(.code, service: p.name, title: L("w.engine.changes", tag, p.name), detail: hits.joined(separator: "\n"), url: link) }
            }
        }
        if !newest.isEmpty { record(.info, service: "rclone", title: L("w.engine.new", newest, current), detail: "", url: "https://github.com/rclone/rclone/releases") }
    }

    /// Lignes des notes de version qui parlent d'un service utilisé ET d'un changement (correction, API, jeton, abandon…).
    static func relevantLines(_ body: String, keywords: [String]) -> [String] {
        let signals = ["fix", "break", "deprecat", "api", "oauth", "token", "chang", "remov", "drop", "no longer", "invalid"]
        let regs = keywords.compactMap { try? NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: $0))\\b", options: .caseInsensitive) }
        var out: [String] = []
        for raw in body.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: CharacterSet(charactersIn: " *-"))
            let low = line.lowercased(), r = NSRange(low.startIndex..., in: low)
            if regs.contains(where: { $0.firstMatch(in: low, range: r) != nil }), signals.contains(where: { low.contains($0) }) { out.append(String(line.prefix(220))) }
            if out.count >= 8 { break }
        }
        return out
    }

    // MARK: Santé des comptes

    private func probeAccounts() async {
        for a in Store.shared.accounts {
            guard let spec = await Mounter.spec(a) else { continue }
            let r = await Rclone.run(["lsd", spec.target, "--max-depth", "0", "--timeout", "30s", "--contimeout", "15s", "--retries", "2"], env: spec.env, timeout: 120)
            if r.code == 0 { continue }
            let name = Providers.find(a.provider)?.name ?? a.name
            switch Self.classify(r.out) {
            case .network: break
            case .auth: record(.user, service: name, title: L("w.auth", a.name), detail: Rclone.lastLine(r.out))
            case .api, .other: record(.code, service: name, title: L("w.api", a.name), detail: Rclone.lastLine(r.out))
            }
        }
    }

    nonisolated static func classify(_ out: String) -> Cause {
        let s = out.lowercased()
        let net = ["no such host", "i/o timeout", "network is unreachable", "connection refused", "connection reset", "no route to host", "dial tcp", "timeout", "temporary failure", "eof"]
        let auth = ["invalid_grant", "unauthorized", "401", "token", "expired", "reauth", "authentication", "permission denied", "login", "forbidden", "403"]
        let api = ["404", "410", "not implemented", "deprecated", "unsupported", "unknown field", "bad request", "400", "invalid argument", "unexpected", "cannot unmarshal", "json"]
        if auth.contains(where: s.contains) { return .auth }
        if api.contains(where: s.contains) { return .api }
        if net.contains(where: s.contains) { return .network }
        return .other
    }

    // MARK: Journal

    /// Ajoute un constat, sans doublon sur 7 jours (même type, service et titre).
    func record(_ kind: Kind, service: String, title: String, detail: String, url: String? = nil) {
        if findings.contains(where: { $0.kind == kind && $0.service == service && $0.title == title && Date().timeIntervalSince($0.date) < 7 * 86400 }) { return }
        findings.insert(Finding(kind: kind, service: service, title: title, detail: detail, url: url), at: 0)
        if findings.count > 200 { findings.removeLast(findings.count - 200) }
        persist()
    }

    func markAllRead() { for i in findings.indices { findings[i].read = true }; persist() }

    private func persist() {
        if let d = try? JSONEncoder().encode(Saved(last: last, findings: findings)) { try? d.write(to: file, options: .atomic) }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        var md = "# mCLOUD — veille sur les services\n\nDernière veille : \(last.map { f.string(from: $0) } ?? "jamais")\n\n"
        let todo = findings.filter { $0.kind == .code }
        md += "## À corriger dans le code (\(todo.count))\n\n"
        for x in todo { md += "- [\(f.string(from: x.date))] **\(x.service)** — \(x.title)\n" + x.detail.split(separator: "\n").map { "    - \($0)\n" }.joined() + (x.url.map { "    - \($0)\n" } ?? "") }
        md += "\n## Autres constats\n\n"
        for x in findings where x.kind != .code { md += "- [\(f.string(from: x.date))] (\(x.kind.rawValue)) **\(x.service)** — \(x.title)\n" }
        try? md.write(to: reportURL, atomically: true, encoding: .utf8)
    }
}
