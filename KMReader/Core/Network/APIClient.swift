//
//  APIClient.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog

class APIClient {
  static let shared = APIClient()

  private let logger = AppLogger(.api)

  private let userAgent: String

  // URLSession with cache configuration for all requests
  private lazy var cachedSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    // Enable disk cache
    configuration.urlCache = URLCache(
      memoryCapacity: 50 * 1024 * 1024,  // 50MB memory cache
      diskCapacity: 200 * 1024 * 1024,  // 200MB disk cache
      diskPath: "komga_cache"
    )
    configuration.requestCachePolicy = .useProtocolCachePolicy
    return URLSession(configuration: configuration)
  }()

  private init() {
    let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "KMReader"
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"

    let device = PlatformHelper.deviceModel
    let osVersion = PlatformHelper.osVersion
    #if os(iOS)
      let platform = "iOS"
    #elseif os(macOS)
      let platform = "macOS"
    #elseif os(tvOS)
      let platform = "tvOS"
    #else
      let platform = "Unknown"
    #endif
    self.userAgent =
      "\(appName)/\(appVersion) (\(device); \(platform) \(osVersion); Build \(buildNumber))"
  }

  func setServer(url: String) {
    AppConfig.serverURL = url
  }

  func setAuthToken(_ token: String?) {
    AppConfig.authToken = token ?? ""
  }

  // MARK: - Temporary Request (doesn't modify global state)

  /// Execute a temporary request without modifying global APIClient state
  /// This is useful for login validation where we don't want to affect the current server connection
  func requestTemporary<T: Decodable>(
    serverURL: String,
    path: String,
    method: String = "GET",
    authToken: String? = nil,
    body: Data? = nil,
    queryItems: [URLQueryItem]? = nil,
    headers: [String: String]? = nil
  ) async throws -> T {
    try await performLoginTemporary(
      serverURL: serverURL,
      path: path,
      method: method,
      authToken: authToken,
      body: body,
      queryItems: queryItems,
      headers: headers
    )
  }

  /// Execute a login request specifically to establish session cookies
  func performLogin(
    serverURL: String,
    path: String,
    method: String = "GET",
    authToken: String,
    authMethod: AuthenticationMethod = .basicAuth,
    queryItems: [URLQueryItem]? = nil,
    headers: [String: String]? = nil
  ) async throws -> User {
    let request = try buildLoginRequest(
      serverURL: serverURL,
      path: path,
      method: method,
      queryItems: queryItems,
      headers: headers,
      authToken: authToken,
      authMethod: authMethod
    )
    let (data, httpResponse) = try await executeRequest(request, isTemporary: false)
    return try decodeResponse(data: data, httpResponse: httpResponse, request: request)
  }

  /// Execute a stateless login request for validation
  func performLoginTemporary<T: Decodable>(
    serverURL: String,
    path: String,
    method: String = "GET",
    authToken: String? = nil,
    authMethod: AuthenticationMethod = .basicAuth,
    body: Data? = nil,
    queryItems: [URLQueryItem]? = nil,
    headers: [String: String]? = nil
  ) async throws -> T {
    let request = try buildLoginRequest(
      serverURL: serverURL,
      path: path,
      method: method,
      body: body,
      queryItems: queryItems,
      headers: headers,
      authToken: authToken,
      authMethod: authMethod
    )

    // Execute request with temporary session (ephemeral, no persistent cookies)
    let tempSession = URLSession(
      configuration: {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        return config
      }())

    let (data, httpResponse) = try await executeRequest(
      request, session: tempSession, isTemporary: true)

    return try decodeResponse(data: data, httpResponse: httpResponse, request: request)
  }

  // MARK: - Private Helpers

  private func decodeResponse<T: Decodable>(
    data: Data,
    httpResponse: HTTPURLResponse,
    request: URLRequest
  ) throws -> T {
    // Handle 204 No Content responses - skip JSON decoding
    if httpResponse.statusCode == 204 || data.isEmpty {
      let expectedTypeName = String(describing: T.self)
      let emptyResponseTypeName = String(describing: EmptyResponse.self)

      if expectedTypeName == emptyResponseTypeName {
        return EmptyResponse() as! T
      } else if data.isEmpty {
        let urlString = request.url?.absoluteString ?? ""
        logger.warning("⚠️ Empty response data from \(urlString)")
        throw APIError.decodingError(
          AppErrorType.missingRequiredData(message: "Empty response data"),
          url: urlString,
          response: nil
        )
      }
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    do {
      return try decoder.decode(T.self, from: data)
    } catch let decodingError as DecodingError {
      // Provide detailed decoding error information
      switch decodingError {
      case .keyNotFound(let key, let context):
        let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
        logger.error("❌ Missing key '\(key.stringValue)' at path: \(path)")
      case .typeMismatch(let type, let context):
        let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
        logger.error("❌ Type mismatch for type '\(String(describing: type))' at path: \(path)")
      case .valueNotFound(let type, let context):
        let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
        logger.error("❌ Value not found for type '\(String(describing: type))' at path: \(path)")
      case .dataCorrupted(let context):
        logger.error("❌ Data corrupted: \(context.debugDescription)")
      @unknown default:
        logger.error("❌ Unknown decoding error: \(decodingError.localizedDescription)")
      }

      let responseBody = String(data: data, encoding: .utf8)
      if let jsonString = responseBody {
        let truncated = String(jsonString.prefix(1000))
        logger.debug("Response data: \(truncated)")
      }

      let urlString = request.url?.absoluteString ?? ""
      throw APIError.decodingError(decodingError, url: urlString, response: responseBody)
    } catch {
      let urlString = request.url?.absoluteString ?? ""
      let errorDesc = error.localizedDescription
      logger.error("❌ Decoding error for \(urlString): \(errorDesc)")

      let responseBody = String(data: data, encoding: .utf8)
      if let jsonString = responseBody {
        let truncated = String(jsonString.prefix(1000))
        logger.debug("Response data: \(truncated)")
      }

      throw APIError.decodingError(error, url: urlString, response: responseBody)
    }
  }

  private func buildRequest(
    path: String,
    method: String,
    body: Data? = nil,
    queryItems: [URLQueryItem]? = nil,
    headers: [String: String]? = nil,
    timeout: TimeInterval? = nil
  ) throws -> URLRequest {
    guard var urlComponents = URLComponents(string: AppConfig.serverURL + path) else {
      throw APIError.invalidURL
    }

    if let queryItems = queryItems {
      urlComponents.queryItems = queryItems
    }

    guard let url = urlComponents.url else {
      throw APIError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body

    configureDefaultHeaders(&request, body: body, headers: headers)

    // Add API Key header on every request when using API Key authentication
    if AppConfig.authMethod == .apiKey {
      let token = AppConfig.authToken
      if !token.isEmpty {
        request.setValue(token, forHTTPHeaderField: "X-API-Key")
      }
    }

    return request
  }

  private func buildLoginRequest(
    serverURL: String? = nil,
    path: String,
    method: String,
    body: Data? = nil,
    queryItems: [URLQueryItem]? = nil,
    headers: [String: String]? = nil,
    authToken: String? = nil,
    authMethod: AuthenticationMethod? = nil
  ) throws -> URLRequest {
    let baseURL = (serverURL ?? AppConfig.serverURL).trimmingCharacters(
      in: .whitespacesAndNewlines)
    var urlString = baseURL
    if !urlString.hasSuffix("/") {
      urlString += "/"
    }
    let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    urlString += trimmedPath

    guard var urlComponents = URLComponents(string: urlString) else {
      throw APIError.invalidURL
    }

    if let queryItems = queryItems {
      urlComponents.queryItems = queryItems
    }

    guard let url = urlComponents.url else {
      throw APIError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body

    configureDefaultHeaders(&request, body: body, headers: headers)

    // Add auth header based on the authentication method
    if let token = authToken, !token.isEmpty {
      let method = authMethod ?? AppConfig.authMethod
      switch method {
      case .basicAuth:
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
      case .apiKey:
        request.setValue(token, forHTTPHeaderField: "X-API-Key")
      }
    }

    return request
  }

  private func buildRequest(
    url: URL,
    method: String,
    body: Data? = nil,
    headers: [String: String]? = nil
  ) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    configureDefaultHeaders(&request, body: body, headers: headers)
    return request
  }

  private func configureDefaultHeaders(
    _ request: inout URLRequest,
    body: Data?,
    headers: [String: String]?
  ) {
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

    if body != nil && request.value(forHTTPHeaderField: "Content-Type") == nil {
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    headers?.forEach { key, value in
      request.setValue(value, forHTTPHeaderField: key)
    }
  }

  /// Actor to synchronize concurrent re-login attempts
  private actor ReLoginActor {
    private var reLoginTask: Task<(Data, HTTPURLResponse), Error>?

    func getReLoginTask(
      perform: @Sendable @escaping () async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
      // If there's already a re-login in progress, wait for it
      if let task = reLoginTask {
        return try await task.value
      }

      // Start a new re-login task
      let task = Task {
        defer { reLoginTask = nil }
        return try await perform()
      }

      reLoginTask = task
      return try await task.value
    }
  }

  private let reLoginActor = ReLoginActor()

  private func executeRequest(
    _ request: URLRequest,
    session: URLSession? = nil,
    isTemporary: Bool = false,
    retryCount: Int = 0
  ) async throws -> (data: Data, response: HTTPURLResponse) {
    let method = request.httpMethod ?? "GET"
    let urlString = request.url?.absoluteString ?? ""
    let prefix = isTemporary ? "[TEMP] " : ""
    logger.info("📡 \(prefix)\(method) \(urlString)")

    let startTime = Date()
    let sessionToUse = session ?? cachedSession

    do {
      let (data, response) = try await sessionToUse.data(for: request)
      let duration = Date().timeIntervalSince(startTime)

      guard let httpResponse = response as? HTTPURLResponse else {
        logger.error("❌ Invalid response from \(urlString)")
        throw APIError.invalidResponse(url: urlString)
      }

      let statusEmoji = (200...299).contains(httpResponse.statusCode) ? "✅" : "❌"
      let durationMs = String(format: "%.2f", duration * 1000)

      // Log session token if returned (for debugging bootstrap)
      if let sessionToken = httpResponse.value(forHTTPHeaderField: "X-Auth-Token") {
        logger.debug("🔑 Session token received: \(sessionToken)")
      }

      logger.info(
        "\(statusEmoji) \(prefix)\(httpResponse.statusCode) \(method) \(urlString) (\(durationMs)ms)"
      )

      guard (200...299).contains(httpResponse.statusCode) else {
        // Handle 401 Unauthorized with re-login
        // Skip re-login for API Key mode as it's stateless and included in every request
        if httpResponse.statusCode == 401 && retryCount == 0 && !isTemporary
          && AppConfig.authMethod != .apiKey
        {
          let token = AppConfig.authToken
          if !token.isEmpty {
            logger.info("🔒 Unauthorized, attempting re-login to refresh session...")

            do {
              // Create a dedicated login request with Authorization header
              let loginRequest = try buildLoginRequest(
                path: "/api/v2/users/me",
                method: "GET",
                queryItems: [URLQueryItem(name: "remember-me", value: "true")],
                headers: ["X-Auth-Token": ""],
                authToken: token
              )

              // Execute login request through the synchronization actor
              _ = try await reLoginActor.getReLoginTask { [weak self] in
                guard let self = self else {
                  throw APIError.networkError(
                    AppErrorType.missingRequiredData(message: "APIClient deallocated"),
                    url: urlString
                  )
                }
                // Use retryCount: 1 to prevent recursive 401 handling if login fails
                return try await self.executeRequest(
                  loginRequest, session: sessionToUse, isTemporary: false, retryCount: 1)
              }

              logger.info("✅ Re-login successful, retrying original request...")
              // Retry the original request UNCHANGED (relying on new session cookies)
              return try await executeRequest(
                request, session: sessionToUse, isTemporary: false, retryCount: 1)
            } catch {
              logger.error("❌ Re-login failed: \(error.localizedDescription)")
              // Fall through to throw the original 401 error or the login error
            }
          }
        }

        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        let responseBody = String(data: data, encoding: .utf8)

        switch httpResponse.statusCode {
        case 400:
          logger.warning("🔒 Bad Request: \(urlString)")
          throw APIError.badRequest(message: errorMessage, url: urlString, response: responseBody)
        case 401:
          logger.warning("🔒 Unauthorized: \(urlString)")
          throw APIError.unauthorized(url: urlString)
        case 403:
          logger.warning("🔒 Forbidden: \(urlString)")
          throw APIError.forbidden(message: errorMessage, url: urlString, response: responseBody)
        case 404:
          logger.warning("🔒 Not Found: \(urlString)")
          throw APIError.notFound(message: errorMessage, url: urlString, response: responseBody)
        case 429:
          logger.warning("🔒 Too Many Requests: \(urlString)")
          throw APIError.tooManyRequests(
            message: errorMessage, url: urlString, response: responseBody)
        case 500...599:
          // Retry on server errors if we haven't exceeded the max retry count
          // and it's not a cancellation error
          if retryCount < AppConfig.apiRetryCount {
            logger.warning(
              "⚠️ Server error, retrying (\(retryCount + 1)/\(AppConfig.apiRetryCount)): \(httpResponse.statusCode)"
            )
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // Wait 1s before retry
            return try await executeRequest(
              request, session: session, isTemporary: isTemporary, retryCount: retryCount + 1)
          }

          logger.error("❌ Server Error \(httpResponse.statusCode): \(errorMessage)")
          throw APIError.serverError(
            code: httpResponse.statusCode, message: errorMessage, url: urlString,
            response: responseBody)
        default:
          logger.error("❌ HTTP \(httpResponse.statusCode): \(errorMessage)")
          throw APIError.httpError(
            code: httpResponse.statusCode, message: errorMessage, url: urlString,
            response: responseBody)
        }
      }

      return (data, httpResponse)
    } catch let error as APIError {
      throw error
    } catch let appError as AppErrorType {
      logger.error("❌ Network error for \(urlString): \(appError.description)")
      handleNetworkError(appError)
      throw APIError.networkError(appError, url: urlString)
    } catch let nsError as NSError where nsError.domain == NSURLErrorDomain {
      let appError = AppErrorType.from(nsError)
      logger.error("❌ Network error for \(urlString): \(appError.description)")
      handleNetworkError(nsError)
      throw APIError.networkError(appError, url: urlString)
    } catch {
      // Retry on network errors if we haven't exceeded the max retry count
      // and it's not a cancellation error
      if retryCount < AppConfig.apiRetryCount && !(error is CancellationError) {
        logger.warning(
          "⚠️ Request failed, retrying (\(retryCount + 1)/\(AppConfig.apiRetryCount)): \(error.localizedDescription)"
        )
        try? await Task.sleep(nanoseconds: 1_000_000_000)  // Wait 1s before retry
        return try await executeRequest(
          request, session: session, isTemporary: isTemporary, retryCount: retryCount + 1)
      }

      logger.error("❌ Network error for \(urlString): \(error.localizedDescription)")
      handleNetworkError(error)
      throw APIError.networkError(error, url: urlString)
    }
  }

  private func handleNetworkError(_ error: Error) {
    // Only switch to offline mode if not already offline and not a temporary/login request
    guard !AppConfig.isOffline else { return }

    // Identify if the error is a network connectivity issue
    let isConnectivityIssue: Bool
    if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain {
      switch nsError.code {
      case NSURLErrorNotConnectedToInternet,
        NSURLErrorTimedOut,
        NSURLErrorCannotFindHost,
        NSURLErrorCannotConnectToHost,
        NSURLErrorNetworkConnectionLost,
        NSURLErrorResourceUnavailable:
        isConnectivityIssue = true
      default:
        isConnectivityIssue = false
      }
    } else if let appError = error as? AppErrorType {
      switch appError {
      case .networkUnavailable, .networkTimeout:
        isConnectivityIssue = true
      default:
        isConnectivityIssue = false
      }
    } else {
      isConnectivityIssue = false
    }

    if isConnectivityIssue {
      logger.info("🔌 Network issue detected, automatically switching to offline mode")
      Task { @MainActor in
        guard !AppConfig.isOffline else { return }
        AppConfig.isOffline = true
        SSEService.shared.disconnect()
        ErrorManager.shared.notify(
          message: String(localized: "notification.automaticOfflineMode")
        )
      }
    }
  }

  // MARK: - Offline Mode Check

  /// Throws APIError.offline if app is in offline mode
  /// This check is bypassed for login/authentication requests
  private func throwIfOffline() throws {
    if AppConfig.isOffline {
      throw APIError.offline
    }
  }

  func request<T: Decodable>(
    path: String,
    method: String = "GET",
    body: Data? = nil,
    queryItems: [URLQueryItem]? = nil,
    headers: [String: String]? = nil,
    bypassOfflineCheck: Bool = false,
    timeout: TimeInterval? = nil
  ) async throws -> T {
    if !bypassOfflineCheck {
      try throwIfOffline()
    }

    let urlRequest = try buildRequest(
      path: path,
      method: method,
      body: body,
      queryItems: queryItems,
      headers: headers
    )
    let (data, httpResponse) = try await executeRequest(urlRequest)

    return try decodeResponse(data: data, httpResponse: httpResponse, request: urlRequest)
  }

  func requestOptional<T: Decodable>(
    path: String,
    method: String = "GET",
    body: Data? = nil,
    queryItems: [URLQueryItem]? = nil,
    headers: [String: String]? = nil
  ) async throws -> T? {
    try throwIfOffline()

    let urlRequest = try buildRequest(
      path: path,
      method: method,
      body: body,
      queryItems: queryItems,
      headers: headers
    )
    let (data, httpResponse) = try await executeRequest(urlRequest)

    if httpResponse.statusCode == 204 || data.isEmpty {
      return nil
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    do {
      return try decoder.decode(T.self, from: data)
    } catch {
      let responseBody = String(data: data, encoding: .utf8)
      let urlString = urlRequest.url?.absoluteString ?? ""
      throw APIError.decodingError(error, url: urlString, response: responseBody)
    }
  }

  func requestData(
    path: String,
    method: String = "GET",
    headers: [String: String]? = nil
  ) async throws -> (data: Data, contentType: String?, suggestedFilename: String?) {
    try throwIfOffline()

    let urlRequest = try buildRequest(
      path: path, method: method, headers: headers)
    let (data, httpResponse) = try await executeRequest(urlRequest)

    return logAndExtractDataResponse(data: data, response: httpResponse, request: urlRequest)
  }

  func requestData(
    url: URL,
    method: String = "GET",
    headers: [String: String]? = nil
  ) async throws -> (data: Data, contentType: String?, suggestedFilename: String?) {
    try throwIfOffline()

    let urlRequest = buildRequest(url: url, method: method, headers: headers)
    let (data, httpResponse) = try await executeRequest(urlRequest)
    return logAndExtractDataResponse(data: data, response: httpResponse, request: urlRequest)
  }

  private func logAndExtractDataResponse(
    data: Data,
    response: HTTPURLResponse,
    request: URLRequest
  ) -> (data: Data, contentType: String?, suggestedFilename: String?) {
    let contentType = response.value(forHTTPHeaderField: "Content-Type")
    let suggestedFilename = filenameFromContentDisposition(
      response.value(forHTTPHeaderField: "Content-Disposition"))

    let dataSize = ByteCountFormatter.string(
      fromByteCount: Int64(data.count), countStyle: .binary)
    let method = request.httpMethod ?? "GET"
    let urlString = request.url?.absoluteString ?? ""
    logger.info("\(response.statusCode) \(method) \(urlString) [\(dataSize)]")

    return (data, contentType, suggestedFilename)
  }

  private func filenameFromContentDisposition(_ header: String?) -> String? {
    guard let header = header else { return nil }
    let parts = header.split(separator: ";")

    for part in parts {
      let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
      let lowercased = trimmed.lowercased()

      if lowercased.hasPrefix("filename*=") {
        let value = trimmed.dropFirst("filename*=".count)
        let components = value.split(
          separator: "'", maxSplits: 2, omittingEmptySubsequences: false)
        if components.count == 3 {
          let encodedFileName = String(components[2])
          return encodedFileName.removingPercentEncoding
        }
      } else if lowercased.hasPrefix("filename=") {
        var fileName = trimmed.dropFirst("filename=".count)
        if fileName.hasPrefix("\""), fileName.hasSuffix("\"") {
          fileName = fileName.dropFirst().dropLast()
        }
        return String(fileName)
      }
    }

    return nil
  }
}
