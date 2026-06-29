//
// WidgetConfigurationService.swift
//
//

import Foundation

#if canImport(WidgetKit) && !os(tvOS)
  import WidgetKit
#endif

actor WidgetConfigurationService {
  static let shared = WidgetConfigurationService()

  private let cacheDuration: TimeInterval = 30
  private var cachedKinds: Set<String>?
  private var cachedAt: Date?
  private var loadingTask: Task<Set<String>, Never>?

  func hasConfiguredWidget(kind: String) async -> Bool {
    await configuredWidgetKinds(matching: [kind]).contains(kind)
  }

  func configuredWidgetKinds(matching kinds: [String]) async -> Set<String> {
    let configuredKinds = await currentConfiguredKinds()
    return Set(kinds).intersection(configuredKinds)
  }

  private func currentConfiguredKinds() async -> Set<String> {
    if let cachedKinds, let cachedAt, Date().timeIntervalSince(cachedAt) < cacheDuration {
      return cachedKinds
    }

    if let loadingTask {
      return await loadingTask.value
    }

    let task = Task {
      await Self.loadConfiguredKinds()
    }
    loadingTask = task

    let kinds = await task.value
    cachedKinds = kinds
    cachedAt = Date()
    loadingTask = nil

    return kinds
  }

  private static func loadConfiguredKinds() async -> Set<String> {
    #if canImport(WidgetKit) && !os(tvOS)
      await withCheckedContinuation { (continuation: CheckedContinuation<Set<String>, Never>) in
        WidgetCenter.shared.getCurrentConfigurations { result in
          switch result {
          case .success(let widgets):
            continuation.resume(returning: Set(widgets.map(\.kind)))
          case .failure(let error):
            AppLogger(.app).error(
              "Failed to read widget configurations: \(error.localizedDescription)"
            )
            continuation.resume(returning: Set(WidgetDataStore.widgetKinds))
          }
        }
      }
    #else
      []
    #endif
  }
}
