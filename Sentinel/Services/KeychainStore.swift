import Foundation
import Security

enum LegacyKeychainStoreError: LocalizedError {
    case unhandled(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "未知钥匙串错误"
            return "旧版钥匙串操作失败：\(message)（\(status)）"
        case .invalidData:
            return "旧版钥匙串中的密码摘要格式无效。"
        }
    }
}

enum LegacyKeychainStore {
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
                throw LegacyKeychainStoreError.invalidData
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw LegacyKeychainStoreError.unhandled(status)
        }
    }

}
