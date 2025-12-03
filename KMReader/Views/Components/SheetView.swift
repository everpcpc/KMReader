//
//  SheetView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

/// Generic container for reader/browse sheets that share the same control layout rules.
/// - Parameters:
///   - title: Navigation bar title.
///   - size: Presentation size hint (medium, large, or both detents).
///   - content: Main body of the sheet (typically a Form or VStack).
///   - controls: Additional buttons such as Done/Save (a Close button is automatically added).
/// - Behavior:
///   - On non-tvOS platforms controls are injected into the navigation toolbar.
///   - On tvOS controls are displayed at the top of the sheet in an HStack.
///   - A standard Close button is always appended unless `showsCloseButton` is false.
struct SheetView<Content: View, Controls: View>: View {
  private let title: String?
  private let size: SheetPresentationSize
  private let showsCloseButton: Bool
  private let content: Content
  private let controls: Controls?
  @Environment(\.dismiss) private var dismiss

  private var hasControls: Bool {
    controls != nil || showsCloseButton
  }

  init(
    title: String? = nil,
    size: SheetPresentationSize = .large,
    showsCloseButton: Bool = true,
    @ViewBuilder content: () -> Content,
    @ViewBuilder controls: () -> Controls
  ) {
    self.title = title
    self.size = size
    self.showsCloseButton = showsCloseButton
    self.content = content()
    self.controls = controls()
  }

  init(
    title: String? = nil,
    size: SheetPresentationSize = .large,
    showsCloseButton: Bool = true,
    @ViewBuilder content: () -> Content
  ) where Controls == EmptyView {
    self.title = title
    self.size = size
    self.showsCloseButton = showsCloseButton
    self.content = content()
    self.controls = nil
  }

  var body: some View {
    NavigationStack {
      sheetContent()
        .padding(PlatformHelper.sheetPadding)
        .inlineTitleIfNeeded(title)
    }.applySheetSize(size)
  }

  @ViewBuilder
  private func sheetContent() -> some View {
    #if os(tvOS)
      VStack(alignment: .trailing, spacing: 16) {
        if hasControls {
          HStack(spacing: 24) {
            if showsCloseButton {
              Button {
                dismiss()
              } label: {
                Label("Close", systemImage: "xmark")
              }
            }
            Spacer()
            if let controls {
              controls
            }
          }
          .focusSection()
        }
        content
      }
    #else
      if hasControls {
        content
          .toolbar {
            if showsCloseButton {
              ToolbarItem(placement: .cancellationAction) {
                Button {
                  dismiss()
                } label: {
                  Label("Close", systemImage: "xmark")
                }
              }
            }
            if let controls {
              ToolbarItem(placement: .automatic) {
                controls
              }
            }
          }
      } else {
        content
      }
    #endif
  }
}

extension View {
  @ViewBuilder
  fileprivate func inlineTitleIfNeeded(_ title: String?) -> some View {
    if let title {
      self.inlineNavigationBarTitle(title)
    } else {
      self
    }
  }
}

enum SheetPresentationSize {
  case medium
  case large
  case both

  #if os(iOS)
    var detents: Set<PresentationDetent> {
      switch self {
      case .medium:
        return [.medium]
      case .large:
        return [.large]
      case .both:
        return [.medium, .large]
      }
    }
  #endif

  #if os(macOS)
    var minDimensions: CGSize {
      switch self {
      case .medium:
        return CGSize(width: 520, height: 420)
      case .large, .both:
        return CGSize(width: 720, height: 600)
      }
    }
  #endif
}

extension View {
  fileprivate func applySheetSize(_ size: SheetPresentationSize) -> some View {
    #if os(iOS)
      return self.presentationDetents(size.detents)
    #elseif os(macOS)
      return self.frame(minWidth: size.minDimensions.width, minHeight: size.minDimensions.height)
    #elseif os(tvOS)
      return self.presentationDetents([.large])
    #else
      return self
    #endif
  }
}
