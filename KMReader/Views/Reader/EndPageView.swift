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

  var body: some View {
    ZStack {
      #if os(iOS)
        // Arc effect overlay
        if isDragging, nextBook != nil {
          let progress = min(abs(dragOffset) / swipeThreshold, 1.0)
          let shouldShowArc = isRTL ? dragOffset > 0 : dragOffset < 0

          if shouldShowArc {
            ArcEffectView(
              progress: progress,
              isLeading: isRTL,
              themeColor: themeColor.color
            )
          }
        }
      #endif

      content
    }
    #if os(iOS)
      .gesture(
        DragGesture(minimumDistance: 10)
          .onChanged { value in
            guard nextBook != nil else { return }

            let translation = value.translation.width
            let shouldAcceptDrag = isRTL ? translation > 0 : translation < 0

            // Only update state for forward swipes
            if shouldAcceptDrag {
              isDragging = true
              dragOffset = translation

              // Trigger haptic feedback when threshold is reached
              if abs(dragOffset) >= swipeThreshold && !hasTriggeredHaptic {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                hasTriggeredHaptic = true
              }
            }
          }
          .onEnded { value in
            let translation = value.translation.width
            let shouldAcceptDrag = isRTL ? translation > 0 : translation < 0

            if shouldAcceptDrag && abs(dragOffset) >= swipeThreshold, let nextBook = nextBook {
              // Trigger navigation to next book
              onNextBook(nextBook.id)
            }

            // Reset state
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
              dragOffset = 0
              isDragging = false
              hasTriggeredHaptic = false
            }
          }
      )
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
