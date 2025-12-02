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
struct MainApp: App {
  private let modelContainer: ModelContainer
  @State private var authViewModel: AuthViewModel

  init() {
    do {
      let schema = Schema([
        KomgaInstance.self,
        KomgaLibrary.self,
        CustomFont.self,
      ])
      let configuration = ModelConfiguration(schema: schema)
      modelContainer = try ModelContainer(
        for: schema,
        configurations: [configuration]
      )
    } catch {
      fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
    }
    KomgaInstanceStore.shared.configure(with: modelContainer)
    KomgaLibraryStore.shared.configure(with: modelContainer)
    CustomFontStore.shared.configure(with: modelContainer)
    _authViewModel = State(initialValue: AuthViewModel())
    SDImageCacheProvider.configureSDWebImage()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(authViewModel)
        .modelContainer(modelContainer)
    }
    #if os(macOS)
      WindowGroup(id: "reader") {
        ReaderWindowView()
          .environment(authViewModel)
          .modelContainer(modelContainer)
      }
      .defaultSize(width: 1200, height: 800)

      Settings {
        SettingsView_macOS()
          .environment(authViewModel)
          .modelContainer(modelContainer)
      }
      .defaultSize(width: 800, height: 600)
    #endif
  }
}
