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
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
  #if os(macOS)
    @Environment(\.openWindow) private var openWindow
  #endif

  private let modelContainer: ModelContainer
  @State private var authViewModel: AuthViewModel
  @State private var readerPresentation = ReaderPresentationManager()

  init() {
    do {
      let schema = Schema([
        KomgaInstance.self,
        KomgaLibrary.self,
        KomgaSeries.self,
        KomgaBook.self,
        KomgaCollection.self,
        KomgaReadList.self,
        CustomFont.self,
        PendingProgress.self,
      ])

      let configuration = ModelConfiguration(schema: schema)
      modelContainer = try ModelContainer(
        for: schema,
        configurations: [configuration]
      )
    } catch {
      fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
    }
    CustomFontStore.shared.configure(with: modelContainer)
    DatabaseOperator.shared = DatabaseOperator(modelContainer: modelContainer)
    _authViewModel = State(initialValue: AuthViewModel())
    SDImageCacheProvider.configureSDWebImage()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        #if os(macOS)
          .background(
            MacReaderWindowConfigurator(openWindow: {
              openWindow(id: "reader")
            })
          )
          .overlay(alignment: .bottom) {
            NotificationOverlay()
          }
        #endif
        #if os(iOS)
          .statusBarHidden(readerPresentation.hideStatusBar)
          .animation(.default, value: readerPresentation.hideStatusBar)
          .tint(themeColor.color)
        #endif
        .environment(authViewModel)
        .environment(readerPresentation)
        .modelContainer(modelContainer)
    }
    #if os(macOS)
      WindowGroup(id: "reader") {
        ReaderWindowView()
          .environment(authViewModel)
          .environment(readerPresentation)
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
