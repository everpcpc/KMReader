//
//  BookReaderView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookReaderView: View {
  let initialBookId: String

  @State private var currentBookId: String
  @State private var viewModel = ReaderViewModel()
  @Environment(\.dismiss) private var dismiss
  @State private var showingControls = true
  @State private var controlsTimer: Timer?
  @State private var currentBook: Book?
  @State private var seriesId: String?
  @State private var nextBook: Book?
  @State private var isAtBottom = false
  @State private var isAtEndPage = false
  @State private var showingReadingDirectionPicker = false
  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange
  @AppStorage("webtoonPageWidthPercentage") private var webtoonPageWidthPercentage: Double = 100.0

  init(bookId: String) {
    self.initialBookId = bookId
    self._currentBookId = State(initialValue: bookId)
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if viewModel.isLoading && viewModel.pages.isEmpty {
        ProgressView()
          .tint(.white)
      } else if !viewModel.pages.isEmpty {
        // Page viewer based on reading direction
        Group {
          switch viewModel.readingDirection {
          case .ltr, .rtl:
            horizontalPageView
          case .vertical:
            verticalPageView
          case .webtoon:
            webtoonPageView
          }
        }
        .onChange(of: viewModel.currentPage) { _, _ in
          Task {
            await viewModel.updateProgress()
            await viewModel.preloadPages()
          }
        }

        // Controls overlay (always show when at end page or webtoon at bottom)
        if showingControls || isAtEndPage || (viewModel.readingDirection == .webtoon && isAtBottom)
        {
          ReaderControlsView(
            showingControls: $showingControls,
            showingReadingDirectionPicker: $showingReadingDirectionPicker,
            viewModel: viewModel,
            currentBook: currentBook,
            themeColorOption: themeColorOption,
            onDismiss: { dismiss() }
          )
        }
      }
    }
    .statusBar(hidden: !showingControls)
    .sheet(isPresented: $showingReadingDirectionPicker) {
      NavigationStack {
        Form {
          Section(header: Text("Reading Direction")) {
            Picker("", selection: $viewModel.readingDirection) {
              ForEach(ReadingDirection.allCases, id: \.self) { direction in
                Label(direction.displayName, systemImage: direction.icon)
                  .tag(direction)
              }
            }
            .pickerStyle(.inline)
          }
        }
        .navigationTitle("Reading Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Done") {
              showingReadingDirectionPicker = false
            }
          }
        }
      }
      .presentationDetents([.medium])
    }
    .task(id: currentBookId) {
      // Reset isAtBottom and isAtEndPage when switching to a new book
      isAtBottom = false
      isAtEndPage = false

      // Load book info to get read progress page and series reading direction
      var initialPage: Int? = nil
      do {
        let book = try await BookService.shared.getBook(id: currentBookId)
        currentBook = book
        seriesId = book.seriesId
        initialPage = book.readProgress?.page

        // Get series reading direction
        let series = try await SeriesService.shared.getOneSeries(id: book.seriesId)
        if let readingDirectionString = series.metadata.readingDirection {
          viewModel.readingDirection = ReadingDirection.fromString(readingDirectionString)
        }

        // Load next book
        if let nextBook = try await BookService.shared.getNextBook(bookId: currentBookId) {
          self.nextBook = nextBook
        } else {
          nextBook = nil
        }
      } catch {
        // Silently fail, will start from first page
      }

      await viewModel.loadPages(bookId: currentBookId, initialPage: initialPage)
      await viewModel.preloadPages()

      // Start timer to auto-hide controls after 3 seconds when entering reader
      if !viewModel.pages.isEmpty {
        resetControlsTimer()
      }
    }
    .onDisappear {
      controlsTimer?.invalidate()
    }
  }

  // Horizontal page view (LTR/RTL)
  private var horizontalPageView: some View {
    TabView(
      selection: Binding(
        get: {
          if isAtEndPage {
            // For LTR, end page is at pages.count; for RTL, end page is at -1
            return viewModel.readingDirection == .rtl ? -1 : viewModel.pages.count
          }
          return viewModel.pageIndexToDisplayIndex(viewModel.currentPage)
        },
        set: { displayIndex in
          withAnimation {
            // Check if it's the end page
            let endPageIndex = viewModel.readingDirection == .rtl ? -1 : viewModel.pages.count
            if displayIndex == endPageIndex {
              isAtEndPage = true
              showingControls = true  // Show controls when reaching end page
            } else {
              isAtEndPage = false
              viewModel.currentPage = viewModel.displayIndexToPageIndex(displayIndex)
            }
          }
        }
      )
    ) {
      // For RTL, show end page first
      if viewModel.readingDirection == .rtl {
        endPageView
          .tag(-1)
      }

      ForEach(0..<viewModel.pages.count, id: \.self) { displayIndex in
        GeometryReader { geometry in
          ZStack {
            PageImageView(
              viewModel: viewModel,
              pageIndex: viewModel.displayIndexToPageIndex(displayIndex)
            )

            // Tap zones overlay
            HStack(spacing: 0) {
              // Left tap zone
              Color.clear
                .frame(width: geometry.size.width * 0.3)
                .contentShape(Rectangle())
                .simultaneousGesture(
                  TapGesture()
                    .onEnded { _ in
                      goToPreviousPage()
                    }
                )

              // Center tap zone (toggle controls)
              Color.clear
                .frame(width: geometry.size.width * 0.4)
                .contentShape(Rectangle())
                .simultaneousGesture(
                  TapGesture()
                    .onEnded { _ in
                      toggleControls()
                    }
                )

              // Right tap zone
              Color.clear
                .frame(width: geometry.size.width * 0.3)
                .contentShape(Rectangle())
                .simultaneousGesture(
                  TapGesture()
                    .onEnded { _ in
                      goToNextPage()
                    }
                )
            }
          }
        }
        .tag(displayIndex)
      }

      // For LTR, show end page last
      if viewModel.readingDirection == .ltr {
        endPageView
          .tag(viewModel.pages.count)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .indexViewStyle(.page(backgroundDisplayMode: .never))
  }

  // End page view with buttons and info
  private var endPageView: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      EndPageView(
        nextBook: nextBook,
        onDismiss: { dismiss() },
        onNextBook: { openNextBook(nextBookId: $0) }
      )
    }
  }

  // Vertical page view (VERTICAL)
  private var verticalPageView: some View {
    GeometryReader { screenGeometry in
      ScrollViewReader { proxy in
        ScrollView(.vertical) {
          LazyVStack(spacing: 0) {
            ForEach(0..<viewModel.pages.count, id: \.self) { pageIndex in
              GeometryReader { geometry in
                ZStack {
                  PageImageView(
                    viewModel: viewModel,
                    pageIndex: pageIndex
                  )

                  // Tap zones overlay
                  VStack(spacing: 0) {
                    // Top tap zone
                    Color.clear
                      .frame(height: geometry.size.height * 0.3)
                      .contentShape(Rectangle())
                      .simultaneousGesture(
                        TapGesture()
                          .onEnded { _ in
                            goToPreviousPage()
                          }
                      )

                    // Center tap zone (toggle controls)
                    Color.clear
                      .frame(height: geometry.size.height * 0.4)
                      .contentShape(Rectangle())
                      .simultaneousGesture(
                        TapGesture()
                          .onEnded { _ in
                            toggleControls()
                          }
                      )

                    // Bottom tap zone
                    Color.clear
                      .frame(height: geometry.size.height * 0.3)
                      .contentShape(Rectangle())
                      .simultaneousGesture(
                        TapGesture()
                          .onEnded { _ in
                            goToNextPage()
                          }
                      )
                  }
                }
              }
              .frame(width: screenGeometry.size.width, height: screenGeometry.size.height)
              .id(pageIndex)
              .onAppear {
                // Update current page when page appears
                if pageIndex != viewModel.currentPage && !isAtEndPage {
                  viewModel.currentPage = pageIndex
                }
              }
            }

            // End page after last page
            endPageView
              .frame(width: screenGeometry.size.width, height: screenGeometry.size.height)
              .id("endPage")
              .onAppear {
                isAtEndPage = true
                showingControls = true  // Show controls when end page appears
              }
          }
        }
        .scrollTargetBehavior(.paging)
        .onChange(of: viewModel.currentPage) { _, newPage in
          // Scroll to current page when changed externally (e.g., from slider)
          if !isAtEndPage {
            withAnimation {
              proxy.scrollTo(newPage, anchor: .top)
            }
          }
        }
        .onChange(of: isAtEndPage) { _, isEnd in
          if isEnd {
            withAnimation {
              proxy.scrollTo("endPage", anchor: .top)
            }
          }
        }
      }
    }
  }

  // Webtoon page view (WEBTOON - continuous vertical scroll)
  private var webtoonPageView: some View {
    let vm = viewModel
    return GeometryReader { geometry in
      let screenWidth = geometry.size.width
      let pageWidth = screenWidth * (webtoonPageWidthPercentage / 100.0)

      ZStack {
        WebtoonReaderView(
          pages: vm.pages,
          currentPage: Binding(
            get: { vm.currentPage },
            set: { newPage in
              if newPage != vm.currentPage {
                vm.currentPage = newPage
              }
            }
          ),
          viewModel: vm,
          pageWidth: pageWidth,
          onPageChange: { pageIndex in
            vm.currentPage = pageIndex
          },
          onCenterTap: {
            toggleControls()
          },
          onScrollToBottom: { atBottom in
            isAtBottom = atBottom
          }
        )

        if isAtBottom {
          VStack {
            Spacer()
            EndPageView(
              nextBook: nextBook,
              onDismiss: { dismiss() },
              onNextBook: { openNextBook(nextBookId: $0) }
            )
            .padding(.bottom, 120)
          }
          .transition(.opacity)
        }
      }
      .ignoresSafeArea()
    }
  }

  private func goToNextPage() {
    switch viewModel.readingDirection {
    case .ltr:
      if viewModel.currentPage < viewModel.pages.count - 1 {
        withAnimation {
          viewModel.currentPage += 1
          isAtEndPage = false
        }
      } else {
        // Navigate to end page
        withAnimation {
          isAtEndPage = true
          showingControls = true  // Show controls when reaching end page
        }
      }
    case .rtl:
      if viewModel.currentPage > 0 {
        withAnimation {
          viewModel.currentPage -= 1
          isAtEndPage = false
        }
      } else {
        // Navigate to end page (which is at -1 for RTL)
        withAnimation {
          isAtEndPage = true
          showingControls = true  // Show controls when reaching end page
        }
      }
    case .vertical:
      if viewModel.currentPage < viewModel.pages.count - 1 {
        withAnimation {
          viewModel.currentPage += 1
          isAtEndPage = false
        }
      } else {
        // Navigate to end page
        withAnimation {
          isAtEndPage = true
          showingControls = true  // Show controls when reaching end page
        }
      }
    case .webtoon:
      // Webtoon mode uses scroll, so we scroll to next page
      if viewModel.currentPage < viewModel.pages.count - 1 {
        withAnimation {
          viewModel.currentPage += 1
        }
      }
    }
  }

  private func goToPreviousPage() {
    switch viewModel.readingDirection {
    case .ltr:
      if isAtEndPage {
        // Go back from end page to last page
        withAnimation {
          isAtEndPage = false
          viewModel.currentPage = viewModel.pages.count - 1
        }
      } else if viewModel.currentPage > 0 {
        withAnimation {
          viewModel.currentPage -= 1
        }
      }
    case .rtl:
      if isAtEndPage {
        // Go back from end page to first page
        withAnimation {
          isAtEndPage = false
          viewModel.currentPage = 0
        }
      } else if viewModel.currentPage < viewModel.pages.count - 1 {
        withAnimation {
          viewModel.currentPage += 1
        }
      }
    case .vertical:
      if isAtEndPage {
        // Go back from end page to last page
        withAnimation {
          isAtEndPage = false
          viewModel.currentPage = viewModel.pages.count - 1
        }
      } else if viewModel.currentPage > 0 {
        withAnimation {
          viewModel.currentPage -= 1
        }
      }
    case .webtoon:
      // Webtoon mode uses scroll, so we scroll to previous page
      if viewModel.currentPage > 0 {
        withAnimation {
          viewModel.currentPage -= 1
        }
      }
    }
  }

  private func toggleReadingDirection() {
    // Toggle direction
    viewModel.readingDirection = viewModel.readingDirection == .ltr ? .rtl : .ltr

    // The currentPage remains the same (actual page index)
    // The display will update automatically through the TabView binding
  }

  private func toggleControls() {
    // Don't hide controls when at end page or webtoon at bottom
    if isAtEndPage || (viewModel.readingDirection == .webtoon && isAtBottom) {
      return
    }
    withAnimation {
      showingControls.toggle()
    }
    if showingControls {
      resetControlsTimer()
    }
  }

  private func resetControlsTimer() {
    // Don't start timer when at end page or webtoon at bottom
    if isAtEndPage || (viewModel.readingDirection == .webtoon && isAtBottom) {
      return
    }
    controlsTimer?.invalidate()
    controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
      withAnimation {
        showingControls = false
      }
    }
  }

  private func openNextBook(nextBookId: String) {
    // Switch to next book by updating currentBookId
    // This will trigger the .task(id: currentBookId) to reload
    currentBookId = nextBookId
    // Reset viewModel state for new book
    viewModel = ReaderViewModel()
    // Reset isAtBottom so buttons hide until user scrolls to bottom
    isAtBottom = false
  }
}
