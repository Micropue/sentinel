import Foundation

struct PasswordRecord: Codable, Sendable {
    let version: Int
    let salt: Data
    let hash: Data
    let iterations: Int
}

enum PasswordRecordStoreError: LocalizedError {
    case corruptRecord
    case readFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .corruptRecord:
            return "保存的解锁凭据格式无效，请在设置中重新创建密码。"
        case .readFailed(let reason):
            return "无法读取本机解锁凭据：\(reason)"
        case .writeFailed(let reason):
            return "无法保存本机解锁凭据：\(reason)"
        }
    }
}

struct PasswordRecordStore: Sendable {
    private static let directoryName = "com.micropue.sentinel"
    private static let fileName = "unlock.json"

    let fileURL: URL

    init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        fileURL = applicationSupport
            .appendingPathComponent(Self.directoryName, isDirectory: true)
            .appendingPathComponent(Self.fileName, isDirectory: false)
    }

    func load() throws -> PasswordRecord? {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        } catch {
            if let cocoaError = error as? CocoaError,
               cocoaError.code == .fileReadNoSuchFile {
                return nil
            }
            throw PasswordRecordStoreError.readFailed(error.localizedDescription)
        }

        do {
            return try JSONDecoder().decode(PasswordRecord.self, from: data)
        } catch {
            throw PasswordRecordStoreError.corruptRecord
        }
    }

    func save(_ record: PasswordRecord) throws {
        let fileManager = FileManager.default
        let directoryURL = fileURL.deletingLastPathComponent()

        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try fileManager.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: directoryURL.path
            )

            let data = try JSONEncoder().encode(record)
            try data.write(to: fileURL, options: .atomic)
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
        } catch {
            throw PasswordRecordStoreError.writeFailed(error.localizedDescription)
        }
    }
}
