//
//  View+Handoff.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

extension View {
  func komgaHandoff(title: String, url: URL?) -> some View {
    modifier(HandoffActivityModifier(title: title, url: url))
  }
}

private struct HandoffActivityModifier: ViewModifier {
  let title: String
  let url: URL?

  @AppStorage("enableHandoff") private var enableHandoff: Bool = true

  func body(content: Content) -> some View {
    content.userActivity(NSUserActivityTypeBrowsingWeb) { activity in
      let isEligible = enableHandoff && url != nil
      activity.title = title
      activity.webpageURL = url
      activity.isEligibleForHandoff = isEligible
      activity.isEligibleForSearch = false
      activity.isEligibleForPublicIndexing = false
    }
  }
}
