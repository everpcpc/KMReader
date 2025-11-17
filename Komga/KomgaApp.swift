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
  }

  private func configureSDWebImage() {
    // Set authentication header for SDWebImage
    if let authToken = UserDefaults.standard.string(forKey: "authToken") {
      SDWebImageDownloader.shared.setValue(
        "Basic \(authToken)", forHTTPHeaderField: "Authorization")
    } else {
      SDWebImageDownloader.shared.setValue(nil, forHTTPHeaderField: "Authorization")
    }

    // Register WebP coder
    SDImageCodersManager.shared.addCoder(SDImageWebPCoder.shared)

    // Configure memory cache limits to prevent excessive memory usage
    // Limit memory cache to 200MB (for decoded images)
    SDImageCache.shared.config.maxMemoryCost = 200 * 1024 * 1024
    // Limit memory cache to 50 images
    SDImageCache.shared.config.maxMemoryCount = 50
    // Limit disk cache to 200MB for thumbnails
    SDImageCache.shared.config.maxDiskSize = 200 * 1024 * 1024
  }
}
