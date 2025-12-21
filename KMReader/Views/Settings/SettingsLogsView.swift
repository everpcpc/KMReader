//
//  SettingsLogsView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Flow
import SwiftUI

struct SettingsLogsView: View {
  @State private var logEntries: [LogStore.LogEntry] = []
  @State private var categoryCounts: [String: Int] = [:]
  @State private var isLoading = false
  @State private var selectedLevel: LogLevel = .info
  @State private var selectedCategory: String = "All"
  @State private var selectedTimeRange: TimeRange = .oneHour
  @State private var searchText = ""

  private var sortedCategories: [(name: String, count: Int)] {
    categoryCounts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
  }

  private var totalCount: Int {
    categoryCounts.values.reduce(0, +)
  }

  var body: some View {
    List {
      Section {
        if isLoading {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
        } else if logEntries.isEmpty {
          Text(String(localized: "settings.logs.empty"))
            .foregroundColor(.secondary)
        } else {
          ForEach(logEntries) { entry in
            LogEntryRow(entry: entry)
              .tvFocusableHighlight()
              #if !os(tvOS)
                .contextMenu {
                  Button {
                    copyToClipboard(formatEntry(entry))
                  } label: {
                    Label(String(localized: "Copy"), systemImage: "doc.on.doc")
                  }
                }
              #endif
          }
        }
      } header: {
        HFlow(spacing: 8) {
          Menu {
            Picker("Time", selection: $selectedTimeRange) {
              ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
              }
            }
            .pickerStyle(.inline)
          } label: {
            LogFilterChip(icon: "clock", text: selectedTimeRange.displayName)
          }
          .adaptiveButtonStyle(.bordered)

          Menu {
            Picker("Level", selection: $selectedLevel) {
              ForEach(LogLevel.allCases, id: \.self) { level in
                Text(level.rawValue).tag(level)
              }
            }
            .pickerStyle(.inline)
          } label: {
            LogFilterChip(icon: "flag", text: selectedLevel.rawValue, color: selectedLevel.color)
          }
          .adaptiveButtonStyle(.bordered)

          CategoryChip(
            name: "All",
            count: totalCount,
            isSelected: selectedCategory == "All"
          ) {
            selectedCategory = "All"
          }

          ForEach(sortedCategories, id: \.name) { category in
            CategoryChip(
              name: category.name,
              count: category.count,
              isSelected: selectedCategory == category.name
            ) {
              selectedCategory = category.name
            }
          }
        }
      }
    }
    .formStyle(.grouped)
    .animation(.default, value: logEntries)
    .animation(.default, value: categoryCounts)
    .animation(.default, value: isLoading)
    .animation(.default, value: selectedTimeRange)
    .animation(.default, value: selectedLevel)
    .animation(.default, value: selectedCategory)
    .searchable(text: $searchText, prompt: String(localized: "settings.logs.search"))
    .onSubmit(of: .search) {
      Task { await loadLogs() }
    }
    .onChange(of: selectedTimeRange) {
      Task { await loadLogs() }
    }
    .onChange(of: selectedLevel) {
      Task { await loadLogs() }
    }
    .onChange(of: selectedCategory) {
      Task { await loadLogs() }
    }
    .refreshable {
      await loadLogs()
    }
    #if !os(tvOS)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          ShareLink(item: exportLogs()) {
            Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
          }
        }
      }
    #endif
    .task {
      await loadLogs()
    }
    .inlineNavigationBarTitle(String(localized: "Logs"))
  }

  private func loadLogs() async {
    isLoading = logEntries.isEmpty
    await loadCategoryCounts()
    let since = Date().addingTimeInterval(selectedTimeRange.interval)
    let results = await LogStore.shared.query(
      minPriority: selectedLevel == .all ? nil : selectedLevel.priority,
      category: selectedCategory == "All" ? nil : selectedCategory,
      search: searchText.isEmpty ? nil : searchText,
      since: since,
      limit: 500
    )
    withAnimation {
      logEntries = results
      isLoading = false
    }
  }

  private func loadCategoryCounts() async {
    let since = Date().addingTimeInterval(selectedTimeRange.interval)
    categoryCounts = await LogStore.shared.categoryCounts(
      minPriority: selectedLevel == .all ? nil : selectedLevel.priority,
      since: since
    )
  }

  private func exportLogs() -> String {
    logEntries.map { formatEntry($0) }.joined(separator: "\n")
  }

  private func formatEntry(_ entry: LogStore.LogEntry) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    let level = LogLevel(entry.level).rawValue
    return
      "[\(formatter.string(from: entry.date))] [\(level)] [\(entry.category)] \(entry.message)"
  }

  private func copyToClipboard(_ text: String) {
    #if os(iOS)
      UIPasteboard.general.string = text
    #elseif os(macOS)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(text, forType: .string)
    #endif
  }
}

// MARK: - Time Range

enum TimeRange: String, CaseIterable, Hashable {
  case fiveMinutes = "5m"
  case thirtyMinutes = "30m"
  case oneHour = "1h"
  case sixHours = "6h"
  case twentyFourHours = "24h"

  var displayName: String { rawValue }

  var interval: TimeInterval {
    switch self {
    case .fiveMinutes: return -5 * 60
    case .thirtyMinutes: return -30 * 60
    case .oneHour: return -60 * 60
    case .sixHours: return -6 * 60 * 60
    case .twentyFourHours: return -24 * 60 * 60
    }
  }
}

// MARK: - Log Filter Chip

struct LogFilterChip: View {
  let icon: String
  let text: String
  var color: Color = .accentColor

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
        .font(.caption)
      Text(text)
        .font(.footnote)
        .fontWeight(.medium)
    }
    .fixedSize()
    .tint(color)
  }
}

// MARK: - Category Chip

struct CategoryChip: View {
  let name: String
  let count: Int
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Text(name)
          .font(.footnote)
          .fontWeight(.medium)
        Text("\(count)")
          .font(.caption)
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
          .clipShape(Capsule())
      }
      .fixedSize()
    }
    .adaptiveButtonStyle(isSelected ? .borderedProminent : .bordered)
  }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
  let entry: LogStore.LogEntry

  private var dateString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter.string(from: entry.date)
  }

  var level: LogLevel {
    LogLevel(entry.level)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(level.rawValue)
          .font(.caption.bold())
          .foregroundColor(level.color)
        Text(entry.category)
          .font(.caption)
          .foregroundColor(.secondary)
        Spacer()
        Text(dateString)
          .font(.caption.monospaced())
          .foregroundColor(.secondary)
      }
      Text(entry.message)
        .font(.footnote.monospaced())
        .lineLimit(5)
        .textSelectionIfAvailable()
    }
    .padding(.vertical, 2)
  }
}
