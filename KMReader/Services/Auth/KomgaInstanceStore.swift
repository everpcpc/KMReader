//
//  KomgaInstanceStore.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

@MainActor
final class KomgaInstanceStore {
  static let shared = KomgaInstanceStore()

  private var container: ModelContainer?

  private init() {}

  func configure(with container: ModelContainer) {
    self.container = container
  }

  private func makeContext() throws -> ModelContext {
    guard let container else {
      throw AppErrorType.storageNotConfigured(message: "ModelContainer is not configured")
    }
    return ModelContext(container)
  }

  @discardableResult
  func upsertInstance(
    serverURL: String,
    username: String,
    authToken: String,
    isAdmin: Bool,
    authMethod: AuthenticationMethod = .basicAuth,
    displayName: String? = nil
  ) throws -> KomgaInstance {
    let trimmedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
    let context = try makeContext()
    let descriptor = FetchDescriptor<KomgaInstance>(
      predicate: #Predicate { instance in
        instance.serverURL == serverURL && instance.username == username
      })

    if let existing = try context.fetch(descriptor).first {
      existing.authToken = authToken
      existing.isAdmin = isAdmin
      existing.authMethod = authMethod
      existing.lastUsedAt = Date()
      if let trimmedDisplayName, !trimmedDisplayName.isEmpty {
        existing.name = trimmedDisplayName
      } else if existing.name.isEmpty {
        existing.name = Self.defaultName(serverURL: serverURL, username: username)
      }
      try context.save()
      return existing
    } else {
      let resolvedName = Self.resolvedName(
        displayName: trimmedDisplayName, serverURL: serverURL, username: username)
      let instance = KomgaInstance(
        name: resolvedName,
        serverURL: serverURL,
        username: username,
        authToken: authToken,
        isAdmin: isAdmin,
        authMethod: authMethod
      )
      context.insert(instance)
      try context.save()
      return instance
    }
  }

  func fetchInstance(idString: String?) -> KomgaInstance? {
    guard
      let idString,
      let uuid = UUID(uuidString: idString),
      let container
    else {
      return nil
    }

    let context = ModelContext(container)
    let descriptor = FetchDescriptor<KomgaInstance>(
      predicate: #Predicate { instance in
        instance.id == uuid
      })

    return try? context.fetch(descriptor).first
  }

  static func defaultName(serverURL: String, username: String) -> String {
    if let host = URL(string: serverURL)?.host, !host.isEmpty {
      return host
    }
    return serverURL
  }

  private static func resolvedName(
    displayName: String?, serverURL: String, username: String
  ) -> String {
    if let displayName, !displayName.isEmpty {
      return displayName
    }
    return defaultName(serverURL: serverURL, username: username)
  }

  func updateLastUsed(for instanceId: String) {
    Task {
      do {
        let context = try makeContext()
        if let uuid = UUID(uuidString: instanceId) {
          let descriptor = FetchDescriptor<KomgaInstance>(
            predicate: #Predicate { instance in
              instance.id == uuid
            })
          if let instance = try context.fetch(descriptor).first {
            instance.lastUsedAt = Date()
            try context.save()
          }
        }
      } catch {
        print("Failed to update last used: \(error)")
      }
    }
  }

  func getLastSyncedAt(instanceId: String) -> (series: Date, books: Date) {
    guard let instance = fetchInstance(idString: instanceId) else {
      return (Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 0))
    }
    return (instance.seriesLastSyncedAt, instance.booksLastSyncedAt)
  }

  func updateSeriesLastSyncedAt(instanceId: String, date: Date) throws {
    let context = try makeContext()
    guard let uuid = UUID(uuidString: instanceId) else { return }
    let descriptor = FetchDescriptor<KomgaInstance>(
      predicate: #Predicate { instance in
        instance.id == uuid
      })
    if let instance = try context.fetch(descriptor).first {
      instance.seriesLastSyncedAt = date
      try context.save()
    }
  }

  func updateBooksLastSyncedAt(instanceId: String, date: Date) throws {
    let context = try makeContext()
    guard let uuid = UUID(uuidString: instanceId) else { return }
    let descriptor = FetchDescriptor<KomgaInstance>(
      predicate: #Predicate { instance in
        instance.id == uuid
      })
    if let instance = try context.fetch(descriptor).first {
      instance.booksLastSyncedAt = date
      try context.save()
    }
  }
}
