//
// Current.swift
//
//

import Foundation

struct Current: Equatable, Sendable {
  var serverURL: String = ""
  var serverDisplayName: String = ""
  var authToken: String = ""
  var authMethod: AuthenticationMethod = .basicAuth
  var username: String = ""
  var userId: String = ""
  var roles: [String] = []
  var isAdmin: Bool = false
  var instanceId: String = ""
  var sessionToken: String = ""

  nonisolated init() {}

  init(
    serverURL: String = "",
    serverDisplayName: String = "",
    authToken: String = "",
    authMethod: AuthenticationMethod = .basicAuth,
    username: String = "",
    userId: String = "",
    roles: [String] = [],
    isAdmin: Bool = false,
    instanceId: String = "",
    sessionToken: String = ""
  ) {
    self.serverURL = serverURL
    self.serverDisplayName = serverDisplayName
    self.authToken = authToken
    self.authMethod = authMethod
    self.username = username
    self.userId = userId
    self.roles = roles
    self.isAdmin = isAdmin
    self.instanceId = instanceId
    self.sessionToken = sessionToken
  }

  var userRoles: [UserRole] {
    roles.map { UserRole(rawValue: $0) }
  }

  mutating func updateMetadata(from user: User) {
    self.userId = user.id
    self.roles = user.roles
    self.isAdmin = user.isAdmin
    self.username = user.email
  }

  mutating func clearUserMetadata() {
    self.userId = ""
    self.roles = []
    self.isAdmin = false
  }

  mutating func reset() {
    let savedURL = serverURL
    self = Current()
    self.serverURL = savedURL
  }
}

extension Current: RawRepresentable {
  public typealias RawValue = String

  public nonisolated init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8),
      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }

    self.serverURL = dict["serverURL"] as? String ?? ""
    self.serverDisplayName = dict["serverDisplayName"] as? String ?? ""
    self.authToken = dict["authToken"] as? String ?? ""
    if let methodRaw = dict["authMethod"] as? String {
      self.authMethod = AuthenticationMethod(rawValue: methodRaw) ?? .basicAuth
    }
    self.username = dict["username"] as? String ?? ""
    self.userId = dict["userId"] as? String ?? ""
    self.roles = dict["roles"] as? [String] ?? []
    self.isAdmin = dict["isAdmin"] as? Bool ?? false
    self.instanceId = dict["instanceId"] as? String ?? ""
    self.sessionToken = dict["sessionToken"] as? String ?? ""
  }

  public nonisolated var rawValue: String {
    let dict: [String: Any] = [
      "authMethod": authMethod.rawValue,
      "authToken": authToken,
      "instanceId": instanceId,
      "isAdmin": isAdmin,
      "roles": roles,
      "serverURL": serverURL,
      "serverDisplayName": serverDisplayName,
      "sessionToken": sessionToken,
      "userId": userId,
      "username": username,
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
      let result = String(data: data, encoding: .utf8)
    else {
      return "{}"
    }
    return result
  }
}
