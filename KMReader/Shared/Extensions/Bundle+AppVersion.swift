//
//  Bundle+AppVersion.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

extension Bundle {
  var appVersion: String {
    let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let build = infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    return "v\(version) (build \(build))"
  }
}
