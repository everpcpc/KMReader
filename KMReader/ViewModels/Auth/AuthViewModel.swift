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
  private let instanceStore = KomgaInstanceStore.shared
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
      user: result.user,
      displayName: displayName,
      shouldPersistInstance: true,
      successMessage: "Logged in successfully"
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

  func testCredentials(serverURL: String, authToken: String) async throws -> User {
    return try await authService.testCredentials(serverURL: serverURL, authToken: authToken)
  }

  func loadCurrentUser() async {
    do {
      user = try await authService.getCurrentUser()
      if let user = user {
        AppConfig.isAdmin = user.roles.contains("ADMIN")
      }
    } catch {
      // Don't show alert for unauthorized errors during background refresh
      if let apiError = error as? APIError, case .unauthorized = apiError {
        // Silently handle unauthorized during background refresh
        return
      }
      ErrorManager.shared.alert(error: error)
    }
  }

  func switchTo(instance: KomgaInstance) async -> Bool {
    isSwitching = true
    switchingInstanceId = instance.id.uuidString
    defer {
      isSwitching = false
      switchingInstanceId = nil
    }

    // Establish stateful session before switching
    do {
      let validatedUser = try await authService.establishSession(
        serverURL: instance.serverURL,
        authToken: instance.authToken
      )

      // Check if switching to a different instance
      let previousInstanceId = AppConfig.currentInstanceId
      let isDifferentInstance = previousInstanceId != instance.id.uuidString

      // Apply switch configuration
      try await applyLoginConfiguration(
        serverURL: instance.serverURL,
        username: instance.username,
        authToken: instance.authToken,
        user: validatedUser,
        displayName: instance.displayName,
        shouldPersistInstance: false,
        successMessage: "Switched to \(instance.name)",
        currentInstanceId: instance.id.uuidString,
        clearLibrariesIfDifferent: isDifferentInstance
      )

      return true
    } catch {
      ErrorManager.shared.alert(error: error)
      return false
    }
  }

  private func applyLoginConfiguration(
    serverURL: String,
    username: String,
    authToken: String,
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
    AppConfig.username = username
    AppConfig.isAdmin = user.roles.contains("ADMIN")
    AppConfig.isLoggedIn = true

    // Clear libraries if switching to a different instance
    if clearLibrariesIfDifferent {
      LibraryManager.shared.clearAllLibraries()
      AppConfig.clearSelectedLibraryIds()
      AppConfig.serverLastUpdate = nil
    }

    // Persist instance if this is a new login
    if shouldPersistInstance {
      let instance = try instanceStore.upsertInstance(
        serverURL: serverURL,
        username: username,
        authToken: authToken,
        isAdmin: user.roles.contains("ADMIN"),
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
