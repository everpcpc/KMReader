//
// ServerInfo.swift
//
//

import Foundation

nonisolated struct ServerInfo: Codable, Sendable {
  let build: BuildInfo?
  let git: GitInfo?
  let java: JavaInfo?
  let os: OSInfo?

  struct BuildInfo: Codable, Sendable {
    let version: String?
    let artifact: String?
    let name: String?
    let group: String?
    let time: String?
  }

  struct GitInfo: Codable, Sendable {
    let branch: String?
    let commit: CommitInfo?

    struct CommitInfo: Codable, Sendable {
      let id: String?
      let idAbbrev: String?
      let time: String?
    }
  }

  struct JavaInfo: Codable, Sendable {
    let version: String?
    let vendor: VendorInfo?
    let runtime: RuntimeInfo?
    let jvm: JVMInfo?

    struct VendorInfo: Codable, Sendable {
      let name: String?
      let version: String?
    }

    struct RuntimeInfo: Codable, Sendable {
      let name: String?
      let version: String?
    }

    struct JVMInfo: Codable, Sendable {
      let name: String?
      let vendor: String?
      let version: String?
    }
  }

  struct OSInfo: Codable, Sendable {
    let name: String?
    let version: String?
    let arch: String?
  }
}
