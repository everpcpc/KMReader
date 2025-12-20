import SwiftUI

struct SettingsAboutSection: View {
  var body: some View {
    Section(header: Text(String(localized: "About"))) {
      Link(destination: URL(string: "https://everpcpc.github.io/KMReader/privacy/")!) {
        HStack {
          Label(String(localized: "Privacy Policy"), systemImage: "hand.raised")
          Spacer()
          Image(systemName: "arrow.up.right.square")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      Link(destination: URL(string: "https://kmreader.userjot.com/")!) {
        HStack {
          Label(String(localized: "Feedback"), systemImage: "paperplane")
          Spacer()
          Image(systemName: "arrow.up.right.square")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      Link(destination: URL(string: "https://testflight.apple.com/join/kHXDCdjv")!) {
        HStack {
          Label(String(localized: "Join Beta"), systemImage: "sparkles")
          Spacer()
          Image(systemName: "arrow.up.right.square")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      Link(destination: URL(string: "https://github.com/everpcpc/KMReader")!) {
        HStack {
          Label(String(localized: "Source Code"), systemImage: "chevron.left.forwardslash.chevron.right")
          Spacer()
          Image(systemName: "arrow.up.right.square")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      HStack {
        Spacer()
        Text(Bundle.main.appVersion)
          .foregroundColor(.secondary)
        Spacer()
      }
    }
  }
}
