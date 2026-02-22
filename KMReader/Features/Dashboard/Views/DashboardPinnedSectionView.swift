//
// DashboardPinnedSectionView.swift
//
//

import SwiftData
import SwiftUI

@MainActor
struct DashboardPinnedSectionView: View {
  let section: DashboardSection
  let refreshTrigger: DashboardRefreshTrigger

  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @AppStorage("dashboardShowGradient") private var dashboardShowGradient: Bool = true

  @Query private var pinnedCollections: [KomgaCollection]
  @Query private var pinnedReadLists: [KomgaReadList]

  @Environment(\.colorScheme) private var colorScheme

  @State private var isLoading = false
  @State private var hasLoadedInitial = false
  @State private var isHoveringScrollArea = false
  @State private var hoverShowDelayTask: Task<Void, Never>?
  @State private var hoverHideDelayTask: Task<Void, Never>?

  init(section: DashboardSection, refreshTrigger: DashboardRefreshTrigger) {
    self.section = section
    self.refreshTrigger = refreshTrigger

    let instanceId = AppConfig.current.instanceId
    _pinnedCollections = Query(
      filter: #Predicate<KomgaCollection> { item in
        item.instanceId == instanceId && item.isPinned == true
      },
      sort: [SortDescriptor(\KomgaCollection.lastModifiedDate, order: .reverse)]
    )
    _pinnedReadLists = Query(
      filter: #Predicate<KomgaReadList> { item in
        item.instanceId == instanceId && item.isPinned == true
      },
      sort: [SortDescriptor(\KomgaReadList.lastModifiedDate, order: .reverse)]
    )
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
          if dashboardShowGradient {
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
                      komgaCollection: collection,
                      coverWidth: compactCoverWidth
                    )
                    .id(collection.collectionId)
                    .frame(width: compactCardWidth)
                  }
                case .readLists:
                  ForEach(pinnedReadLists) { readList in
                    ReadListCompactCardView(
                      komgaReadList: readList,
                      coverWidth: compactCoverWidth
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
      .task {
        guard !hasLoadedInitial else { return }
        hasLoadedInitial = true
        await refresh()
      }
    }
  }

  private func refresh() async {
    guard !isLoading, !AppConfig.isOffline else { return }
    isLoading = true
    switch section.contentKind {
    case .collections:
      await SyncService.shared.syncCollections(instanceId: currentInstanceId)
    case .readLists:
      await SyncService.shared.syncReadLists(instanceId: currentInstanceId)
    default:
      break
    }
    isLoading = false
  }
}
