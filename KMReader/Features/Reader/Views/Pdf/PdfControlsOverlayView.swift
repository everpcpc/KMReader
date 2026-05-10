#if os(iOS) || os(macOS)
  import SwiftUI

  struct PdfControlsOverlayView: View {
    @Binding var readingDirection: ReadingDirection
    @Binding var pageLayout: PageLayout
    @Binding var isolateCoverPage: Bool
    @Binding var continuousScroll: Bool

    @Binding var showingPageJumpSheet: Bool
    @Binding var showingSearchSheet: Bool
    @Binding var showingTOCSheet: Bool
    @Binding var showingReaderSettingsSheet: Bool
    @Binding var showingDetailSheet: Bool

    let currentBook: Book?
    let fallbackTitle: String
    let incognito: Bool
    let currentPage: Int
    let pageCount: Int
    let hasTOC: Bool
    let canSearch: Bool
    let controlsVisible: Bool
    let showGradientBackground: Bool
    let showProgressBarWhileReading: Bool
    let onDismiss: () -> Void

    @Namespace private var progressBarNamespace

    private var animation: Animation {
      .easeInOut(duration: 0.2)
    }

    private var progress: Double {
      guard pageCount > 0 else { return 0 }
      let clampedPage = min(max(currentPage, 1), pageCount)
      return Double(clampedPage) / Double(pageCount)
    }

    private var displayedCurrentPage: String {
      guard pageCount > 0 else { return "0" }
      if currentPage > pageCount {
        return String(localized: "reader.page.end")
      }
      return String(max(1, currentPage))
    }

    var body: some View {
      ZStack(alignment: .bottom) {
        topControlsLayer
        bottomControlsLayer
        hiddenProgressLayer
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .animation(animation, value: controlsVisible)
      .animation(animation, value: showProgressBarWhileReading)
      .allowsHitTesting(controlsVisible)
      #if os(iOS)
        .tint(.primary)
      #endif
    }

    private var progressHorizontalPadding: CGFloat {
      controlsVisible ? 0 : 48
    }

    private var bottomControlsTransition: AnyTransition {
      guard showProgressBarWhileReading else {
        return .move(edge: .bottom).combined(with: .opacity)
      }
      return .opacity
    }

    @ViewBuilder
    private var topControlsLayer: some View {
      VStack(spacing: 0) {
        if controlsVisible {
          topBar
            .transition(
              .move(edge: .top)
                .combined(with: .opacity)
            )
        }

        Spacer(minLength: 0)
      }
    }

    @ViewBuilder
    private var bottomControlsLayer: some View {
      if controlsVisible {
        visibleBottomOverlayBar
          .transition(bottomControlsTransition)
      }
    }

    @ViewBuilder
    private var hiddenProgressLayer: some View {
      if !controlsVisible && showProgressBarWhileReading {
        hiddenProgressBar
          .transition(.opacity)
      }
    }

    private var topBar: some View {
      HStack {
        #if !os(macOS)
          Button {
            onDismiss()
          } label: {
            Image(systemName: "xmark")
              .contentShape(Circle())
          }
          .buttonBorderShape(.circle)
          .controlSize(.large)
          .readerControlButtonStyle()
        #endif

        Spacer()

        if !titleText.isEmpty {
          Button {
            guard currentBook != nil else { return }
            showingDetailSheet = true
          } label: {
            HStack(spacing: 4) {
              if incognito {
                Image(systemName: "eye.slash.fill")
                  .font(.callout)
              }

              if let subtitleText {
                VStack(alignment: incognito ? .leading : .center, spacing: 4) {
                  Text(titleText)
                    .lineLimit(1)
                  Text(subtitleText)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .lineLimit(1)
                }
              } else {
                Text(titleText)
                  .lineLimit(2)
              }
            }
            .padding(.vertical, 2)
            .padding(.horizontal)
            .readerHeaderTitleControlFrame()
            .contentShape(Capsule())
          }
          .optimizedControlSize()
          .readerControlButtonStyle()
        }

        Spacer()

        #if !os(macOS)
          Menu {
            menuContent()
          } label: {
            Image(systemName: "ellipsis")
              .padding(4)
              .contentShape(Circle())
          }
          .buttonBorderShape(.circle)
          .controlSize(.large)
          .readerControlButtonStyle()
        #endif
      }
      .allowsHitTesting(true)
      .padding()
      .iPadIgnoresSafeArea(paddingTop: 24)
      .background {
        gradientBackground(startPoint: .top, endPoint: .bottom)
          .ignoresSafeArea(edges: .top)
      }
    }

    private var visibleBottomOverlayBar: some View {
      bottomOverlayContent(showPageButton: true)
        .padding()
        .background {
          gradientBackground(startPoint: .bottom, endPoint: .top)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var hiddenProgressBar: some View {
      ZStack(alignment: .bottom) {
        Color.clear
        bottomOverlayContent(showPageButton: false)
          .frame(maxWidth: .infinity)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .readerIgnoresSafeArea()
      .allowsHitTesting(false)
    }

    private func bottomOverlayContent(showPageButton: Bool) -> some View {
      VStack(spacing: 12) {
        if showPageButton {
          HStack {
            Spacer(minLength: 0)

            Button {
              guard pageCount > 0 else { return }
              showingPageJumpSheet = true
            } label: {
              HStack(spacing: 6) {
                Image(systemName: "bookmark")
                Text("\(displayedCurrentPage) / \(pageCount)")
                  .monospacedDigit()
              }
              .contentShape(Capsule())
            }
            .readerControlButtonStyle()
            .disabled(pageCount <= 0)

            Spacer(minLength: 0)
          }
          .optimizedControlSize()
          .allowsHitTesting(true)
        }

        progressBar
          .padding(.horizontal, progressHorizontalPadding)
      }
      .animation(animation, value: progressHorizontalPadding)
    }

    @ViewBuilder
    private var progressBar: some View {
      let bar = ReadingProgressBar(progress: progress, type: .reader)
        .scaleEffect(x: readingDirection == .rtl ? -1 : 1, y: 1)

      if showProgressBarWhileReading {
        bar.matchedGeometryEffect(id: "readerProgressBar", in: progressBarNamespace)
      } else {
        bar
      }
    }

    @ViewBuilder
    private func menuContent() -> some View {
      Section {
        Picker(selection: $readingDirection) {
          ForEach(ReadingDirection.pdfAvailableCases, id: \.self) { direction in
            Label(direction.displayName, systemImage: direction.icon)
              .tag(direction)
          }
        } label: {
          Label(String(localized: "Reading Direction"), systemImage: readingDirection.icon)
        }
        .pickerStyle(.menu)

        Picker(selection: $pageLayout) {
          ForEach(PageLayout.allCases, id: \.self) { layout in
            Label(layout.displayName, systemImage: layout.icon)
              .tag(layout)
          }
        } label: {
          Label(String(localized: "Page Layout"), systemImage: pageLayout.icon)
        }
        .pickerStyle(.menu)

        if pageLayout.supportsDualPageOptions {
          pageIsolation()
        }

        Toggle(isOn: $continuousScroll) {
          Label(String(localized: "Continuous Scroll"), systemImage: "scroll")
        }
      } header: {
        Text(String(localized: "Current Reading Options"))
      }

      Button {
        showingReaderSettingsSheet = true
      } label: {
        Label(String(localized: "Reader Settings"), systemImage: "gearshape")
      }

      Section {
        if hasTOC {
          Button {
            showingTOCSheet = true
          } label: {
            Label(String(localized: "Table of Contents"), systemImage: "list.bullet")
          }
        }

        Button {
          guard pageCount > 0 else { return }
          showingPageJumpSheet = true
        } label: {
          Label(String(localized: "Jump to Page"), systemImage: "bookmark")
        }
        .disabled(pageCount <= 0)

        Button {
          showingSearchSheet = true
        } label: {
          Label(String(localized: "Search"), systemImage: "magnifyingglass")
        }
        .disabled(!canSearch)
      } header: {
        Text(String(localized: "Page Navigation"))
      }
    }

    @ViewBuilder
    private func pageIsolation() -> some View {
      Button {
        isolateCoverPage.toggle()
      } label: {
        Label(
          String(localized: "Isolate Cover Page"),
          systemImage: isolateCoverPage ? "checkmark.rectangle.portrait" : "rectangle.portrait"
        )
      }
    }

    @ViewBuilder
    private func gradientBackground(
      startPoint: UnitPoint,
      endPoint: UnitPoint
    ) -> some View {
      if showGradientBackground {
        LinearGradient(
          gradient: Gradient(colors: [
            Color.black.opacity(0.72),
            Color.black.opacity(0.44),
            Color.clear,
          ]),
          startPoint: startPoint,
          endPoint: endPoint
        )
      }
    }

    private var titleText: String {
      if let currentBook {
        if currentBook.oneshot {
          return currentBook.metadata.title
        }

        return "#\(currentBook.metadata.number) - \(currentBook.metadata.title)"
      }

      return fallbackTitle
    }

    private var subtitleText: String? {
      guard let currentBook else { return nil }
      guard !currentBook.oneshot else { return nil }
      return currentBook.seriesTitle
    }
  }
#endif
