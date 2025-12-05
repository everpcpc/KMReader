//
//  LibraryListContent.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct LibraryListContent: View {
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @Query(sort: [SortDescriptor(\KomgaLibrary.name, order: .forward)]) private var allLibraries:
    [KomgaLibrary]
  @State private var performingLibraryIds: Set<String> = []
  @State private var isPerformingGlobalAction = false
  @State private var isLoading = false
  @State private var selectedLibraryIds: [String] = []

  let showMetrics: Bool
  let showDeleteAction: Bool
  let loadMetrics: Bool
  let onLibrarySelected: ((String?) -> Void)?
  let onDeleteLibrary: ((KomgaLibrary) -> Void)?

  private let libraryService = LibraryService.shared
  private let libraryStore = KomgaLibraryStore.shared

  init(
    showMetrics: Bool = true,
    showDeleteAction: Bool = false,
    loadMetrics: Bool = true,
    onLibrarySelected: ((String?) -> Void)? = nil,
    onDeleteLibrary: ((KomgaLibrary) -> Void)? = nil
  ) {
    self.showMetrics = showMetrics
    self.showDeleteAction = showDeleteAction
    self.loadMetrics = loadMetrics
    self.onLibrarySelected = onLibrarySelected
    self.onDeleteLibrary = onDeleteLibrary
  }

  private var libraries: [KomgaLibrary] {
    guard !currentInstanceId.isEmpty else {
      return []
    }
    return allLibraries.filter {
      $0.instanceId == currentInstanceId && $0.libraryId != KomgaLibrary.allLibrariesId
    }
  }

  private var allLibrariesEntry: KomgaLibrary? {
    guard !currentInstanceId.isEmpty else {
      return nil
    }
    return allLibraries.first {
      $0.instanceId == currentInstanceId && $0.libraryId == KomgaLibrary.allLibrariesId
    }
  }

  var body: some View {
    Form {
      if isLoading && libraries.isEmpty {
        Section {
          HStack {
            Spacer()
            ProgressView("Loading Libraries…")
            Spacer()
          }
        }
        .listRowBackground(Color.clear)
      } else if libraries.isEmpty {
        Section {
          VStack(spacing: 12) {
            Image(systemName: "books.vertical")
              .font(.largeTitle)
              .foregroundColor(.secondary)
            Text("No libraries found")
              .font(.headline)
            Text("Add a library from Komga's web interface to manage it here.")
              .font(.caption)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
            Button("Retry") {
              Task {
                await refreshLibraries()
              }
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
        }
        .listRowBackground(Color.clear)
      } else {
        Section {
          allLibrariesRowView()
          ForEach(libraries, id: \.libraryId) { library in
            libraryRowView(library)
          }
        }
        .listRowBackground(Color.clear)
      }
    }
    .formStyle(.grouped)
    #if os(iOS) || os(macOS)
      .scrollContentBackground(.hidden)
    #endif
    .task {
      await loadLibraries()
    }
    .refreshable {
      await refreshLibraries()
    }
    .onAppear {
      selectedLibraryIds = dashboard.libraryIds
    }
    .onDisappear {
      if dashboard.libraryIds != selectedLibraryIds {
        dashboard.libraryIds = selectedLibraryIds
      }
    }
  }

  func loadLibraries() async {
    isLoading = true
    await LibraryManager.shared.loadLibraries()
    if loadMetrics && isAdmin {
      await loadLibraryMetrics()
      await loadAllLibrariesMetrics()
    }
    isLoading = false
  }

  func refreshLibraries() async {
    isLoading = true
    await LibraryManager.shared.refreshLibraries()
    if loadMetrics && isAdmin {
      await loadLibraryMetrics()
      await loadAllLibrariesMetrics()
    }
    isLoading = false
  }

  private func loadAllLibrariesMetrics() async {
    // Ensure entry exists before loading to avoid flickering
    if !currentInstanceId.isEmpty {
      let hasEntry = await MainActor.run {
        allLibrariesEntry != nil
      }
      if !hasEntry {
        // Create empty entry as placeholder
        do {
          try await MainActor.run {
            try libraryStore.upsertAllLibrariesEntry(
              instanceId: currentInstanceId,
              fileSize: nil,
              booksCount: nil,
              seriesCount: nil,
              sidecarsCount: nil,
              collectionsCount: nil,
              readlistsCount: nil
            )
          }
        } catch {
          // Silently fail
        }
      }
    }

    var metrics = AllLibrariesMetricsData()

    await withTaskGroup(of: (String, Double?).self) { group in
      group.addTask {
        if let metric = try? await ManagementService.shared.getMetric(
          MetricName.booksFileSize.rawValue),
          let value = metric.measurements.first?.value
        {
          return ("fileSize", value)
        }
        return ("fileSize", nil)
      }
      group.addTask {
        if let metric = try? await ManagementService.shared.getMetric(MetricName.books.rawValue),
          let value = metric.measurements.first?.value
        {
          return ("books", value)
        }
        return ("books", nil)
      }
      group.addTask {
        if let metric = try? await ManagementService.shared.getMetric(MetricName.series.rawValue),
          let value = metric.measurements.first?.value
        {
          return ("series", value)
        }
        return ("series", nil)
      }
      group.addTask {
        if let metric = try? await ManagementService.shared.getMetric(MetricName.sidecars.rawValue),
          let value = metric.measurements.first?.value
        {
          return ("sidecars", value)
        }
        return ("sidecars", nil)
      }
      group.addTask {
        if let metric = try? await ManagementService.shared.getMetric(
          MetricName.collections.rawValue),
          let value = metric.measurements.first?.value
        {
          return ("collections", value)
        }
        return ("collections", nil)
      }
      group.addTask {
        if let metric = try? await ManagementService.shared.getMetric(
          MetricName.readlists.rawValue),
          let value = metric.measurements.first?.value
        {
          return ("readlists", value)
        }
        return ("readlists", nil)
      }

      for await (key, value) in group {
        switch key {
        case "fileSize":
          metrics.fileSize = value
        case "books":
          metrics.booksCount = value
        case "series":
          metrics.seriesCount = value
        case "sidecars":
          metrics.sidecarsCount = value
        case "collections":
          metrics.collectionsCount = value
        case "readlists":
          metrics.readlistsCount = value
        default:
          break
        }
      }
    }

    // Persist metrics to SwiftData
    if !currentInstanceId.isEmpty {
      do {
        try libraryStore.upsertAllLibrariesEntry(
          instanceId: currentInstanceId,
          fileSize: metrics.fileSize,
          booksCount: metrics.booksCount,
          seriesCount: metrics.seriesCount,
          sidecarsCount: metrics.sidecarsCount,
          collectionsCount: metrics.collectionsCount,
          readlistsCount: metrics.readlistsCount
        )
      } catch {
        // Silently fail
      }
    }
  }

  private func loadLibraryMetrics() async {
    // Load all 4 base metrics in parallel
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        await self.processLibraryMetric(
          metricName: MetricName.booksFileSize.rawValue,
          setter: { library, value in library.fileSize = value }
        )
      }
      group.addTask {
        await self.processLibraryMetric(
          metricName: MetricName.books.rawValue,
          setter: { library, value in library.booksCount = value }
        )
      }
      group.addTask {
        await self.processLibraryMetric(
          metricName: MetricName.series.rawValue,
          setter: { library, value in library.seriesCount = value }
        )
      }
      group.addTask {
        await self.processLibraryMetric(
          metricName: MetricName.sidecars.rawValue,
          setter: { library, value in library.sidecarsCount = value }
        )
      }
    }
  }

  private func processLibraryMetric(
    metricName: String,
    setter: @escaping (KomgaLibrary, Double) -> Void
  ) async {
    guard let metric = try? await ManagementService.shared.getMetric(metricName),
      let libraryTag = metric.availableTags?.first(where: { $0.tag == "library" })
    else {
      return
    }

    // Process all libraries for this metric in parallel
    await withTaskGroup(of: (String, Double?).self) { group in
      for libraryId in libraryTag.values {
        group.addTask {
          if let libraryMetric = try? await ManagementService.shared.getMetric(
            metricName,
            tags: [MetricTag(key: "library", value: libraryId)]
          ),
            let value = libraryMetric.measurements.first(where: { $0.statistic == "VALUE" })?.value
          {
            return (libraryId, value)
          }
          return (libraryId, nil)
        }
      }

      for await (libraryId, value) in group {
        if let value = value,
          let library = libraries.first(where: { $0.libraryId == libraryId })
        {
          setter(library, value)
        }
      }
    }
  }

  @ViewBuilder
  private func allLibrariesRowView() -> some View {
    let isSelected = selectedLibraryIds.isEmpty

    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        selectedLibraryIds = []
        onLibrarySelected?("")
      }
    } label: {
      allLibrariesRowContent(isSelected: isSelected)
    }
    .adaptiveButtonStyle(.plain)
    #if os(iOS) || os(macOS)
      .listRowSeparator(.hidden)
    #endif
    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
    .contextMenu {
      if isAdmin {
        allLibrariesContextMenu()
      }
    }
  }

  @ViewBuilder
  private func allLibrariesRowContent(isSelected: Bool) -> some View {
    let entry = allLibrariesEntry
    let hasMetrics = showMetrics && hasAllLibrariesMetrics(entry)
    let metricsText = hasMetrics ? formatAllLibrariesMetrics(entry) : ""
    let fileSizeText = showMetrics ? (entry?.fileSize.map { formatFileSize($0) } ?? "") : ""

    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text("All Libraries")
            .font(.headline)
          if !fileSizeText.isEmpty {
            Text(fileSizeText)
              .font(.caption)
              .foregroundColor(.secondary)
              .opacity(fileSizeText.isEmpty ? 0 : 1)
              .animation(.easeInOut(duration: 0.2), value: fileSizeText.isEmpty)
          }
        }
        if isAdmin && showMetrics && hasMetrics {
          Text(metricsText)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      if isSelected {
        Image(systemName: "checkmark.circle.fill")
          .font(.title3)
          .foregroundColor(.accentColor)
          .transition(.scale.combined(with: .opacity))
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.06))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(
          isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
          lineWidth: 1.5
        )
    )
    .animation(.easeInOut(duration: 0.2), value: isSelected)
    .contentShape(Rectangle())
  }

  @ViewBuilder
  private func libraryRowView(_ library: KomgaLibrary) -> some View {
    let isPerforming = performingLibraryIds.contains(library.libraryId)
    let isSelected = selectedLibraryIds.contains(library.libraryId)

    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        var currentIds = selectedLibraryIds
        if isSelected {
          currentIds.removeAll { $0 == library.libraryId }
        } else {
          if !currentIds.contains(library.libraryId) {
            currentIds.append(library.libraryId)
          }
        }
        var seen = Set<String>()
        selectedLibraryIds = currentIds.filter { seen.insert($0).inserted }
        onLibrarySelected?(isSelected ? nil : library.libraryId)
      }
    } label: {
      librarySummary(library, isPerforming: isPerforming, isSelected: isSelected)
        .contentShape(Rectangle())
    }
    .adaptiveButtonStyle(.plain)
    #if os(iOS) || os(macOS)
      .listRowSeparator(.hidden)
    #endif
    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
    .contextMenu {
      libraryContextMenu(library, isPerforming: isPerforming)
    }
  }

  @ViewBuilder
  private func librarySummary(_ library: KomgaLibrary, isPerforming: Bool, isSelected: Bool)
    -> some View
  {
    let metricsText = showMetrics && hasMetrics(library) ? formatMetrics(library) : ""
    let fileSizeText = showMetrics ? (library.fileSize.map { formatFileSize($0) } ?? "") : ""

    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(library.name)
            .font(.headline)
          if !fileSizeText.isEmpty {
            Text(fileSizeText)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        if !metricsText.isEmpty {
          Text(metricsText)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      if isPerforming {
        ProgressView()
          .progressViewStyle(.circular)
      } else if isSelected {
        Image(systemName: "checkmark.circle.fill")
          .font(.title3)
          .foregroundColor(.accentColor)
          .transition(.scale.combined(with: .opacity))
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.06))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(
          isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
          lineWidth: 1.5
        )
    )
    .animation(.easeInOut(duration: 0.2), value: isSelected)
  }

  @ViewBuilder
  private func allLibrariesContextMenu() -> some View {
    Button {
      performGlobalAction {
        try await scanAllLibraries(deep: false)
      }
    } label: {
      Label("Scan All Libraries", systemImage: "arrow.clockwise")
    }
    .disabled(isPerformingGlobalAction)

    Button {
      performGlobalAction {
        try await scanAllLibraries(deep: true)
      }
    } label: {
      Label("Scan All Libraries (Deep)", systemImage: "arrow.triangle.2.circlepath")
    }
    .disabled(isPerformingGlobalAction)

    Button {
      performGlobalAction {
        try await emptyTrashAllLibraries()
      }
    } label: {
      Label("Empty Trash for All Libraries", systemImage: "trash.slash")
    }
    .disabled(isPerformingGlobalAction)
  }

  @ViewBuilder
  private func libraryContextMenu(_ library: KomgaLibrary, isPerforming: Bool) -> some View {
    if isAdmin {
      Button {
        scanLibrary(library)
      } label: {
        Label("Scan Library Files", systemImage: "arrow.clockwise")
      }
      .disabled(isPerforming)

      Button {
        scanLibraryDeep(library)
      } label: {
        Label("Scan Library Files (Deep)", systemImage: "arrow.triangle.2.circlepath")
      }
      .disabled(isPerforming)

      Button {
        analyzeLibrary(library)
      } label: {
        Label("Analyze", systemImage: "waveform.path.ecg")
      }
      .disabled(isPerforming)

      Button {
        refreshMetadata(library)
      } label: {
        Label("Refresh Metadata", systemImage: "arrow.triangle.branch")
      }
      .disabled(isPerforming)

      Button {
        emptyTrash(library)
      } label: {
        Label("Empty Trash", systemImage: "trash.slash")
      }
      .disabled(isPerforming)

      if showDeleteAction {
        Divider()

        Button(role: .destructive) {
          onDeleteLibrary?(library)
        } label: {
          Label("Delete Library", systemImage: "trash")
        }
        .disabled(isPerforming)
      }
    }
  }

  // MARK: - Helper Functions

  private func hasMetrics(_ library: KomgaLibrary) -> Bool {
    library.seriesCount != nil || library.booksCount != nil || library.fileSize != nil
      || library.sidecarsCount != nil
  }

  private func formatMetrics(_ library: KomgaLibrary) -> String {
    var parts: [String] = []

    if let seriesCount = library.seriesCount {
      parts.append("\(formatNumber(seriesCount)) series")
    }
    if let booksCount = library.booksCount {
      parts.append("\(formatNumber(booksCount)) books")
    }
    if let sidecarsCount = library.sidecarsCount {
      parts.append("\(formatNumber(sidecarsCount)) sidecars")
    }

    return parts.joined(separator: " · ")
  }

  private func formatNumber(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
  }

  private func formatFileSize(_ bytes: Double) -> String {
    return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
  }

  private func hasAllLibrariesMetrics(_ entry: KomgaLibrary?) -> Bool {
    guard let entry else { return false }
    return entry.seriesCount != nil || entry.booksCount != nil || entry.fileSize != nil
      || entry.sidecarsCount != nil || entry.collectionsCount != nil
      || entry.readlistsCount != nil
  }

  private func formatAllLibrariesMetrics(_ entry: KomgaLibrary?) -> String {
    guard let entry else { return "" }
    var lines: [String] = []

    // First line: series, books, sidecars
    var firstLineParts: [String] = []
    if let seriesCount = entry.seriesCount {
      firstLineParts.append("\(formatNumber(seriesCount)) series")
    }
    if let booksCount = entry.booksCount {
      firstLineParts.append("\(formatNumber(booksCount)) books")
    }
    if let sidecarsCount = entry.sidecarsCount {
      firstLineParts.append("\(formatNumber(sidecarsCount)) sidecars")
    }
    if !firstLineParts.isEmpty {
      lines.append(firstLineParts.joined(separator: " · "))
    }

    // Second line: collections, readlists
    var secondLineParts: [String] = []
    if let collectionsCount = entry.collectionsCount {
      secondLineParts.append("\(formatNumber(collectionsCount)) collections")
    }
    if let readlistsCount = entry.readlistsCount {
      secondLineParts.append("\(formatNumber(readlistsCount)) readlists")
    }
    if !secondLineParts.isEmpty {
      lines.append(secondLineParts.joined(separator: " · "))
    }

    return lines.joined(separator: "\n")
  }

  // MARK: - Library Actions

  private func scanLibrary(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.scanLibrary(id: library.libraryId)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library scan started")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func scanLibraryDeep(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.scanLibrary(id: library.libraryId, deep: true)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library scan started")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func analyzeLibrary(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.analyzeLibrary(id: library.libraryId)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library analysis started")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func refreshMetadata(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.refreshMetadata(id: library.libraryId)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library metadata refresh started")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func emptyTrash(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.emptyTrash(id: library.libraryId)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Trash emptied")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func scanAllLibraries(deep: Bool) async throws {
    for library in libraries {
      try await libraryService.scanLibrary(id: library.libraryId, deep: deep)
    }
  }

  private func emptyTrashAllLibraries() async throws {
    for library in libraries {
      try await libraryService.emptyTrash(id: library.libraryId)
    }
  }

  private func performGlobalAction(_ action: @escaping () async throws -> Void) {
    guard !isPerformingGlobalAction else { return }
    isPerformingGlobalAction = true
    Task {
      do {
        try await action()
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        isPerformingGlobalAction = false
      }
    }
  }
}

// MARK: - Data Structures

struct AllLibrariesMetricsData {
  var fileSize: Double?
  var seriesCount: Double?
  var booksCount: Double?
  var sidecarsCount: Double?
  var collectionsCount: Double?
  var readlistsCount: Double?
}
