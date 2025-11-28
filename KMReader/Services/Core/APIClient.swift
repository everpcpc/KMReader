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

  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "KMReader", category: "API")

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

    let device = PlatformHelper.deviceModel
    let osVersion = PlatformHelper.osVersion
    #if canImport(UIKit)
      let platform = "iOS"
    #elseif canImport(AppKit)
      let platform = "macOS"
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

  // MARK: - Private Helpers

  private func buildRequest(
    path: String,
    method: String,
    body: Data? = nil,
    queryItems: [URLQueryItem]? = nil,
    headers: [String: String]? = nil
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

    if !AppConfig.authToken.isEmpty {
      request.addValue("Basic \(AppConfig.authToken)", forHTTPHeaderField: "Authorization")
    }

    if body != nil && request.value(forHTTPHeaderField: "Content-Type") == nil {
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    headers?.forEach { key, value in
      request.setValue(value, forHTTPHeaderField: key)
    }
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
    } catch let appError as AppErrorType {
      // Convert AppErrorType to APIError if it's a network error
      switch appError {
      case .networkUnavailable, .networkTimeout, .networkCancelled, .networkError:
        logger.error("❌ Network error for \(urlString): \(appError.description)")
        throw APIError.networkError(appError, url: urlString)
      default:
        throw APIError.networkError(appError, url: urlString)
      }
    } catch let nsError as NSError where nsError.domain == NSURLErrorDomain {
      // Convert NSError to AppErrorType first, then to APIError
      let appError = AppErrorType.from(nsError)
      logger.error("❌ Network error for \(urlString): \(appError.description)")
      throw APIError.networkError(appError, url: urlString)
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
    queryItems: [URLQueryItem]? = nil,
    headers: [String: String]? = nil
  ) async throws -> T {
    let urlRequest = try buildRequest(
      path: path, method: method, body: body, queryItems: queryItems, headers: headers)
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

  func requestOptional<T: Decodable>(
    path: String,
    method: String = "GET",
    body: Data? = nil,
    queryItems: [URLQueryItem]? = nil,
    headers: [String: String]? = nil
  ) async throws -> T? {
    let urlRequest = try buildRequest(
      path: path, method: method, body: body, queryItems: queryItems, headers: headers)
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
    let urlRequest = try buildRequest(path: path, method: method, headers: headers)
    let (data, httpResponse) = try await executeRequest(urlRequest)

    return logAndExtractDataResponse(data: data, response: httpResponse, request: urlRequest)
  }

  func requestData(
    url: URL,
    method: String = "GET",
    headers: [String: String]? = nil
  ) async throws -> (data: Data, contentType: String?, suggestedFilename: String?) {
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
