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
  ) async {
    isLoading = true

    do {
      user = try await authService.login(
        username: username, password: password, serverURL: serverURL)
      AppConfig.isLoggedIn = true
      LibraryManager.shared.clearAllLibraries()
      AppConfig.clearSelectedLibraryIds()
      persistInstance(serverURL: serverURL, username: username, displayName: displayName)
      await LibraryManager.shared.loadLibraries()
      credentialsVersion = UUID()
      ErrorManager.shared.notify(message: "Logged in successfully")

      // Connect to SSE after successful login if enabled
      if AppConfig.enableSSE {
        sseService.connect()
      }
    } catch {
      ErrorManager.shared.alert(error: error)
      AppConfig.isLoggedIn = false
    }

    isLoading = false
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

  func switchTo(instance: KomgaInstance) {
    let previousInstanceId = AppConfig.currentInstanceId
    if previousInstanceId != instance.id.uuidString {
      LibraryManager.shared.clearAllLibraries()
      AppConfig.clearSelectedLibraryIds()
      AppConfig.serverLastUpdate = nil
    }
    APIClient.shared.setServer(url: instance.serverURL)
    APIClient.shared.setAuthToken(instance.authToken)
    AppConfig.username = instance.username
    AppConfig.isAdmin = instance.isAdmin
    AppConfig.serverDisplayName = instance.displayName
    AppConfig.isLoggedIn = true
    AppConfig.currentInstanceId = instance.id.uuidString
    credentialsVersion = UUID()

    Task {
      await loadCurrentUser()
      await LibraryManager.shared.loadLibraries()
      ErrorManager.shared.notify(message: "Switched to \(instance.name)")

      // Reconnect SSE with new instance if enabled
      sseService.disconnect()
      if AppConfig.enableSSE {
        sseService.connect()
      }
    }
  }

  private func persistInstance(serverURL: String, username: String, displayName: String?) {
    guard !AppConfig.authToken.isEmpty else {
      return
    }

    do {
      let instance = try instanceStore.upsertInstance(
        serverURL: serverURL,
        username: username,
        authToken: AppConfig.authToken,
        isAdmin: AppConfig.isAdmin,
        displayName: displayName
      )
      AppConfig.currentInstanceId = instance.id.uuidString
      AppConfig.serverDisplayName = instance.displayName
    } catch {
      ErrorManager.shared
        .notify(message: "Failed to remember server: \(error.localizedDescription)")
    }
  }
}
