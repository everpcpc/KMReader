//
//  ServerUpdateStatusView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ServerUpdateStatusView: View {
  @AppStorage("serverLastUpdate") private var serverLastUpdateInterval: TimeInterval = 0
  @AppStorage("taskQueueStatus") private var taskQueueStatusRaw: String = ""
  @AppStorage("isOffline") private var isOffline: Bool = false

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
        lastServerEventText
          .foregroundColor(.secondary)
        if taskStatus.count > 0 {
          Text("•")
            .foregroundColor(.secondary)
          NavigationLink(value: NavDestination.settingsTasks) {
            HStack(spacing: 4) {
              Text("Running Tasks: \(taskStatus.count)")
              Image(systemName: "chevron.right")
            }
          }
        }
      }
    }
    .font(.footnote)
    .monospacedDigit()
  }

  private var lastServerEventText: Text {
    guard serverLastUpdateInterval > 0 else { return Text("Server not updated yet") }
    let lastEventTime = Date(timeIntervalSince1970: serverLastUpdateInterval)
    return Text("Server updated \(lastEventTime, style: .relative) ago")
  }

  static func recordUpdate(date: Date = Date()) {
    AppConfig.serverLastUpdate = date
  }
}
