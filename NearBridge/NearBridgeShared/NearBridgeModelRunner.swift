import Foundation

public enum SandboxedModelRunnerError: String, Error, Codable, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case modelUnavailable
    case responseTooLarge
    case connectionFailed
    case malformedResponse
    case executionFailed

    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "The sandboxed model request is invalid"
        case .modelUnavailable: return "The Host-managed local generation model is unavailable"
        case .responseTooLarge: return "The sandboxed model response exceeds the registered limit"
        case .connectionFailed: return "The app-sandboxed model runner could not be reached"
        case .malformedResponse: return "The app-sandboxed model runner returned an invalid response"
        case .executionFailed: return "The Host-managed local generation model failed"
        }
    }
}

public struct SandboxedModelRequest: Codable, Equatable, Sendable {
    public let prompt: String
    public let maximumOutputCharacters: Int
    public let maximumResponseTokens: Int

    public init(prompt: String, maximumOutputCharacters: Int, maximumResponseTokens: Int) {
        self.prompt = prompt
        self.maximumOutputCharacters = maximumOutputCharacters
        self.maximumResponseTokens = maximumResponseTokens
    }

    public func validate() throws {
        let normalized = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 1_200 else {
            throw SandboxedModelRunnerError.invalidRequest
        }
        guard (1...1_200).contains(maximumOutputCharacters),
              (1...512).contains(maximumResponseTokens) else {
            throw SandboxedModelRunnerError.invalidRequest
        }
    }
}

public struct SandboxedModelResponse: Codable, Equatable, Sendable {
    public let text: String
    public let runtimeDisclosure: String

    public init(text: String, runtimeDisclosure: String) {
        self.text = text
        self.runtimeDisclosure = runtimeDisclosure
    }
}

@objc public protocol NearBridgeModelRunnerXPC {
    func generate(
        _ requestData: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    )
}

public protocol SandboxedModelRunning: Sendable {
    func generate(_ request: SandboxedModelRequest) async throws -> SandboxedModelResponse
}

public struct XPCSandboxedModelRunner: SandboxedModelRunning, Sendable {
    public static let serviceName = "org.holonia.nearbridge.model-runner"

    public init() {}

    public func generate(_ request: SandboxedModelRequest) async throws -> SandboxedModelResponse {
        try request.validate()
#if os(macOS)
        let requestData = try JSONEncoder().encode(request)
        return try await withCheckedThrowingContinuation { continuation in
            let state = XPCReplyState()
            let connectionBox = XPCConnectionBox(serviceName: Self.serviceName)
            let connection = connectionBox.connection
            connection.remoteObjectInterface = NSXPCInterface(with: NearBridgeModelRunnerXPC.self)

            let finish: @Sendable (Result<SandboxedModelResponse, Error>) -> Void = { result in
                guard state.claim() else { return }
                connectionBox.connection.invalidate()
                continuation.resume(with: result)
            }

            connection.interruptionHandler = {
                finish(.failure(SandboxedModelRunnerError.connectionFailed))
            }
            connection.invalidationHandler = {
                finish(.failure(SandboxedModelRunnerError.connectionFailed))
            }
            connection.resume()

            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 90) {
                finish(.failure(SandboxedModelRunnerError.executionFailed))
            }

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
                finish(.failure(SandboxedModelRunnerError.connectionFailed))
            }) as? NearBridgeModelRunnerXPC else {
                finish(.failure(SandboxedModelRunnerError.connectionFailed))
                return
            }

            proxy.generate(requestData) { responseData, errorCode in
                if let errorCode,
                   let runnerError = SandboxedModelRunnerError(rawValue: errorCode) {
                    finish(.failure(runnerError))
                    return
                }
                guard let responseData,
                      let response = try? JSONDecoder().decode(SandboxedModelResponse.self, from: responseData),
                      !response.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      response.text.count <= request.maximumOutputCharacters else {
                    finish(.failure(SandboxedModelRunnerError.malformedResponse))
                    return
                }
                finish(.success(response))
            }
        }
#else
        throw SandboxedModelRunnerError.modelUnavailable
#endif
    }
}

#if os(macOS)
private final class XPCReplyState: @unchecked Sendable {
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

private final class XPCConnectionBox: @unchecked Sendable {
    let connection: NSXPCConnection

    init(serviceName: String) {
        connection = NSXPCConnection(serviceName: serviceName)
    }
}
#endif
