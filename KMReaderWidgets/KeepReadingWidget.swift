//
//  KeepReadingWidget.swift
//  KMReaderWidgets
//

import SwiftUI
import WidgetKit

struct KeepReadingEntry: TimelineEntry {
  let date: Date
  let books: [WidgetBookEntry]
}

struct KeepReadingProvider: TimelineProvider {
  func placeholder(in context: Context) -> KeepReadingEntry {
    KeepReadingEntry(date: .now, books: [])
  }

  func getSnapshot(in context: Context, completion: @escaping (KeepReadingEntry) -> Void) {
    let books = WidgetDataStore.loadEntries(forKey: WidgetDataStore.keepReadingKey)
    completion(KeepReadingEntry(date: .now, books: books))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<KeepReadingEntry>) -> Void) {
    let books = WidgetDataStore.loadEntries(forKey: WidgetDataStore.keepReadingKey)
    let entry = KeepReadingEntry(date: .now, books: books)
    let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
    completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
  }
}

struct KeepReadingWidgetEntryView: View {
  @Environment(\.widgetFamily) var widgetFamily
  let entry: KeepReadingEntry

  var body: some View {
    if entry.books.isEmpty {
      emptyView
    } else {
      switch widgetFamily {
      case .systemSmall:
        WidgetBookCardView(entry: entry.books[0], showProgress: true)
      case .systemMedium:
        mediumView
      case .systemLarge:
        largeView
      default:
        WidgetBookCardView(entry: entry.books[0], showProgress: true)
      }
    }
  }

  private var emptyView: some View {
    VStack(spacing: 8) {
      Image(systemName: "book.closed")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text(String(localized: "widget.no_books"))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var mediumView: some View {
    let books = Array(entry.books.prefix(3))
    return HStack(spacing: 8) {
      ForEach(books, id: \.id) { book in
        WidgetBookCardView(entry: book, showProgress: true)
      }
    }
  }

  private var largeView: some View {
    let books = Array(entry.books.prefix(4))
    let topRow = Array(books.prefix(2))
    let bottomRow = Array(books.dropFirst(2))
    return VStack(alignment: .leading, spacing: 8) {
      Text(String(localized: "widget.keep_reading.title"))
        .font(.headline)

      HStack(spacing: 8) {
        ForEach(topRow, id: \.id) { book in
          WidgetBookCardView(entry: book, showProgress: true)
        }
      }
      if !bottomRow.isEmpty {
        HStack(spacing: 8) {
          ForEach(bottomRow, id: \.id) { book in
            WidgetBookCardView(entry: book, showProgress: true)
          }
          if bottomRow.count < 2 {
            Spacer()
          }
        }
      }
    }
  }
}

struct KeepReadingWidget: Widget {
  let kind = "KeepReadingWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: KeepReadingProvider()) { entry in
      KeepReadingWidgetEntryView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName(String(localized: "widget.keep_reading.title"))
    .description(String(localized: "widget.keep_reading.description"))
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}
