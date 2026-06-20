//
// SeriesDeletionService.swift
//
//

import Foundation

nonisolated enum SeriesDeletionService {
  static func deleteSeries(_ item: SeriesDisplayItem) async throws {
    try await deleteSeries(
      seriesId: item.seriesId,
      instanceId: item.instanceId,
      libraryId: item.series.libraryId
    )
  }

  static func deleteSeries(
    _ series: Series,
    instanceId: String = AppConfig.current.instanceId
  ) async throws {
    try await deleteSeries(
      seriesId: series.id,
      instanceId: instanceId,
      libraryId: series.libraryId
    )
  }

  static func deleteSeries(
    seriesId: String,
    instanceId: String = AppConfig.current.instanceId,
    libraryId: String? = nil
  ) async throws {
    let resolvedLibraryId = await resolveLibraryId(
      seriesId: seriesId,
      instanceId: instanceId,
      libraryId: libraryId
    )

    try await SeriesService.deleteSeries(seriesId: seriesId)

    await markSeriesUnavailable(seriesId: seriesId, instanceId: instanceId)
    let markedBookIds = await markSeriesBooksUnavailable(seriesId: seriesId, instanceId: instanceId)

    let bookIds =
      markedBookIds.isEmpty
      ? await fetchSeriesBookIds(seriesId: seriesId, instanceId: instanceId)
      : markedBookIds

    await ContentProjectionNotifier.postBooksDidChange(
      bookIds: bookIds,
      libraryId: resolvedLibraryId
    )
    await ContentProjectionNotifier.postSeriesDidChange(
      seriesId: seriesId,
      libraryId: resolvedLibraryId
    )
  }

  private static func markSeriesUnavailable(seriesId: String, instanceId: String) async {
    guard let database = try? await DatabaseOperator.database() else { return }
    await database.markSeriesUnavailable(seriesId: seriesId, instanceId: instanceId)
  }

  private static func markSeriesBooksUnavailable(seriesId: String, instanceId: String) async -> [String] {
    guard let database = try? await DatabaseOperator.database() else { return [] }
    return await database.markSeriesBooksUnavailable(seriesId: seriesId, instanceId: instanceId)
  }

  private static func fetchSeriesBookIds(seriesId: String, instanceId: String) async -> [String] {
    guard let database = try? await DatabaseOperator.database() else { return [] }
    return await database.fetchAllSeriesBookIds(seriesId: seriesId, instanceId: instanceId)
  }

  private static func resolveLibraryId(
    seriesId: String,
    instanceId: String,
    libraryId: String?
  ) async -> String? {
    if let libraryId {
      return libraryId
    }

    guard
      let database = try? await DatabaseOperator.database(),
      let item = try? await database.fetchSeriesDisplayItem(seriesId: seriesId, instanceId: instanceId)
    else {
      return nil
    }

    return item.series.libraryId
  }
}
