// mCLOUD — import de la liste des comptes de CloudMounter (nom, service, montage automatique, identifiant).
// Les jetons et mots de passe de CloudMounter restent dans son Trousseau : non lus. Chaque compte importé est « à autoriser ».
import Foundation

enum Importer {
    static let plist = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Preferences/com.eltima.cloudmounter.plist")
    static var available: Bool { FileManager.default.fileExists(atPath: plist.path) }

    private static let map: [String: String] = ["GDrive": "gdrive", "Dropbox": "dropbox", "OneDrive": "onedrive", "Box": "box", "PCloud": "pcloud",
                                                "Mega": "mega", "S3": "s3", "SFTP": "sftp", "FTP": "ftp", "WebDAV": "webdav", "Backblaze": "b2", "B2": "b2",
                                                "Nextcloud": "nextcloud", "Wasabi": "wasabi"]

    /// Comptes de CloudMounter pas encore présents dans mCLOUD.
    @MainActor static func read() -> [Account] {
        guard let d = NSDictionary(contentsOf: plist), let list = d["CustomPluginSettings"] as? [[String: Any]] else { return [] }
        let dropboxUsers = d["DropboxUsers"] as? [String: [String: String]] ?? [:]
        var out: [Account] = []
        for e in list {
            guard let cls = e["MountFSClassName"] as? String else { continue }
            let key = cls.replacingOccurrences(of: "Connection", with: "")
            guard let pid = map[key] ?? map.first(where: { key.hasPrefix($0.key) })?.value else { continue }
            let label = (e["MountFSLabel"] as? String) ?? (Providers.find(pid)?.name ?? key)
            if Store.shared.accounts.contains(where: { $0.name == label }) { continue }
            var hint = ""
            if let o = e["MountFSOptions"] as? [String: Any] { hint = (o["login"] as? String) ?? (o["user"] as? String) ?? "" }
            else if let id = e["MountFSOptions"] as? String, let u = dropboxUsers[id] { hint = u["email"] ?? "" }
            out.append(Account(name: label, remote: "", provider: pid, atLogin: (e["MountFSAutoMount"] as? Bool) ?? false, pending: true, hint: hint))
        }
        return out
    }

    @MainActor @discardableResult static func run() -> Int {
        let found = read()
        found.forEach { Store.shared.add($0) }
        return found.count
    }
}
