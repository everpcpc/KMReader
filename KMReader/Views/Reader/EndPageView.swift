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
  let isRTL: Bool
  let onFocusChange: ((Bool) -> Void)?

  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
  @Environment(\.readerBackgroundPreference) private var readerBackground

  #if os(iOS)
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var hasTriggeredHaptic = false
    private let swipeThreshold: CGFloat = 200
    @GestureState private var gestureTranslation: CGFloat = 0
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
      return isRTL ? dragOffset > 0 : dragOffset < 0
    }
  #endif

  var body: some View {
    ZStack {
      Color.clear
        #if os(iOS)
          .overlay(
            SwipeDetector(
              isRTL: isRTL,
              onUpdate: { translation in
                guard nextBook != nil else { return }
                isDragging = true
                dragOffset = translation

                if abs(dragOffset) >= swipeThreshold && !hasTriggeredHaptic {
                  let impact = UIImpactFeedbackGenerator(style: .medium)
                  impact.impactOccurred()
                  hasTriggeredHaptic = true
                }
              },
              onEnd: { translation in
                let shouldAcceptDrag = isRTL ? translation > 0 : translation < 0

                if shouldAcceptDrag && abs(dragOffset) >= swipeThreshold, let nextBook = nextBook {
                  onNextBook(nextBook.id)
                }

                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                  dragOffset = 0
                  isDragging = false
                  hasTriggeredHaptic = false
                }
              }
            )
          )
        #endif

      #if os(iOS)
        if shouldShowArc {
          ArcEffectView(
            progress: dragProgress,
            isLeading: isRTL,
            themeColor: themeColor.color
          )
        }
      #endif

      content
    }
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
    VStack(spacing: PlatformHelper.buttonSpacing) {
      HStack(spacing: PlatformHelper.buttonSpacing) {

        // Next book button for RTL
        if isRTL, let nextBook = nextBook {
          Button {
            onNextBook(nextBook.id)
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "arrow.left")
                .font(.system(size: 16, weight: .semibold))
              Text(String(localized: "reader.nextBook"))
                .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
              RoundedRectangle(cornerRadius: 25)
                .fill(themeColor.color.opacity(0.85))
                .overlay(
                  RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            .contentShape(Rectangle())
          }
          .adaptiveButtonStyle(.plain)
          #if os(tvOS)
            .focused($focusedButton, equals: .next)
          #endif
        }

        // Hidden button for navigation
        #if os(tvOS)
          if !isRTL {
            Button {
            } label: {
              Color.clear
                .frame(width: 1, height: 1)
            }
            .adaptiveButtonStyle(.plain)
            .focused($focusedButton, equals: .hidden)
          }
        #endif

        // Dismiss button
        Button {
          onDismiss()
        } label: {
          HStack(spacing: 8) {
            if !isRTL {
              Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
            }
            Text("Close")
              .font(.system(size: 16, weight: .medium))
            if isRTL {
              Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
            }
          }
          .foregroundColor(themeColor.color)
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(
            RoundedRectangle(cornerRadius: 25)
              .fill(Color.clear)
              .overlay(
                RoundedRectangle(cornerRadius: 25)
                  .stroke(themeColor.color.opacity(0.5), lineWidth: 1)
              )
          )
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          .contentShape(Rectangle())
        }
        .adaptiveButtonStyle(.plain)
        #if os(tvOS)
          .focused($focusedButton, equals: .close)
        #endif

        // Hidden button for navigation
        #if os(tvOS)
          if isRTL {
            Button {
            } label: {
              Color.clear
                .frame(width: 1, height: 1)
            }
            .adaptiveButtonStyle(.plain)
            .focused($focusedButton, equals: .hidden)
          }
        #endif

        // Next book button
        if !isRTL, let nextBook = nextBook {
          Button {
            onNextBook(nextBook.id)
          } label: {
            HStack(spacing: 8) {
              Text(String(localized: "reader.nextBook"))
                .font(.system(size: 16, weight: .medium))
              Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
              RoundedRectangle(cornerRadius: 25)
                .fill(themeColor.color.opacity(0.85))
                .overlay(
                  RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            .contentShape(Rectangle())
          }
          .adaptiveButtonStyle(.plain)
          #if os(tvOS)
            .focused($focusedButton, equals: .next)
          #endif
        }
      }
      NextBookInfoView(nextBook: nextBook, readList: readList)
    }
  }

}

#if os(iOS)
  struct SwipeDetector: UIViewRepresentable {
    var isRTL: Bool
    var onUpdate: (CGFloat) -> Void
    var onEnd: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
      let view = UIView()
      view.backgroundColor = .clear
      let gesture = UIPanGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
      gesture.delegate = context.coordinator
      view.addGestureRecognizer(gesture)
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

      init(parent: SwipeDetector) {
        self.parent = parent
      }

      @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view).x
        if gesture.state == .changed {
          parent.onUpdate(translation)
        } else if gesture.state == .ended || gesture.state == .cancelled {
          parent.onEnd(translation)
        }
      }

      func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: pan.view)

        // Ignore vertical swipes
        if abs(velocity.y) > abs(velocity.x) { return false }

        // LTR: Forward is Left (< 0), Backward is Right (> 0)
        // RTL: Forward is Right (> 0), Backward is Left (< 0)
        if parent.isRTL {
          return velocity.x > 0  // Accept only Next Book (Right)
        } else {
          return velocity.x < 0  // Accept only Next Book (Left)
        }
      }
    }
  }
#endif
