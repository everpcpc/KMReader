//
//  PageTapModifier.swift
//  KMReader
//
//  Created by antigravity on 2025/12/15.
//

import SwiftUI

#if os(iOS)
  import UIKit

  /// A transparent view that observes taps and long presses without blocking underlying views.
  /// Used in EPUB reader where we need to overlay on top of UIViewControllerRepresentable.
  struct TapGestureOverlay: UIViewRepresentable {
    let onTap: (CGPoint) -> Void

    func makeUIView(context: Context) -> UIView {
      let view = UIView()
      view.backgroundColor = .clear
      view.isUserInteractionEnabled = true

      let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
      tap.numberOfTapsRequired = 1
      tap.cancelsTouchesInView = false
      tap.delegate = context.coordinator
      view.addGestureRecognizer(tap)

      let longPress = UILongPressGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
      longPress.minimumPressDuration = 0.5
      longPress.cancelsTouchesInView = false
      longPress.delegate = context.coordinator
      view.addGestureRecognizer(longPress)

      return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
      context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
      var onTap: ((CGPoint) -> Void)?
      var isLongPressing = false

      @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
          isLongPressing = true
        } else if gesture.state == .ended || gesture.state == .cancelled {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isLongPressing = false
          }
        }
      }

      @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard !isLongPressing, let view = gesture.view else { return }
        let location = gesture.location(in: view)
        onTap?(location)
      }

      func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
      ) -> Bool {
        return true
      }
    }
  }
#endif

#if os(macOS)
  import AppKit

  /// A transparent view for macOS that observes clicks/presses.
  struct TapGestureOverlay: NSViewRepresentable {
    let onTap: (CGPoint) -> Void

    func makeNSView(context: Context) -> NSView {
      let view = NSView()
      view.wantsLayer = true
      view.layer?.backgroundColor = .clear

      let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
      click.numberOfClicksRequired = 1
      click.delegate = context.coordinator
      view.addGestureRecognizer(click)

      let press = NSPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePress(_:)))
      press.minimumPressDuration = 0.5
      press.delegate = context.coordinator
      view.addGestureRecognizer(press)

      return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
      context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    class Coordinator: NSObject, NSGestureRecognizerDelegate {
      var onTap: ((CGPoint) -> Void)?
      var isLongPressing = false

      @objc func handlePress(_ gesture: NSPressGestureRecognizer) {
        if gesture.state == .began {
          isLongPressing = true
        } else if gesture.state == .ended || gesture.state == .cancelled {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isLongPressing = false
          }
        }
      }

      @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
        guard !isLongPressing, let view = gesture.view else { return }
        let location = gesture.location(in: view)
        let flippedY = view.bounds.height - location.y
        onTap?(CGPoint(x: location.x, y: flippedY))
      }

      func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
      ) -> Bool {
        return true
      }
    }
  }
#endif

struct PageTapModifier: ViewModifier {
  let size: CGSize
  let readingDirection: ReadingDirection
  let isZoomed: Bool
  let liveTextActive: Bool
  let onNextPage: () -> Void
  let onPreviousPage: () -> Void
  let onToggleControls: () -> Void

  @AppStorage("disableTapToTurnPage") private var disableTapToTurnPage: Bool = false
  @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large

  func body(content: Content) -> some View {
    #if os(iOS) || os(macOS)
      content
        .overlay(
          TapGestureOverlay(
            onTap: { location in
              guard !isZoomed && !liveTextActive else { return }
              handleTap(at: location)
            }
          )
          .allowsHitTesting(!isZoomed && liveTextActive == false)
        )
    #else
      content
    #endif
  }

  private func handleTap(at location: CGPoint) {
    if readingDirection == .vertical || readingDirection == .webtoon {
      handleVerticalTap(at: location)
    } else {
      handleHorizontalTap(at: location)
    }
  }

  private func handleHorizontalTap(at location: CGPoint) {
    guard size.width > 0 else { return }
    let normalizedX = max(0, min(1, location.x / size.width))
    let zoneThreshold = tapZoneSize.value

    if normalizedX < zoneThreshold {
      if !disableTapToTurnPage {
        if readingDirection == .rtl {
          onNextPage()
        } else {
          onPreviousPage()
        }
      }
    } else if normalizedX > (1.0 - zoneThreshold) {
      if !disableTapToTurnPage {
        if readingDirection == .rtl {
          onPreviousPage()
        } else {
          onNextPage()
        }
      }
    } else {
      onToggleControls()
    }
  }

  private func handleVerticalTap(at location: CGPoint) {
    guard size.height > 0 else { return }
    let normalizedY = max(0, min(1, location.y / size.height))
    let zoneThreshold = tapZoneSize.value

    if normalizedY < zoneThreshold {
      if !disableTapToTurnPage {
        onPreviousPage()
      }
    } else if normalizedY > (1.0 - zoneThreshold) {
      if !disableTapToTurnPage {
        onNextPage()
      }
    } else {
      onToggleControls()
    }
  }
}

extension View {
  func pageTapGesture(
    size: CGSize,
    readingDirection: ReadingDirection,
    isZoomed: Bool = false,
    liveTextActive: Bool = false,
    onNextPage: @escaping () -> Void,
    onPreviousPage: @escaping () -> Void,
    onToggleControls: @escaping () -> Void
  ) -> some View {
    modifier(
      PageTapModifier(
        size: size,
        readingDirection: readingDirection,
        isZoomed: isZoomed,
        liveTextActive: liveTextActive,
        onNextPage: onNextPage,
        onPreviousPage: onPreviousPage,
        onToggleControls: onToggleControls
      )
    )
  }
}
