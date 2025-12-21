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

  var body: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
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
            HStack(spacing: 2) {
              Text("Offline Policy")
              Text(":")
              Text(policy.label)
            }
          } icon: {
            Image(systemName: policy.icon)
              .frame(width: PlatformHelper.iconSize, height: PlatformHelper.iconSize)
          }
          .fixedSize()
        }
        .font(.caption)
        .adaptiveButtonStyle(.bordered)

        Spacer()

        Label {
          Text(status.label)
        } icon: {
          Image(systemName: status.icon)
            .foregroundColor(status.color)
        }
        .font(.subheadline)
        .foregroundColor(.secondary)

        Button {
          Task {
            await DatabaseOperator.shared.toggleSeriesDownload(
              seriesId: komgaSeries.seriesId, instanceId: currentInstanceId
            )
            try? await DatabaseOperator.shared.commit()
          }
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
    .animation(.default, value: status)
    .animation(.default, value: policy)
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
}
