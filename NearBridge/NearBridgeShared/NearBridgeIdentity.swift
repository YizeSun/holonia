import CryptoKit
import Foundation
import Security

public struct NearBridgeNodeIdentity: Codable, Equatable, Sendable {
    public let nodeID: String
    public let publicKeyBase64: String

    public var fingerprint: String {
        String(nodeID.prefix(12)).uppercased()
    }
}

public enum HostIdentityError: Error, LocalizedError {
    case keychain(OSStatus)
    case invalidStoredKey

    public var errorDescription: String? {
        switch self {
        case .keychain(let status): return "Keychain operation failed (\(status))"
        case .invalidStoredKey: return "The stored NearBridge identity key is invalid"
        }
    }
}

final class KeychainBlobStore {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func read(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw HostIdentityError.keychain(status) }
        return item as? Data
    }

    func write(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw HostIdentityError.keychain(updateStatus) }

        var addition = query
        addition[kSecValueData as String] = data
        addition[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addition as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw HostIdentityError.keychain(addStatus) }
    }

    func remove(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw HostIdentityError.keychain(status)
        }
    }
}

public final class HostIdentityManager {
    private let privateKey: P256.Signing.PrivateKey
    public let identity: NearBridgeNodeIdentity

    public init(privateKeyData: Data) throws {
        do {
            privateKey = try P256.Signing.PrivateKey(rawRepresentation: privateKeyData)
        } catch {
            throw HostIdentityError.invalidStoredKey
        }
        let publicKey = privateKey.publicKey.rawRepresentation
        identity = NearBridgeNodeIdentity(
            nodeID: Self.hexDigest(SHA256.hash(data: publicKey)),
            publicKeyBase64: publicKey.base64EncodedString()
        )
    }

    public static func loadOrCreate() throws -> HostIdentityManager {
        let store = KeychainBlobStore(service: "org.holonia.nearbridge.host")
        let account = "p256-signing-private-key-v1"
        if let stored = try store.read(account: account) {
            return try HostIdentityManager(privateKeyData: stored)
        }
        let key = P256.Signing.PrivateKey()
        try store.write(key.rawRepresentation, account: account)
        return try HostIdentityManager(privateKeyData: key.rawRepresentation)
    }

    public static func ephemeral() throws -> HostIdentityManager {
        try HostIdentityManager(privateKeyData: P256.Signing.PrivateKey().rawRepresentation)
    }

    public func sign(_ data: Data) throws -> Data {
        try privateKey.signature(for: data).derRepresentation
    }

    public static func verify(signature: Data, data: Data, publicKey: Data) -> Bool {
        guard
            let key = try? P256.Signing.PublicKey(rawRepresentation: publicKey),
            let signature = try? P256.Signing.ECDSASignature(derRepresentation: signature)
        else { return false }
        return key.isValidSignature(signature, for: data)
    }

    public static func nodeID(for publicKey: Data) -> String {
        hexDigest(SHA256.hash(data: publicKey))
    }

    private static func hexDigest<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
