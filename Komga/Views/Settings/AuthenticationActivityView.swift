//
//  AuthenticationActivityView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct AuthenticationActivityView: View {
  @State private var activities: [AuthenticationActivity] = []
  @State private var isLoading = false
  @State private var isLoadingMore = false
  @State private var errorMessage: String?
  @State private var currentPage = 0
  @State private var hasMorePages = true

  var body: some View {
    Form {
      if isLoading && activities.isEmpty {
        Section {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
        }
      } else if let errorMessage = errorMessage, activities.isEmpty {
        Section {
          HStack {
            Label("Error", systemImage: "exclamationmark.triangle")
              .foregroundColor(.red)
            Spacer()
            Text(errorMessage)
              .foregroundColor(.secondary)
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
        }
      } else {
        Section {
          ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
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

              if let error = activity.error {
                Text(error)
                  .font(.caption)
                  .foregroundColor(.red)
              }

              if let ip = activity.ip {
                HStack {
                  Label("IP", systemImage: "network")
                    .font(.caption)
                    .foregroundColor(.secondary)
                  Text(ip)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }

              if let userAgent = activity.userAgent {
                Text(userAgent)
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .lineLimit(2)
              }

              if let apiKeyComment = activity.apiKeyComment {
                HStack {
                  Label("API Key", systemImage: "key")
                    .font(.caption)
                    .foregroundColor(.secondary)
                  Text(apiKeyComment)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
            }
            .padding(.vertical, 4)
            .onAppear {
              if index >= activities.count - 3 && hasMorePages && !isLoadingMore {
                Task {
                  await loadMoreActivities()
                }
              }
            }
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
    .navigationTitle("Authentication Activity")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await loadActivities(refresh: true)
    }
    .refreshable {
      await loadActivities(refresh: true)
    }
  }

  private func loadActivities(refresh: Bool = false) async {
    if refresh {
      currentPage = 0
      hasMorePages = true
      activities = []
    }

    isLoading = true
    errorMessage = nil

    do {
      let page = try await AuthService.shared.getAuthenticationActivity(page: 0, size: 20)
      activities = page.content
      hasMorePages = !page.last
      currentPage = 1
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  private func loadMoreActivities() async {
    guard hasMorePages && !isLoadingMore else { return }

    isLoadingMore = true

    do {
      let page = try await AuthService.shared.getAuthenticationActivity(page: currentPage, size: 20)
      activities.append(contentsOf: page.content)
      hasMorePages = !page.last
      currentPage += 1
    } catch {
      errorMessage = error.localizedDescription
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
