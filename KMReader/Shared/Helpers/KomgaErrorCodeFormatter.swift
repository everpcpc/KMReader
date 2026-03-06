//
// KomgaErrorCodeFormatter.swift
//
//

import Foundation

nonisolated enum KomgaErrorCodeFormatter {
  static func localizedMessage(for message: String?) -> String? {
    guard let message, !message.isEmpty else { return nil }
    let errorCodePattern = try! Regex(#"ERR_\d{4}"#)

    return message.replacing(errorCodePattern) { match in
      let code = String(match.0)
      return Bundle.main.localizedString(forKey: code, value: code, table: nil)
    }
  }
}
