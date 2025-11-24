//
//  KomgaApp.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SDWebImage
import SDWebImageWebPCoder
import SwiftUI

@main
struct KomgaApp: App {
  @State private var authViewModel = AuthViewModel()

  init() {
    configureSDWebImage()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(authViewModel)
        .onChange(of: authViewModel.isLoggedIn) {
          configureSDWebImage()
        }
    }
    #if canImport(AppKit)
      WindowGroup("Reader", id: "reader") {
        ReaderWindowView()
          .environment(authViewModel)
      }
      .defaultSize(width: 1200, height: 800)
    #endif
  }

  private func configureSDWebImage() {
    // Set authentication header for SDWebImage
    if let authToken = AppConfig.authToken {
      SDWebImageDownloader.shared.setValue(
        "Basic \(authToken)", forHTTPHeaderField: "Authorization")
    } else {
      SDWebImageDownloader.shared.setValue(nil, forHTTPHeaderField: "Authorization")
    }

    // Register WebP coder
    SDImageCodersManager.shared.addCoder(SDImageWebPCoder.shared)
  }
}
