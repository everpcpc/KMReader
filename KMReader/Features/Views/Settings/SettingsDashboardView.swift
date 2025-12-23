//
//  SettingsDashboardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsDashboardView: View {
  var body: some View {
    #if os(tvOS)
      SettingsDashboardView_tvOS()
    #elseif os(macOS)
      SettingsDashboardView_macOS()
    #else
      SettingsDashboardView_iOS()
    #endif
  }
}

#if os(iOS)
  private struct SettingsDashboardView_iOS: View {
    @AppStorage("dashboard") private var dashboard: DashboardConfiguration =
      DashboardConfiguration()
    private var controller: DashboardSectionsController {
      DashboardSectionsController(dashboard: $dashboard)
    }

    var body: some View {
      List {
        Section(header: Text(String(localized: "dashboard.sections"))) {
          ForEach(controller.sections) { section in
            HStack {
              Label(section.displayName, systemImage: section.icon)
              Spacer()
              Toggle("", isOn: controller.sectionToggleBinding(for: section))
            }
          }
          .onMove(perform: controller.moveSections)
          #if os(iOS)
            .environment(\.editMode, .constant(.active))
          #endif
        }

        if !controller.hiddenSections.isEmpty {
          Section(header: Text(String(localized: "dashboard.hiddenSections"))) {
            ForEach(controller.hiddenSections) { section in
              HStack {
                Label(section.displayName, systemImage: section.icon)
                Spacer()
                Toggle("", isOn: controller.hiddenSectionToggleBinding(for: section))
              }
            }
          }
        }

        Section {
          Button {
            withAnimation {
              controller.resetSections()
            }
          } label: {
            HStack {
              Spacer()
              Text(String(localized: "dashboard.reset"))
              Spacer()
            }
          }
        }
      }
      .optimizedListStyle()
      .inlineNavigationBarTitle(SettingsSection.dashboard.title)
      .animation(.default, value: dashboard)
    }
  }
#elseif os(macOS)
  private struct SettingsDashboardView_macOS: View {
    @AppStorage("dashboard") private var dashboard: DashboardConfiguration =
      DashboardConfiguration()
    private var controller: DashboardSectionsController {
      DashboardSectionsController(dashboard: $dashboard)
    }

    var body: some View {
      Form {
        Section(header: Text(String(localized: "dashboard.sections"))) {
          List {
            ForEach(controller.sections) { section in
              HStack {
                Label(section.displayName, systemImage: section.icon)
                Spacer()
                Toggle("", isOn: controller.sectionToggleBinding(for: section))
              }
            }
            .onMove(perform: controller.moveSections)
          }
          .listStyle(.inset(alternatesRowBackgrounds: true))
          .scrollDisabled(true)
        }

        if !controller.hiddenSections.isEmpty {
          Section(header: Text(String(localized: "dashboard.hiddenSections"))) {
            ForEach(controller.hiddenSections) { section in
              HStack {
                Label(section.displayName, systemImage: section.icon)
                Spacer()
                Toggle("", isOn: controller.hiddenSectionToggleBinding(for: section))
              }
            }
          }
        }

        Section {
          Button {
            withAnimation {
              controller.resetSections()
            }
          } label: {
            HStack {
              Spacer()
              Text(String(localized: "dashboard.reset"))
              Spacer()
            }
          }
        }
      }
      .formStyle(.grouped)
      .inlineNavigationBarTitle(SettingsSection.dashboard.title)
      .animation(.default, value: dashboard)
    }
  }
