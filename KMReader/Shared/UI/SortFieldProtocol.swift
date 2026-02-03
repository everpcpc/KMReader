//
//  SortFieldProtocol.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

// Protocol to unify different sort field types
protocol SortFieldProtocol: CaseIterable, Hashable, RawRepresentable
where RawValue == String, AllCases: RandomAccessCollection {
  var displayName: String { get }
  var supportsDirection: Bool { get }
}

extension SeriesSortField: SortFieldProtocol {}
extension BookSortField: SortFieldProtocol {}
extension SimpleSortField: SortFieldProtocol {}
