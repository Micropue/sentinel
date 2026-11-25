import CryptoKit
import Foundation
import Security

enum PasswordVaultError: LocalizedError {
    case invalidFormat
    case corruptRecord
    case alreadyConfigured
    case legacyPasswordUnavailable
    case legacyImportInProgress
    case locked
    case randomGenerationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "解锁密码必须恰好为 6 位数字。"
        case .corruptRecord:
            return "保存的解锁凭据无法读取，请在设置中重新设置密码。"
        case .alreadyConfigured:
            return "当前已经设置了本机解锁密码。"
        case .legacyPasswordUnavailable:
            return "旧版钥匙串中没有可导入的解锁密码。"
        case .legacyImportInProgress:
            return "请先完成或取消当前的旧版密码读取操作。"
        case .locked:
            return "锁定期间不能修改解锁凭据。"
        case .randomGenerationFailed(let status):
            return "无法生成安全随机数（\(status)）。"
        }
    }
}

struct PasswordVault: Sendable {
    static let passwordLength = 6
    private static let iterationCount = 210_000
    private static let saltLength = 16
    private static let keyLength = 32

    private let store: PasswordRecordStore

    init(store: PasswordRecordStore = PasswordRecordStore()) {
        self.store = store
    }

    var hasPassword: Bool {
        (try? store.load()) != nil
    }

    static func validateFormat(_ password: String) throws {
        let scalars = password.unicodeScalars
        guard scalars.count == passwordLength,
              scalars.allSatisfy({ $0.value >= 48 && $0.value <= 57 })
        else {
            throw PasswordVaultError.invalidFormat
        }
    }

    func setPassword(_ password: String) throws {
        try Self.validateFormat(password)
        let salt = try Self.randomSalt()
        let passwordData = Data(password.utf8)

        guard let hash = Self.pbkdf2(
            password: passwordData,
            salt: salt,
            iterations: Self.iterationCount,
            keyLength: Self.keyLength
        ) else {
            throw PasswordVaultError.corruptRecord
        }

        let record = PasswordRecord(
            version: 1,
            salt: salt,
            hash: hash,
            iterations: Self.iterationCount
        )
        try store.save(record)
    }

    @discardableResult
    func importLegacyPasswordRecord() throws -> Bool {
        if (try? store.load()) != nil {
            throw PasswordVaultError.alreadyConfigured
        }

        guard let data = try LegacyKeychainStore.readPasswordData() else {
            return false
        }

        let record = try Self.decodeRecord(data)
        try store.save(record)
        return true
    }

    func verify(_ password: String) async -> Bool {
        guard let record = try? recordForVerification() else {
            return false
        }
        let passwordData = Data(password.utf8)

        return await Task.detached(priority: .userInitiated) {
            guard let candidate = Self.pbkdf2(
                password: passwordData,
                salt: record.salt,
                iterations: record.iterations,
                keyLength: record.hash.count
            ) else {
                return false
            }
            return Self.constantTimeEqual(candidate, record.hash)
        }.value
    }

    private func recordForVerification() throws -> PasswordRecord {
        guard let record = try? store.load() else {
            throw PasswordVaultError.corruptRecord
        }
        guard record.version == 1,
              !record.salt.isEmpty,
              record.hash.count == Self.keyLength,
              record.iterations > 0,
              record.iterations <= 1_000_000
        else {
            throw PasswordVaultError.corruptRecord
        }
        return record
    }

    private static func decodeRecord(_ data: Data) throws -> PasswordRecord {
        guard let record = try? JSONDecoder().decode(PasswordRecord.self, from: data),
              record.version == 1,
              !record.salt.isEmpty,
              record.hash.count == keyLength,
              record.iterations > 0,
              record.iterations <= 1_000_000
        else {
            throw PasswordVaultError.corruptRecord
        }
        return record
    }

    private static func randomSalt() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: saltLength)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, saltLength, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw PasswordVaultError.randomGenerationFailed(status)
        }
        return Data(bytes)
    }

    private static func pbkdf2(
        password: Data,
        salt: Data,
        iterations: Int,
        keyLength: Int
    ) -> Data? {
        guard iterations > 0, keyLength > 0 else {
            return nil
        }

        let key = SymmetricKey(data: password)
        let digestLength = 32
        let blockCount = Int(ceil(Double(keyLength) / Double(digestLength)))
        var derived = Data()

        for blockIndex in 1...blockCount {
            var blockSalt = salt
            var bigEndianIndex = UInt32(blockIndex).bigEndian
            withUnsafeBytes(of: &bigEndianIndex) {
                blockSalt.append(contentsOf: $0)
            }

            var u = Data(HMAC<SHA256>.authenticationCode(for: blockSalt, using: key))
            var accumulator = u

            if iterations > 1 {
                for _ in 1..<iterations {
                    u = Data(HMAC<SHA256>.authenticationCode(for: u, using: key))
                    for index in accumulator.indices {
                        accumulator[index] ^= u[index]
                    }
                }
            }

            derived.append(accumulator)
        }

        guard derived.count >= keyLength else {
            return nil
        }
        return Data(derived.prefix(keyLength))
    }

    private static func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }

        var difference: UInt8 = 0
        for index in lhs.indices {
            difference |= lhs[index] ^ rhs[index]
        }
        return difference == 0
    }
}
