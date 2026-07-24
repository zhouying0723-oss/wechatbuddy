import Foundation
import Security

protocol APIKeyStoring: Sendable {
    func loadAPIKey() throws -> String?
    func saveAPIKey(_ apiKey: String) throws
    func deleteAPIKey() throws
}

enum APIKeyValidationError: LocalizedError, Equatable {
    case empty

    var errorDescription: String? {
        "API Key 不能为空"
    }
}

enum KeychainAPIKeyStoreError: LocalizedError, Equatable {
    case invalidStoredData
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidStoredData:
            return "Keychain 中的 API Key 数据格式无效"
        case let .unexpectedStatus(status):
            let systemMessage = SecCopyErrorMessageString(status, nil) as String?
            return "Keychain 操作失败：\(systemMessage ?? "系统错误 \(status)")"
        }
    }
}

struct APIKeyValidator {
    static func validated(_ apiKey: String) throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw APIKeyValidationError.empty
        }
        return trimmedKey
    }
}

struct KeychainAPIKeyStore: APIKeyStoring {
    static let service = "com.wechatbuddy.app.openai"
    static let account = "api-key"

    func loadAPIKey() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainAPIKeyStoreError.unexpectedStatus(status)
        }
        guard
            let data = result as? Data,
            let apiKey = String(data: data, encoding: .utf8)
        else {
            throw KeychainAPIKeyStoreError.invalidStoredData
        }
        return apiKey
    }

    func saveAPIKey(_ apiKey: String) throws {
        let validatedKey = try APIKeyValidator.validated(apiKey)
        let data = Data(validatedKey.utf8)
        let update = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            update as CFDictionary
        )

        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainAPIKeyStoreError.unexpectedStatus(updateStatus)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] =
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainAPIKeyStoreError.unexpectedStatus(addStatus)
        }
    }

    func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainAPIKeyStoreError.unexpectedStatus(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account
        ]
    }
}
