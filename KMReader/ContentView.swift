//
//  ContentView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ContentView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @Environment(ReaderPresentationManager.self) private var readerPresentation
  #if os(macOS)
    @Environment(\.openWindow) private var openWindow
  #endif

  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
  @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
  @AppStorage("enableSSE") private var enableSSE: Bool = true

  @State private var errorManager = ErrorManager.shared

  var body: some View {
    ZStack {
      Group {
        if isLoggedIn {
          MainTabView()
        } else {
          LandingView()
        }
      }
      .task {
        if isLoggedIn {
          await authViewModel.loadCurrentUser()
          await LibraryManager.shared.loadLibraries()
          // Connect to SSE on app startup if already logged in and enabled
          if enableSSE {
            SSEService.shared.connect()
          }
        }
      }
      .onChange(of: isLoggedIn) { _, isLoggedIn in
        SDImageCacheProvider.configureSDWebImage()
        if isLoggedIn {
          Task {
            await authViewModel.loadCurrentUser()
            await LibraryManager.shared.loadLibraries()
            // Connect to SSE when login state changes to logged in and enabled
            if enableSSE {
              SSEService.shared.connect()
            }
          }
        } else {
          // Disconnect SSE when logged out
          SSEService.shared.disconnect()
        }
      }
      .onChange(of: authViewModel.credentialsVersion) {
        SDImageCacheProvider.configureSDWebImage()
      }
      .onAppear {
        SDImageCacheProvider.configureSDWebImage()
      }

      // Notification overlay
      VStack(alignment: .center) {
        Spacer()
        ForEach($errorManager.notifications, id: \.self) { $notification in
          Text(notification)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .foregroundStyle(.white)
            .background(themeColor.color)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 10)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
      }
      .animation(.default, value: errorManager.notifications)
      .padding(.horizontal, 8)
      .padding(.bottom, 64)
    }
    #if os(iOS)
      // only set tint color on iOS
      .tint(themeColor.color)
    #endif
    .alert("Error", isPresented: $errorManager.hasAlert) {
      Button("OK") {
        ErrorManager.shared.vanishError()
      }
      #if os(iOS) || os(macOS)
        Button("Copy") {
          PlatformHelper.generalPasteboard.string = errorManager.currentError?.description
          ErrorManager.shared.notify(message: "Copied")
        }
      #endif
    } message: {
      if let error = errorManager.currentError {
        Text(verbatim: error.description)
      } else {
        Text("Unknown Error")
      }
    }
    #if os(iOS) || os(tvOS)
      .fullScreenCover(isPresented: readerIsPresented) {
        if let state = readerPresentation.readerState, let book = state.book {
          BookReaderView(book: book, incognito: state.incognito)
          .transition(.scale.animation(.easeInOut))
        } else {
          ReaderPlaceholderView {
            readerPresentation.closeReader()
          }
        }
      }
    #elseif os(macOS)
      .background(
        MacReaderWindowConfigurator(openWindow: {
          openWindow(id: "reader")
        }))
    #endif
  }
}

struct MainTabView: View {
  var body: some View {
    TabView {
      DashboardView()
        .tabItem {
          Label("Home", systemImage: "house")
        }

      BrowseView()
        .tabItem {
          Label("Browse", systemImage: "books.vertical")
        }

      #if !os(macOS)
        SettingsView()
          .tabItem {
            Label("Settings", systemImage: "gearshape")
          }
      #endif

    }.tabBarMinimizeBehaviorIfAvailable()
  }
}

#if os(iOS) || os(tvOS)
  extension ContentView {
    fileprivate var readerIsPresented: Binding<Bool> {
      Binding(
        get: { readerPresentation.readerState != nil },
        set: { newValue in
          if !newValue {
            readerPresentation.closeReader()
          }
        }
      )
    }
  }

  private struct ReaderPlaceholderView: View {
    let onClose: () -> Void

    var body: some View {
      VStack(spacing: 16) {
        ProgressView()
          .progressViewStyle(.circular)

        Text("Preparing reader…")
          .font(.headline)
          .foregroundColor(.secondary)

        Button {
          onClose()
        } label: {
          Label("Cancel", systemImage: "xmark.circle")
            .font(.headline)
        }
        .adaptiveButtonStyle(.bordered)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(.systemBackground).ignoresSafeArea())
    }
  }
#elseif os(macOS)
  private struct MacReaderWindowConfigurator: View {
    @Environment(ReaderPresentationManager.self) private var readerPresentation
    let openWindow: () -> Void

    var body: some View {
      Color.clear
        .onAppear {
          readerPresentation.configureWindowOpener(openWindow)
        }
    }
  }
#endif
