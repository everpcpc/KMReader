import SwiftUI

struct SettingsAboutSection: View {
  @State private var showSubscription = false

  private var isSupporter: Bool {
    StoreManager.shared.hasActiveSubscription
  }

  var body: some View {
    Section(header: Text(String(localized: "About"))) {
      Button {
        showSubscription = true
      } label: {
        HStack {
          if isSupporter {
            Label(String(localized: "Thanks for Support"), systemImage: "heart.fill")
              .foregroundColor(.pink)
          } else {
            Label(String(localized: "Buy Me a Coffee"), systemImage: "cup.and.saucer.fill")
          }
          Spacer()
          if isSupporter {
            Text("☕️")
          } else {
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
      .buttonStyle(.borderless)
      .sheet(isPresented: $showSubscription) {
        SubscriptionView()
      }

      Link(destination: URL(string: "https://kmreader.everpcpc.com/privacy/")!) {
        HStack {
          Label(String(localized: "Privacy Policy"), systemImage: "hand.raised")
          Spacer()
          Image(systemName: "arrow.up.right.square")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      Link(
        destination: URL(
          string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
      ) {
        HStack {
          Label(String(localized: "Terms of Use"), systemImage: "doc.text")
          Spacer()
          Image(systemName: "arrow.up.right.square")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      Link(destination: URL(string: "https://apps.apple.com/app/id6755198424?action=write-review")!) {
        HStack {
          Label(String(localized: "Rate This App"), systemImage: "star")
          Spacer()
          Image(systemName: "arrow.up.right.square")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      Link(destination: URL(string: "https://github.com/everpcpc/KMReader/issues")!) {
        HStack {
          Label(String(localized: "Feedback"), systemImage: "paperplane")
          Spacer()
          Image(systemName: "arrow.up.right.square")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      Link(destination: URL(string: "https://github.com/everpcpc/KMReader")!) {
        HStack {
          Label(
            String(localized: "Source Code"), systemImage: "chevron.left.forwardslash.chevron.right"
          )
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
