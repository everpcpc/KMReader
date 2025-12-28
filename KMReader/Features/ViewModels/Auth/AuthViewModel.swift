//
//  AuthViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
class AuthViewModel {
  var isLoading = false
  var isSwitching = false
  var switchingInstanceId: String?
  var user: User?
  var credentialsVersion = UUID()

  private let authService = AuthService.shared
  private let sseService = SSEService.shared

  init() {
  }

  func login(
    username: String,
    password: String,
    serverURL: String,
    displayName: String? = nil
  ) async throws {
    isLoading = true
    defer { isLoading = false }

    // Validate authentication using temporary request
    let result = try await authService.login(
      username: username, password: password, serverURL: serverURL)

    // Apply login configuration
    try await applyLoginConfiguration(
      serverURL: serverURL,
      username: username,
      authToken: result.authToken,
      authMethod: .basicAuth,
      user: result.user,
      displayName: displayName,
      shouldPersistInstance: true,
      successMessage: String(localized: "Logged in successfully")
    )
  }

  func loginWithAPIKey(
    apiKey: String,
    serverURL: String,
    displayName: String? = nil
  ) async throws {
    isLoading = true
    defer { isLoading = false }

    // Validate authentication using API Key
    let result = try await authService.loginWithAPIKey(
      apiKey: apiKey, serverURL: serverURL)

    // Apply login configuration
    try await applyLoginConfiguration(
      serverURL: serverURL,
      username: result.user.email,
      authToken: result.apiKey,
      authMethod: .apiKey,
      user: result.user,
      displayName: displayName,
      shouldPersistInstance: true,
      successMessage: String(localized: "Logged in successfully")
    )
  }

  func logout() {
    // Disconnect SSE before logout
    sseService.disconnect()

    Task {
      try? await authService.logout()
    }
    AppConfig.isLoggedIn = false
    AppConfig.serverLastUpdate = nil
    user = nil
    credentialsVersion = UUID()
    LibraryManager.shared.clearAllLibraries()
    AppConfig.clearSelectedLibraryIds()
  }

  func validate(serverURL: String) async throws {
    try await authService.validate(serverURL: serverURL)
  }

  func testCredentials(
    serverURL: String, authToken: String, authMethod: AuthenticationMethod = .basicAuth
  ) async throws -> User {
    return try await authService.testCredentials(
      serverURL: serverURL, authToken: authToken, authMethod: authMethod)
  }

  /// Load current user from server.
  /// Returns true if server is reachable, false if offline/unreachable.
  /// 401 errors trigger logout.
  func loadCurrentUser(timeout: TimeInterval? = nil) async -> Bool {
    isLoading = true
    defer { isLoading = false }
    do {
      user = try await authService.getCurrentUser(timeout: timeout)

      if let user = user {
        AppConfig.isAdmin = user.roles.contains("ADMIN")
      }
      return true
    } catch {
      if let apiError = error as? APIError {
        switch apiError {
        case .unauthorized:
          // 401: logout
          logout()
          return true  // Server is reachable, just not authorized
        case .networkError:
          // Server unreachable
          return false
        default:
          // Other API errors - server is reachable
          ErrorManager.shared.alert(error: error)
          return true
        }
      }
      // Non-API errors (likely network issues)
      return false
    }
  }

  func switchTo(instance: KomgaInstance) async -> Bool {
    isSwitching = true
    switchingInstanceId = instance.id.uuidString
    defer {
      isSwitching = false
      switchingInstanceId = nil
    }

    // Check if switching to a different instance
    let previousInstanceId = AppConfig.currentInstanceId
    let isDifferentInstance = previousInstanceId != instance.id.uuidString

    // Establish stateful session before switching
    do {
      let validatedUser = try await authService.establishSession(
        serverURL: instance.serverURL,
        authToken: instance.authToken,
        authMethod: instance.resolvedAuthMethod,
        timeout: 5
      )

      // Apply switch configuration
      try await applyLoginConfiguration(
        serverURL: instance.serverURL,
        username: instance.username,
        authToken: instance.authToken,
        authMethod: instance.resolvedAuthMethod,
        user: validatedUser,
        displayName: instance.displayName,
        shouldPersistInstance: false,
        successMessage: String(localized: "Switched to \(instance.name)"),
        currentInstanceId: instance.id.uuidString,
        clearLibrariesIfDifferent: isDifferentInstance
      )

      return true
    } catch let apiError as APIError {
      // Check if this is a network error - switch to offline mode
      if case .networkError = apiError {
        // Set up the instance config without full login
        APIClient.shared.setServer(url: instance.serverURL)
        APIClient.shared.setAuthToken(instance.authToken)
        AppConfig.authMethod = instance.resolvedAuthMethod
        AppConfig.username = instance.username
        AppConfig.isAdmin = false  // Cannot verify admin status offline
        AppConfig.isLoggedIn = true
        AppConfig.currentInstanceId = instance.id.uuidString
        AppConfig.serverDisplayName = instance.displayName

        if isDifferentInstance {
          AppConfig.clearSelectedLibraryIds()
          AppConfig.serverLastUpdate = nil
        }

        // Switch to offline mode
        AppConfig.isOffline = true
        SSEService.shared.disconnect()

        // We cannot load the user object offline, but isLoggedIn=true allows entry
        self.user = nil
        credentialsVersion = UUID()

        ErrorManager.shared.notify(
          message: String(localized: "Server unreachable, switched to offline mode")
        )
        return true
      }

      // Non-network errors: show alert and fail
      ErrorManager.shared.alert(error: apiError)
      return false
    } catch {
      ErrorManager.shared.alert(error: error)
      return false
    }
  }

  private func applyLoginConfiguration(
    serverURL: String,
    username: String,
    authToken: String,
    authMethod: AuthenticationMethod,
    user: User,
    displayName: String?,
    shouldPersistInstance: Bool,
    successMessage: String,
    currentInstanceId: String? = nil,
    clearLibrariesIfDifferent: Bool = true
  ) async throws {
    // Update AppConfig only after validation succeeds
    APIClient.shared.setServer(url: serverURL)
    APIClient.shared.setAuthToken(authToken)
    AppConfig.authMethod = authMethod
    AppConfig.username = username
    AppConfig.isAdmin = user.roles.contains("ADMIN")
    AppConfig.isLoggedIn = true

    // Reset offline mode on successful login/switch
    if AppConfig.isOffline {
      AppConfig.isOffline = false
    }

    // Clear libraries if switching to a different instance
    if clearLibrariesIfDifferent {
      AppConfig.clearSelectedLibraryIds()
      AppConfig.serverLastUpdate = nil
    }

    // Persist instance if this is a new login
    if shouldPersistInstance {
      let instance = try await DatabaseOperator.shared.upsertInstance(
        serverURL: serverURL,
        username: username,
        authToken: authToken,
        isAdmin: user.roles.contains("ADMIN"),
        authMethod: authMethod,
        displayName: displayName
      )
      AppConfig.currentInstanceId = instance.id.uuidString
      AppConfig.serverDisplayName = instance.displayName
    } else if let instanceId = currentInstanceId {
      // Update current instance ID for switch
      AppConfig.currentInstanceId = instanceId
      AppConfig.serverDisplayName = displayName ?? ""
    }

    // Load libraries
    await LibraryManager.shared.loadLibraries()

    // Update user and credentials version
    self.user = user
    credentialsVersion = UUID()

    // Show success message
    ErrorManager.shared.notify(message: successMessage)

    // Reconnect SSE with new instance if enabled
    sseService.disconnect()
    if AppConfig.enableSSE {
      sseService.connect()
    }
  }

}
