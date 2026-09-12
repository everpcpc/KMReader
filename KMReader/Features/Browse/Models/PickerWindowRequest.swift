//
// PickerWindowRequest.swift
//
//

#if os(macOS)
  import Foundation

  /// Payload for the standalone picker window (`WindowGroup(for:)`).
  /// Presenting the read-list / collection pickers as independent windows
  /// instead of view-attached sheets avoids wedging the app when the picker
  /// is triggered from an NSMenu action on macOS 15 (#959).
  enum PickerWindowRequest: Codable, Hashable {
    case readList(bookId: String)
    case collection(seriesId: String)
  }
#endif
