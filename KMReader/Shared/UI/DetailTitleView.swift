import SwiftUI

struct DetailTitleView: View {
  let title: String

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      Text(title)
        .font(.title2)
        .fixedSize(horizontal: false, vertical: true)
        .textSelectionIfAvailable()
        .layoutPriority(1)

      #if os(iOS) || os(macOS)
        Button {
          copyTitle()
        } label: {
          Image(systemName: "doc.on.doc")
            .font(.subheadline)
        }
        .adaptiveButtonStyle(.plain)
        .foregroundStyle(.secondary)
      #endif
    }
  }

  private func copyTitle() {
    #if os(iOS) || os(macOS)
      PlatformHelper.generalPasteboard.string = title
      ErrorManager.shared.notify(message: String(localized: "notification.copied"))
    #endif
  }
}
