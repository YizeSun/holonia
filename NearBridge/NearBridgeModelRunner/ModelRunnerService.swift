import Foundation
import FoundationModels
import NearBridgeShared

private final class ModelRunnerService: NSObject, NearBridgeModelRunnerXPC {
    func generate(
        _ requestData: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    ) {
        guard let request = try? JSONDecoder().decode(SandboxedModelRequest.self, from: requestData) else {
            reply(nil, SandboxedModelRunnerError.invalidRequest.rawValue)
            return
        }
        do {
            try request.validate()
        } catch {
            reply(nil, SandboxedModelRunnerError.invalidRequest.rawValue)
            return
        }

        Task {
            guard #available(macOS 26.0, *) else {
                reply(nil, SandboxedModelRunnerError.modelUnavailable.rawValue)
                return
            }
            let model = SystemLanguageModel.default
            guard model.availability == .available else {
                reply(nil, SandboxedModelRunnerError.modelUnavailable.rawValue)
                return
            }

            do {
                let session = LanguageModelSession(
                    model: model,
                    tools: [],
                    instructions: "Answer the user's plain-text question directly and concisely. You have no files, workspace, commands, network, credentials, tools, or device-control access. Never claim that you used any of them."
                )
                let options = GenerationOptions(
                    maximumResponseTokens: request.maximumResponseTokens
                )
                let response = try await session.respond(to: request.prompt, options: options)
                let bounded = String(
                    response.content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .prefix(request.maximumOutputCharacters)
                )
                guard !bounded.isEmpty else {
                    reply(nil, SandboxedModelRunnerError.executionFailed.rawValue)
                    return
                }
                let payload = SandboxedModelResponse(
                    text: bounded,
                    runtimeDisclosure: "Apple Foundation Models · app-sandboxed XPC · tools: none · network: denied"
                )
                reply(try JSONEncoder().encode(payload), nil)
            } catch {
                reply(nil, SandboxedModelRunnerError.executionFailed.rawValue)
            }
        }
    }
}

private final class ModelRunnerListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = ModelRunnerService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: NearBridgeModelRunnerXPC.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }
}

@main
private enum ModelRunnerMain {
    static func main() {
        let delegate = ModelRunnerListenerDelegate()
        let listener = NSXPCListener.service()
        listener.delegate = delegate
        listener.resume()
    }
}
