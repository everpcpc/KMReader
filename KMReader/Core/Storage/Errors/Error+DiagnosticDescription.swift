//
// Error+DiagnosticDescription.swift
//
//

import Foundation

extension Error {
  /// True for pure Swift errors that do not implement `LocalizedError` and
  /// bridge to NSError with a generic "The operation couldn't be completed.
  /// (Module.Type error N.)" message that drops the case name and its payload
  /// (e.g. `LibArchive.ArchiveError`).
  nonisolated var isGenericBridgedSwiftError: Bool {
    guard !(self is LocalizedError) else { return false }
    return (self as NSError).domain == String(reflecting: type(of: self))
  }

  /// Description for logs and diagnostics. For generic bridged Swift errors,
  /// returns the full `String(describing:)` dump (e.g.
  /// `readFailed(message: "Truncated ZIP file body")`) instead of the generic
  /// bridged message.
  nonisolated var diagnosticDescription: String {
    isGenericBridgedSwiftError ? String(describing: self) : localizedDescription
  }
}
