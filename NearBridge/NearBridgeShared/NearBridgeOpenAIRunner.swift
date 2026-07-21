import Foundation

public enum RemoteModelRunnerError: String, Error, Codable, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case missingCredential
    case connectionFailed
    case unauthorized
    case rateLimited
    case providerFailed
    case malformedResponse
    case responseTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "The remote model request is invalid"
        case .missingCredential: return "Configure an OpenAI API key on the Mac Host before using this Primary Holon"
        case .connectionFailed: return "The isolated OpenAI model runner could not reach the approved endpoint"
        case .unauthorized: return "OpenAI rejected the configured API key"
        case .rateLimited: return "OpenAI rate-limited the model request"
        case .providerFailed: return "The approved OpenAI model request failed"
        case .malformedResponse: return "OpenAI returned no valid text answer"
        case .responseTooLarge: return "The OpenAI answer exceeds the registered NearBridge limit"
        }
    }
}

public struct RemoteModelRequest: Codable, Equatable, Sendable {
    public let prompt: String
    public let apiKey: String
    public let maximumOutputCharacters: Int
    public let maximumResponseTokens: Int

    public init(
        prompt: String,
        apiKey: String,
        maximumOutputCharacters: Int,
        maximumResponseTokens: Int
    ) {
        self.prompt = prompt
        self.apiKey = apiKey
        self.maximumOutputCharacters = maximumOutputCharacters
        self.maximumResponseTokens = maximumResponseTokens
    }

    public func validate() throws {
        let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPrompt.isEmpty, normalizedPrompt.count <= 1_200 else {
            throw RemoteModelRunnerError.invalidRequest
        }
        do {
            try OpenAIAPIKeyStore.validate(apiKey)
        } catch {
            throw RemoteModelRunnerError.invalidRequest
        }
        guard (1...4_000).contains(maximumOutputCharacters),
              (1...2_048).contains(maximumResponseTokens) else {
            throw RemoteModelRunnerError.invalidRequest
        }
    }
}

public struct RemoteModelResponse: Codable, Equatable, Sendable {
    public let text: String
    public let model: String
    public let runtimeDisclosure: String

    public init(text: String, model: String, runtimeDisclosure: String) {
        self.text = text
        self.model = model
        self.runtimeDisclosure = runtimeDisclosure
    }
}

@objc public protocol NearBridgeOpenAIRunnerXPC {
    func generate(
        _ requestData: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    )
}

public protocol RemoteModelRunning: Sendable {
    func generate(_ request: RemoteModelRequest) async throws -> RemoteModelResponse
}

public struct XPCRemoteModelRunner: RemoteModelRunning, Sendable {
    public static let serviceName = "org.holonia.nearbridge.openai-runner"

    public init() {}

    public func generate(_ request: RemoteModelRequest) async throws -> RemoteModelResponse {
        try request.validate()
#if os(macOS)
        let requestData = try JSONEncoder().encode(request)
        return try await withCheckedThrowingContinuation { continuation in
            let state = RemoteXPCReplyState()
            let connectionBox = RemoteXPCConnectionBox(serviceName: Self.serviceName)
            let connection = connectionBox.connection
            connection.remoteObjectInterface = NSXPCInterface(with: NearBridgeOpenAIRunnerXPC.self)

            let finish: @Sendable (Result<RemoteModelResponse, Error>) -> Void = { result in
                guard state.claim() else { return }
                connectionBox.connection.invalidate()
                continuation.resume(with: result)
            }

            connection.interruptionHandler = {
                finish(.failure(RemoteModelRunnerError.connectionFailed))
            }
            connection.invalidationHandler = {
                finish(.failure(RemoteModelRunnerError.connectionFailed))
            }
            connection.resume()

            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 120) {
                finish(.failure(RemoteModelRunnerError.connectionFailed))
            }

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
                finish(.failure(RemoteModelRunnerError.connectionFailed))
            }) as? NearBridgeOpenAIRunnerXPC else {
                finish(.failure(RemoteModelRunnerError.connectionFailed))
                return
            }

            proxy.generate(requestData) { responseData, errorCode in
                if let errorCode,
                   let runnerError = RemoteModelRunnerError(rawValue: errorCode) {
                    finish(.failure(runnerError))
                    return
                }
                guard let responseData,
                      let response = try? JSONDecoder().decode(RemoteModelResponse.self, from: responseData),
                      !response.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      response.text.count <= request.maximumOutputCharacters else {
                    finish(.failure(RemoteModelRunnerError.malformedResponse))
                    return
                }
                finish(.success(response))
            }
        }
