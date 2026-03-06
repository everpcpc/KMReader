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
      return localizedErrorCode(for: code) ?? code
    }
  }

  private static func localizedErrorCode(for code: String) -> String? {
    // Keep these keys as string literals so Xcode string extraction can retain them.
    switch code {
    case "ERR_1000":
      return String(localized: "ERR_1000")
    case "ERR_1001":
      return String(localized: "ERR_1001")
    case "ERR_1002":
      return String(localized: "ERR_1002")
    case "ERR_1003":
      return String(localized: "ERR_1003")
    case "ERR_1004":
      return String(localized: "ERR_1004")
    case "ERR_1005":
      return String(localized: "ERR_1005")
    case "ERR_1006":
      return String(localized: "ERR_1006")
    case "ERR_1007":
      return String(localized: "ERR_1007")
    case "ERR_1008":
      return String(localized: "ERR_1008")
    case "ERR_1009":
      return String(localized: "ERR_1009")
    case "ERR_1015":
      return String(localized: "ERR_1015")
    case "ERR_1016":
      return String(localized: "ERR_1016")
    case "ERR_1017":
      return String(localized: "ERR_1017")
    case "ERR_1018":
      return String(localized: "ERR_1018")
    case "ERR_1019":
      return String(localized: "ERR_1019")
    case "ERR_1020":
      return String(localized: "ERR_1020")
    case "ERR_1021":
      return String(localized: "ERR_1021")
    case "ERR_1022":
      return String(localized: "ERR_1022")
    case "ERR_1023":
      return String(localized: "ERR_1023")
    case "ERR_1024":
      return String(localized: "ERR_1024")
    case "ERR_1025":
      return String(localized: "ERR_1025")
    case "ERR_1026":
      return String(localized: "ERR_1026")
    case "ERR_1027":
      return String(localized: "ERR_1027")
    case "ERR_1028":
      return String(localized: "ERR_1028")
    case "ERR_1029":
      return String(localized: "ERR_1029")
    case "ERR_1030":
      return String(localized: "ERR_1030")
    case "ERR_1031":
      return String(localized: "ERR_1031")
    case "ERR_1032":
      return String(localized: "ERR_1032")
    case "ERR_1033":
      return String(localized: "ERR_1033")
    case "ERR_1034":
      return String(localized: "ERR_1034")
    case "ERR_1035":
      return String(localized: "ERR_1035")
    case "ERR_1036":
      return String(localized: "ERR_1036")
    case "ERR_1037":
      return String(localized: "ERR_1037")
    case "ERR_1038":
      return String(localized: "ERR_1038")
    case "ERR_1039":
      return String(localized: "ERR_1039")
    default:
      return nil
    }
  }
}
