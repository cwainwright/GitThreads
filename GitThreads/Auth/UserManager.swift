//
//  UserManager.swift
//  GitThreads
//
//  Created by Christopher Wainwright on 03/08/2025.
//

import Foundation

struct User : Identifiable, Codable {
    var id: String { username }
    let username: String
    let authorizationToken: AuthorizationToken
}

extension User : Equatable {
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.username == rhs.username
    }
}

// MARK: User Management

fileprivate extension UserDefaults {
    func string(forKey key: UserManager.Keys) -> String? {
        self.string(forKey: key.rawValue)
    }
    
    func stringArray(forKey key: UserManager.Keys) -> [String] {
        self.stringArray(forKey: key.rawValue) ?? []
    }

    func set(_ value: Any?, forKey key: UserManager.Keys) {
        self.set(value, forKey: key.rawValue)
    }
    
    func removeObject(forKey key: UserManager.Keys) {
        self.removeObject(forKey: key.rawValue)
    }
}

struct UserManager {
    enum Keys : String {
        case currentUser = "current-user"
        case storedUsers = "stored-users"
    }
    
    static var currentUsername: String? {
        get { UserDefaults.standard.string(forKey: .currentUser) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: .currentUser)
            } else {
                UserDefaults.standard.removeObject(forKey: .currentUser)
            }
        }
    }
    
    /// Get user from UserDefaults and fetch auth details from keychain
    /// Attempt to log user in from persisted data
    static func getUser() async throws -> User? {
        guard let username = currentUsername else { return nil }
        guard let token = try await KeychainStore(account: username).read(as: AuthorizationToken.self) else {
            // Authentication token does not exist, so neither should user
            UserManager.currentUsername = nil
            UserManager.LoggedIn.remove(username)
            return nil
        }
        return User(username: username, authorizationToken: token)
    }
    
    /// Get user from username and fetch auth details from keychain
    /// Attempt to laod user in from persisted data
    static func getUser(username: String) async throws -> User? {
        guard
            let token = try await KeychainStore(account: username).read(as: AuthorizationToken.self)
        else {
            // User does not exist in keychain and should be removed
            UserManager.LoggedIn.remove(username)
            return nil
        }
        return User(username: username, authorizationToken: token)
    }
    
    /// Set user details in UserDefaults and Keychain from provided data
    static func setUser(_ user: User) async throws {
        try await KeychainStore(account: user.username).save(user.authorizationToken)
        LoggedIn.add(user.username)
        currentUsername = user.username
    }
    
    /// Erase user from UserDefaults and Keychain
    static func logout(_ user: User) async throws {
        try await KeychainStore(account: user.username).delete()
        UserManager.LoggedIn.remove(user.username)
        currentUsername = nil
    }
    
    struct LoggedIn {
        static func add(_ user: String) {
            var users = get()
            if !users.contains(user) {
                users.append(user)
                UserDefaults.standard.set(users, forKey: .storedUsers)
            }
        }
        
        static func get() -> [String] {
            UserDefaults.standard.stringArray(forKey: .storedUsers)
        }
        
        static func remove(_ user: String) {
            var users = get()
            users.removeAll { $0 == user }
            UserDefaults.standard.set(users, forKey: .storedUsers)
        }
    }
}
