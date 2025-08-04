//
//  GitHub App.swift
//  GitThreads
//
//  Created by Christopher Wainwright on 03/06/2025.
//

import Foundation

let CLIENT_ID = "Iv23liNQh5gHzWzzLksa"

enum GitHubAuthorizationError : Error, LocalizedError {
    case tokenError(String)
    case loginError(String)
    
    var errorDescription: String? {
        switch self {
        case .tokenError(let message):
            return "Token Error: \(message)"
        case .loginError(let message):
            return "Login Error: \(message)"
        }
    }
}

struct GitHubAuthorization {
    static func authorize(using prompt: @escaping (DeviceCodeResponse) -> Void) async throws -> User {
        let deviceCode = try await Authorization.requestDeviceCode()
        
        await MainActor.run {
            prompt(deviceCode)
        }
        
        let token: AuthorizationToken
        do {
            token = try await Authorization.getTokenResponse(deviceCode: deviceCode)
        } catch {
            throw GitHubAuthorizationError.tokenError(error.localizedDescription)
        }
        
        let username: String
        do {
            username = try await Authorization.getUser(authorizationToken: token)
        } catch {
            throw GitHubAuthorizationError.loginError(error.localizedDescription)
        }
        
        // Return account name and token
        return .init(username: username, authorizationToken: token)
    }
}

struct Authorization {
    static func requestDeviceCode() async throws -> DeviceCodeResponse {
        guard let url = URL(string: "https://github.com/login/device/code")
        else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let body = "client_id=\(CLIENT_ID)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HTTPError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(DeviceCodeResponse.self, from: data)
    }
    
    static func requestLogin(device_code: DeviceCodeResponse) {
        print("Please login at \(device_code.verificationUri)")
        print("Enter the following code: \(device_code.userCode)")
        print("Code expires in: \(device_code.expiresIn) seconds")
    }
    
    static func requestToken(deviceCode: String) async throws -> AuthorizationResponse {
        guard let url = URL(string: "https://github.com/login/oauth/access_token")
        else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let parameters: [String: String] = [
            "client_id": CLIENT_ID,
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
        ]
        
        let body = parameters.map({ "\($0.key)=\($0.value)" }).joined(separator: "&")
        
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HTTPError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        print("\(String(data: data, encoding: .utf8) ?? "Data Decode Failed")")
        
        return try decoder.decode(AuthorizationResponse.self, from:data)
    }

    static func getTokenResponse(deviceCode: DeviceCodeResponse) async throws -> AuthorizationToken {
        let timeoutThreshhold = 100
        
        var pendingAuthCount = 0
        var slowDownCount = 0
        var pollInterval = TimeInterval(deviceCode.interval)
        
        for _ in (0...timeoutThreshhold) {
            do {
                let tokenResponse = try await requestToken(deviceCode: deviceCode.deviceCode)
                
                switch tokenResponse {
                case .error(let error):
                    switch error {
                    case .authorizationPending:
                        pendingAuthCount += 1
                    case .slowDown:
                        pollInterval += 5
                        slowDownCount += 1
                    default:
                        throw HTTPError.unauthorized
                    }
                case .token(let token):
                    return token
                }
            }
            
            try await Task.sleep(for: .seconds(pollInterval))
        }
        throw AuthorizationError.timeout
    }
    
    static func getUser(authorizationToken: AuthorizationToken) async throws -> String {
        guard let url = URL(string: "https://api.github.com/user")
        else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authorizationToken.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard(200..<300).contains(httpResponse.statusCode) else {
            throw HTTPError(statusCode: httpResponse.statusCode)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let username = json["login"] as? String
        else {throw URLError(.badServerResponse)}
        
        return username
    }
}
