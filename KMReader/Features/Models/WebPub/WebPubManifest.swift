//
//  WebPubManifest.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

struct WebPubPublication: Codable, Sendable {
  let context: String?
  let metadata: WebPubMetadata?
  let readingOrder: [WebPubLink]
  let resources: [WebPubLink]
  let toc: [WebPubLink]
  let images: [WebPubLink]
  let links: [WebPubLink]
  let pageList: [WebPubLink]
  let landmarks: [WebPubLink]

  enum CodingKeys: String, CodingKey {
    case context
    case metadata
    case readingOrder
    case resources
    case toc
    case images
    case links
    case pageList
    case landmarks
  }

  init(
    context: String? = nil,
    metadata: WebPubMetadata? = nil,
    readingOrder: [WebPubLink] = [],
    resources: [WebPubLink] = [],
    toc: [WebPubLink] = [],
    images: [WebPubLink] = [],
    links: [WebPubLink] = [],
    pageList: [WebPubLink] = [],
    landmarks: [WebPubLink] = []
  ) {
    self.context = context
    self.metadata = metadata
    self.readingOrder = readingOrder
    self.resources = resources
    self.toc = toc
    self.images = images
    self.links = links
    self.pageList = pageList
    self.landmarks = landmarks
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let metadata = try container.decodeIfPresent(WebPubMetadata.self, forKey: .metadata)
    let readingOrder = try container.decodeIfPresent([WebPubLink].self, forKey: .readingOrder) ?? []
    let resources = try container.decodeIfPresent([WebPubLink].self, forKey: .resources) ?? []
    let toc = try container.decodeIfPresent([WebPubLink].self, forKey: .toc) ?? []
    let images = try container.decodeIfPresent([WebPubLink].self, forKey: .images) ?? []
    let links = try container.decodeIfPresent([WebPubLink].self, forKey: .links) ?? []
    let pageList = try container.decodeIfPresent([WebPubLink].self, forKey: .pageList) ?? []
    let landmarks = try container.decodeIfPresent([WebPubLink].self, forKey: .landmarks) ?? []

    var context = try container.decodeIfPresent(String.self, forKey: .context)
    if context == nil {
      let dynamic = try decoder.container(keyedBy: DynamicCodingKey.self)
      context = try dynamic.decodeIfPresent(String.self, forKey: DynamicCodingKey("@context"))
    }

    self.init(
      context: context,
      metadata: metadata,
      readingOrder: readingOrder,
      resources: resources,
      toc: toc,
      images: images,
      links: links,
      pageList: pageList,
      landmarks: landmarks
    )
  }
}

struct WebPubLink: Codable, Sendable {
  let href: String
  let title: String?
  let type: String?
  let rel: String?
  let templated: Bool?
  let properties: [String: JSONAny]?
  let height: Int?
  let width: Int?
}

struct WebPubMetadata: Codable, Sendable {
  let title: String?
  let language: String?
  let readingProgression: WebPubReadingProgression?
}

enum WebPubReadingProgression: String, Codable, Sendable {
  case rtl
  case ltr
  case ttb
  case btt
  case auto
}

private struct DynamicCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init(_ string: String) {
    self.stringValue = string
    self.intValue = nil
  }

  init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(intValue: Int) {
    self.intValue = intValue
    self.stringValue = String(intValue)
  }
}
