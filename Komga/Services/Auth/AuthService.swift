//
//  AuthService.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

class AuthService {
  static let shared = AuthService()
  private let apiClient = APIClient.shared

  private init() {}

  func login(username: String, password: String, serverURL: String, rememberMe: Bool = true)
    async throws -> User
  {
    // Set server URL
    apiClient.setServer(url: serverURL)

    // Create basic auth token
    let credentials = "\(username):\(password)"
    guard let credentialsData = credentials.data(using: .utf8) else {
      throw APIError.invalidURL
    }
    let base64Credentials = credentialsData.base64EncodedString()

    // Set auth token temporarily for the login request
    apiClient.setAuthToken(base64Credentials)

    // Try to get user info with basic auth to verify login
    let queryItems = [URLQueryItem(name: "remember-me", value: rememberMe ? "true" : "false")]
    let user: User = try await apiClient.request(
      path: "/api/v2/users/me", queryItems: queryItems)

    // Store credentials if successful
    AppConfig.username = username
    AppConfig.isLoggedIn = true

    return user
  }

  func logout() async throws {
    // Call logout API
    do {
      let _: EmptyResponse = try await apiClient.request(path: "/api/logout", method: "POST")
    } catch {
      // Continue even if logout API fails
    }

    // Clear local data
    apiClient.setAuthToken(nil)
    AppConfig.clearAuthData()
  }

  func isLoggedIn() -> Bool {
    return AppConfig.isLoggedIn
  }

  func getCurrentUser() async throws -> User {
    return try await apiClient.request(path: "/api/v2/users/me")
  }

  func getAuthenticationActivity(page: Int = 0, size: Int = 20) async throws -> Page<
    AuthenticationActivity
  > {
    let queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]
    return try await apiClient.request(
      path: "/api/v2/users/me/authentication-activity",
      queryItems: queryItems
    )
  }
}
