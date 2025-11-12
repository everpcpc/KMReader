//
//  APIClient.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog

enum APIError: Error {
  case invalidURL
  case invalidResponse
  case httpError(Int, String)
  case decodingError(Error)
  case unauthorized
  case networkError(Error)
}

class APIClient {
  static let shared = APIClient()

  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Komga", category: "API")

  private var baseURL: String {
    UserDefaults.standard.string(forKey: "serverURL") ?? ""
  }

  private var authToken: String? {
    UserDefaults.standard.string(forKey: "authToken")
  }

  private init() {}

  func setServer(url: String) {
    UserDefaults.standard.set(url, forKey: "serverURL")
  }

  func setAuthToken(_ token: String?) {
    if let token = token {
      UserDefaults.standard.set(token, forKey: "authToken")
    } else {
      UserDefaults.standard.removeObject(forKey: "authToken")
    }
  }

  func request<T: Decodable>(
    path: String,
    method: String = "GET",
    body: Data? = nil,
    queryItems: [URLQueryItem]? = nil
  ) async throws -> T {
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

    if let authToken = authToken {
      request.addValue("Basic \(authToken)", forHTTPHeaderField: "Authorization")
    }

    if body != nil {
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    // Log request
    logger.info("📡 \(method) \(url.absoluteString)")

    let startTime = Date()

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      let duration = Date().timeIntervalSince(startTime)

      guard let httpResponse = response as? HTTPURLResponse else {
        logger.error("❌ Invalid response from \(url.absoluteString)")
        throw APIError.invalidResponse
      }

      // Log response
      let statusEmoji = (200...299).contains(httpResponse.statusCode) ? "✅" : "❌"
      logger.info(
        "\(statusEmoji) \(httpResponse.statusCode) \(method) \(url.absoluteString) (\(String(format: "%.2f", duration * 1000))ms)"
      )

      guard (200...299).contains(httpResponse.statusCode) else {
        if httpResponse.statusCode == 401 {
          logger.warning("🔒 Unauthorized: \(url.absoluteString)")
          throw APIError.unauthorized
        }

        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        logger.error("❌ HTTP \(httpResponse.statusCode): \(errorMessage)")
        throw APIError.httpError(httpResponse.statusCode, errorMessage)
      }

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601

      do {
        // Log response data for debugging
        if data.isEmpty {
          logger.warning("⚠️ Empty response data from \(url.absoluteString)")
        }

        return try decoder.decode(T.self, from: data)
      } catch let decodingError as DecodingError {
        // Provide detailed decoding error information
        switch decodingError {
        case .keyNotFound(let key, let context):
          logger.error(
            "❌ Missing key '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
          )
        case .typeMismatch(let type, let context):
          logger.error(
            "❌ Type mismatch for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
          )
        case .valueNotFound(let type, let context):
          logger.error(
            "❌ Value not found for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
          )
        case .dataCorrupted(let context):
          logger.error("❌ Data corrupted: \(context.debugDescription)")
        @unknown default:
          logger.error("❌ Unknown decoding error: \(decodingError.localizedDescription)")
        }

        // Log raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
          logger.debug("Response data: \(jsonString.prefix(1000))")
        }

        throw APIError.decodingError(decodingError)
      } catch {
        logger.error("❌ Decoding error for \(url.absoluteString): \(error.localizedDescription)")

        // Log raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
          logger.debug("Response data: \(jsonString.prefix(1000))")
        }

        throw APIError.decodingError(error)
      }
    } catch let error as APIError {
      throw error
    } catch {
      logger.error("❌ Network error for \(url.absoluteString): \(error.localizedDescription)")
      throw APIError.networkError(error)
    }
  }

  func requestData(
    path: String,
    method: String = "GET"
  ) async throws -> Data {
    guard let url = URL(string: baseURL + path) else {
      throw APIError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = method

    if let authToken = authToken {
      request.addValue("Basic \(authToken)", forHTTPHeaderField: "Authorization")
    }

    // Log request
    logger.info("📡 \(method) \(url.absoluteString) [Data]")

    let startTime = Date()

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      let duration = Date().timeIntervalSince(startTime)

      guard let httpResponse = response as? HTTPURLResponse else {
        logger.error("❌ Invalid response from \(url.absoluteString)")
        throw APIError.invalidResponse
      }

      // Log response with data size
      let statusEmoji = (200...299).contains(httpResponse.statusCode) ? "✅" : "❌"
      let dataSize = ByteCountFormatter.string(
        fromByteCount: Int64(data.count), countStyle: .binary)
      logger.info(
        "\(statusEmoji) \(httpResponse.statusCode) \(method) \(url.absoluteString) (\(String(format: "%.2f", duration * 1000))ms, \(dataSize))"
      )

      guard (200...299).contains(httpResponse.statusCode) else {
        if httpResponse.statusCode == 401 {
          logger.warning("🔒 Unauthorized: \(url.absoluteString)")
          throw APIError.unauthorized
        }
        logger.error("❌ HTTP \(httpResponse.statusCode): Failed to fetch data")
        throw APIError.httpError(httpResponse.statusCode, "Failed to fetch data")
      }

      return data
    } catch let error as APIError {
      throw error
    } catch {
      logger.error("❌ Network error for \(url.absoluteString): \(error.localizedDescription)")
      throw APIError.networkError(error)
    }
  }
}
