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
        ZStack {
          TabView(selection: $viewModel.currentPage) {
            ForEach(0..<viewModel.pages.count, id: \.self) { index in
              PageImageView(
                viewModel: viewModel,
                pageIndex: index
              )
              .tag(index)
            }
          }
          .tabViewStyle(.page(indexDisplayMode: .never))
          .onChange(of: viewModel.currentPage) { _, _ in
            Task {
              await viewModel.updateProgress()
              await viewModel.preloadPages()
            }
          }

          // Tap zones overlay covering entire screen (only when controls are hidden)
          if !showingControls {
            GeometryReader { geometry in
              HStack(spacing: 0) {
                // Left tap zone
                Color.clear
                  .frame(width: geometry.size.width * 0.3)
                  .contentShape(Rectangle())
                  .onTapGesture {
                    goToPreviousPage()
                  }

                // Center tap zone (toggle controls)
                Color.clear
                  .frame(width: geometry.size.width * 0.4)
                  .contentShape(Rectangle())
                  .onTapGesture {
                    toggleControls()
                  }

                // Right tap zone
                Color.clear
                  .frame(width: geometry.size.width * 0.3)
                  .contentShape(Rectangle())
                  .onTapGesture {
                    goToNextPage()
                  }
              }
            }
            .allowsHitTesting(true)
          }
        }

        // Controls overlay
        if showingControls {
          VStack {
            // Top bar
            HStack {
              Button(action: {
                dismiss()
              }) {
                Image(systemName: "xmark")
                  .font(.title2)
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
                  get: { Double(viewModel.currentPage) },
                  set: { viewModel.currentPage = Int($0) }
                ),
                in: 0...Double(max(0, viewModel.pages.count - 1)),
                step: 1
              )
              .tint(.white)
            }
            .padding()
            .background(Color.black.opacity(0.5))
          }
          .transition(.opacity)
          .onTapGesture {
            // Prevent tap from passing through to tap zones
          }
        }
      }
    }
    .navigationBarHidden(true)
    .statusBar(hidden: !showingControls)
    .task {
      await viewModel.loadPages(bookId: bookId)
      await viewModel.preloadPages()
    }
    .onDisappear {
      controlsTimer?.invalidate()
    }
  }

  private func goToNextPage() {
    if viewModel.currentPage < viewModel.pages.count - 1 {
      withAnimation {
        viewModel.currentPage += 1
      }
    }
  }

  private func goToPreviousPage() {
    if viewModel.currentPage > 0 {
      withAnimation {
        viewModel.currentPage -= 1
      }
    }
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
            .gesture(
              DragGesture(minimumDistance: scale > 1.0 ? 0 : 100)
                .onChanged { value in
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
            .onTapGesture {
              if scale > 1.0 {
                // Tap to reset zoom when zoomed in
                withAnimation {
                  scale = 1.0
                  offset = .zero
                  lastOffset = .zero
                }
              }
              // When not zoomed, let the overlay handle taps
            }
        } else {
          ProgressView()
            .tint(.white)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .task {
      image = await viewModel.loadPageImage(pageIndex: pageIndex)
    }
  }
}

#Preview {
  BookReaderView(bookId: "1")
}
