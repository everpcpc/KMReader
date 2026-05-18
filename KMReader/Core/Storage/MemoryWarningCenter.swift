import Foundation

#if os(iOS) || os(tvOS)
  import UIKit

  @MainActor
  protocol MemoryWarningListener: AnyObject {
    func handleMemoryWarning()
  }

  @MainActor
  final class MemoryWarningCenter {
    static let shared = MemoryWarningCenter()

    private struct WeakListener {
      weak var value: (any MemoryWarningListener)?
    }

    private let logger = AppLogger(.app)
    private var listeners: [WeakListener] = []

    private init() {
      Task { @MainActor [weak self] in
        for await _ in NotificationCenter.default.notifications(
          named: UIApplication.didReceiveMemoryWarningNotification
        ) {
          self?.notifyListeners()
        }
      }
    }

    func addListener(_ listener: any MemoryWarningListener) {
      compactListeners()
      guard !listeners.contains(where: { $0.value === listener }) else { return }
      listeners.append(WeakListener(value: listener))
    }

    func removeListener(_ listener: any MemoryWarningListener) {
      listeners.removeAll { $0.value == nil || $0.value === listener }
    }

    private func notifyListeners() {
      compactListeners()
      let liveListeners = listeners.compactMap(\.value)
      logger.warning("⚠️ [Memory] Received memory warning; notifying \(liveListeners.count) listener(s)")
      for listener in liveListeners {
        listener.handleMemoryWarning()
      }
    }

    private func compactListeners() {
      listeners.removeAll { $0.value == nil }
    }
  }
#endif
