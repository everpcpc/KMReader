//
//  CompositeID.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

enum CompositeID {
  static nonisolated func generate(instanceId: String, id: String) -> String {
    "\(instanceId)_\(id)"
  }

  static nonisolated func generate(id: String) -> String {
    generate(instanceId: AppConfig.currentInstanceId, id: id)
  }
}
