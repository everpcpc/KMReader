//
// ReadingPagesHeatmapWeek.swift
//
//

import Foundation

nonisolated struct ReadingPagesHeatmapWeek: Equatable, Sendable, Identifiable {
  let id: String
  let days: [ReadingStatsTimePoint?]
}
