//
//  ReaderControlsView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI
import UniformTypeIdentifiers

struct ReaderControlsView: View {
  @Binding var showingControls: Bool
  @Binding var showingReadingDirectionPicker: Bool
  @Binding var readingDirection: ReadingDirection
  let viewModel: ReaderViewModel
  let currentBook: Book?
  let dualPage: Bool
  let onDismiss: () -> Void

  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  @State private var saveImageResult: SaveImageResult?
  @State private var showSaveAlert = false
  @State private var showDocumentPicker = false
  @State private var fileToSave: URL?
  @State private var showingPageJumpSheet = false

  enum SaveImageResult: Equatable {
    case success
    case failure(String)
  }

  private var displayedCurrentPage: String {
    guard viewModel.pages.count > 0 else { return "0" }
    if viewModel.currentPageIndex >= viewModel.pages.count {
      return "END"
    } else {
      if dualPage, let pair = viewModel.dualPageIndices[viewModel.currentPageIndex] {
        return pair.display
      } else {
        return String(viewModel.currentPageIndex + 1)
      }
    }
  }

  private func jumpToPage(page: Int) {
    guard !viewModel.pages.isEmpty else { return }
    let clampedPage = min(max(page, 1), viewModel.pages.count)
    let targetIndex = clampedPage - 1
    if targetIndex != viewModel.currentPageIndex {
      viewModel.targetPageIndex = targetIndex
    }
  }

  var body: some View {
    VStack {
      // Top bar
      VStack(spacing: 12) {
        HStack {
          Button {
            onDismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.title3)
              .foregroundColor(.white)
              .padding()
              .background(themeColor.color.opacity(0.8))
              .clipShape(Circle())
          }
          .frame(minWidth: 40, minHeight: 40)
          .contentShape(Rectangle())

          Spacer()

          // Page count
          Button {
            guard !viewModel.pages.isEmpty else { return }
            showingPageJumpSheet = true
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "arrow.up.arrow.down")
                .font(.caption)
              Text("\(displayedCurrentPage) / \(viewModel.pages.count)")
                .monospacedDigit()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(themeColor.color.opacity(0.8))
            .cornerRadius(20)
            .overlay(
              RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          }
          .buttonStyle(.plain)
          .disabled(viewModel.pages.isEmpty)

          Spacer()

          // Display mode toggle button
          Button {
            showingReadingDirectionPicker = true
          } label: {
            Image(systemName: readingDirection.icon)
              .font(.title3)
              .foregroundColor(.white)
              .padding()
              .background(themeColor.color.opacity(0.8))
              .clipShape(Circle())
          }
          .frame(minWidth: 40, minHeight: 40)
          .contentShape(Rectangle())
        }
      }
      .padding()
      .allowsHitTesting(true)

      // Series and book title
      if let book = currentBook {
        VStack(spacing: 4) {
          Text(book.seriesTitle)
            .font(.headline)
            .foregroundColor(.white)
          Text("#\(Int(book.number)) - \(book.metadata.title)")
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(themeColor.color.opacity(0.8))
        .cornerRadius(12)
      }

      Spacer()

      // Bottom slider
      ProgressView(
        value: Double(min(viewModel.currentPageIndex + 1, viewModel.pages.count)),
        total: Double(viewModel.pages.count)
      )
      .scaleEffect(x: readingDirection == .rtl ? -1 : 1, y: 1)
      .padding()
    }
    .padding(.vertical)
    .allowsHitTesting(true)
    .transition(.opacity)
    .onChange(of: readingDirection) { _, _ in
      if showingReadingDirectionPicker {
        showingReadingDirectionPicker = false
      }
    }
    .sheet(isPresented: $showingPageJumpSheet) {
      PageJumpSheetView(
        bookId: viewModel.bookId,
        totalPages: viewModel.pages.count,
        currentPage: min(viewModel.currentPageIndex + 1, viewModel.pages.count),
        readingDirection: readingDirection,
        onJump: jumpToPage
      )
    }
    .sheet(isPresented: $showingReadingDirectionPicker) {
      ReadingDirectionPickerSheetView(readingDirection: $readingDirection)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
    }
  }
}
