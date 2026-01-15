//
//  SettingsApiKeyView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsApiKeyView: View {
  @State private var apiKeys: [ApiKey] = []
  @State private var isLoading = false
  @State private var showingAddSheet = false
  @State private var keyToDelete: ApiKey?
  @State private var showingDeleteConfirmation = false
  @State private var lastActivities: [String: Date] = [:]

  @State private var showRelativeDate = true

  var body: some View {
    Form {
      Section {
        if isLoading && apiKeys.isEmpty {
          ProgressView()
            .frame(maxWidth: .infinity, alignment: .center)
        } else if apiKeys.isEmpty {
          Text("No API Keys found")
            .foregroundColor(.secondary)
        } else {
          #if os(tvOS) || os(macOS)
            Section {
              Button {
                showingAddSheet = true
              } label: {
                HStack {
                  Spacer()
                  Image(systemName: "plus")
                  Spacer()
                }
              }
              .adaptiveButtonStyle(.borderedProminent)
              .listRowBackground(Color.clear)
            }
          #endif

          ForEach(apiKeys) { apiKey in
            VStack(alignment: .leading) {
              HStack {
                Image(systemName: "key")
                  .font(.footnote)
                Text(apiKey.comment.isEmpty ? "No comment" : apiKey.comment)
                  .bold()
              }
              HStack {
                Image(systemName: "calendar")
                Text("Created")
                  .foregroundColor(.secondary.opacity(0.6))
                Text(formatTime(apiKey.createdDate))
                  .monospacedDigit()
              }
              .font(.caption)
              .foregroundColor(.secondary)

              if let lastActivity = lastActivities[apiKey.id] {
                HStack {
                  Image(systemName: "clock")
                  Text("Recent activity")
                    .foregroundColor(.secondary.opacity(0.6))
                  if showRelativeDate {
                    Button {
                      withAnimation {
                        showRelativeDate = false
                      }
                    } label: {
                      Text(lastActivity.formatted(.relative(presentation: .named)))
                        .monospacedDigit()
                    }.adaptiveButtonStyle(.plain)
                  } else {
                    Button {
                      withAnimation {
                        showRelativeDate = true
                      }
                    } label: {
                      Text(formatTime(lastActivity))
                        .monospacedDigit()
                    }.adaptiveButtonStyle(.plain)
                  }
                }
                .font(.caption)
                .foregroundColor(.secondary)
              } else {
                HStack {
                  Image(systemName: "clock")
                  Text("No recent activity")
                }
                .font(.caption)
                .foregroundColor(.secondary)
              }
            }.tvFocusableHighlight()
              #if os(iOS) || os(macOS)
                .swipeActions {
                  Button(role: .destructive) {
                    keyToDelete = apiKey
                    showingDeleteConfirmation = true
                  } label: {
                    Label(String(localized: "Delete"), systemImage: "trash")
                  }
                }
              #endif
          }
        }
      }
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle(SettingsSection.apiKeys.title)
    .animation(.default, value: apiKeys)
    .animation(.default, value: lastActivities)
    #if os(iOS)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button {
            showingAddSheet = true
          } label: {
            Image(systemName: "plus")
          }
        }
      }
    #endif
    .task {
      await loadApiKeys()
    }
    .refreshable {
      await loadApiKeys()
    }
    .alert(String(localized: "Delete API Key"), isPresented: $showingDeleteConfirmation) {
      Button(String(localized: "Delete"), role: .destructive) {
        if let key = keyToDelete {
          deleteApiKey(key)
        }
      }
      Button(String(localized: "Cancel"), role: .cancel) {
        keyToDelete = nil
      }
    } message: {
      Text(
        "Any applications or scripts using this API key will no longer be able to access the Komga API. You cannot undo this action."
      )
    }
    .sheet(isPresented: $showingAddSheet) {
      SettingsApiKeyAddSheet {
        Task { await loadApiKeys() }
      }
    }
  }

  private func formatTime(_ date: Date) -> String {
    return date.formatted(date: .abbreviated, time: .shortened)
  }

  private func loadApiKeys() async {
    isLoading = true
    do {
      apiKeys = try await AuthService.shared.getApiKeys()
      for apiKey in apiKeys {
        Task {
          do {
            let activity = try await AuthService.shared.getLatestAuthenticationActivity(
              apiKey: apiKey)
            lastActivities[apiKey.id] = activity.dateTime
          } catch {
            // Ignore error for missing activity
          }
        }
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }
    isLoading = false
  }

  private func deleteApiKey(_ apiKey: ApiKey) {
    Task {
      do {
        try await AuthService.shared.deleteApiKey(id: apiKey.id)
        if let index = apiKeys.firstIndex(where: { $0.id == apiKey.id }) {
          apiKeys.remove(at: index)
        }
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.apiKey.deleted"))
        }
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
