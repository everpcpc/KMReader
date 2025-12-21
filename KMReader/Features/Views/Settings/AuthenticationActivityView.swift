//
//  AuthenticationActivityView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct AuthenticationActivityView: View {
  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @State private var activities: [AuthenticationActivity] = []
  @State private var isLoading = false
  @State private var isLoadingMore = false
  @State private var currentPage = 0
  @State private var hasMorePages = true
  @State private var lastTriggeredIndex: Int = -1

  var body: some View {
    List {
      if isLoading && activities.isEmpty {
        Section {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
        }
      } else if activities.isEmpty {
        Section {
          HStack {
            Spacer()
            VStack(spacing: 8) {
              Image(systemName: "clock")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
              Text("No activity found")
                .foregroundColor(.secondary)
            }
            Spacer()
          }
          .padding(.vertical)
          .tvFocusableHighlight()
        }
      } else {
        Section {
          ForEach(Array(activities.enumerated()), id: \.offset) { index, activity in
            activityRow(activity: activity, index: index)
          }

          if isLoadingMore {
            HStack {
              Spacer()
              ProgressView()
              Spacer()
            }
            .padding(.vertical)
          }
        }
      }
    }
    .optimizedListStyle()
    .inlineNavigationBarTitle(String(localized: "title.authenticationActivity"))
    .task {
      if isAdmin {
        await loadActivities(refresh: true)
      }
    }
    .refreshable {
      if isAdmin {
        await loadActivities(refresh: true)
      }
    }
  }

  @ViewBuilder
  private func activityRow(activity: AuthenticationActivity, index: Int) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: activity.success ? "checkmark.circle.fill" : "xmark.circle.fill")
          .foregroundColor(activity.success ? .green : .red)
        if let source = activity.source {
          Text(source)
            .font(.headline)
        } else {
          Text(activity.success ? "Success" : "Failed")
            .font(.headline)
        }
        Spacer()
        Text(formatDate(activity.dateTime))
          .font(.caption)
          .foregroundColor(.secondary)
      }

      if let userAgent = activity.userAgent {
        HStack {
          Image(systemName: "desktopcomputer")
          Text(userAgent).lineLimit(1)
        }
        .font(.caption)
        .foregroundColor(.secondary)
      }

      if let ip = activity.ip {
        HStack {
          Image(systemName: "network")
          Text(ip)
        }
        .font(.caption)
        .foregroundColor(.secondary)
      }

      if let apiKeyComment = activity.apiKeyComment {
        HStack {
          Image(systemName: "key")
          Text("API Key")
          Text(apiKeyComment)
        }
        .font(.caption)
        .foregroundColor(.secondary)
      }

      if let error = activity.error {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")

          Text(error)
        }
        .font(.caption)
        .foregroundColor(.red)
      }
    }
    .tvFocusableHighlight()
    #if os(tvOS)
      .padding(.vertical, 12)
      .padding(.horizontal, 16)
    #else
      .padding(.vertical, 4)
    #endif
    .onAppear {
      guard index >= activities.count - 3,
        hasMorePages,
        !isLoadingMore,
        lastTriggeredIndex != index
      else {
        return
      }
      lastTriggeredIndex = index
      Task {
        await loadMoreActivities()
      }
    }
  }

  private func loadActivities(refresh: Bool = false) async {
    if refresh {
      currentPage = 0
      hasMorePages = true
      lastTriggeredIndex = -1
    }

    isLoading = true

    do {
      let page = try await AuthService.shared.getAuthenticationActivity(page: 0, size: 20)
      await MainActor.run {
        activities = page.content
        hasMorePages = !page.last
        currentPage = 1
        lastTriggeredIndex = -1
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
  }

  private func loadMoreActivities() async {
    guard hasMorePages && !isLoadingMore else { return }

    isLoadingMore = true

    do {
      let page = try await AuthService.shared.getAuthenticationActivity(page: currentPage, size: 20)
      await MainActor.run {
        activities.append(contentsOf: page.content)
        hasMorePages = !page.last
        currentPage += 1
        lastTriggeredIndex = -1
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoadingMore = false
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}
