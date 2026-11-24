import Foundation
import Security

enum KeychainStoreError: LocalizedError {
    case unhandled(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "未知钥匙串错误"
            return "钥匙串操作失败：\(message)（\(status)）"
        case .invalidData:
            return "钥匙串中的密码数据格式无效。"
        }
    }
}

enum KeychainStore {
    private static let service = "com.micropue.sentinel"
    private static let account = "unlock-password"

    static func readPasswordData() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainStoreError.invalidData
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainStoreError.unhandled(status)
        }
    }

    static func savePasswordData(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrLabel as String: "Sentinel 解锁密码",
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw KeychainStoreError.unhandled(updateStatus)
        }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.unhandled(addStatus)
        }
    }

    static func deletePasswordData() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unhandled(status)
        }
    }
}
