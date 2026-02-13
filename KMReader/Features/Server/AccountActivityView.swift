//
//  AccountActivityView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct AccountActivityView: View {
  @AppStorage("currentAccount") private var current: Current = .init()
  @State private var pagination = PaginationState<AuthenticationActivity>(pageSize: 20)
  @State private var isLoading = false
  @State private var isLoadingMore = false
  @State private var lastTriggeredIndex: Int = -1

  var body: some View {
    List {
      if isLoading && pagination.isEmpty {
        Section {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
        }
      } else if pagination.isEmpty {
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
          ForEach(Array(pagination.items.enumerated()), id: \.element.id) { index, activity in
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
    // Cannot use Form for this, it would cause endless fetch on macOS.
    .optimizedListStyle()
    .inlineNavigationBarTitle(ServerSection.authenticationActivity.title)
    .task {
      if current.isAdmin {
        await loadActivities(refresh: true)
      }
    }
    .refreshable {
      if current.isAdmin {
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
        if let apiKeyComment = activity.apiKeyComment {
          HStack(spacing: 4) {
            Image(systemName: "key")
              .font(.caption)
            Text(apiKeyComment)
              .font(.footnote)
              .lineLimit(1)
          }.foregroundColor(.secondary)
        }
        Spacer()
        Text(activity.dateTime.formattedMediumDateTime)
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
      guard index >= pagination.items.count - 3,
        pagination.hasMorePages,
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
      pagination.reset()
      lastTriggeredIndex = -1
    }

    isLoading = true

    do {
      let page = try await AuthService.shared.getAuthenticationActivity(
        page: pagination.currentPage,
        size: pagination.pageSize
      )
      _ = pagination.applyPage(page.content)
      pagination.advance(moreAvailable: !page.last)
      lastTriggeredIndex = -1
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
  }

  private func loadMoreActivities() async {
    guard pagination.hasMorePages && !isLoadingMore else { return }

    isLoadingMore = true

    do {
      let page = try await AuthService.shared.getAuthenticationActivity(
        page: pagination.currentPage,
        size: pagination.pageSize
      )
      _ = pagination.applyPage(page.content)
      pagination.advance(moreAvailable: !page.last)
      lastTriggeredIndex = -1
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoadingMore = false
  }
}
