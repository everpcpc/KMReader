//
// DashboardPinnedSectionView.swift
//
//

import SwiftUI

@MainActor
struct DashboardPinnedSectionView: View {
  let section: DashboardSection
  let refreshTrigger: DashboardRefreshTrigger

  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @AppStorage("showDashboardSectionGradientBackground")
  private var showDashboardSectionGradientBackground: Bool =
    AppConfig.showDashboardSectionGradientBackground

  @Environment(\.colorScheme) private var colorScheme

  @State private var isLoading = false
  @State private var pinnedCollections: [CollectionDisplayItem] = []
  @State private var pinnedReadLists: [ReadListDisplayItem] = []
  @State private var isHoveringScrollArea = false
  @State private var hoverShowDelayTask: Task<Void, Never>?
  @State private var hoverHideDelayTask: Task<Void, Never>?

  init(section: DashboardSection, refreshTrigger: DashboardRefreshTrigger) {
    self.section = section
    self.refreshTrigger = refreshTrigger
  }

  private var isSupportedSection: Bool {
    switch section.contentKind {
    case .collections, .readLists:
      return true
    default:
      return false
    }
  }

  private var hasItems: Bool {
    switch section.contentKind {
    case .collections:
      return !pinnedCollections.isEmpty
    case .readLists:
      return !pinnedReadLists.isEmpty
    default:
      return false
    }
  }

  private var itemIds: [String] {
    switch section.contentKind {
    case .collections:
      return pinnedCollections.map(\.collectionId)
    case .readLists:
      return pinnedReadLists.map(\.readListId)
    default:
      return []
    }
  }

  private var destination: NavDestination {
    switch section.contentKind {
    case .collections:
      return .browseCollections
    case .readLists:
      return .browseReadLists
    default:
      return .browseCollections
    }
  }

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

  private var compactCardWidth: CGFloat {
    let proposed = LayoutConfig.cardWidth(for: gridDensity) * 2.0
    #if os(tvOS)
      return min(max(proposed, 360), 680)
    #else
      return min(max(proposed, 220), 480)
    #endif
  }

  private var compactCoverWidth: CGFloat {
    min(max(compactCardWidth * 0.24, 64), 132)
  }

  private var spacing: CGFloat {
    LayoutConfig.spacing(for: gridDensity)
  }

  var body: some View {
    if isSupportedSection {
      ZStack {
        #if os(iOS) || os(macOS)
          if showDashboardSectionGradientBackground {
            LinearGradient(
              colors: backgroundColors,
              startPoint: .top,
              endPoint: .bottom
            ).ignoresSafeArea()
          }
        #endif

        VStack(alignment: .leading, spacing: 0) {
          NavigationLink(value: destination) {
            HStack {
              Text(section.displayName)
                .font(.title2)
                .bold()
                .fontDesign(.serif)
              Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
            }
          }
          .buttonStyle(.plain)
          .padding()
          #if os(macOS)
            .padding(.leading, 16)
          #endif
          .disabled(!hasItems)

          ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
              LazyHStack(alignment: .top, spacing: spacing) {
                switch section.contentKind {
                case .collections:
                  ForEach(pinnedCollections) { collection in
                    CollectionCompactCardView(
                      item: collection,
                      coverWidth: compactCoverWidth,
                      onChanged: schedulePinnedItemsReload
                    )
                    .id(collection.collectionId)
                    .frame(width: compactCardWidth)
                  }
                case .readLists:
                  ForEach(pinnedReadLists) { readList in
                    ReadListCompactCardView(
                      item: readList,
                      coverWidth: compactCoverWidth,
                      onChanged: schedulePinnedItemsReload
                    )
                    .id(readList.readListId)
                    .frame(width: compactCardWidth)
                  }
                default:
                  EmptyView()
                }
              }
              .padding(.vertical)
              #if os(macOS)
                .padding(.leading, 16)
              #endif
            }
            .contentMargins(.horizontal, spacing, for: .scrollContent)
            .scrollClipDisabled()
            #if os(macOS)
              .overlay {
                HorizontalScrollButtons(
                  scrollProxy: proxy,
                  itemIds: itemIds,
                  isVisible: isHoveringScrollArea
                )
              }
            #endif
          }
        }
      }
      .opacity(hasItems ? 1 : 0)
      .frame(height: hasItems ? nil : 0)
      #if os(macOS)
        .onContinuousHover { phase in
          switch phase {
          case .active:
            hoverHideDelayTask?.cancel()
            hoverHideDelayTask = nil
            hoverShowDelayTask?.cancel()
            hoverShowDelayTask = Task { @MainActor in
              try? await Task.sleep(nanoseconds: 100_000_000)
              guard !Task.isCancelled else { return }
              withAnimation(.easeInOut(duration: 0.2)) {
                isHoveringScrollArea = true
              }
            }
          case .ended:
            hoverShowDelayTask?.cancel()
            hoverShowDelayTask = nil
            hoverHideDelayTask?.cancel()
            hoverHideDelayTask = Task { @MainActor in
              try? await Task.sleep(nanoseconds: 100_000_000)
              guard !Task.isCancelled else { return }
              withAnimation(.easeInOut(duration: 0.2)) {
                isHoveringScrollArea = false
              }
            }
          }
        }
      #endif
      .onChange(of: refreshTrigger) { _, newTrigger in
        if let sections = newTrigger.sectionsToRefresh, !sections.contains(section) {
          return
        }
        Task {
          await refresh()
        }
      }
      .task(id: currentInstanceId) {
        await refresh()
      }
    }
  }

  private func refresh() async {
    guard !isLoading else { return }
    isLoading = true
    defer {
      isLoading = false
    }

    await loadPinnedItems()

    guard !AppConfig.isOffline else { return }
    switch section.contentKind {
    case .collections:
      await SyncService.syncCollections(instanceId: currentInstanceId)
    case .readLists:
      await SyncService.syncReadLists(instanceId: currentInstanceId)
    default:
      break
    }
    await loadPinnedItems()
  }

  private func schedulePinnedItemsReload() {
    Task {
      await loadPinnedItems()
    }
  }

  private func loadPinnedItems() async {
    guard !currentInstanceId.isEmpty else {
      if !pinnedCollections.isEmpty { pinnedCollections = [] }
      if !pinnedReadLists.isEmpty { pinnedReadLists = [] }
      return
    }

    do {
      let database = try await DatabaseOperator.database()
      switch section.contentKind {
      case .collections:
        let loadedCollections = try await database.fetchPinnedCollectionDisplayItems(
          instanceId: currentInstanceId
        )
        if pinnedCollections != loadedCollections {
          pinnedCollections = loadedCollections
        }
        if !pinnedReadLists.isEmpty { pinnedReadLists = [] }
      case .readLists:
        let loadedReadLists = try await database.fetchPinnedReadListDisplayItems(
          instanceId: currentInstanceId
        )
        if pinnedReadLists != loadedReadLists {
          pinnedReadLists = loadedReadLists
        }
        if !pinnedCollections.isEmpty { pinnedCollections = [] }
      default:
        break
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }
}
