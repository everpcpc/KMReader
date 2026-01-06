//
//  DashboardLocalSectionView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

/// Protocol for local dashboard section items
protocol DashboardLocalItem {
  var itemId: String { get }
  var itemName: String { get }
  var itemCount: Int { get }
  var itemCountLabel: String { get }
  var lastModifiedDate: Date { get }
}

extension KomgaCollection: DashboardLocalItem {
  var itemId: String { collectionId }
  var itemName: String { name }
  var itemCount: Int { seriesIds.count }
  var itemCountLabel: String { "\(seriesIds.count) series" }
}

extension KomgaReadList: DashboardLocalItem {
  var itemId: String { readListId }
  var itemName: String { name }
  var itemCount: Int { bookIds.count }
  var itemCountLabel: String { "\(bookIds.count) books" }
}

// MARK: - Main Container View

struct DashboardLocalSectionView: View {
  let section: DashboardSection
  let refreshTrigger: DashboardRefreshTrigger
  var onUpdated: (() -> Void)? = nil

  var body: some View {
    switch section {
    case .collections:
      DashboardCollectionsSection(
        refreshTrigger: refreshTrigger,
        onUpdated: onUpdated
      )
    case .readLists:
      DashboardReadListsSection(
        refreshTrigger: refreshTrigger,
        onUpdated: onUpdated
      )
    default:
      EmptyView()
    }
  }
}

// MARK: - Collections Section

private struct DashboardCollectionsSection: View {
  let refreshTrigger: DashboardRefreshTrigger
  var onUpdated: (() -> Void)? = nil

  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @Query private var items: [KomgaCollection]

  @State private var isLoading = false

  init(refreshTrigger: DashboardRefreshTrigger, onUpdated: (() -> Void)? = nil) {
    self.refreshTrigger = refreshTrigger
    self.onUpdated = onUpdated

    let instanceId = AppConfig.currentInstanceId
    _items = Query(
      filter: #Predicate<KomgaCollection> { $0.instanceId == instanceId },
      sort: [SortDescriptor(\KomgaCollection.lastModifiedDate, order: .reverse)]
    )
  }

  var body: some View {
    DashboardLocalSectionContent(
      section: .collections,
      refreshTrigger: refreshTrigger,
      items: items,
      onRefresh: refresh
    ) { collection in
      CollectionCompactCardView(
        komgaCollection: collection,
        onActionCompleted: onUpdated
      )
    }
  }

  private func refresh() async {
    guard !isLoading, !AppConfig.isOffline else { return }
    isLoading = true
    await SyncService.shared.syncCollections(instanceId: currentInstanceId)
    isLoading = false
  }
}

// MARK: - ReadLists Section

private struct DashboardReadListsSection: View {
  let refreshTrigger: DashboardRefreshTrigger
  var onUpdated: (() -> Void)? = nil

  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @Query private var items: [KomgaReadList]

  @State private var isLoading = false

  init(refreshTrigger: DashboardRefreshTrigger, onUpdated: (() -> Void)? = nil) {
    self.refreshTrigger = refreshTrigger
    self.onUpdated = onUpdated

    let instanceId = AppConfig.currentInstanceId
    _items = Query(
      filter: #Predicate<KomgaReadList> { $0.instanceId == instanceId },
      sort: [SortDescriptor(\KomgaReadList.lastModifiedDate, order: .reverse)]
    )
  }

  var body: some View {
    DashboardLocalSectionContent(
      section: .readLists,
      refreshTrigger: refreshTrigger,
      items: items,
      onRefresh: refresh
    ) { readList in
      ReadListCompactCardView(
        komgaReadList: readList,
        onActionCompleted: onUpdated
      )
    }
  }

  private func refresh() async {
    guard !isLoading, !AppConfig.isOffline else { return }
    isLoading = true
    await SyncService.shared.syncReadLists(instanceId: currentInstanceId)
    isLoading = false
  }
}

// MARK: - Generic Content View

private struct DashboardLocalSectionContent<
  Item: DashboardLocalItem & Identifiable, ItemView: View
>: View {
  let section: DashboardSection
  let refreshTrigger: DashboardRefreshTrigger
  let items: [Item]
  let onRefresh: () async -> Void
  @ViewBuilder let itemView: (Item) -> ItemView

  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @Environment(\.colorScheme) private var colorScheme

  @State private var isHoveringScrollArea = false
  @State private var hasLoadedInitial = false

  private let cardWidth: CGFloat = 240

  private var backgroundColors: [Color] {
    if colorScheme == .dark {
      return [
        Color.secondary.opacity(0.2),
        Color.clear,
      ]
    } else {
      return [
        Color.clear,
        Color.secondary.opacity(0.1),
      ]
    }
  }

  private var spacing: CGFloat {
    LayoutConfig.spacing(for: gridDensity)
  }

  private var destination: NavDestination {
    switch section {
    case .collections:
      return .browseCollections
    case .readLists:
      return .browseReadLists
    default:
      return .browseCollections
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      NavigationLink(value: destination) {
        HStack {
          Text(section.displayName)
            .font(.appSerifDesign(size: 22, weight: .bold))
          Image(systemName: "chevron.right")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .buttonStyle(.plain)
      .padding(.horizontal)

      ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(alignment: .top, spacing: spacing) {
            ForEach(items) { item in
              itemView(item)
                .id(item.itemId)
                .frame(width: cardWidth)
            }
          }
          .padding(.vertical)
        }
        .contentMargins(.horizontal, spacing, for: .scrollContent)
        .scrollClipDisabled()
        .overlay {
          HorizontalScrollButtons(
            scrollProxy: proxy,
            itemIds: items.map(\.itemId),
            isVisible: isHoveringScrollArea
          )
        }
      }
    }
    .padding(.vertical, 16)
    #if os(iOS) || os(macOS)
      .background {
        LinearGradient(
          colors: backgroundColors,
          startPoint: .top,
          endPoint: .bottom
        )
      }
    #endif
    #if os(macOS)
      .onContinuousHover { phase in
        switch phase {
        case .active:
          withAnimation {
            isHoveringScrollArea = true
          }
        case .ended:
          withAnimation {
            isHoveringScrollArea = false
          }
        }
      }
    #endif
    .opacity(items.isEmpty ? 0 : 1)
    .frame(height: items.isEmpty ? 0 : nil)
    .onChange(of: refreshTrigger) {
      if let sections = refreshTrigger.sectionsToRefresh, !sections.contains(section) {
        return
      }
      Task {
        await onRefresh()
      }
    }
    .task {
      guard !hasLoadedInitial else { return }
      hasLoadedInitial = true
      await onRefresh()
    }
  }
}
