import XCTest
@testable import NearBridgeShared

final class NearBridgeOpenAIRunnerTests: XCTestCase {
    private let apiKey = "sk-test-12345678901234567890"

    func testEmbeddedRunnerInfoPlistsDeclareApplicationXPCService() throws {
        let nearBridgeRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        for relativePath in [
            "NearBridgeOpenAIRunner/Info.plist",
            "NearBridgeModelRunner/Info.plist"
        ] {
            let data = try Data(contentsOf: nearBridgeRoot.appendingPathComponent(relativePath))
            let plist = try XCTUnwrap(
                PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            )
            let xpcService = try XCTUnwrap(plist["XPCService"] as? [String: Any])
            XCTAssertEqual(xpcService["ServiceType"] as? String, "Application", relativePath)
        }
    }

    func testRequestUsesFixedEndpointModelAndNoToolsOrCredentialInBody() throws {
        let request = RemoteModelRequest(
            prompt: "What can NearBridge do?",
            apiKey: apiKey,
            maximumOutputCharacters: 4_000,
            maximumResponseTokens: 2_048
        )
        let urlRequest = try OpenAIResponsesClient(
            transport: StubOpenAITransport(result: .init(data: Data(), statusCode: 200, finalURL: OpenAIResponsesClient.endpoint))
        ).makeURLRequest(for: request)
        let body = try XCTUnwrap(urlRequest.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(urlRequest.url, OpenAIResponsesClient.endpoint)
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer \(apiKey)")
        XCTAssertEqual(json["model"] as? String, OpenAIResponsesClient.model)
        XCTAssertEqual(json["input"] as? String, "What can NearBridge do?")
        XCTAssertEqual(json["store"] as? Bool, false)
        XCTAssertEqual(json["max_output_tokens"] as? Int, 2_048)
        XCTAssertEqual(json["safety_identifier"] as? String, request.safetyIdentifier)
        XCTAssertNil(json["tools"])
        XCTAssertFalse(String(data: body, encoding: .utf8)?.contains(apiKey) ?? true)
    }

    func testResponseParserReturnsOnlyBoundedOutputText() async throws {
        let data = Data("""
        {
          "model": "gpt-5.6-sol-2026-07-01",
          "output": [
            {"content": [{"type": "output_text", "text": "A concise answer from the Mac model."}]}
          ]
        }
        """.utf8)
        let client = OpenAIResponsesClient(transport: StubOpenAITransport(result: .init(
            data: data,
            statusCode: 200,
            finalURL: OpenAIResponsesClient.endpoint
        )))

        let response = try await client.generate(RemoteModelRequest(
            prompt: "Question",
            apiKey: apiKey,
            maximumOutputCharacters: 200,
            maximumResponseTokens: 256
        ))

        XCTAssertEqual(response.text, "A concise answer from the Mac model.")
        XCTAssertEqual(response.model, "gpt-5.6-sol-2026-07-01")
    }

    func testHTTPFailuresMapWithoutReturningProviderBodyOrCredential() async {
        let client = OpenAIResponsesClient(transport: StubOpenAITransport(result: .init(
            data: Data("secret provider details".utf8),
            statusCode: 401,
            finalURL: OpenAIResponsesClient.endpoint
        )))

        do {
            _ = try await client.generate(RemoteModelRequest(
                prompt: "Question",
                apiKey: apiKey,
                maximumOutputCharacters: 200,
                maximumResponseTokens: 256
            ))
            XCTFail("Expected authorization failure")
        } catch {
            XCTAssertEqual(error as? RemoteModelRunnerError, .unauthorized)
            XCTAssertFalse(error.localizedDescription.contains(apiKey))
            XCTAssertFalse(error.localizedDescription.contains("provider details"))
        }
    }

    func testUnexpectedFinalURLIsRejected() async {
        let client = OpenAIResponsesClient(transport: StubOpenAITransport(result: .init(
            data: Data("{}".utf8),
            statusCode: 200,
            finalURL: URL(string: "https://example.com/v1/responses")
        )))

        do {
            _ = try await client.generate(RemoteModelRequest(
                prompt: "Question",
                apiKey: apiKey,
                maximumOutputCharacters: 200,
                maximumResponseTokens: 256
            ))
            XCTFail("Expected endpoint validation failure")
        } catch {
            XCTAssertEqual(error as? RemoteModelRunnerError, .connectionFailed)
        }
    }

    func testOversizedProviderAnswerIsRejected() async {
        let data = Data("""
        {
          "model": "test-model",
          "output": [
            {"content": [{"type": "output_text", "text": "123456"}]}
          ]
        }
        """.utf8)
        let client = OpenAIResponsesClient(transport: StubOpenAITransport(result: .init(
            data: data,
            statusCode: 200,
            finalURL: OpenAIResponsesClient.endpoint
        )))

        do {
            _ = try await client.generate(RemoteModelRequest(
                prompt: "Question",
                apiKey: apiKey,
                maximumOutputCharacters: 5,
                maximumResponseTokens: 256
            ))
            XCTFail("Expected bounded-output failure")
        } catch {
            XCTAssertEqual(error as? RemoteModelRunnerError, .responseTooLarge)
        }
    }

    func testCredentialAndRequestValidationRejectMalformedValues() {
        XCTAssertThrowsError(try OpenAIAPIKeyStore.validate("not-a-key"))
        XCTAssertThrowsError(try RemoteModelRequest(
            prompt: String(repeating: "x", count: 1_201),
            apiKey: apiKey,
            maximumOutputCharacters: 4_000,
            maximumResponseTokens: 2_048
        ).validate())
    }
}

private struct StubOpenAITransport: OpenAIHTTPTransport {
    let result: OpenAIHTTPResult

    func perform(_ request: URLRequest) async throws -> OpenAIHTTPResult {
        result
    }
}
