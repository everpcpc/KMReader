//
// ServerUpdateStatusView.swift
//
//

import SwiftUI

struct ServerUpdateStatusView: View {
  @AppStorage("taskQueueStatus") private var taskQueueStatusRaw: String = ""
  @AppStorage("isOffline") private var isOffline: Bool = false

  /// Whether the running-tasks segment links to the Tasks page. Disable when
  /// embedded inside another NavigationLink (e.g. the iPhone settings server
  /// card) to avoid stacked disclosure indicators.
  var showsTasksLink: Bool = true

  private var taskStatus: TaskQueueSSEDto {
    TaskQueueSSEDto(rawValue: taskQueueStatusRaw) ?? TaskQueueSSEDto()
  }

  var body: some View {
    HStack {
      if isOffline {
        Image(systemName: "wifi.slash")
          .foregroundColor(.orange)
        Text(String(localized: "settings.offline"))
          .foregroundColor(.orange)
      } else {
        Image(systemName: "antenna.radiowaves.left.and.right")
          .foregroundColor(.secondary)
        if taskStatus.count > 0 {
          Text("•")
            .foregroundColor(.secondary)
          if showsTasksLink {
            NavigationLink(value: NavDestination.settingsTasks) {
              HStack(spacing: 4) {
                Text("Running Tasks: \(taskStatus.count)")
                Image(systemName: "chevron.right")
              }
            }.adaptiveButtonStyle(.plain)
          } else {
            Text("Running Tasks: \(taskStatus.count)")
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .font(.footnote)
    .monospacedDigit()
  }
}
