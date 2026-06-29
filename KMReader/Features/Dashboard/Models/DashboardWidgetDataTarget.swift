//
// DashboardWidgetDataTarget.swift
//
//

enum DashboardWidgetDataTarget: Sendable {
  case keepReading
  case recentlyAdded
  case recentlyUpdatedSeries

  func update(books: [Book], instanceId: String, libraryIds: [String]) {
    switch self {
    case .keepReading:
      WidgetDataService.updateKeepReadingBooks(books, instanceId: instanceId, libraryIds: libraryIds)
    case .recentlyAdded:
      WidgetDataService.updateRecentlyAddedBooks(books, instanceId: instanceId, libraryIds: libraryIds)
    case .recentlyUpdatedSeries:
      break
    }
  }

  func update(series: [Series], instanceId: String, libraryIds: [String]) {
    switch self {
    case .recentlyUpdatedSeries:
      WidgetDataService.updateRecentlyUpdatedSeries(
        series,
        instanceId: instanceId,
        libraryIds: libraryIds
      )
    case .keepReading, .recentlyAdded:
      break
    }
  }

  func update(ids: [String], instanceId: String, libraryIds: [String]) async {
    switch self {
    case .keepReading:
      await WidgetDataService.updateKeepReadingBookIds(
        ids,
        instanceId: instanceId,
        libraryIds: libraryIds
      )
    case .recentlyAdded:
      await WidgetDataService.updateRecentlyAddedBookIds(
        ids,
        instanceId: instanceId,
        libraryIds: libraryIds
      )
    case .recentlyUpdatedSeries:
      await WidgetDataService.updateRecentlyUpdatedSeriesIds(
        ids,
        instanceId: instanceId,
        libraryIds: libraryIds
      )
    }
  }
}
