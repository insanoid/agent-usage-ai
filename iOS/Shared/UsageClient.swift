import Foundation

final class RejectRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

struct UsageClient: Sendable {
    static let timeout: TimeInterval = 12

    func request(endpoint: ServerEndpoint, token: String) throws -> URLRequest {
        guard !token.isEmpty,
              !token.contains(where: { $0.isWhitespace || $0.isNewline }) else { throw APIError.missingToken }
        var request = URLRequest(
            url: endpoint.usageURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: Self.timeout
        )
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    func fetch(endpoint: ServerEndpoint, token: String) async throws -> UsageSnapshot {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = Self.timeout
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration, delegate: RejectRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request(endpoint: endpoint, token: token))
        return try decode(data: data, response: response)
    }

    func decode(data: Data, response: URLResponse) throws -> UsageSnapshot {
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidReport }
        switch response.statusCode {
        case 200: return try UsageSnapshot.decode(data)
        case 401, 403: throw APIError.unauthorized
        case 503: throw APIError.unavailable
        default: throw APIError.http(response.statusCode)
        }
    }
}
