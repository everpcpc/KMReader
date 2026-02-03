//
//  Current.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

struct Current: Equatable, Sendable {
  var serverURL: String = ""
  var serverDisplayName: String = ""
  var authToken: String = ""
  var authMethod: AuthenticationMethod = .basicAuth
  var username: String = ""
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
    isAdmin: Bool = false,
    instanceId: String = "",
    sessionToken: String = ""
  ) {
    self.serverURL = serverURL
    self.serverDisplayName = serverDisplayName
    self.authToken = authToken
    self.authMethod = authMethod
    self.username = username
    self.isAdmin = isAdmin
    self.instanceId = instanceId
    self.sessionToken = sessionToken
  }

  mutating func updateMetadata(from user: User) {
    self.isAdmin = user.isAdmin
    self.username = user.email
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
    self.isAdmin = dict["isAdmin"] as? Bool ?? false
    self.instanceId = dict["instanceId"] as? String ?? ""
    self.sessionToken = dict["sessionToken"] as? String ?? ""
  }

  public nonisolated var rawValue: String {
    let dict: [String: Any] = [
      "serverURL": serverURL,
      "serverDisplayName": serverDisplayName,
      "authToken": authToken,
      "authMethod": authMethod.rawValue,
      "username": username,
      "isAdmin": isAdmin,
      "instanceId": instanceId,
      "sessionToken": sessionToken,
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: dict),
      let result = String(data: data, encoding: .utf8)
    else {
      return "{}"
    }
    return result
  }
}
