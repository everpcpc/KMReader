//
//  AuthViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

@MainActor
@Observable
class AuthViewModel {
  var isLoggedIn = false
  var isLoading = false
  var errorMessage: String?
  var user: User?

  private let authService = AuthService.shared

  init() {
    self.isLoggedIn = authService.isLoggedIn()
  }

  func login(username: String, password: String, serverURL: String) async {
    isLoading = true
    errorMessage = nil

    do {
      user = try await authService.login(
        username: username, password: password, serverURL: serverURL)
      isLoggedIn = true
    } catch {
      errorMessage = handleError(error)
      isLoggedIn = false
    }

    isLoading = false
  }

  func logout() {
    Task {
      try? await authService.logout()
    }
    isLoggedIn = false
    user = nil
  }

  func loadCurrentUser() async {
    do {
      user = try await authService.getCurrentUser()
    } catch {
      errorMessage = handleError(error)
    }
  }

  private func handleError(_ error: Error) -> String {
    if let apiError = error as? APIError {
      switch apiError {
      case .unauthorized:
        return "Invalid credentials"
      case .httpError(let code, let message):
        return "Server error (\(code)): \(message)"
      case .networkError:
        return "Network error. Please check your connection."
      case .invalidURL:
        return "Invalid server URL"
      default:
        return error.localizedDescription
      }
    }
    return error.localizedDescription
  }
}
