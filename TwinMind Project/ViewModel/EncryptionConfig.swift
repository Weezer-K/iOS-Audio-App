//
//  EncryptionConfig.swift
//  TwinMind Project
//
//  Created by Kyle Peters on 7/4/25.
//

import CryptoKit
import Foundation

import CryptoKit
import Foundation

enum EncryptionConfig {
  static let keyTag = "com.twinmind.audioencryption.key"

  static let sharedKey: SymmetricKey = {
    if let existing = KeychainHelper.loadKey(forKey: keyTag) {
      return existing
    } else {
      let newKey = SymmetricKey(size: .bits256)
      try? KeychainHelper.save(key: newKey, forKey: keyTag)
      return newKey
    }
  }()

  static func encrypt(_ data: Data) throws -> Data {
    let box = try AES.GCM.seal(data, using: sharedKey)
    guard let combined = box.combined else {
      throw NSError(
        domain: "Encryption", code: 0,
        userInfo: [NSLocalizedDescriptionKey: "seal failed"]
      )
    }
    return combined
  }

  static func decrypt(_ data: Data) throws -> Data {
    let box = try AES.GCM.SealedBox(combined: data)
    return try AES.GCM.open(box, using: sharedKey)
  }
}

enum KeychainHelper {
    static func save(key: SymmetricKey, forKey keyName: String) throws {
        let data = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String:             kSecClassGenericPassword,
            kSecAttrAccount as String:       keyName,
            kSecValueData as String:         data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func loadKey(forKey keyName: String) -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrAccount as String:     keyName,
            kSecMatchLimit as String:      kSecMatchLimitOne,
            kSecReturnData as String:      true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return SymmetricKey(data: data)
        }
        return nil
    }

    static private let apiKeyTag = "com.twinmind.deepgramApiKey"
    static private let encryptionKeyTag = "com.twinmind.encryptionKey"

    static func saveAPIKey(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        let query: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrAccount as String:     apiKeyTag,
            kSecValueData as String:       data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrAccount as String:     apiKeyTag,
            kSecMatchLimit as String:      kSecMatchLimitOne,
            kSecReturnData as String:      true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    static func saveEncryptionKey(_ key: SymmetricKey) throws {
        try save(key: key, forKey: encryptionKeyTag)
    }
    
    static func loadEncryptionKey() -> SymmetricKey? {
        return loadKey(forKey: encryptionKeyTag)
    }
}
