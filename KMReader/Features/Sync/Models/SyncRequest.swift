//
// SyncRequest.swift
//
//

import Foundation

nonisolated struct SyncRequest: Sendable {
  let instanceId: String
  let forceFullSync: Bool
}
