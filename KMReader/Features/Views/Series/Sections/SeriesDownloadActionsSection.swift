//
//  SeriesDownloadActionsSection.swift
//  KMReader
//

import SwiftData
import SwiftUI

struct SeriesDownloadActionsSection: View {
  @Environment(KomgaSeries.self) private var komgaSeries

  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""

  private var series: Series {
    komgaSeries.toSeries()
  }

  private var status: SeriesDownloadStatus {
    komgaSeries.downloadStatus
  }

  private var policy: SeriesOfflinePolicy {
    komgaSeries.offlinePolicy
  }

  private var policyLabel: Text {
    Text("Offline Policy") + Text(" : ") + Text(policy.label)
  }

  var body: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        InfoChip(
          label: status.label,
          systemImage: status.icon,
          backgroundColor: status.color.opacity(0.2),
          foregroundColor: status.color
        )

        Spacer()

        Menu {
          Picker(
            "",
            selection: Binding(
              get: { policy },
              set: { updatePolicy($0) }
            )
          ) {
            ForEach(SeriesOfflinePolicy.allCases, id: \.self) { p in
              Label(p.label, systemImage: p.icon)
                .tag(p)
            }
          }
          .pickerStyle(.inline)
        } label: {
          Label {
            policyLabel.lineLimit(1)
          } icon: {
            Image(systemName: policy.icon)
              .frame(width: PlatformHelper.iconSize, height: PlatformHelper.iconSize)
          }
        }
        .font(.caption)
        .adaptiveButtonStyle(.bordered)

        Button {
          toggleSeriesDownload()
        } label: {
          Label {
            Text(status.toggleLabel)
          } icon: {
            Image(systemName: status.toggleIcon)
              .frame(width: PlatformHelper.iconSize, height: PlatformHelper.iconSize)
          }
        }
        .font(.caption)
        .adaptiveButtonStyle(
          status.isDownloaded || status.isPending ? .bordered : .borderedProminent
        )
        .tint(status.toggleColor)
      }

    }
    .animation(.easeInOut(duration: 0.2), value: status)
    .animation(.easeInOut(duration: 0.2), value: policy)
    .padding(.vertical, 4)
  }

  private func updatePolicy(_ newPolicy: SeriesOfflinePolicy) {
    Task {
      await DatabaseOperator.shared.updateSeriesOfflinePolicy(
        seriesId: komgaSeries.seriesId, instanceId: currentInstanceId, policy: newPolicy
      )
      try? await DatabaseOperator.shared.commit()
    }
  }

  private func toggleSeriesDownload() {
    Task {
      await DatabaseOperator.shared.toggleSeriesDownload(
        seriesId: komgaSeries.seriesId, instanceId: currentInstanceId
      )
      try? await DatabaseOperator.shared.commit()
    }
  }
}
