//
//  ServerInfo.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct ServerInfo: Codable {
  let build: BuildInfo?
  let git: GitInfo?
  let java: JavaInfo?
  let os: OSInfo?

  struct BuildInfo: Codable {
    let version: String?
    let artifact: String?
    let name: String?
    let group: String?
    let time: String?
  }

  struct GitInfo: Codable {
    let branch: String?
    let commit: CommitInfo?

    struct CommitInfo: Codable {
      let id: String?
      let idAbbrev: String?
      let time: String?
    }
  }

  struct JavaInfo: Codable {
    let version: String?
    let vendor: VendorInfo?
    let runtime: RuntimeInfo?
    let jvm: JVMInfo?

    struct VendorInfo: Codable {
      let name: String?
      let version: String?
    }

    struct RuntimeInfo: Codable {
      let name: String?
      let version: String?
    }

    struct JVMInfo: Codable {
      let name: String?
      let vendor: String?
      let version: String?
    }
  }

  struct OSInfo: Codable {
    let name: String?
    let version: String?
    let arch: String?
  }
}
