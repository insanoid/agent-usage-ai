import Foundation
import Security

struct TokenStore: Sendable {
    private func query(endpoint: String) throws -> [String: Any] {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "UsageKeychainGroup") as? String,
              !group.isEmpty else { throw APIError.keychain(errSecMissingEntitlement) }
        return [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "AgentUsageMobile.API",
                kSecAttrAccount as String: endpoint,
                kSecAttrAccessGroup as String: group]
    }

    func read(endpoint: String) throws -> String? {
        var query = try query(endpoint: endpoint)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else { throw APIError.keychain(status) }
        return token
    }

    func save(_ token: String, endpoint: String) throws {
        let query = try query(endpoint: endpoint)
        let values: [String: Any] = [kSecValueData as String: Data(token.utf8),
                                     kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            let added = SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil)
            guard added == errSecSuccess else { throw APIError.keychain(added) }
        } else if status != errSecSuccess {
            throw APIError.keychain(status)
        }
    }
}

struct UsageRepository: Sendable {
    let store: SharedStore

    func refresh() async throws -> CachedUsage {
        guard let settings = try store.settings() else { throw APIError.missingToken }
        do {
            guard let token = try TokenStore().read(endpoint: settings.endpoint) else { throw APIError.missingToken }
            let snapshot = try await UsageClient().fetch(endpoint: ServerEndpoint(settings.endpoint), token: token)
            let cache = CachedUsage(endpoint: settings.endpoint, snapshot: snapshot, fetchedAt: .now, failure: nil)
            try store.save(cache)
            return cache
        } catch {
            // Never include the response body, request, URL, or token in shared error state.
            let message = Self.message(for: error)
            try store.recordFailure(message, endpoint: settings.endpoint)
            throw error
        }
    }

    static func message(for error: Error) -> String {
        if let error = error as? APIError {
            return error.localizedDescription
        }
        if error is DecodingError {
            return "The server returned an unreadable report."
        }
        if error is URLError {
            return "Cannot reach the server. Check Tailscale and your connection."
        }
        return "Cannot read or save usage. Check device storage and App Group signing."
    }
}
