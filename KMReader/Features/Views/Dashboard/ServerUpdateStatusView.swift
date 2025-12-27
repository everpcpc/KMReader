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
          .font(.caption)
          .foregroundColor(.orange)
      } else {
        Image(systemName: "antenna.radiowaves.left.and.right")
          .foregroundColor(.secondary)
        lastServerEventText
          .font(.caption)
          .foregroundColor(.secondary)
        if taskStatus.count > 0 {
          Text("•")
            .foregroundColor(.secondary)
          Text("Running Tasks: \(taskStatus.count)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
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