#elseif os(tvOS)
  private struct SettingsDashboardView_tvOS: View {
    @AppStorage("dashboard") private var dashboard: DashboardConfiguration =
      DashboardConfiguration()
    private var controller: DashboardSectionsController {
      DashboardSectionsController(dashboard: $dashboard)
    }

    @State private var isEditMode = false
    @State private var movingSection: DashboardSection?
    @FocusState private var focusedHandle: DashboardSection?

    var body: some View {
      Form {
        HStack {
          Spacer()
          Button {
            isEditMode.toggle()
            if !isEditMode {
              movingSection = nil
              focusedHandle = nil
            }
          } label: {
            Text(isEditMode ? "Done" : "Edit")
          }
          .adaptiveButtonStyle(.borderedProminent)
        }
        .listRowBackground(Color.clear)

        Section(header: Text(String(localized: "dashboard.sections"))) {
          ForEach(controller.sections) { section in
            HStack {
              Text(section.displayName)
                .font(.headline)
              Spacer()
              HStack(spacing: 18) {
                Button {
                  if movingSection == section {
                    movingSection = nil
                    focusedHandle = nil
                  } else {
                    movingSection = section
                    focusedHandle = section
                  }
                } label: {
                  Image(systemName: "line.3.horizontal")
                }
                .adaptiveButtonStyle(.plain)
                .focused($focusedHandle, equals: section)

                if isEditMode {
                  Button {
                    if movingSection == section {
                      movingSection = nil
                      focusedHandle = nil
                    }
                    withAnimation {
                      controller.hideSection(section)
                    }
                  } label: {
                    Image(systemName: "minus.circle.fill")
                  }
                  .adaptiveButtonStyle(.plain)
                }
              }
              .padding(.horizontal, 18)
            }
            .listRowBackground(
              Capsule()
                .fill(PlatformHelper.secondarySystemBackgroundColor)
                .opacity(movingSection == section ? 0.5 : 0))
          }
          .onMoveCommand { direction in
            guard let movingSection = movingSection else { return }
            if let focus = focusedHandle, focus != movingSection {
              focusedHandle = movingSection
            }
            withAnimation {
              switch direction {
              case .up:
                moveSectionUp(movingSection)
              case .down:
                moveSectionDown(movingSection)
              default:
                break
              }
            }
          }
        }

        if isEditMode && !controller.hiddenSections.isEmpty {
          Section(header: Text(String(localized: "dashboard.hiddenSections"))) {
            ForEach(controller.hiddenSections) { section in
              HStack {
                Text(section.displayName)
                  .font(.headline)
                Spacer()
                Button {
                  withAnimation {
                    controller.showSection(section)
                  }
                } label: {
                  Image(systemName: "plus.circle")
                }
                .adaptiveButtonStyle(.plain)
              }
              .padding(.vertical, 8)
            }
          }
        }

        Section {
          Button {
            movingSection = nil
            focusedHandle = nil
            withAnimation {
              controller.resetSections()
            }
          } label: {
            HStack {
              Spacer()
              Text(String(localized: "dashboard.reset"))
              Spacer()
            }
          }
        }
      }
      .formStyle(.grouped)
      .inlineNavigationBarTitle(SettingsSection.dashboard.title)
      .animation(.default, value: dashboard)
      .onAppear {
        movingSection = nil
        focusedHandle = nil
      }
    }

    private func moveSectionUp(_ section: DashboardSection) {
      var currentSections = controller.sections
      guard let index = currentSections.firstIndex(of: section), index > 0 else { return }
      currentSections.swapAt(index, index - 1)
      controller.setSections(currentSections)
    }

    private func moveSectionDown(_ section: DashboardSection) {
      var currentSections = controller.sections
      guard let index = currentSections.firstIndex(of: section),
        index < currentSections.count - 1
      else { return }
      currentSections.swapAt(index, index + 1)
      controller.setSections(currentSections)
    }
  }
#endif

private struct DashboardSectionsController {
  var dashboard: Binding<DashboardConfiguration>

  var sections: [DashboardSection] {
    dashboard.wrappedValue.sections
  }

  var hiddenSections: [DashboardSection] {
    DashboardSection.allCases.filter { !isSectionVisible($0) }
  }

  private var libraryIds: [String] {
    dashboard.wrappedValue.libraryIds
  }

  private func updateSections(_ newSections: [DashboardSection]) {
    dashboard.wrappedValue = DashboardConfiguration(
      sections: newSections,
      libraryIds: libraryIds
    )
  }

  func isSectionVisible(_ section: DashboardSection) -> Bool {
    sections.contains(section)
  }

  func hideSection(_ section: DashboardSection) {
    guard let index = sections.firstIndex(of: section) else { return }
    var newSections = sections
    newSections.remove(at: index)
    updateSections(newSections)
  }

  func showSection(_ section: DashboardSection) {
    guard !isSectionVisible(section) else { return }
    var newSections = sections
    if let referenceIndex = DashboardSection.allCases.firstIndex(of: section) {
      var insertIndex = newSections.count
      for (idx, existingSection) in newSections.enumerated() {
        if let existingIndex = DashboardSection.allCases.firstIndex(of: existingSection),
          existingIndex > referenceIndex
        {
          insertIndex = idx
          break
        }
      }
      newSections.insert(section, at: insertIndex)
    } else {
      newSections.append(section)
    }
    updateSections(newSections)
  }

  func moveSections(_ source: IndexSet, _ destination: Int) {
    var newSections = sections
    newSections.move(fromOffsets: source, toOffset: destination)
    updateSections(newSections)
  }

  func setSections(_ newSections: [DashboardSection]) {
    updateSections(newSections)
  }

  func resetSections() {
    updateSections(DashboardSection.allCases)
  }

  func sectionToggleBinding(for section: DashboardSection) -> Binding<Bool> {
    Binding(
      get: { isSectionVisible(section) },
      set: { newValue in
        withAnimation {
          if newValue {
            showSection(section)
          } else {
            hideSection(section)
          }
        }
      }
    )
  }

  func hiddenSectionToggleBinding(for section: DashboardSection) -> Binding<Bool> {
    Binding(
      get: { isSectionVisible(section) },
      set: { _ in
        withAnimation {
          showSection(section)
        }
      }
    )
  }

}
