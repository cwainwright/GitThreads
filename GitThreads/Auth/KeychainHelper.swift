//
//  KeychainHelper.swift
//  GitThreads
//
//  Created by Christopher Wainwright on 03/08/2025.
//

import Foundation
import Security
import Combine


// MARK: Keychain Management

struct KeychainStore {
    let service: String = "com.cwainwright.GitThreads"
    let account: String
    
    func save(_ data: Data) async throws {
        try await delete()
        
        try await withCheckedThrowingContinuation { continuation in
            let query: [String: Any] = [
                kSecClass as String : kSecClassGenericPassword,
                kSecAttrService as String : service,
                kSecAttrAccount as String : account,
                kSecValueData as String : data
            ]
            
            let status = SecItemAdd(query as CFDictionary, nil)
            
            if status == errSecSuccess {
                continuation.resume()
            } else {
                continuation.resume(throwing: NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
            }
        }
    }
    
    func read() async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            let query: [String : Any] = [
                kSecClass as String : kSecClassGenericPassword,
                kSecAttrService as String : service,
                kSecAttrAccount as String : account,
                kSecReturnData as String : true,
                kSecMatchLimit as String : kSecMatchLimitOne
            ]
            
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            
            switch status {
                case errSecSuccess: continuation.resume(returning: item as? Data)
                case errSecItemNotFound: continuation.resume(returning: nil)
                default: continuation.resume(throwing: NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
            }
        }
    }
    
    func delete() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let query: [String : Any] = [
                kSecClass as String : kSecClassGenericPassword,
                kSecAttrService as String : service,
                kSecAttrAccount as String : account
            ]
            
            let status = SecItemDelete(query as CFDictionary)
            switch status {
                case errSecSuccess: continuation.resume()
                case errSecItemNotFound: continuation.resume()
                default: continuation.resume(throwing: NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
            }
        }
    }

    func save<T: Codable>(_ value: T, using encoder: JSONEncoder = JSONEncoder()) async throws {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(value) else { return }
        try await save(data)
    }
    
    func read<T: Codable>(as type: T.Type, using decoder: JSONDecoder = JSONDecoder()) async throws -> T? {
        guard let data = try await read() else {return nil}
        let decoder = JSONDecoder()
        return try? decoder.decode(T.self, from: data)
    }
}

