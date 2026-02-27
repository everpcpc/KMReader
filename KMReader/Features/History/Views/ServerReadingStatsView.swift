//
// ServerReadingStatsView.swift
//
//

import Charts
import SwiftData
import SwiftUI

struct ServerReadingStatsView: View {
  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("isOffline") private var isOffline: Bool = false
  @Query private var instances: [KomgaInstance]
  @Query(sort: [SortDescriptor(\KomgaLibrary.name, order: .forward)]) private var allLibraries: [KomgaLibrary]

  @State private var selectedLibraryId: String = ""
  @State private var viewModel = ReadingStatsViewModel()
  @State private var selectedTimePointIndex: Int?

  private var libraries: [KomgaLibrary] {
    guard !current.instanceId.isEmpty else { return [] }
    return allLibraries.filter {
      $0.instanceId == current.instanceId && $0.libraryId != KomgaLibrary.allLibrariesId
    }
  }

  private var currentInstance: KomgaInstance? {
    guard let uuid = UUID(uuidString: current.instanceId) else { return nil }
    return instances.first { $0.id == uuid }
  }

  private var shouldShowInitialSyncHint: Bool {
    guard let currentInstance else { return false }
    let neverSyncedAt = Date(timeIntervalSince1970: 0)
    let hasNeverSynced =
      currentInstance.seriesLastSyncedAt == neverSyncedAt
      && currentInstance.booksLastSyncedAt == neverSyncedAt
    let hasAnyLocalBook = (viewModel.payload?.summary.totalBooks ?? 0) > 0
    return hasNeverSynced && !hasAnyLocalBook
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        controlsSection

        if let errorMessage = viewModel.errorMessage {
          Text(errorMessage)
            .font(.footnote)
            .foregroundStyle(.orange)
        }

        if shouldShowInitialSyncHint {
          Text(
            String(
              localized: "Local data has not been synced yet. Run offline sync first to generate reading stats."
            )
          )
          .font(.footnote)
          .foregroundStyle(.orange)
        }

        if viewModel.isLoading && viewModel.payload == nil {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
          .padding(.top, 24)
        } else if let payload = viewModel.payload {
          statsContent(payload: payload)
        } else {
          emptyState
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 12)
    }
    .inlineNavigationBarTitle(ServerSection.readingStats.title)
    .task(id: current.instanceId) {
      selectedLibraryId = ""
      await reload(forceRefresh: false)
    }
    .onChange(of: selectedLibraryId) { _, _ in
      Task {
        await reload(forceRefresh: false)
      }
    }
    .onChange(of: viewModel.selectedTimeRange) { _, _ in
      selectedTimePointIndex = nil
    }
    .onChange(of: isOffline) { oldValue, newValue in
      if oldValue && !newValue {
        Task {
          await reload(forceRefresh: false)
        }
      }
    }
    #if os(iOS) || os(macOS)
      .refreshable {
        await reload(forceRefresh: true)
      }
    #endif
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          Task {
            await reload(forceRefresh: true)
          }
        } label: {
          if viewModel.isRefreshing {
            ProgressView()
          } else {
            Image(systemName: "arrow.clockwise")
          }
        }
        .disabled(viewModel.isLoading || viewModel.isRefreshing)
      }
    }
  }

  private var controlsSection: some View {
    HStack(spacing: 8) {
      Picker(String(localized: "Library"), selection: $selectedLibraryId) {
        Text(String(localized: "All Libraries"))
          .lineLimit(1)
          .truncationMode(.tail)
          .tag("")
        ForEach(libraries) { library in
          Text(library.name)
            .lineLimit(1)
            .truncationMode(.tail)
            .tag(library.libraryId)
        }
      }
      .pickerStyle(.menu)
      .frame(maxWidth: 220, alignment: .leading)
      .lineLimit(1)
      .truncationMode(.tail)

      Spacer()

      if let lastUpdatedAt = viewModel.lastUpdatedAt {
        Text(lastUpdatedAt.formatted(date: .numeric, time: .shortened))
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.tail)
      }

      if viewModel.isUsingCachedData {
        Text(String(localized: "Cached"))
          .font(.caption)
          .fontWeight(.semibold)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.orange.opacity(0.2), in: Capsule())
          .foregroundStyle(.orange)
      }
    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "chart.bar.doc.horizontal")
        .font(.system(size: 36))
        .foregroundStyle(.secondary)
      Text(String(localized: "No reading stats available"))
        .font(.headline)
      Text(
        shouldShowInitialSyncHint
          ? String(
            localized: "Local data has not been synced yet. Run offline sync first to generate reading stats."
          )
          : String(localized: "Pull to refresh to recalculate reading stats from local data.")
      )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Button {
        Task {
          await reload(forceRefresh: true)
        }
      } label: {
        Label(String(localized: "Refresh"), systemImage: "arrow.clockwise")
      }
      .adaptiveButtonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 28)
  }

  @ViewBuilder
  private func statsContent(payload: ReadingStatsPayload) -> some View {
    let summary = payload.summary
    let filteredTimeSeries = viewModel.filteredTimeSeries()
    let indexedTimeSeries = Array(filteredTimeSeries.enumerated())

    summarySection(summary)

    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Text(String(localized: "Reading Time"))
          .font(.headline)

        Spacer()

        Picker(String(localized: "Range"), selection: $viewModel.selectedTimeRange) {
          ForEach(ReadingStatsTimeRange.allCases, id: \.self) { range in
            Text(range.title)
              .tag(range)
          }
        }
        .pickerStyle(.menu)
      }

      if filteredTimeSeries.isEmpty {
        sectionEmptyState(systemImage: "chart.xyaxis.line", message: String(localized: "No data"))
      } else {
        Chart(indexedTimeSeries, id: \.offset) { item in
          let index = item.offset
          let point = item.element

          LineMark(
            x: .value("Index", index),
            y: .value("Hours", point.value)
          )
          .foregroundStyle(Color.accentColor)

          AreaMark(
            x: .value("Index", index),
            y: .value("Hours", point.value)
          )
          .interpolationMethod(.catmullRom)
          .foregroundStyle(
            LinearGradient(
              colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.05)],
              startPoint: .top,
              endPoint: .bottom
            )
          )

          if selectedTimePointIndex == index {
            PointMark(
              x: .value("Index", index),
              y: .value("Hours", point.value)
            )
            .symbolSize(60)
            .foregroundStyle(Color.accentColor)
          }
        }
        .chartXAxis {
          AxisMarks(values: axisMarkIndices(count: filteredTimeSeries.count)) { value in
            if let index = value.as(Int.self), index < filteredTimeSeries.count {
              AxisValueLabel(axisLabel(for: filteredTimeSeries[index]))
            }
          }
        }
        #if !os(tvOS)
          .chartOverlay { proxy in
            GeometryReader { geometry in
              Color.clear
              .contentShape(Rectangle())
              .gesture(
                DragGesture(minimumDistance: 0)
                  .onChanged { drag in
                    guard let plotFrame = proxy.plotFrame else { return }
                    let plotOrigin = geometry[plotFrame].origin
                    let plotX = drag.location.x - plotOrigin.x

                    guard plotX >= 0, plotX <= proxy.plotSize.width else { return }

                    if let index = proxy.value(atX: plotX, as: Int.self) {
                      selectedTimePointIndex = max(0, min(index, filteredTimeSeries.count - 1))
                    } else if let index = proxy.value(atX: plotX, as: Double.self) {
                      let rounded = Int(index.rounded())
                      selectedTimePointIndex = max(0, min(rounded, filteredTimeSeries.count - 1))
                    }
                  }
              )
            }
          }
        #endif
        .chartBackground { _ in
          if let selectedTimePointIndex,
            selectedTimePointIndex >= 0,
            selectedTimePointIndex < filteredTimeSeries.count
          {
            let point = filteredTimeSeries[selectedTimePointIndex]
            VStack(alignment: .leading, spacing: 4) {
              Text(displayDate(for: point))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
              Text(String(localized: "Reading Time: \(formatHoursAndMinutes(point.value))"))
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 8)
            .padding(.trailing, 8)
          }
        }
        .frame(height: 220)

        Text(String(localized: "X-axis: Date, Y-axis: Estimated reading hours."))
          .font(.caption)
          .foregroundStyle(.secondary)

        #if !os(tvOS)
          Text(String(localized: "Tip: Tap or drag a point to view details."))
            .font(.caption)
            .foregroundStyle(.secondary)
        #endif
      }
    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))

    sectionCard(title: String(localized: "Reading Status")) {
      if payload.statusDistribution.isEmpty {
        sectionEmptyState(systemImage: "chart.bar", message: String(localized: "No data"))
      } else {
        pieChart(payload.statusDistribution)
      }
    }

    sectionCard(title: String(localized: "Reading by Weekday")) {
      if payload.dailyDistribution.isEmpty {
        sectionEmptyState(systemImage: "calendar", message: String(localized: "No data"))
      } else {
        distributionChart(payload.dailyDistribution, keepOrder: true)
      }
    }

    sectionCard(title: String(localized: "Reading by Hour")) {
      if payload.hourlyDistribution.isEmpty {
        sectionEmptyState(systemImage: "clock", message: String(localized: "No data"))
      } else {
        distributionChart(payload.hourlyDistribution, keepOrder: true, sparseAxisLabels: true)
      }
    }

    topItemsSection(title: String(localized: "Top Authors"), items: payload.topAuthors)
    topItemsSection(title: String(localized: "Top Genres"), items: payload.topGenres)
    topItemsSection(title: String(localized: "Top Tags"), items: payload.topTags)

    sectionCard(title: String(localized: "Genres Distribution")) {
      if payload.genreDistribution.isEmpty {
        sectionEmptyState(systemImage: "chart.pie", message: String(localized: "No data"))
      } else {
        pieChart(payload.genreDistribution)
      }
    }

    sectionCard(title: String(localized: "Tags Distribution")) {
      if payload.tagDistribution.isEmpty {
        sectionEmptyState(systemImage: "chart.pie", message: String(localized: "No data"))
      } else {
        pieChart(payload.tagDistribution)
      }
    }
  }

  private func summarySection(_ summary: ReadingStatsSummary) -> some View {
    let cards = [
      (String(localized: "Books Started"), formatCount(summary.booksStartedReading), "book"),
      (String(localized: "Books Completed"), formatCount(summary.booksCompletedReading), "checkmark.circle"),
      (String(localized: "Pages Read"), formatCount(summary.totalPagesRead), "doc.text"),
      (String(localized: "Reading Days"), formatCount(summary.readingDays), "calendar"),
      (String(localized: "Estimated Hours"), formatDecimal(summary.estimatedReadingHours), "hourglass"),
      (String(localized: "Avg Pages / Book"), formatDecimal(summary.averagePagesPerBook), "chart.bar.xaxis"),
      (String(localized: "Total Books"), formatCount(summary.totalBooks), "books.vertical"),
      (String(localized: "Last Read"), formatLastRead(summary.lastReadAt), "clock.arrow.circlepath"),
    ]

    return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
      ForEach(cards.indices, id: \.self) { index in
        let card = cards[index]
        VStack(alignment: .leading, spacing: 8) {
          Label(card.0, systemImage: card.2)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(card.1)
            .font(.title3)
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
      }
    }
  }

  private func distributionChart(
    _ items: [ReadingStatsItem],
    keepOrder: Bool = false,
    sparseAxisLabels: Bool = false
  ) -> some View {
    let chartItems: [ReadingStatsItem]
    if keepOrder {
      chartItems = items
    } else {
      chartItems = Array(items.sorted { $0.value > $1.value }.prefix(16))
    }

    if sparseAxisLabels {
      let indexedItems = Array(chartItems.enumerated())
      return AnyView(
        Chart(indexedItems, id: \.offset) { item in
          BarMark(
            x: .value("Index", item.offset),
            y: .value("Value", item.element.value)
          )
          .foregroundStyle(Color.accentColor.gradient)
        }
        .chartXAxis {
          AxisMarks(values: distributionAxisIndices(count: chartItems.count, keepOrder: keepOrder)) { value in
            if let index = value.as(Int.self), index >= 0, index < chartItems.count {
              AxisValueLabel(chartItems[index].name)
            }
          }
        }
        .frame(height: 220)
      )
    }

    return AnyView(
      Chart(chartItems) { item in
        BarMark(
          x: .value("Label", item.name),
          y: .value("Value", item.value)
        )
        .foregroundStyle(Color.accentColor.gradient)
      }
      .frame(height: 220)
    )
  }

  private func pieChart(_ items: [ReadingStatsItem]) -> some View {
    let topItems = Array(items.sorted { $0.value > $1.value }.prefix(12))

    return Chart(topItems, id: \.id) { item in
      SectorMark(
        angle: .value("Value", item.value),
        innerRadius: .ratio(0.58),
        angularInset: 1.5
      )
      .foregroundStyle(by: .value("Label", item.name))
    }
    .frame(height: 240)
  }

  private func topItemsSection(title: String, items: [ReadingStatsItem]) -> some View {
    sectionCard(title: title) {
      let sortedItems = items.sorted { $0.value > $1.value }
      if sortedItems.isEmpty {
        sectionEmptyState(systemImage: "list.bullet", message: String(localized: "No data"))
      } else {
        VStack(spacing: 8) {
          ForEach(sortedItems.prefix(10).indices, id: \.self) { index in
            let item = sortedItems[index]
            HStack(spacing: 8) {
              Text("\(index + 1).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)

              Text(item.name)
                .lineLimit(1)

              Spacer()

              Text(formatDecimal(item.value))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
      content()
    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }

  private func sectionEmptyState(systemImage: String, message: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: systemImage)
        .foregroundStyle(.secondary)
      Text(message)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
  }

  private func formatCount(_ value: Double) -> String {
    Int(max(value.rounded(), 0)).formatted()
  }

  private func formatDecimal(_ value: Double) -> String {
    if abs(value.rounded() - value) < 0.01 {
      return Int(value.rounded()).formatted()
    }

    return String(format: "%.1f", value)
  }

  private func formatLastRead(_ rawValue: String?) -> String {
    guard let rawValue else {
      return String(localized: "No record")
    }

    guard let date = ReadingStatsViewModel.parseDate(rawValue) else {
      return rawValue
    }

    return date.formattedMediumDate
  }

  private func axisMarkIndices(count: Int) -> [Int] {
    guard count > 0 else { return [] }
    let desiredMarks = 6
    let step = max(1, Int(ceil(Double(count) / Double(desiredMarks))))
    var indices = Array(stride(from: 0, to: count, by: step))
    if indices.last != count - 1 {
      indices.append(count - 1)
    }
    return indices
  }

  private func distributionAxisIndices(count: Int, keepOrder: Bool) -> [Int] {
    guard count > 0 else { return [] }
    if keepOrder == false {
      return Array(0..<count)
    }
    let desiredMarks = 8
    let step = max(1, Int(ceil(Double(count) / Double(desiredMarks))))
    var indices = Array(stride(from: 0, to: count, by: step))
    if indices.last != count - 1 {
      indices.append(count - 1)
    }
    return indices
  }

  private func axisLabel(for point: ReadingStatsTimePoint) -> String {
    point.name
  }

  private func displayDate(for point: ReadingStatsTimePoint) -> String {
    if let dateString = point.dateString {
      if dateString.count == 4 {
        return dateString
      }

      if dateString.count == 7, let date = Self.monthKeyFormatter.date(from: dateString) {
        return Self.monthDisplayFormatter.string(from: date)
      }
    }

    guard let date = ReadingStatsViewModel.parseDate(point.dateString) else {
      return point.name
    }
    return date.formattedMediumDate
  }

  private func formatHoursAndMinutes(_ hours: Double) -> String {
    let totalMinutes = Int((hours * 60).rounded())
    let hourPart = totalMinutes / 60
    let minutePart = totalMinutes % 60

    if hourPart == 0 {
      return "\(minutePart)m"
    }
    if minutePart == 0 {
      return "\(hourPart)h"
    }
    return "\(hourPart)h \(minutePart)m"
  }

  private static let monthKeyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM"
    return formatter
  }()

  private static let monthDisplayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.setLocalizedDateFormatFromTemplate("yMMM")
    return formatter
  }()

  private func reload(forceRefresh: Bool) async {
    await viewModel.load(
      instanceId: current.instanceId,
      libraryId: selectedLibraryId,
      forceRefresh: forceRefresh
    )
  }
}