#else
        throw RemoteModelRunnerError.connectionFailed
#endif
    }
}

public struct OpenAIHTTPResult: Sendable {
    public let data: Data
    public let statusCode: Int
    public let finalURL: URL?

    public init(data: Data, statusCode: Int, finalURL: URL?) {
        self.data = data
        self.statusCode = statusCode
        self.finalURL = finalURL
    }
}

public protocol OpenAIHTTPTransport: Sendable {
    func perform(_ request: URLRequest) async throws -> OpenAIHTTPResult
}

public final class URLSessionOpenAITransport: NSObject, OpenAIHTTPTransport, URLSessionTaskDelegate, @unchecked Sendable {
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 90
        configuration.timeoutIntervalForResource = 110
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    public override init() {
        super.init()
    }

    public func perform(_ request: URLRequest) async throws -> OpenAIHTTPResult {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteModelRunnerError.connectionFailed
        }
        return OpenAIHTTPResult(
            data: data,
            statusCode: httpResponse.statusCode,
            finalURL: httpResponse.url
        )
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

public struct OpenAIResponsesClient: Sendable {
    public static let model = "gpt-5.6-sol"
    public static let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    private let transport: any OpenAIHTTPTransport

    public init(transport: any OpenAIHTTPTransport = URLSessionOpenAITransport()) {
        self.transport = transport
    }

    public func generate(_ request: RemoteModelRequest) async throws -> RemoteModelResponse {
        let urlRequest = try makeURLRequest(for: request)
        let result: OpenAIHTTPResult
        do {
            result = try await transport.perform(urlRequest)
        } catch let error as RemoteModelRunnerError {
            throw error
        } catch {
            throw RemoteModelRunnerError.connectionFailed
        }

        guard result.finalURL?.scheme == "https",
              result.finalURL?.host == Self.endpoint.host,
              result.finalURL?.path == Self.endpoint.path else {
            throw RemoteModelRunnerError.connectionFailed
        }
        switch result.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw RemoteModelRunnerError.unauthorized
        case 429:
            throw RemoteModelRunnerError.rateLimited
        default:
            throw RemoteModelRunnerError.providerFailed
        }

        guard let decoded = try? JSONDecoder().decode(OpenAIResponseEnvelope.self, from: result.data) else {
            throw RemoteModelRunnerError.malformedResponse
        }
        let text = decoded.output
            .flatMap(\.content)
            .filter { $0.type == "output_text" }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw RemoteModelRunnerError.malformedResponse }
        guard text.count <= request.maximumOutputCharacters else {
            throw RemoteModelRunnerError.responseTooLarge
        }
        return RemoteModelResponse(
            text: text,
            model: decoded.model ?? Self.model,
            runtimeDisclosure: "OpenAI Responses API · model-only · store: false · tools: omitted"
        )
    }

    func makeURLRequest(for request: RemoteModelRequest) throws -> URLRequest {
        try request.validate()
        let body = OpenAIRequestBody(
            model: Self.model,
            instructions: "Answer the user's plain-text question directly and concisely. You have no files, workspace, commands, tools, device control, or persistent memory. Never claim that you used any of them.",
            input: request.prompt,
            maximumOutputTokens: request.maximumResponseTokens,
            store: false
        )
        var urlRequest = URLRequest(url: Self.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 90
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(request.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(body)
        return urlRequest
    }
}

private struct OpenAIRequestBody: Encodable {
    let model: String
    let instructions: String
    let input: String
    let maximumOutputTokens: Int
    let store: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case instructions
        case input
        case maximumOutputTokens = "max_output_tokens"
        case store
    }
}

private struct OpenAIResponseEnvelope: Decodable {
    struct Output: Decodable {
        let content: [Content]
    }

    struct Content: Decodable {
        let type: String
        let text: String?
    }

    let model: String?
    let output: [Output]
}

#if os(macOS)
private final class RemoteXPCReplyState: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !completed else { return false }
        completed = true
        return true
    }
}

private final class RemoteXPCConnectionBox: @unchecked Sendable {
    let connection: NSXPCConnection

    init(serviceName: String) {
        connection = NSXPCConnection(serviceName: serviceName)
    }
}
#endif
