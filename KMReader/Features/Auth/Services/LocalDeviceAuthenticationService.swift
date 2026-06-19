//
// LocalDeviceAuthenticationService.swift
//

import Foundation

#if os(iOS) || os(macOS)
  import LocalAuthentication
#endif

@MainActor
enum LocalDeviceAuthenticationService {
  static var canAuthenticate: Bool {
    #if os(iOS) || os(macOS)
      let context = LAContext()
      var error: NSError?
      return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    #else
      return false
    #endif
  }

  static func authenticate(reason: String) async -> Bool {
    #if os(iOS) || os(macOS)
      let context = LAContext()
      do {
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
      } catch {
        guard !isCancellation(error) else { return false }
        if isUnavailable(error) {
          ErrorManager.shared.notify(
            message: String(localized: "Device authentication is not available on this device."))
        } else {
          ErrorManager.shared.notify(message: String(localized: "Authentication failed."))
        }
        return false
      }
    #else
      ErrorManager.shared.notify(
        message: String(localized: "Device authentication is not available on this device."))
      return false
    #endif
  }

  #if os(iOS) || os(macOS)
    private static func isCancellation(_ error: Error) -> Bool {
      guard let laError = error as? LAError else { return false }
      switch laError.code {
      case .appCancel, .systemCancel, .userCancel:
        return true
      default:
        return false
      }
    }

    private static func isUnavailable(_ error: Error) -> Bool {
      guard let laError = error as? LAError else { return false }
      switch laError.code {
      case .biometryLockout, .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet:
        return true
      default:
        return false
      }
    }
  #endif
}
