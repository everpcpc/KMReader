//
// SplashView.swift
//
//

import SwiftUI

struct SplashView: View {
  @State private var isVisible: Bool
  @State private var loadingMessageIndex = 0
  @State private var pulseProgress = 1.0
  @State private var messageRotationTask: Task<Void, Never>?

  let initializer: InstanceInitializer?
  let isMigration: Bool

  init(initializer: InstanceInitializer? = nil, isMigration: Bool = false) {
    self.initializer = initializer
    self.isMigration = isMigration
    _isVisible = State(initialValue: isMigration)
  }

  private var loadingMessages: [String] {
    if isMigration {
      [
        String(
          localized: "splash.migration.preparing",
          defaultValue: "Preparing local database migration"
        ),
        String(
          localized: "splash.migration.migrating",
          defaultValue: "Migrating existing local data"
        ),
        String(
          localized: "splash.migration.finalizing",
          defaultValue: "Finalizing local data migration"
        ),
      ]
    } else {
      [
        String(localized: "splash.loading.connecting"),
        String(localized: "splash.loading.syncing"),
        String(localized: "splash.loading.updating"),
        String(localized: "splash.loading.preparing"),
      ]
    }
  }

  private var isSyncing: Bool {
    initializer?.isSyncing ?? false
  }

  private var syncStages: [SyncStage] {
    initializer?.visibleStages ?? SyncStage.visibleStages(includeReconcile: false)
  }

  private var includesReconcileStages: Bool {
    initializer?.includesReconcileStages ?? false
  }

  private func stageProgress(for stage: SyncStage) -> Double {
    initializer?.progress(for: stage) ?? 0.0
  }

  private func stageTextStyle(for stage: SyncStage) -> AnyShapeStyle {
    let progress = stageProgress(for: stage)
    return AnyShapeStyle((progress > 0.0 && progress < 1.0) ? .primary : .secondary)
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
          // Stage-based progress bars during initialization
          VStack(alignment: .leading, spacing: 10) {
            ForEach(syncStages, id: \.self) { stage in
              VStack(alignment: .leading, spacing: 4) {
                HStack {
                  Text(stage.localizedName(includeReconcile: includesReconcileStages))
                    .font(.caption)
                    .foregroundStyle(stageTextStyle(for: stage))
                  Spacer()
                  Text("\(Int(stageProgress(for: stage) * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                }

                ProgressView(value: stageProgress(for: stage))
                  .progressViewStyle(.linear)
              }
            }
          }
          .frame(maxWidth: 320)
          .opacity(isVisible ? 1.0 : 0.0)
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

          if isMigration {
            Text(
              String(
                localized: "splash.migration.duration_hint",
                defaultValue:
                  "Large libraries may take 1-2 minutes to migrate. Please keep KMReader open."
              )
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)
          }
        }
      }

      Spacer()
        .frame(height: 60)
    }
    .onAppear {
      if !isVisible {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0)) {
          isVisible = true
        }
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
          withAnimation(.easeInOut(duration: 0.5)) {
            loadingMessageIndex = (loadingMessageIndex + 1) % loadingMessages.count
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

#Preview("Migrating") {
  SplashView(isMigration: true)
}

#Preview("Initializing") {
  SplashView(initializer: InstanceInitializer.shared)
}
