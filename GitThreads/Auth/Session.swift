//
//  Session.swift
//  GitThreads
//
//  Created by Christopher Wainwright on 03/08/2025.
//

import Foundation

enum SessionState {
    case loading
    case loggedOut
    case loggedIn(User)
}

@MainActor
final class Session: ObservableObject {
    
    @Published var sessionState: SessionState = .loading
    @Published var sessionError: String?
    
    func attemptStateChange<T>(change: @escaping () async throws -> T) async throws -> T {
        let tempState = sessionState
        sessionState = .loading
        do {
            let result = try await change()
            return result
        } catch {
            sessionError = error.localizedDescription
            sessionState = tempState
            throw error
        }
    }
    
    /// Attempt to load user from UserDefaults and Keychain
    func login() async throws {
        if let user = try await UserManager.getUser() {
            self.sessionState = .loggedIn(user)
        } else {
            self.sessionState = .loggedOut
        }
    }
    
    /// Store user to UserDefaults and Keychain
    func login(user: User) async throws {
        try await attemptStateChange {
            self.sessionState = .loggedIn(user)
            try await UserManager.setUser(user)
        }
    }
    
    /// Delete user from UserDefaults, Keychain and set logout state
    func logout(removeUser: Bool = true) async throws {
        switch sessionState {
        case .loggedIn(let user):
            if removeUser {
                try await UserManager.logout(user)
            }
            sessionState = .loggedOut
        default:
            // Session is either in the process of loggingOut,
            // or is loggedOut, ignore action
            return
        }
    }
    
    /// Switch to user
    func switchUser(username: String) async throws {
        try await attemptStateChange {
            if let user = try await UserManager.getUser(username: username) {
                self.sessionState = .loggedIn(user)
                UserManager.currentUsername = username
            }
        }
    }
    
    func getUsers() -> [String] {
        return UserManager.LoggedIn.get()
    }
}
