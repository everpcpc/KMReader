//
//  SaveImageButton.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

// Save image button for context menu
struct SaveImageButton: View {
  let viewModel: ReaderViewModel
  let page: BookPage
  @State private var saveImageStatus: SaveImageStatus = .idle
  @State private var showSaveAlert = false

  var body: some View {
    Button {
      Task {
        await saveImageToPhotos()
      }
    } label: {
      Label("Save to Photos", systemImage: "square.and.arrow.down")
    }
    .disabled(saveImageStatus == .saving)
    .alert("Save Image", isPresented: $showSaveAlert) {
      Button("OK") {
        saveImageStatus = .idle
      }
    } message: {
      switch saveImageStatus {
      case .idle, .saving:
        Text("")
      case .success:
        Text("Image saved to Photos successfully")
      case .failed(let error):
        Text("Failed to save image: \(error)")
      }
    }
    .onChange(of: saveImageStatus) { oldValue, newValue in
      if newValue == .success || (newValue != .idle && newValue != .saving) {
        showSaveAlert = true
      }
    }
  }

  private func saveImageToPhotos() async {
    await MainActor.run {
      saveImageStatus = .saving
    }

    let result = await viewModel.savePageImageToPhotos(page: page)

    await MainActor.run {
      switch result {
      case .success:
        saveImageStatus = .success
      case .failure(let error):
        saveImageStatus = .failed(error.localizedDescription)
      }
    }
  }
}
