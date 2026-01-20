//
//  APIError.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum APIError: Error, CustomStringConvertible, LocalizedError {
  case invalidURL
  case invalidResponse(url: String?)
  case httpError(code: Int, message: String, url: String?, response: String?, request: String?)
  case decodingError(Error, url: String?, response: String?)
  case unauthorized(url: String?)
  case networkError(Error, url: String?)
  case badRequest(message: String, url: String?, response: String?, request: String?)
  case forbidden(message: String, url: String?, response: String?, request: String?)
  case notFound(message: String, url: String?, response: String?, request: String?)
  case tooManyRequests(message: String, url: String?, response: String?, request: String?)
  case serverError(code: Int, message: String, url: String?, response: String?, request: String?)
  case offline

  private static func truncateResponse(_ response: String?) -> String? {
    guard let response = response, !response.isEmpty else {
      return nil
    }
    let maxLength = 500
    if response.count <= maxLength {
      return response
    }
    return String(response.prefix(maxLength)) + "..."
  }

  private static func formatError(
    title: String,
    code: Int? = nil,
    url: String? = nil,
    response: String? = nil,
    request: String? = nil
  ) -> String {
    var parts: [String] = []

    if let url = url {
      parts.append("URL: \(url)")
    }

    if let code = code {
      parts.append("Status: \(code)")
    }

    if let truncated = truncateResponse(response) {
      parts.append("Response: \(truncated)")
    }

    if let request = request, !request.isEmpty {
      parts.append("Request: \(request)")
    }

    if parts.isEmpty {
      return title
    }

    return "\(title)\n\(parts.joined(separator: "\n"))"
  }

  var description: String {
    switch self {
    case .invalidURL:
      return "Invalid server URL"
    case .invalidResponse(let url):
      return Self.formatError(title: "Invalid response from server", url: url)
    case .httpError(let code, let message, let url, let response, let request):
      return Self.formatError(
        title: "Server error (\(code)): \(message)",
        code: code,
        url: url,
        response: response,
        request: request
      )
    case .decodingError(let error, let url, let response):
      return Self.formatError(
        title: "Failed to decode response: \(error.localizedDescription)",
        url: url,
        response: response
      )
    case .unauthorized(let url):
      return Self.formatError(
        title: "Unauthorized. Please check your credentials.",
        code: 401,
        url: url
      )
    case .networkError(let error, let url):
      let errorMessage: String
      // Handle AppErrorType first
      if let appError = error as? AppErrorType {
        errorMessage = appError.description
      } else if let nsError = error as NSError? {
        // Convert NSError to AppErrorType
        let appError = AppErrorType.from(nsError)
        errorMessage = appError.description
      } else {
        errorMessage = "Network error: \(error.localizedDescription)"
      }
      return Self.formatError(title: errorMessage, url: url)
    case .badRequest(let message, let url, let response, let request):
      return Self.formatError(
        title: "Bad request: \(message)",
        code: 400,
        url: url,
        response: response,
        request: request
      )
    case .forbidden(let message, let url, let response, let request):
      return Self.formatError(
        title: "Forbidden: \(message)",
        code: 403,
        url: url,
        response: response,
        request: request
      )
    case .notFound(let message, let url, let response, let request):
      return Self.formatError(
        title: "Not found: \(message)",
        code: 404,
        url: url,
        response: response,
        request: request
      )
    case .tooManyRequests(let message, let url, let response, let request):
      return Self.formatError(
        title: "Too many requests: \(message)",
        code: 429,
        url: url,
        response: response,
        request: request
      )
    case .serverError(let code, let message, let url, let response, let request):
      return Self.formatError(
        title: "Server error (\(code)): \(message)",
        code: code,
        url: url,
        response: response,
        request: request
      )
    case .offline:
      return "App is in offline mode"
    }
  }

  var errorDescription: String? {
    description
  }
}
