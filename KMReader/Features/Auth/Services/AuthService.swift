//
// AuthService.swift
//
//

import Foundation
import OSLog

nonisolated private struct ClientSetting: Decodable, Sendable {
  let value: String
}

nonisolated enum AuthService {
  private static let apiClient = APIClient.shared
  private static let logger = AppLogger(.auth)

  static func login(
    username: String,
    password: String,
    serverURL: String,
    rememberMe: Bool = true,
    timeout: TimeInterval? = nil
  )
    async throws -> (user: User, authToken: String)
  {
    // Create basic auth token
    let credentials = "\(username):\(password)"
    guard let credentialsData = credentials.data(using: .utf8) else {
      throw APIError.invalidURL
    }
    let base64Credentials = credentialsData.base64EncodedString()

    // 1. Validate server connection (unauthenticated)
    _ = try await validate(serverURL: serverURL)

    // 2. Perform stateful login to establish session cookies
    logger.info("🔐 Establishing session for \(username) at \(serverURL)")
    let user = try await establishSession(
      serverURL: serverURL, authToken: base64Credentials, authMethod: .basicAuth,
      rememberMe: rememberMe, timeout: timeout)

    logger.info("✅ Session established for \(username)")
    return (user: user, authToken: base64Credentials)
  }

  static func loginWithAPIKey(
    apiKey: String,
    serverURL: String,
    rememberMe: Bool = true,
    timeout: TimeInterval? = nil
  )
    async throws -> (user: User, apiKey: String)
  {
    // 1. Validate server connection (unauthenticated)
    _ = try await validate(serverURL: serverURL)

    // 2. Perform stateful login to establish session cookies
    logger.info("🔐 Establishing session with API Key at \(serverURL)")
    let user = try await establishSession(
      serverURL: serverURL, authToken: apiKey, authMethod: .apiKey, rememberMe: rememberMe,
      timeout: timeout)

    logger.info("✅ Session established with API Key")
    return (user: user, apiKey: apiKey)
  }

  static func establishSession(
    serverURL: String, authToken: String, authMethod: AuthenticationMethod = .basicAuth,
    rememberMe: Bool = true, timeout: TimeInterval? = nil
  ) async throws
    -> User
  {
    let queryItems = [URLQueryItem(name: "remember-me", value: rememberMe ? "true" : "false")]

    // Use X-Auth-Token to explicitly request a session ID in the response
    let headers = ["X-Auth-Token": ""]

    // Explicitly set the server URL in AppConfig so apiClient.request uses the correct base
    AppConfig.current.serverURL = serverURL

    return try await apiClient.performLogin(
      serverURL: serverURL,
      path: "/api/v2/users/me",
      method: "GET",
      authToken: authToken,
      authMethod: authMethod,
      queryItems: queryItems,
      headers: headers,
      timeout: timeout
    )
  }

  @concurrent
  static func logout(clearCurrent: Bool = false) async throws {
    do {
      let _: EmptyResponse = try await apiClient.request(
        path: "/api/logout",
        method: "POST",
        category: .general
      )
    } catch {
      // Continue even if logout API fails
    }

    // Clear local data
    apiClient.setAuthToken("")
    await MainActor.run {
      AppConfig.clearAuthData(clearCurrent: clearCurrent)
    }
  }

  static func validate(serverURL: String) async throws {
    // Validate server connection using unauthenticated request
    // /api/v1/client-settings/global/list allows unauthenticated access
    logger.info("📡 Testing connection to \(serverURL)")

    // Use ephemeral session to avoid any side effects
    let _: [String: ClientSetting] = try await apiClient.performLoginTemporary(
      serverURL: serverURL,
      path: "/api/v1/client-settings/global/list",
      method: "GET"
    )
    logger.info("✅ Server connection successful")
  }

  static func testCredentials(
    serverURL: String, authToken: String, authMethod: AuthenticationMethod = .basicAuth
  ) async throws -> User {
    // Stateless check
    logger.info("📡 Testing credentials for \(serverURL)")
    let user: User = try await apiClient.performLoginTemporary(
      serverURL: serverURL,
      path: "/api/v2/users/me",
      method: "GET",
      authToken: authToken,
      authMethod: authMethod
    )
    logger.info("✅ Credentials validation successful")
    return user
  }

  static func getCurrentUser(timeout: TimeInterval? = nil) async throws -> User {
    return try await apiClient.request(
      path: "/api/v2/users/me",
      bypassOfflineCheck: true,
      timeout: timeout,
      category: .auth
    )
  }

  static func getAuthenticationActivity(page: Int = 0, size: Int = 20) async throws -> Page<
    AuthenticationActivity
  > {
    let queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]
    return try await apiClient.request(
      path: "/api/v2/users/me/authentication-activity",
      queryItems: queryItems,
      category: .general
    )
  }

  static func getLatestAuthenticationActivity(apiKey: ApiKey) async throws -> AuthenticationActivity {
    let queryItems = [URLQueryItem(name: "apikey_id", value: apiKey.id)]
    return try await apiClient.request(
      path: "/api/v2/users/\(apiKey.userId)/authentication-activity/latest",
      queryItems: queryItems,
      category: .general
    )
  }

  static func getApiKeys() async throws -> [ApiKey] {
    return try await apiClient.request(
      path: "/api/v2/users/me/api-keys",
      category: .general
    )
  }

  static func createApiKey(comment: String) async throws -> ApiKey {
    let request = ApiKeyRequest(comment: comment)
    let body = try JSONEncoder().encode(request)
    return try await apiClient.request(
      path: "/api/v2/users/me/api-keys",
      method: "POST",
      body: body,
      category: .general
    )
  }

  static func deleteApiKey(id: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v2/users/me/api-keys/\(id)",
      method: "DELETE",
      category: .general
    )
  }

  static func updatePassword(userId: String, password: String) async throws {
    let body = try JSONEncoder().encode(["password": password])
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v2/users/\(userId)/password",
      method: "PATCH",
      body: body,
      category: .general
    )
  }
}
