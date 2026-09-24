//
// DashboardSectionView.swift
//
//

import SwiftUI

@MainActor
struct DashboardSectionView: View {
  let section: DashboardSection

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @AppStorage("dashboardHorizontalBookCards")
  private var dashboardHorizontalBookCards: Bool = true
  @AppStorage("showDashboardSectionGradientBackground")
  private var showDashboardSectionGradientBackground: Bool =
    AppConfig.showDashboardSectionGradientBackground
  @Environment(\.colorScheme) private var colorScheme

  @State private var viewModel: DashboardSectionViewModel

  private let logger = AppLogger(.dashboard)

  init(section: DashboardSection) {
    self.section = section
    _viewModel = State(initialValue: DashboardSectionViewModel(section: section))
  }

  private var pagination: PaginationState<IdentifiedString> {
    viewModel.pagination
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

  private var cardWidth: CGFloat {
    LayoutConfig.cardWidth(for: gridDensity)
  }

  /// Horizontal cards only apply to Keep Reading.
  private var useHorizontalBookCards: Bool {
    section == .keepReading && dashboardHorizontalBookCards
  }

  private var horizontalCardWidth: CGFloat {
    LayoutConfig.horizontalCardWidth
  }

  private var horizontalCoverWidth: CGFloat {
    LayoutConfig.horizontalCoverWidth
  }

  private var itemWidth: CGFloat {
    useHorizontalBookCards ? horizontalCardWidth : cardWidth
  }

  private var spacing: CGFloat {
    LayoutConfig.spacing(for: gridDensity)
  }

  var body: some View {
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
        NavigationLink(value: NavDestination.dashboardSectionDetail(section: section)) {
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
        .padding(.horizontal)
        .padding(.top)
        #if os(macOS)
          .padding(.leading, 16)
        #endif
        .disabled(pagination.isEmpty)

        ScrollViewReader { proxy in
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: spacing) {
              ForEach(pagination.items) { item in
                itemView(for: item.id)
                  .id(item.id)
                  .frame(width: itemWidth)
                  .onAppear {
                    viewModel.loadMoreIfNeeded(after: item, libraryIds: dashboard.libraryIds)
                  }
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
            .macHorizontalScrollButtons(
              scrollProxy: proxy,
              itemIds: pagination.items.map(\.id)
            )
          #endif
        }
      }
    }
    .opacity(pagination.isEmpty ? 0 : 1)
    .frame(height: pagination.isEmpty ? 0 : nil)
    .onReceive(NotificationCenter.default.publisher(for: .dashboardSectionsShouldReload)) {
      notification in
      guard let command = DashboardSectionRefreshNotifier.reloadCommand(from: notification) else {
        return
      }
      handleReloadCommand(command)
    }
    .onAppear {
      DashboardRefreshCoordinator.shared.registerSection(section)
      viewModel.ensureLoaded(libraryIds: dashboard.libraryIds)
    }
    .onDisappear {
      DashboardRefreshCoordinator.shared.unregisterSection(section)
    }
  }

  @ViewBuilder
  private func itemView(for itemId: String) -> some View {
    switch section.contentKind {
    case .books:
      BookQueryItemView(
        bookId: itemId,
        layout: .grid,
        showSeriesTitle: true,
        horizontalCoverWidth: useHorizontalBookCards ? horizontalCoverWidth : nil,
        onItemMissing: {
          viewModel.removeItem(id: itemId)
        }
      )
    case .series:
      SeriesQueryItemView(
        seriesId: itemId,
        layout: .grid,
        onItemMissing: {
          viewModel.removeItem(id: itemId)
        }
      )
    case .collections, .readLists:
      EmptyView()
    }
  }

  private func handleReloadCommand(_ command: DashboardSectionReloadCommand) {
    guard command.includes(section) else {
      logger.debug("Dashboard section \(section) skipping reload: targeted other sections")
      return
    }

    if command.source == .auto, pagination.currentPage > 1 {
      logger.debug(
        "Dashboard section \(section) skipping auto-refresh: deep in pagination (page \(pagination.currentPage))"
      )
      return
    }

    let libraryIds = dashboard.libraryIds
    Task {
      logger.debug("Dashboard section \(section) reloading")
      defer {
        DashboardRefreshCoordinator.shared.acknowledgeSectionReload(
          commandID: command.id, section: section)
      }
      await viewModel.reload(libraryIds: libraryIds)
    }
  }
}
