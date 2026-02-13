//
//  Double+FileSize.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

extension Double {

  var humanReadableFileSize: String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = .useAll
    formatter.countStyle = .file
    formatter.includesUnit = true
    return formatter.string(fromByteCount: Int64(self))
  }
}
