//
// DashboardSectionView.swift
//
//

import SwiftUI

@MainActor
struct DashboardSectionView: View {
  let section: DashboardSection

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
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

  private var cardKind: DashboardCardKind {
    dashboard.cardKind(for: section)
  }

  private var cardKindBinding: Binding<DashboardCardKind> {
    Binding(
      get: { cardKind },
      set: { dashboard.setCardKind($0, for: section) }
    )
  }

  private var itemWidth: CGFloat {
    switch cardKind {
    case .horizontal:
      return LayoutConfig.horizontalCardWidth
    case .large:
      return LayoutConfig.dashboardLargeCardWidth
    case .small:
      return LayoutConfig.dashboardSmallCardWidth
    }
  }

  private var horizontalCoverWidth: CGFloat? {
    cardKind == .horizontal ? LayoutConfig.horizontalCoverWidth : nil
  }

  private var spacing: CGFloat {
    LayoutConfig.defaultSpacing
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
        HStack {
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
          .disabled(viewModel.pagination.isEmpty)

          Spacer()

          if section.availableCardKinds.count > 1 {
            Menu {
              Picker(selection: cardKindBinding) {
                ForEach(section.availableCardKinds, id: \.self) { kind in
                  Label(kind.title, systemImage: kind.icon).tag(kind)
                }
              } label: {
                EmptyView()
              }
              .pickerStyle(.inline)
              .labelsHidden()
            } label: {
              Image(systemName: "rectangle.3.group")
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding(.horizontal)
        .padding(.top)
        #if os(macOS)
          .padding(.leading, 16)
        #endif

        ScrollViewReader { proxy in
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: spacing) {
              ForEach(viewModel.pagination.items) { item in
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
              itemIds: viewModel.pagination.items.map(\.id)
            )
          #endif
        }
      }
    }
    .opacity(viewModel.pagination.isEmpty ? 0 : 1)
    .frame(height: viewModel.pagination.isEmpty ? 0 : nil)
    .onReceive(NotificationCenter.default.publisher(for: .dashboardSectionsShouldReload)) {
      notification in
      guard let command = DashboardSectionRefreshNotifier.reloadCommand(from: notification) else {
        return
      }
      handleReloadCommand(command)
    }
    .onChange(of: section.mergesReadListContinuations ? ReadListReadingService.shared.snapshot : nil) {
      _, snapshot in
      viewModel.reloadIfReadListsOutdated(by: snapshot, libraryIds: dashboard.libraryIds)
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
        horizontalCoverWidth: horizontalCoverWidth,
        coverOnly: cardKind == .small,
        cardWidth: itemWidth,
        onItemMissing: {
          viewModel.removeItem(id: itemId)
        }
      )
    case .series:
      SeriesQueryItemView(
        seriesId: itemId,
        layout: .grid,
        coverOnly: cardKind == .small,
        cardWidth: itemWidth,
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

    if command.source == .auto, viewModel.pagination.currentPage > 1 {
      logger.debug(
        "Dashboard section \(section) skipping auto-refresh: deep in pagination (page \(viewModel.pagination.currentPage))"
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
