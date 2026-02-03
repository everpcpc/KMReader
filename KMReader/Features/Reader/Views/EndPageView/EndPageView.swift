//
//  EndPageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct EndPageView: View {
  @Bindable var viewModel: ReaderViewModel
  let nextBook: Book?
  let readList: ReadList?
  let onDismiss: () -> Void
  let onNextBook: (String) -> Void
  let readingDirection: ReadingDirection
  let onPreviousPage: () -> Void
  let onFocusChange: ((Bool) -> Void)?
  var onExternalPanUpdate: ((@escaping (CGFloat) -> Void) -> Void)?
  var onExternalPanEnd: ((@escaping (CGFloat) -> Void) -> Void)?
  var showImage: Bool = true

  @Environment(\.readerBackgroundPreference) private var readerBackground

  @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
  @AppStorage("tapZoneMode") private var tapZoneMode: TapZoneMode = .auto

  #if os(iOS)
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var hasTriggeredHaptic = false
    private let swipeThreshold: CGFloat = 120
  #endif

  #if os(tvOS)
    private enum ButtonFocus: Hashable {
      case hidden
      case close
      case next
    }
    @FocusState private var focusedButton: ButtonFocus?
    @State private var shouldSetFocus = false
  #endif

  #if os(iOS)
    var dragProgress: CGFloat {
      guard nextBook != nil else { return 0 }
      return min(abs(dragOffset) / swipeThreshold, 1.0)
    }

    var shouldShowArc: Bool {
      guard nextBook != nil else { return false }
      guard isDragging else { return false }
      return readingDirection.isForwardSwipe(dragOffset)
    }

    func handlePanUpdate(_ translation: CGFloat) {
      guard nextBook != nil else { return }
      isDragging = true
      dragOffset = translation

      if abs(dragOffset) >= swipeThreshold && !hasTriggeredHaptic {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        hasTriggeredHaptic = true
      }
    }

    func handlePanEnd(_ translation: CGFloat) {
      let shouldAcceptDrag = readingDirection.isForwardSwipe(translation)

      if shouldAcceptDrag && abs(dragOffset) >= swipeThreshold, let nextBook = nextBook {
        onNextBook(nextBook.id)
      }

      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        dragOffset = 0
        isDragging = false
        hasTriggeredHaptic = false
      }
    }
  #endif

  private var textColor: Color {
    switch readerBackground {
    case .black:
      return .white
    case .white:
      return .black
    case .gray:
      return .white
    case .system:
      return .primary
    }
  }

  var body: some View {
    ZStack {
      #if os(iOS)
        if readingDirection != .webtoon {
          readerBackground.color
            .readerIgnoresSafeArea()
            .overlay(
              Group {
                SwipeDetector(
                  readingDirection: readingDirection,
                  tapZoneMode: tapZoneMode,
                  tapZoneSize: tapZoneSize,
                  onPreviousPage: onPreviousPage,
                  onUpdate: { translation in
                    handlePanUpdate(translation)
                  },
                  onEnd: { translation in
                    handlePanEnd(translation)
                  }
                )
              }
            )
        }
      #endif

      #if os(iOS)
        if shouldShowArc {
          ArcEffectView(
            color: textColor,
            progress: dragProgress,
            readingDirection: readingDirection,
          )
          .environment(\.layoutDirection, .leftToRight)
          .allowsHitTesting(false)
        }
      #endif

      content
    }
    #if os(iOS)
      .onAppear {
        onExternalPanUpdate?(handlePanUpdate)
        onExternalPanEnd?(handlePanEnd)
      }
    #endif
    #if os(tvOS)
      .id("endpage-\(viewModel.currentPageIndex >= viewModel.pages.count ? "active" : "inactive")")
      .onAppear {
        if viewModel.currentPageIndex >= viewModel.pages.count {
          shouldSetFocus = true
        }
      }
      .onChange(of: viewModel.currentPageIndex) { _, newIndex in
        if newIndex >= viewModel.pages.count {
          shouldSetFocus = true
        }
      }
      .onChange(of: shouldSetFocus) { _, shouldSet in
        guard shouldSet else { return }
        focusedButton = .close
        onFocusChange?(true)
        shouldSetFocus = false
      }
      .onChange(of: focusedButton) { _, newValue in
        let hasFocus = newValue != nil && newValue != .hidden
        onFocusChange?(hasFocus)
      }
      .defaultFocus($focusedButton, .close)
      .focusSection()
    #endif
  }

  private var content: some View {
    VStack {
      NextBookInfoView(
        textColor: textColor,
        nextBook: nextBook,
        readList: readList,
        showImage: showImage
      )
      .environment(\.layoutDirection, .leftToRight)
      .allowsHitTesting(false)

      HStack(spacing: 16) {
        // Hidden button for navigation (leading side)
        #if os(tvOS)
          Button {
          } label: {
            Color.clear
              .frame(width: 1, height: 1)
          }
          .adaptiveButtonStyle(.plain)
          .focused($focusedButton, equals: .hidden)
        #endif

        // Dismiss button
        Button {
          onDismiss()
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "xmark")
            Text("Close")
          }
          .padding(.horizontal, 4)
          .contentShape(.capsule)
        }
        .adaptiveButtonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(.primary)
        #if os(tvOS)
          .focused($focusedButton, equals: .close)
        #endif

        // Next book button
        if let nextBook = nextBook {
          Button {
            onNextBook(nextBook.id)
          } label: {
            HStack(spacing: 8) {
              Text(String(localized: "reader.nextBook"))
              Image(systemName: readingDirection == .rtl ? "arrow.left" : "arrow.right")
            }
            .padding(.horizontal, 4)
            .contentShape(.capsule)
          }
          .adaptiveButtonStyle(.bordered)
          .buttonBorderShape(.capsule)
          .tint(.primary)
          #if os(tvOS)
            .focused($focusedButton, equals: .next)
          #endif
        }
      }
    }
    .environment(\.layoutDirection, readingDirection == .rtl ? .rightToLeft : .leftToRight)
    .padding(40)
  }

}

