//
//  SettingsLibrariesView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SettingsLibrariesView: View {
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @Query(sort: [SortDescriptor(\KomgaLibrary.name, order: .forward)]) private var allLibraries:
    [KomgaLibrary]
  @State private var performingLibraryIds: Set<String> = []
  @State private var libraryPendingDelete: KomgaLibrary?
  @State private var deleteConfirmationText: String = ""
  @State private var isPerformingGlobalAction = false
  @State private var isLoading = false
  @State private var allLibrariesMetrics: AllLibrariesMetricsData?

  private let libraryService = LibraryService.shared

  private var libraries: [KomgaLibrary] {
    guard !currentInstanceId.isEmpty else {
      return []
    }
    return allLibraries.filter { $0.instanceId == currentInstanceId }
  }

  private var isDeleteAlertPresented: Binding<Bool> {
    Binding(
      get: { libraryPendingDelete != nil },
      set: {
        if !$0 {
          libraryPendingDelete = nil
          deleteConfirmationText = ""
        }
      }
    )
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
    .inlineNavigationBarTitle("Libraries")
    .alert("Delete Library?", isPresented: isDeleteAlertPresented) {
      if let libraryPendingDelete {
        TextField("Enter library name", text: $deleteConfirmationText)
        Button("Delete", role: .destructive) {
          deleteConfirmedLibrary()
        }
        .disabled(deleteConfirmationText != libraryPendingDelete.name)
        Button("Cancel", role: .cancel) {
          deleteConfirmationText = ""
        }
      }
    } message: {
      if let libraryPendingDelete {
        Text(
          "This will permanently delete \(libraryPendingDelete.name) from Komga.\n\nTo confirm, please type the library name: \(libraryPendingDelete.name)"
        )
      }
    }
    .refreshable {
      await refreshLibraries()
    }
    .task {
      await refreshLibraries()
    }
  }

  private func refreshLibraries() async {
    isLoading = true
    await LibraryManager.shared.refreshLibraries()
    if isAdmin {
      await loadLibraryMetrics()
      await loadAllLibrariesMetrics()
    }
    isLoading = false
  }

  private func loadAllLibrariesMetrics() async {
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

    withAnimation {
      allLibrariesMetrics = metrics
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
    let isSelected = dashboard.libraryIds.isEmpty

    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        dashboard.libraryIds = []
      }
    } label: {
      HStack(spacing: 8) {
        VStack(alignment: .leading, spacing: 2) {
          Text("All Libraries")
            .font(.headline)
          if let metrics = allLibrariesMetrics, hasAllLibrariesMetrics(metrics) {
            VStack(alignment: .leading, spacing: 2) {
              if !formatAllLibrariesMetrics(metrics).isEmpty {
                Text(formatAllLibrariesMetrics(metrics))
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
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
      .contentShape(Rectangle())
    }
    .adaptiveButtonStyle(.plain)
    #if os(iOS) || os(macOS)
      .listRowSeparator(.hidden)
    #endif
    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
    .contextMenu {
      if isAdmin {
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
    }
  }

  @ViewBuilder
  private func libraryRowView(_ library: KomgaLibrary) -> some View {
    let isPerforming = performingLibraryIds.contains(library.libraryId)
    let isSelected = dashboard.libraryIds.contains(library.libraryId)

    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        var currentIds = dashboard.libraryIds
        if isSelected {
          // Deselect: remove from selection
          currentIds.removeAll { $0 == library.libraryId }
        } else {
          // Select: add to selection (avoid duplicates)
          if !currentIds.contains(library.libraryId) {
            currentIds.append(library.libraryId)
          }
        }
        // Remove duplicates while preserving order
        var seen = Set<String>()
        dashboard.libraryIds = currentIds.filter { seen.insert($0).inserted }
      }
    } label: {
      librarySummary(library, isPerforming: isPerforming, isSelected: isSelected)
        .contentShape(Rectangle())
    }
    .adaptiveButtonStyle(.plain)
    #if os(iOS) || os(macOS)
      .listRowSeparator(.hidden)
    #endif
    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
    .contextMenu {
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

        Divider()

        Button(role: .destructive) {
          deleteConfirmationText = ""
          libraryPendingDelete = library
        } label: {
          Label("Delete Library", systemImage: "trash")
        }
        .disabled(isPerforming)
      }
    }
  }

  @ViewBuilder
  private func librarySummary(_ library: KomgaLibrary, isPerforming: Bool, isSelected: Bool)
    -> some View
  {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(library.name)
          .font(.headline)
        if hasMetrics(library) {
          Text(formatMetrics(library))
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
    if let fileSize = library.fileSize {
      parts.append(formatFileSize(fileSize))
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

  private func hasAllLibrariesMetrics(_ metrics: AllLibrariesMetricsData) -> Bool {
    metrics.seriesCount != nil || metrics.booksCount != nil || metrics.fileSize != nil
      || metrics.sidecarsCount != nil || metrics.collectionsCount != nil
      || metrics.readlistsCount != nil
  }

  private func formatAllLibrariesMetrics(_ metrics: AllLibrariesMetricsData) -> String {
    var parts: [String] = []

    if let seriesCount = metrics.seriesCount {
      parts.append("\(formatNumber(seriesCount)) series")
    }
    if let booksCount = metrics.booksCount {
      parts.append("\(formatNumber(booksCount)) books")
    }
    if let sidecarsCount = metrics.sidecarsCount {
      parts.append("\(formatNumber(sidecarsCount)) sidecars")
    }
    if let fileSize = metrics.fileSize {
      parts.append(formatFileSize(fileSize))
    }

    if let collectionsCount = metrics.collectionsCount {
      parts.append("\(formatNumber(collectionsCount)) collections")
    }
    if let readlistsCount = metrics.readlistsCount {
      parts.append("\(formatNumber(readlistsCount)) readlists")
    }

    return parts.joined(separator: " · ")
  }

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

  private func deleteConfirmedLibrary() {
    guard let library = libraryPendingDelete else { return }
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.deleteLibrary(id: library.libraryId)
        await refreshLibraries()
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library deleted")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
        libraryPendingDelete = nil
        deleteConfirmationText = ""
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
