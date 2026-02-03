//
//  View+Handoff.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

extension View {
  @ViewBuilder
  func komgaHandoff(title: String, url: URL?) -> some View {
    HandoffActivityView(base: self, title: title, url: url)
  }
}

private struct HandoffActivityView<Base: View>: View {
  let base: Base
  let title: String
  let url: URL?

  @AppStorage("enableHandoff") private var enableHandoff: Bool = true

  var body: some View {
    if enableHandoff, let url {
      base.userActivity(NSUserActivityTypeBrowsingWeb) { activity in
        activity.title = title
        activity.webpageURL = url
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.isEligibleForPublicIndexing = false
      }
    } else {
      base
    }
  }
}
