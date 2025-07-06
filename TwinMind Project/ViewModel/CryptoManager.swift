//
//  CryptoManager.swift
//  TwinMind Project
//
//  Created by Kyle Peters on 7/5/25.
//

import Foundation
import CryptoKit
import Security

final class CryptoManager {
    static let shared = CryptoManager()
    private let keyTag = "com.twinmind.audioencryption.key"
    private var key: SymmetricKey

    private init() {
        if let storedKey = CryptoManager.loadKey(tag: keyTag) {
            key = storedKey
        } else {
            key = SymmetricKey(size: .bits256)
            CryptoManager.saveKey(key, tag: keyTag)
        }
    }

    func encrypt(data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }

    func decrypt(data: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    private static func saveKey(_ key: SymmetricKey, tag: String) {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadKey(tag: String) -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return SymmetricKey(data: data)
        }
        return nil
    }
}

