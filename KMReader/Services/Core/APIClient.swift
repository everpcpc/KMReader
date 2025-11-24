//
//  APIClient.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog

#if canImport(UIKit)
  import UIKit
#endif

class APIClient {
  static let shared = APIClient()

  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "KMReader", category: "API")

  private var baseURL: String {
    AppConfig.serverURL
  }

  private var authToken: String? {
    AppConfig.authToken
  }

  private let userAgent: String

  // URLSession with cache configuration for all requests
  private lazy var cachedSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    // Enable disk cache
    configuration.urlCache = URLCache(
      memoryCapacity: 50 * 1024 * 1024,  // 50MB memory cache
      diskCapacity: 500 * 1024 * 1024,  // 500MB disk cache
      diskPath: "komga_cache"
    )
    configuration.requestCachePolicy = .useProtocolCachePolicy
    return URLSession(configuration: configuration)
  }()

  private init() {
    let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "KMReader"
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"

    #if canImport(UIKit)
      let systemInfo = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
      let deviceInfo = "\(UIDevice.current.model); Build \(buildNumber)"
    #else
      let osVersion = ProcessInfo.processInfo.operatingSystemVersion
      let systemInfo =
        "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
      let deviceInfo = "Unknown; Build \(buildNumber)"
    #endif

    self.userAgent = "\(appName)/\(appVersion) (\(systemInfo); \(deviceInfo))"
  }

  func setServer(url: String) {
    AppConfig.serverURL = url
  }

  func setAuthToken(_ token: String?) {
    AppConfig.authToken = token
  }

  // MARK: - Private Helpers

  private func buildRequest(
    path: String,
    method: String,
    body: Data? = nil,
    queryItems: [URLQueryItem]? = nil
  ) throws -> URLRequest {
    guard var urlComponents = URLComponents(string: baseURL + path) else {
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

    // Set User-Agent
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

    if let authToken = authToken {
      request.addValue("Basic \(authToken)", forHTTPHeaderField: "Authorization")
    }

    if body != nil {
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    return request
  }

  private func executeRequest(_ request: URLRequest) async throws -> (
    data: Data, response: HTTPURLResponse
  ) {
    let method = request.httpMethod ?? "GET"
    let urlString = request.url?.absoluteString ?? ""
    logger.info("📡 \(method) \(urlString)")

    let startTime = Date()

    do {
      let (data, response) = try await cachedSession.data(for: request)
      let duration = Date().timeIntervalSince(startTime)

      guard let httpResponse = response as? HTTPURLResponse else {
        logger.error("❌ Invalid response from \(urlString)")
        throw APIError.invalidResponse(url: urlString)
      }

      let statusEmoji = (200...299).contains(httpResponse.statusCode) ? "✅" : "❌"
      let durationMs = String(format: "%.2f", duration * 1000)
      logger.info(
        "\(statusEmoji) \(httpResponse.statusCode) \(method) \(urlString) (\(durationMs)ms)")

      guard (200...299).contains(httpResponse.statusCode) else {
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
    } catch let nsError as NSError where nsError.domain == NSURLErrorDomain {
      logger.error("❌ Network error for \(urlString): \(nsError.localizedDescription)")
      throw APIError.networkError(nsError, url: urlString)
    } catch {
      let errorDesc = error.localizedDescription
      logger.error("❌ Network error for \(urlString): \(errorDesc)")
      throw APIError.networkError(error, url: urlString)
    }
  }

  func request<T: Decodable>(
    path: String,
    method: String = "GET",
    body: Data? = nil,
    queryItems: [URLQueryItem]? = nil
  ) async throws -> T {
    let urlRequest = try buildRequest(
      path: path, method: method, body: body, queryItems: queryItems)
    let (data, httpResponse) = try await executeRequest(urlRequest)

    // Handle 204 No Content responses - skip JSON decoding
    if httpResponse.statusCode == 204 || data.isEmpty {
      // Check if we're expecting an EmptyResponse by comparing type names
      let expectedTypeName = String(describing: T.self)
      let emptyResponseTypeName = String(describing: EmptyResponse.self)

      if expectedTypeName == emptyResponseTypeName {
        // Return empty response instance for 204/empty responses
        return EmptyResponse() as! T
      } else if data.isEmpty {
        // For non-empty response types, empty data is an error
        let urlString = urlRequest.url?.absoluteString ?? ""
        logger.warning("⚠️ Empty response data from \(urlString)")
        throw APIError.decodingError(
          NSError(
            domain: "APIClient", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Empty response data"]),
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

      // Log raw response for debugging
      let responseBody = String(data: data, encoding: .utf8)
      if let jsonString = responseBody {
        let truncated = String(jsonString.prefix(1000))
        logger.debug("Response data: \(truncated)")
      }

      let urlString = urlRequest.url?.absoluteString ?? ""
      throw APIError.decodingError(decodingError, url: urlString, response: responseBody)
    } catch {
      let urlString = urlRequest.url?.absoluteString ?? ""
      let errorDesc = error.localizedDescription
      logger.error("❌ Decoding error for \(urlString): \(errorDesc)")

      // Log raw response for debugging
      let responseBody = String(data: data, encoding: .utf8)
      if let jsonString = responseBody {
        let truncated = String(jsonString.prefix(1000))
        logger.debug("Response data: \(truncated)")
      }

      throw APIError.decodingError(error, url: urlString, response: responseBody)
    }
  }

  func requestData(
    path: String,
    method: String = "GET"
  ) async throws -> (data: Data, contentType: String?) {
    let urlRequest = try buildRequest(path: path, method: method)
    let (data, httpResponse) = try await executeRequest(urlRequest)

    // Get content type from response
    let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")

    // Log response with data size
    let dataSize = ByteCountFormatter.string(
      fromByteCount: Int64(data.count), countStyle: .binary)
    let method = urlRequest.httpMethod ?? "GET"
    let urlString = urlRequest.url?.absoluteString ?? ""
    logger.info("\(httpResponse.statusCode) \(method) \(urlString) [\(dataSize)]")

    return (data, contentType)
  }
}
