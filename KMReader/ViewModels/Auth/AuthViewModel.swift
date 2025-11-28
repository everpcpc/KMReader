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
  private var loggedInState: Bool
  var isLoggedIn: Bool {
    get { loggedInState }
    set {
      if loggedInState != newValue {
        loggedInState = newValue
        AppConfig.isLoggedIn = newValue
      }
    }
  }
  var isLoading = false
  var user: User?
  var credentialsVersion = UUID()

  private let authService = AuthService.shared
  private let instanceStore = KomgaInstanceStore.shared

  init() {
    self.loggedInState = authService.isLoggedIn()
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
      isLoggedIn = true
      LibraryManager.shared.clearAllLibraries()
      AppConfig.selectedLibraryId = ""
      persistInstance(serverURL: serverURL, username: username, displayName: displayName)
      await LibraryManager.shared.loadLibraries()
      credentialsVersion = UUID()
    } catch {
      ErrorManager.shared.alert(error: error)
      isLoggedIn = false
    }

    if isLoggedIn {
      ErrorManager.shared.notify(message: "Logged in successfully")
    }

    isLoading = false
  }

  func logout() {
    Task {
      try? await authService.logout()
    }
    isLoggedIn = false
    user = nil
    credentialsVersion = UUID()
    LibraryManager.shared.clearAllLibraries()
    AppConfig.selectedLibraryId = ""
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
      AppConfig.selectedLibraryId = ""
    }
    APIClient.shared.setServer(url: instance.serverURL)
    APIClient.shared.setAuthToken(instance.authToken)
    AppConfig.username = instance.username
    AppConfig.isAdmin = instance.isAdmin
    isLoggedIn = true
    AppConfig.currentInstanceId = instance.id.uuidString
    credentialsVersion = UUID()

    Task {
      await loadCurrentUser()
      await LibraryManager.shared.loadLibraries()
      ErrorManager.shared.notify(message: "Switched to \(instance.name)")
    }
  }

  private func persistInstance(serverURL: String, username: String, displayName: String?) {
    guard let authToken = AppConfig.authToken else {
      return
    }

    do {
      let instance = try instanceStore.upsertInstance(
        serverURL: serverURL,
        username: username,
        authToken: authToken,
        isAdmin: AppConfig.isAdmin,
        displayName: displayName
      )
      AppConfig.currentInstanceId = instance.id.uuidString
    } catch {
      ErrorManager.shared
        .notify(message: "Failed to remember server: \(error.localizedDescription)")
    }
  }
}