#if os(iOS)
  struct SwipeDetector: UIViewRepresentable {
    var readingDirection: ReadingDirection
    var tapZoneMode: TapZoneMode
    var tapZoneSize: TapZoneSize
    var onPreviousPage: () -> Void
    var onUpdate: (CGFloat) -> Void
    var onEnd: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
      let view = UIView()
      view.backgroundColor = .clear

      let gesture = UIPanGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handlePan(_:))
      )
      gesture.delegate = context.coordinator
      view.addGestureRecognizer(gesture)

      if readingDirection != .webtoon {
        let singleTap = UITapGestureRecognizer(
          target: context.coordinator,
          action: #selector(Coordinator.handleSingleTap(_:))
        )
        singleTap.numberOfTapsRequired = 1
        singleTap.delegate = context.coordinator
        singleTap.cancelsTouchesInView = false
        view.addGestureRecognizer(singleTap)

        let longPress = UILongPressGestureRecognizer(
          target: context.coordinator,
          action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        longPress.delegate = context.coordinator
        longPress.cancelsTouchesInView = false
        view.addGestureRecognizer(longPress)
      }
      return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
      context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(parent: self)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
      var parent: SwipeDetector

      var isLongPressing = false
      var lastLongPressEndTime: Date = .distantPast
      var lastTouchStartTime: Date = .distantPast

      init(parent: SwipeDetector) {
        self.parent = parent
      }

      func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        lastTouchStartTime = Date()
        if let view = touch.view, view is UIControl {
          return false
        }
        return true
      }

      @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation: CGFloat
        switch parent.readingDirection {
        case .ltr, .rtl:
          translation = gesture.translation(in: gesture.view).x
        case .vertical, .webtoon:
          translation = gesture.translation(in: gesture.view).y
        }
        if gesture.state == .changed {
          parent.onUpdate(translation)
        } else if gesture.state == .ended || gesture.state == .cancelled {
          parent.onEnd(translation)
        }
      }

      func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: pan.view)

        switch parent.readingDirection {
        case .ltr:
          // Ignore vertical swipes, accept leftward (< 0) for next
          if abs(velocity.y) > abs(velocity.x) { return false }
          return velocity.x < 0
        case .rtl:
          // Ignore vertical swipes, accept rightward (> 0) for next
          if abs(velocity.y) > abs(velocity.x) { return false }
          return velocity.x > 0
        case .vertical, .webtoon:
          // Ignore horizontal swipes, accept upward (< 0) for next
          if abs(velocity.x) > abs(velocity.y) { return false }
          return velocity.y < 0
        }
      }

      @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
          isLongPressing = true
        } else if gesture.state == .ended || gesture.state == .cancelled {
          lastLongPressEndTime = Date()
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLongPressing = false
          }
        }
      }

      @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        let holdDuration = Date().timeIntervalSince(lastTouchStartTime)
        guard !isLongPressing && holdDuration < 0.3 else { return }

        if Date().timeIntervalSince(lastLongPressEndTime) < 0.5 { return }

        guard let view = gesture.view else { return }

        let location = gesture.location(in: view)
        let normalizedX = location.x / view.bounds.width
        let normalizedY = location.y / view.bounds.height

        let action = TapZoneHelper.action(
          normalizedX: normalizedX,
          normalizedY: normalizedY,
          tapZoneMode: parent.tapZoneMode,
          readingDirection: parent.readingDirection,
          zoneThreshold: parent.tapZoneSize.value
        )

        switch action {
        case .previous:
          parent.onPreviousPage()
        default:
          break
        }
      }
    }
  }
#endif
