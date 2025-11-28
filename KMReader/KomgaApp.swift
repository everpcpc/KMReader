//
//  KomgaApp.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SDWebImage
import SDWebImageWebPCoder
import SwiftData
import SwiftUI

@main
struct KomgaApp: App {
  private let modelContainer: ModelContainer
  @State private var authViewModel: AuthViewModel

  init() {
    do {
      modelContainer = try ModelContainer(for: KomgaInstance.self, KomgaLibrary.self)
    } catch {
      fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
    }
    KomgaInstanceStore.shared.configure(with: modelContainer)
    KomgaLibraryStore.shared.configure(with: modelContainer)
    _authViewModel = State(initialValue: AuthViewModel())
    SDImageCacheProvider.configureSDWebImage()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(authViewModel)
        .modelContainer(modelContainer)
    }
    #if canImport(AppKit)
      WindowGroup("Reader", id: "reader") {
        ReaderWindowView()
          .environment(authViewModel)
          .modelContainer(modelContainer)
      }
      .defaultSize(width: 1200, height: 800)
    #endif
  }
}
