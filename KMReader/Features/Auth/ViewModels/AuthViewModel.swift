//
// AuthViewModel.swift
//
//

import Foundation
import SwiftUI

@MainActor
@Observable
class AuthViewModel {
  enum BootstrapState: Equatable {
    case requiresValidation
    case validating
    case ready
  }

  var isLoading = false
  var isSwitching = false
  var switchingInstanceId: String?
  private(set) var bootstrapState: BootstrapState

  init() {
    bootstrapState = AppConfig.isLoggedIn ? .requiresValidation : .ready
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
    let result = try await AuthService.login(
      username: username, password: password, serverURL: serverURL, timeout: AppConfig.authTimeout)

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
    let result = try await AuthService.loginWithAPIKey(
      apiKey: apiKey, serverURL: serverURL, timeout: AppConfig.authTimeout)

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

  func logout(clearCurrent: Bool = false) {
    LocalDeviceAuthenticationService.shared.clearProtectedAccess()
    Task {
      // Disconnect SSE before logout
      await SSEService.shared.disconnect()
      try? await AuthService.logout(clearCurrent: clearCurrent)
    }
    // ViewModel-specific cleanup
    AppConfig.isLoggedIn = false
    AppConfig.showProtectedServers = false
    if clearCurrent {
      AppConfig.current = Current()
    } else {
      var current = AppConfig.current
      current.clearUserMetadata()
      AppConfig.current = current
    }
    bootstrapState = .requiresValidation
  }

  func validate(serverURL: String) async throws {
    try await AuthService.validate(serverURL: serverURL)
  }

  func testCredentials(
    serverURL: String, authToken: String, authMethod: AuthenticationMethod = .basicAuth
  ) async throws -> User {
    return try await AuthService.testCredentials(
      serverURL: serverURL, authToken: authToken, authMethod: authMethod)
  }

  /// Load current user from server.
  /// Returns true if server is reachable, false if offline/unreachable.
  /// 401 errors trigger logout.
  func loadCurrentUser(timeout: TimeInterval? = nil) async -> Bool {
    isLoading = true
    bootstrapState = .validating
    defer { isLoading = false }
    do {
      let effectiveTimeout = timeout ?? AppConfig.authTimeout
      let user = try await AuthService.getCurrentUser(timeout: effectiveTimeout)
      var current = AppConfig.current
      current.updateMetadata(from: user)
      AppConfig.current = current
      bootstrapState = .ready
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
          bootstrapState = .ready
          return false
        default:
          // Other API errors - server is reachable
          bootstrapState = .ready
          ErrorManager.shared.alert(error: error)
          return true
        }
      }
      // Non-API errors (likely network issues)
      bootstrapState = .ready
      return false
    }
  }

  func switchTo(instance: ServerDisplayItem) async -> Bool {
    if instance.protected {
      let authenticated = await LocalDeviceAuthenticationService.shared.authenticateProtectedAccess(
        reason: String(localized: "Authenticate to switch to this protected server.")
      )
      guard authenticated else { return false }
    }

    isSwitching = true
    switchingInstanceId = instance.instanceId
    defer {
      isSwitching = false
      switchingInstanceId = nil
    }

    // Ensure current session is logged out before switching to a new instance when sharing a single session
    try? await AuthService.logout()

    // Establish stateful session before switching
    do {
      let validatedUser = try await AuthService.establishSession(
        serverURL: instance.serverURL,
        authToken: instance.authToken,
        authMethod: instance.authMethod,
        timeout: AppConfig.authTimeout
      )

      // Apply switch configuration
      try await applyLoginConfiguration(
        serverURL: instance.serverURL,
        username: instance.username,
        authToken: instance.authToken,
        authMethod: instance.authMethod,
        user: validatedUser,
        displayName: instance.displayName,
        instanceId: instance.instanceId,
        shouldPersistInstance: false,
        protected: instance.protected,
        successMessage: String(localized: "Switched to \(instance.name)")
      )

      return true
    } catch let apiError as APIError {
      // Check if this is a network error - switch to offline mode
      if case .networkError = apiError {
        // Set up the instance config without full login
        APIClient.shared.setServer(url: instance.serverURL)
        APIClient.shared.setAuthToken(instance.authToken)

        AppConfig.current = Current(
          serverURL: instance.serverURL,
          serverDisplayName: instance.displayName,
          authToken: instance.authToken,
          authMethod: instance.authMethod,
          username: instance.username,
          isAdmin: false,
          instanceId: instance.instanceId
        )

        AppConfig.isLoggedIn = true

        AppConfig.dashboard.libraryIds = []
        DashboardSectionCacheStore.shared.reset()
        AppConfig.serverLastUpdate = nil

        // Switch to offline mode
        AppConfig.enterAutoOfflineMode()
        await SSEService.shared.disconnect()

        // We cannot load the user object offline, but isLoggedIn=true allows entry
        var current = AppConfig.current
        current.clearUserMetadata()
        AppConfig.current = current
        bootstrapState = .ready
        if instance.protected {
          ExternalContentSurfaceService.clearAll()
        }

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
    instanceId: String? = nil,
    shouldPersistInstance: Bool,
    protected: Bool = false,
    successMessage: String
  ) async throws {
    // Update AppConfig only after validation succeeds
    APIClient.shared.setServer(url: serverURL)
    APIClient.shared.setAuthToken(authToken)

    let finalInstanceId: String
    let finalDisplayName: String

    // Persist instance if this is a new login
    if shouldPersistInstance {
      let instanceSummary = try await DatabaseOperator.database().upsertInstance(
        serverURL: serverURL,
        username: username,
        authToken: authToken,
        isAdmin: user.isAdmin,
        authMethod: authMethod,
        displayName: displayName
      )
      finalInstanceId = instanceSummary.id.uuidString
      finalDisplayName = instanceSummary.displayName
    } else {
      finalInstanceId = instanceId ?? AppConfig.current.instanceId
      finalDisplayName = displayName ?? ""
    }

    AppConfig.current = Current(
      serverURL: serverURL,
      serverDisplayName: finalDisplayName,
      authToken: authToken,
      authMethod: authMethod,
      username: user.email,
      isAdmin: user.isAdmin,
      instanceId: finalInstanceId
    )

    AppConfig.isLoggedIn = true

    // Reset offline mode on successful login/switch
    if AppConfig.isOffline {
      AppConfig.exitOfflineMode()
    }

    AppConfig.dashboard.libraryIds = []
    DashboardSectionCacheStore.shared.reset()
    AppConfig.serverLastUpdate = nil

    // Load libraries
    await LibraryManager.shared.loadLibraries()

    // Update user and credentials version
    var current = AppConfig.current
    current.updateMetadata(from: user)
    AppConfig.current = current

    // Show success message
    ErrorManager.shared.notify(message: successMessage)
    bootstrapState = .ready

    // Reconnect SSE with new instance if enabled
    await SSEService.shared.disconnect()
    await SSEService.shared.connect()

    ExternalContentSurfaceService.updateAfterSelectingInstance(
      instanceId: finalInstanceId,
      protected: protected
    )
  }

  func updatePassword(password: String) async throws {
    let userId = AppConfig.current.userId
    guard !userId.isEmpty else { return }
    try await AuthService.updatePassword(userId: userId, password: password)
  }
}
