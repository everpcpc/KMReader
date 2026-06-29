//
// DashboardWidgetDataTarget.swift
//
//

enum DashboardWidgetDataTarget: Sendable {
  case keepReading
  case recentlyAdded
  case recentlyUpdatedSeries

  func update(books: [Book], instanceId: String) {
    switch self {
    case .keepReading:
      WidgetDataService.updateKeepReadingBooks(books, instanceId: instanceId)
    case .recentlyAdded:
      WidgetDataService.updateRecentlyAddedBooks(books, instanceId: instanceId)
    case .recentlyUpdatedSeries:
      break
    }
  }

  func update(series: [Series], instanceId: String) {
    switch self {
    case .recentlyUpdatedSeries:
      WidgetDataService.updateRecentlyUpdatedSeries(series, instanceId: instanceId)
    case .keepReading, .recentlyAdded:
      break
    }
  }

  func update(ids: [String], instanceId: String) async {
    switch self {
    case .keepReading:
      await WidgetDataService.updateKeepReadingBookIds(ids, instanceId: instanceId)
    case .recentlyAdded:
      await WidgetDataService.updateRecentlyAddedBookIds(ids, instanceId: instanceId)
    case .recentlyUpdatedSeries:
      await WidgetDataService.updateRecentlyUpdatedSeriesIds(ids, instanceId: instanceId)
    }
  }
}
