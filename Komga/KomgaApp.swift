//
//  KomgaApp.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

@main
struct KomgaApp: App {
  @State private var authViewModel = AuthViewModel()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(authViewModel)
    }
  }
}
