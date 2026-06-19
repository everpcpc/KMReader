//
// DashboardSectionReloadCommand.swift
//
//

import Foundation

struct DashboardSectionReloadCommand: Equatable, Sendable {
  let id: UUID
  let source: DashboardRefreshSource
  let sections: Set<DashboardSection>?
  let reason: String

  func includes(_ section: DashboardSection) -> Bool {
    sections?.contains(section) ?? true
  }
}
