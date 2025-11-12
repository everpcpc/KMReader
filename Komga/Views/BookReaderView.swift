//
//  BookReaderView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookReaderView: View {
  let bookId: String

  @State private var viewModel = ReaderViewModel()
  @Environment(\.dismiss) private var dismiss
  @State private var showingControls = true
  @State private var controlsTimer: Timer?

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if viewModel.isLoading && viewModel.pages.isEmpty {
        ProgressView()
          .tint(.white)
      } else if !viewModel.pages.isEmpty {
        // Page viewer with swipe animation
        TabView(
          selection: Binding(
            get: { viewModel.pageIndexToDisplayIndex(viewModel.currentPage) },
            set: { displayIndex in
              withAnimation {
                viewModel.currentPage = viewModel.displayIndexToPageIndex(displayIndex)
              }
            }
          )
        ) {
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
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        .onChange(of: viewModel.currentPage) { _, _ in
          Task {
            await viewModel.updateProgress()
            await viewModel.preloadPages()
          }
        }
        .onChange(of: viewModel.readingDirection) { _, _ in
          // When direction changes, maintain the current page position
          // The TabView will automatically update due to the binding
        }

        // Controls overlay
        if showingControls {
          VStack {
            // Top bar
            HStack {
              Button {
                dismiss()
              } label: {
                Image(systemName: "xmark")
                  .font(.title2)
                  .foregroundColor(.white)
                  .padding()
                  .background(Color.black.opacity(0.5))
                  .clipShape(Circle())
              }

              Spacer()

              // Reading direction toggle button
              Button {
                toggleReadingDirection()
              } label: {
                Image(
                  systemName: viewModel.readingDirection == .ltr
                    ? "arrow.left.arrow.right" : "arrow.right.arrow.left"
                )
                .font(.title3)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
              }

              Spacer()

              Text("\(viewModel.currentPage + 1) / \(viewModel.pages.count)")
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(20)
            }
            .padding()

            Spacer()

            // Bottom slider
            VStack {
              Slider(
                value: Binding(
                  get: { Double(viewModel.pageIndexToDisplayIndex(viewModel.currentPage)) },
                  set: { displayIndex in
                    viewModel.currentPage = viewModel.displayIndexToPageIndex(Int(displayIndex))
                  }
                ),
                in: 0...Double(max(0, viewModel.pages.count - 1)),
                step: 1
              )
              .tint(.white)
            }
            .padding()
          }
          .background(
            LinearGradient(
              gradient: Gradient(colors: [
                .black.opacity(0.5),
                .black.opacity(0.2),
                .clear, .clear,
                .black.opacity(0.2),
                .black.opacity(0.5),
              ]),
              startPoint: .top,
              endPoint: .bottom
            )
            .allowsHitTesting(false)
          )
          .transition(.opacity)
        }
      }
    }
    .statusBar(hidden: !showingControls)
    .task {
      // Load book info to get read progress page
      var initialPage: Int? = nil
      do {
        let book = try await BookService.shared.getBook(id: bookId)
        initialPage = book.readProgress?.page
      } catch {
        // Silently fail, will start from first page
      }

      await viewModel.loadPages(bookId: bookId, initialPage: initialPage)
      await viewModel.preloadPages()
    }
    .onDisappear {
      controlsTimer?.invalidate()
    }
  }

  private func goToNextPage() {
    switch viewModel.readingDirection {
    case .ltr:
      if viewModel.currentPage < viewModel.pages.count - 1 {
        withAnimation {
          viewModel.currentPage += 1
        }
      }
    case .rtl:
      if viewModel.currentPage > 0 {
        withAnimation {
          viewModel.currentPage -= 1
        }
      }
    }
  }

  private func goToPreviousPage() {
    switch viewModel.readingDirection {
    case .ltr:
      if viewModel.currentPage > 0 {
        withAnimation {
          viewModel.currentPage -= 1
        }
      }
    case .rtl:
      if viewModel.currentPage < viewModel.pages.count - 1 {
        withAnimation {
          viewModel.currentPage += 1
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
    withAnimation {
      showingControls.toggle()
    }
    if showingControls {
      resetControlsTimer()
    }
  }

  private func resetControlsTimer() {
    controlsTimer?.invalidate()
    controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
      withAnimation {
        showingControls = false
      }
    }
  }
}

struct PageImageView: View {
  var viewModel: ReaderViewModel
  let pageIndex: Int

  @State private var image: UIImage?
  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        if let image = image {
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
              MagnificationGesture()
                .onChanged { value in
                  let delta = value / lastScale
                  lastScale = value
                  scale *= delta
                }
                .onEnded { _ in
                  lastScale = 1.0
                  if scale < 1.0 {
                    withAnimation {
                      scale = 1.0
                      offset = .zero
                    }
                  } else if scale > 4.0 {
                    withAnimation {
                      scale = 4.0
                    }
                  }
                }
            )
            .simultaneousGesture(
              DragGesture(minimumDistance: 0)
                .onChanged { value in
                  // Only handle drag when zoomed in
                  if scale > 1.0 {
                    offset = CGSize(
                      width: lastOffset.width + value.translation.width,
                      height: lastOffset.height + value.translation.height
                    )
                  }
                }
                .onEnded { _ in
                  if scale > 1.0 {
                    lastOffset = offset
                  }
                }
            )
            .onTapGesture(count: 2) {
              // Double tap to zoom in/out
              if scale > 1.0 {
                withAnimation {
                  scale = 1.0
                  offset = .zero
                  lastOffset = .zero
                }
              } else {
                withAnimation {
                  scale = 2.0
                }
              }
            }
        } else {
          ProgressView()
            .tint(.white)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .task(id: pageIndex) {
      // Reset image and zoom state when page changes
      image = nil
      scale = 1.0
      lastScale = 1.0
      offset = .zero
      lastOffset = .zero

      // Load new page image
      image = await viewModel.loadPageImage(pageIndex: pageIndex)
    }
  }
}

#Preview {
  BookReaderView(bookId: "1")
}
