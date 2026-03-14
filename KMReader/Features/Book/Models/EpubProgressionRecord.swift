//
// EpubProgressionRecord.swift
//
//

import Foundation

enum EpubProgressionRecordState: String, Codable {
  case available
  case missing
}

struct EpubProgressionRecord: Codable {
  let state: EpubProgressionRecordState
  let progression: R2Progression?

  static func available(_ progression: R2Progression) -> EpubProgressionRecord {
    EpubProgressionRecord(state: .available, progression: progression)
  }

  static let missing = EpubProgressionRecord(state: .missing, progression: nil)
}

enum StoredEpubProgressionState {
  case unknown
  case missing
  case available(R2Progression)
}
