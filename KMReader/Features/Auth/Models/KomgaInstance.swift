//
// KomgaInstance.swift
//

import Foundation
import SwiftData

typealias KomgaInstance = KMReaderSchemaV6.KomgaInstance

extension KomgaInstance {
  var displayName: String {
    name.isEmpty ? serverURL : name
  }

  var resolvedAuthMethod: AuthenticationMethod {
    authMethod ?? .basicAuth
  }
}
