// mCLOUD — comptes enregistrés (JSON) et mots de passe de chiffrement (Trousseau).
import Foundation
import Security

struct Account: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String                // nom du disque (visible dans le Finder)
    var remote: String              // nom du compte dans rclone.conf
    var provider: String
    var encrypted = false
    var atLogin = false
    var cacheMode = "minimal"      // minimal (stockage local quasi nul) | balanced | offline
    var cacheGB = 5
    var cacheDays = 7
    var pending = false             // importé de CloudMounter : à autoriser avant le premier montage
    var hint = ""                   // identifiant ou courriel attendu pour l'autorisation
    var volumeName: String { name.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == " " }
        .trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "-").nonEmpty ?? "mCLOUD" }
}

private extension String { var nonEmpty: String? { isEmpty ? nil : self } }

@MainActor
final class Store: ObservableObject {
    static let shared = Store()
    @Published var accounts: [Account] = []
    private var file: URL { Rclone.supportDir.appendingPathComponent("accounts.json") }

    init() {
        if let d = try? Data(contentsOf: file), let a = try? JSONDecoder().decode([Account].self, from: d) { accounts = a }
    }
    func save() {
        if let d = try? JSONEncoder().encode(accounts) { try? d.write(to: file, options: .atomic) }
    }
    func add(_ a: Account) { accounts.append(a); save() }
    func update(_ a: Account) { if let i = accounts.firstIndex(where: { $0.id == a.id }) { accounts[i] = a; save() } }
    func remove(_ a: Account) { accounts.removeAll { $0.id == a.id }; Keychain.delete(a.id.uuidString); save() }
    func uniqueRemote(_ base: String) -> String {
        let slug = base.lowercased().filter { $0.isLetter || $0.isNumber }.prefix(12)
        var n = "mc\(slug)", i = 1
        while accounts.contains(where: { $0.remote == n }) { i += 1; n = "mc\(slug)\(i)" }
        return n
    }
}

enum Keychain {
    private static var service: String { (Bundle.main.bundleIdentifier ?? "fr.stephan.mcloud") + ".crypt" }
    static func set(_ key: String, _ value: String) {
        delete(key)
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: key, kSecValueData as String: Data(value.utf8)]
        SecItemAdd(q as CFDictionary, nil)
    }
    static func get(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(decoding: d, as: UTF8.self)
    }
    static func delete(_ key: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
    }
}
