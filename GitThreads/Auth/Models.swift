//
//  GitHubAuthModels.swift
//  GitThreads
//
//  Created by Christopher Wainwright on 03/08/2025.
//

import Foundation

enum HTTPError: Error, LocalizedError {
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case internalServerError
    case unknown(Int)

    init(statusCode: Int) {
        switch statusCode {
        case 400: self = .badRequest
        case 401: self = .unauthorized
        case 403: self = .forbidden
        case 404: self = .notFound
        case 500: self = .internalServerError
        default: self = .unknown(statusCode)
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .badRequest: return "Bad Request"
        case .unauthorized: return "Unauthorized"
        case .forbidden: return "Forbidden"
        case .notFound: return "Not Found"
        case .internalServerError: return "Internal Server Error"
        case .unknown(let errorCode): return "Unknown, HTTP Code: \(errorCode)"
        }
    }
}

struct DeviceCodeResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int
}

struct AuthorizationToken : Codable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String
    let refreshTokenExpiresIn: Int
}

enum AuthorizationError : String, Codable, Error {
    case authorizationPending = "authorization_pending"
    case slowDown = "slow_down"
    case accessDenied = "access_denied"
    case invalidGrant = "invalid_grant"
    case expiredToken = "expired_token"
    case timeout = "request_timeout"
    case invalidFormat = "invalid_format"
}

enum AuthorizationResponse : Codable {
    case token(AuthorizationToken)
    case error(AuthorizationError)
    
    enum CodingKeys: String, CodingKey {
        case error
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let error = try? container.decodeIfPresent(AuthorizationError.self, forKey: .error) {
            self = .error(error)
        } else {
            if let token = try? AuthorizationToken(from: decoder) {
                self = .token(token)
            } else {
                print("Stage Failed")
                self = .error(.invalidFormat)
            }
        }
    }
}
