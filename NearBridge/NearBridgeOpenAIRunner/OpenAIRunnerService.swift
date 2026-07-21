import Foundation
import NearBridgeShared

private final class OpenAIRunnerService: NSObject, NearBridgeOpenAIRunnerXPC {
    private let client = OpenAIResponsesClient()

    func generate(
        _ requestData: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    ) {
        guard let request = try? JSONDecoder().decode(RemoteModelRequest.self, from: requestData) else {
            reply(nil, RemoteModelRunnerError.invalidRequest.rawValue)
            return
        }
        do {
            try request.validate()
        } catch let error as RemoteModelRunnerError {
            reply(nil, error.rawValue)
            return
        } catch {
            reply(nil, RemoteModelRunnerError.invalidRequest.rawValue)
            return
        }

        Task {
            do {
                let response = try await client.generate(request)
                reply(try JSONEncoder().encode(response), nil)
            } catch let error as RemoteModelRunnerError {
                reply(nil, error.rawValue)
            } catch {
                reply(nil, RemoteModelRunnerError.providerFailed.rawValue)
            }
        }
    }
}

private final class OpenAIRunnerListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = OpenAIRunnerService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: NearBridgeOpenAIRunnerXPC.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }
}

@main
private enum OpenAIRunnerMain {
    static func main() {
        let delegate = OpenAIRunnerListenerDelegate()
        let listener = NSXPCListener.service()
        listener.delegate = delegate
        listener.resume()
    }
}
