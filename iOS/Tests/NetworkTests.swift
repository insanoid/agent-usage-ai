import Foundation
@testable import UsageMobileCore
import XCTest

final class NetworkTests: XCTestCase {
    func testRequestAuthenticatesOnlyValidatedEndpointAndDisablesResponseCaching() throws {
        let request = try UsageClient().request(
            endpoint: ServerEndpoint("https://example.ts.net/agent-usage"),
            token: "test-only-token"
        )
        XCTAssertEqual(request.url?.absoluteString, "https://example.ts.net/agent-usage/v1/usage")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-only-token")
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertLessThanOrEqual(request.timeoutInterval, 15)
        XCTAssertThrowsError(try UsageClient().request(endpoint: ServerEndpoint("https://host"), token: ""))
    }

    func testHTTPAuthenticationAndUnavailableErrorsDoNotAcceptSuccessfulLookingBody() throws {
        for status in [301, 302, 401, 403, 500, 503] {
            let response = try XCTUnwrap(try HTTPURLResponse(
                url: XCTUnwrap(URL(string: "https://host")),
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            ))
            XCTAssertThrowsError(try UsageClient().decode(data: fixture, response: response))
        }
    }

    func testRedirectDelegateRejectsCredentialsForwardingEvenToSameHost() async throws {
        let delegate = RejectRedirects()
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let task = try session.dataTask(with: XCTUnwrap(URL(string: "https://original.example")))
        for destination in ["https://attacker.example", "https://original.example/another", "http://original.example"] {
            let redirected: URLRequest? = await withCheckedContinuation { continuation in
                delegate.urlSession(
                    session,
                    task: task,
                    willPerformHTTPRedirection: HTTPURLResponse(
                        url: task.originalRequest!.url!,
                        statusCode: 302,
                        httpVersion: nil,
                        headerFields: nil
                    )!,
                    newRequest: URLRequest(url: URL(string: destination)!)
                ) {
                    continuation.resume(returning: $0)
                }
            }
            XCTAssertNil(redirected)
        }
    }
}
