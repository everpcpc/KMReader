//
//  NotificationOverlay.swift
//  KMReader
//

import SwiftUI

struct NotificationOverlay: View {
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
  @State private var errorManager = ErrorManager.shared

  var body: some View {
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
    .alert(String(localized: "error.title"), isPresented: $errorManager.hasAlert) {
      Button(String(localized: "common.ok")) {
        ErrorManager.shared.vanishError()
      }
      #if os(iOS) || os(macOS)
        Button(String(localized: "common.copy")) {
          PlatformHelper.generalPasteboard.string = errorManager.currentError?.description
          ErrorManager.shared.notify(message: String(localized: "notification.copied"))
        }
      #endif
    } message: {
      if let error = errorManager.currentError {
        Text(verbatim: error.description)
      } else {
        Text(String(localized: "error.unknown"))
      }
    }
  }
}
