//
//  EncryptionConfig.swift
//

import CryptoKit
import Foundation
import SwiftUICore

enum EncryptionConfig {
    private static let keyKey = "encryptionSymmetricKey"

    static var sharedKey: SymmetricKey = {
        if let base64 = UserDefaults.standard.string(forKey: keyKey),
           let data = Data(base64Encoded: base64) {
            return SymmetricKey(data: data)
        } else {
            let key = SymmetricKey(size: .bits256)
            let base64 = key.withUnsafeBytes { Data($0).base64EncodedString() }
            UserDefaults.standard.set(base64, forKey: keyKey)
            return key
        }
    }()

    static func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: sharedKey)
        guard let combined = sealedBox.combined else {
            throw NSError(domain: "Encryption", code: -1)
        }
        return combined
    }

    static func decrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: sharedKey)
    }
}

enum KeychainHelper {
    static func save(key: SymmetricKey, forKey keyName: String) throws {
        let data = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyName,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func loadKey(forKey keyName: String) -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return SymmetricKey(data: data)
    }
}
