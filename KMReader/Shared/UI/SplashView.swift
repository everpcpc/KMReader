//
//  SplashView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SplashView: View {
  @State private var isVisible = false
  @State private var loadingMessageIndex = 0
  @State private var pulseProgress = 1.0
  @State private var messageRotationTask: Task<Void, Never>?

  var initializer: InstanceInitializer?

  private let loadingMessages = [
    String(localized: "splash.loading.connecting"),
    String(localized: "splash.loading.syncing"),
    String(localized: "splash.loading.updating"),
    String(localized: "splash.loading.preparing"),
  ]

  private var isSyncing: Bool {
    initializer?.isSyncing ?? false
  }

  private var initializationProgress: Double {
    initializer?.progress ?? 0.0
  }

  private var currentPhaseName: String {
    initializer?.currentPhaseName ?? ""
  }

  var body: some View {
    VStack(spacing: 32) {
      Spacer()

      VStack(spacing: 16) {
        // Logo with animation
        Image("logo")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(height: 140)
          .scaleEffect(isVisible ? 1.0 : 0.8)
          .opacity(isVisible ? 1.0 : 0.0)

        // App Name
        Text("KMReader")
          .font(.system(size: 48, weight: .bold, design: .rounded))
          .foregroundStyle(.primary)
          .tracking(1.2)
          .offset(y: isVisible ? 0 : 20)
          .opacity(isVisible ? 1.0 : 0.0)

        // Tagline
        Text("Your personal manga reader")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .tracking(0.5)
          .offset(y: isVisible ? 0 : 20)
          .opacity(isVisible ? 0.8 : 0.0)
      }

      Spacer()

      VStack(spacing: 16) {
        if isSyncing {
          // Determinate progress bar during initialization
          VStack(spacing: 8) {
            ProgressView(value: initializationProgress)
              .progressViewStyle(.linear)
              .frame(maxWidth: 280)
              .opacity(isVisible ? 1.0 : 0.0)

            Text(currentPhaseName)
              .font(.caption)
              .foregroundStyle(.secondary)
              .monospacedDigit()

            Text("\(Int(initializationProgress * 100))%")
              .font(.caption2)
              .foregroundStyle(.tertiary)
              .monospacedDigit()
          }
        } else {
          // Indeterminate spinner when not initializing
          ProgressView()
            .controlSize(.large)
            .scaleEffect(pulseProgress)
            .opacity(isVisible ? 1.0 : 0.0)

          Text(loadingMessages[loadingMessageIndex])
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .transition(
              .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity))
            )
            .id(loadingMessageIndex)
        }
      }

      Spacer()
        .frame(height: 60)
    }
    .onAppear {
      withAnimation(.spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0)) {
        isVisible = true
      }

      // Pulse animation for ProgressView
      withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
        pulseProgress = 1.1
      }

      // Rotate loading messages
      messageRotationTask?.cancel()
      messageRotationTask = Task {
        while !Task.isCancelled {
          try? await Task.sleep(nanoseconds: 2_000_000_000)
          await MainActor.run {
            withAnimation(.easeInOut(duration: 0.5)) {
              loadingMessageIndex = (loadingMessageIndex + 1) % loadingMessages.count
            }
          }
        }
      }
    }
    .onDisappear {
      messageRotationTask?.cancel()
      messageRotationTask = nil
    }
  }
}

#Preview {
  SplashView()
}

#Preview("Initializing") {
  SplashView(initializer: InstanceInitializer.shared)
}
