// mCLOUD — services pris en charge (moteur rclone). Une entrée par service ; `keywords` sert à la veille.
import Foundation

struct Field: Identifiable {
    let key: String            // clé rclone
    let label: String          // clé L10n
    var secret = false         // champ masqué, mot de passe « obscurci » par rclone
    var optional = false
    var id: String { key }
}

struct Provider: Identifiable {
    let id: String
    let name: String
    let type: String                    // type rclone
    var fixed: [String: String] = [:]
    var fields: [Field] = []
    var oauth = false                   // autorisation dans le navigateur
    var twoFactor = false               // questions successives (code reçu)
    var symbol = "cloud"
    var keywords: [String] = []         // mots repérés dans les notes de version de rclone
}

enum Providers {
    private static let oauthOptional = [Field(key: "client_id", label: "f.client_id", optional: true),
                                        Field(key: "client_secret", label: "f.client_secret", secret: true, optional: true)]
    static var all: [Provider] {
        var l: [Provider] = [
            Provider(id: "gdrive", name: "Google Drive", type: "drive", fixed: ["scope": "drive"], fields: oauthOptional, oauth: true, symbol: "externaldrive.connected.to.line.below", keywords: ["drive", "google"]),
            Provider(id: "dropbox", name: "Dropbox", type: "dropbox", fields: oauthOptional, oauth: true, symbol: "shippingbox", keywords: ["dropbox"]),
            Provider(id: "onedrive", name: "OneDrive", type: "onedrive", fields: oauthOptional, oauth: true, symbol: "cloud", keywords: ["onedrive", "sharepoint", "microsoft", "graph"]),
            Provider(id: "icloud", name: "iCloud Drive", type: "iclouddrive", fields: [Field(key: "apple_id", label: "f.apple_id"), Field(key: "password", label: "f.pass", secret: true)], twoFactor: true, symbol: "icloud", keywords: ["icloud", "apple"]),
            Provider(id: "box", name: "Box", type: "box", fields: oauthOptional, oauth: true, symbol: "archivebox", keywords: ["box"]),
            Provider(id: "pcloud", name: "pCloud", type: "pcloud", fields: oauthOptional, oauth: true, symbol: "cloud.fill", keywords: ["pcloud"]),
            Provider(id: "mega", name: "MEGA", type: "mega", fields: [Field(key: "user", label: "f.user"), Field(key: "pass", label: "f.pass", secret: true)], symbol: "m.circle", keywords: ["mega"]),
            Provider(id: "s3", name: "Amazon S3", type: "s3", fixed: ["provider": "AWS"], fields: [Field(key: "access_key_id", label: "f.access_key"), Field(key: "secret_access_key", label: "f.secret_key", secret: true), Field(key: "region", label: "f.region", optional: true)], symbol: "server.rack", keywords: ["s3", "aws"]),
            Provider(id: "b2", name: "Backblaze B2", type: "b2", fields: [Field(key: "account", label: "f.account"), Field(key: "key", label: "f.key", secret: true)], symbol: "flame", keywords: ["b2", "backblaze"]),
            Provider(id: "wasabi", name: "Wasabi", type: "s3", fixed: ["provider": "Wasabi", "endpoint": "s3.wasabisys.com"], fields: [Field(key: "access_key_id", label: "f.access_key"), Field(key: "secret_access_key", label: "f.secret_key", secret: true), Field(key: "region", label: "f.region", optional: true)], symbol: "server.rack", keywords: ["wasabi"]),
            Provider(id: "s3other", name: "S3", type: "s3", fixed: ["provider": "Other"], fields: [Field(key: "endpoint", label: "f.endpoint"), Field(key: "access_key_id", label: "f.access_key"), Field(key: "secret_access_key", label: "f.secret_key", secret: true), Field(key: "region", label: "f.region", optional: true)], symbol: "server.rack", keywords: ["s3"]),
            Provider(id: "sftp", name: "SFTP", type: "sftp", fields: [Field(key: "host", label: "f.host"), Field(key: "user", label: "f.user"), Field(key: "port", label: "f.port", optional: true), Field(key: "pass", label: "f.pass", secret: true, optional: true), Field(key: "key_file", label: "f.keyfile", optional: true)], symbol: "terminal", keywords: ["sftp", "ssh"]),
            Provider(id: "ftp", name: "FTP", type: "ftp", fields: [Field(key: "host", label: "f.host"), Field(key: "user", label: "f.user"), Field(key: "port", label: "f.port", optional: true), Field(key: "pass", label: "f.pass", secret: true)], symbol: "arrow.up.arrow.down.circle", keywords: ["ftp"]),
            Provider(id: "nextcloud", name: "Nextcloud", type: "webdav", fixed: ["vendor": "nextcloud"], fields: [Field(key: "url", label: "f.url"), Field(key: "user", label: "f.user"), Field(key: "pass", label: "f.pass", secret: true)], symbol: "cloud.bolt", keywords: ["nextcloud", "webdav"]),
            Provider(id: "webdav", name: "WebDAV", type: "webdav", fixed: ["vendor": "other"], fields: [Field(key: "url", label: "f.url"), Field(key: "user", label: "f.user", optional: true), Field(key: "pass", label: "f.pass", secret: true, optional: true)], symbol: "network", keywords: ["webdav"]),
        ]
        if (Bundle.main.bundleIdentifier ?? "").hasSuffix(".dev") {   // essais sans compte réel
            l.append(Provider(id: "local", name: "Dossier local (test)", type: "local", fields: [Field(key: "root", label: "f.path")], symbol: "folder"))
        }
        return l
    }
    static func find(_ id: String) -> Provider? { all.first { $0.id == id } }
}
