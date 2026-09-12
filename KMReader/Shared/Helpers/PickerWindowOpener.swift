//
// PickerWindowOpener.swift
//
//

#if os(macOS)
  import Foundation

  /// Routes picker-window open requests from deep view hierarchies (context
  /// menus, toolbar menus) to the `openWindow` environment captured at the
  /// app scene root (#959).
  @MainActor
  final class PickerWindowOpener {
    static let shared = PickerWindowOpener()

    private var openWindowHandler: ((PickerWindowRequest) -> Void)?

    private init() {}

    func configure(_ handler: @escaping (PickerWindowRequest) -> Void) {
      openWindowHandler = handler
    }

    func open(_ request: PickerWindowRequest) {
      openWindowHandler?(request)
    }
  }
#endif
