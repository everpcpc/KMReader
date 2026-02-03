//
//  View+Handoff.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

enum HandoffScope {
  case browse
  case reader
}

extension View {
  func komgaHandoff(title: String, url: URL?, scope: HandoffScope) -> some View {
    modifier(HandoffActivityModifier(title: title, url: url, scope: scope))
  }
}

private struct HandoffActivityModifier: ViewModifier {
  let title: String
  let url: URL?
  let scope: HandoffScope

  @AppStorage("enableBrowseHandoff") private var enableBrowseHandoff: Bool = true
  @AppStorage("enableReaderHandoff") private var enableReaderHandoff: Bool = false

  private var isEnabled: Bool {
    switch scope {
    case .browse:
      return enableBrowseHandoff
    case .reader:
      return enableReaderHandoff
    }
  }

  func body(content: Content) -> some View {
    content.userActivity(NSUserActivityTypeBrowsingWeb) { activity in
      let isEligible = isEnabled && url != nil
      activity.title = title
      activity.webpageURL = url
      activity.isEligibleForHandoff = isEligible
      activity.isEligibleForSearch = false
      activity.isEligibleForPublicIndexing = false
    }
  }
}
