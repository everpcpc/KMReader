//
// SeriesDeletionService.swift
//
//

import Foundation

nonisolated enum SeriesDeletionService {
  private static let logger = AppLogger(.api)

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

    let syncedSeries = await syncDeletedSeriesProjection(seriesId: seriesId, instanceId: instanceId)
    await syncDeletedSeriesBooks(seriesId: seriesId, instanceId: instanceId)
    await markSeriesUnavailable(seriesId: seriesId, instanceId: instanceId)
    let markedBookIds = await markSeriesBooksUnavailable(seriesId: seriesId, instanceId: instanceId)

    let finalLibraryId = syncedSeries?.libraryId ?? resolvedLibraryId
    let bookIds =
      markedBookIds.isEmpty
      ? await fetchSeriesBookIds(seriesId: seriesId, instanceId: instanceId)
      : markedBookIds

    await ContentProjectionNotifier.postBooksDidChange(
      bookIds: bookIds,
      libraryId: finalLibraryId,
      refreshDelay: 0
    )
    await ContentProjectionNotifier.postSeriesDidChange(
      seriesId: seriesId,
      libraryId: finalLibraryId,
      refreshDelay: 0
    )
  }

  private static func syncDeletedSeriesProjection(seriesId: String, instanceId: String) async -> Series? {
    do {
      return try await SyncService.syncSeriesDetail(seriesId: seriesId)
    } catch APIError.notFound {
      return nil
    } catch {
      logger.error("Failed to sync deleted series projection: \(error)")
      return nil
    }
  }

  private static func syncDeletedSeriesBooks(seriesId: String, instanceId: String) async {
    do {
      try await SyncService.syncAllSeriesBooks(seriesId: seriesId)
    } catch {
      logger.error("Failed to sync deleted series books projection: \(error)")
    }
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
