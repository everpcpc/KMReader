//
//  SettingsDashboardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsDashboardView: View {
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()

  #if os(tvOS)
    @State private var isEditMode = false
    @State private var movingSection: DashboardSection?
    @FocusState private var focusedHandle: DashboardSection?
  #endif

  private func isSectionVisible(_ section: DashboardSection) -> Bool {
    return dashboard.sections.contains(section)
  }

  private func hideSection(_ section: DashboardSection) {
    if let index = dashboard.sections.firstIndex(of: section) {
      var newSections = dashboard.sections
      newSections.remove(at: index)
      dashboard = DashboardConfiguration(sections: newSections, libraryIds: dashboard.libraryIds)
    }
  }

  private func showSection(_ section: DashboardSection) {
    if !dashboard.sections.contains(section) {
      var newSections = dashboard.sections
      // Add at the end or find a good position based on allCases order
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
      dashboard = DashboardConfiguration(sections: newSections, libraryIds: dashboard.libraryIds)
    }
  }

  private func moveSections(from source: IndexSet, to destination: Int) {
    var newSections = dashboard.sections
    newSections.move(fromOffsets: source, toOffset: destination)
    dashboard = DashboardConfiguration(sections: newSections)
  }

  #if os(tvOS)
    private func moveSectionUp(_ section: DashboardSection) {
      guard let index = dashboard.sections.firstIndex(of: section),
        index > 0
      else { return }
      var newSections = dashboard.sections
      newSections.swapAt(index, index - 1)
      dashboard = DashboardConfiguration(sections: newSections, libraryIds: dashboard.libraryIds)
    }

    private func moveSectionDown(_ section: DashboardSection) {
      guard let index = dashboard.sections.firstIndex(of: section),
        index < dashboard.sections.count - 1
      else { return }
      var newSections = dashboard.sections
      newSections.swapAt(index, index + 1)
      dashboard = DashboardConfiguration(sections: newSections, libraryIds: dashboard.libraryIds)
    }
  #endif

  private var hiddenSections: [DashboardSection] {
    DashboardSection.allCases.filter { !isSectionVisible($0) }
  }

  private func sectionToggleBinding(for section: DashboardSection) -> Binding<Bool> {
    Binding(
      get: { isSectionVisible(section) },
      set: { _ in
        withAnimation {
          if isSectionVisible(section) {
            hideSection(section)
          } else {
            showSection(section)
          }
        }
      }
    )
  }

  private func hiddenSectionToggleBinding(for section: DashboardSection) -> Binding<Bool> {
    Binding(
      get: { isSectionVisible(section) },
      set: { _ in
        withAnimation {
          showSection(section)
        }
      }
    )
  }

  var body: some View {
    Form {
      #if os(tvOS)
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
          .buttonStyle(.plain)
        }
      #endif

      Section(header: Text("Dashboard Sections")) {
        ForEach(dashboard.sections) { section in
          HStack {
            #if os(tvOS)
              Text(section.displayName)
                .font(.headline)
            #else
              Label(section.displayName, systemImage: section.icon)
            #endif
            Spacer()
            #if os(tvOS)
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
                .buttonStyle(.plain)
                .focused($focusedHandle, equals: section)

                if isEditMode {
                  Button {
                    if movingSection == section {
                      movingSection = nil
                      focusedHandle = nil
                    }
                    withAnimation {
                      hideSection(section)
                    }
                  } label: {
                    Image(systemName: "minus.circle.fill")
                  }
                  .buttonStyle(.plain)
                }
              }
              .padding(.horizontal, 18)
            #else
              Toggle("", isOn: sectionToggleBinding(for: section))
            #endif
          }
          #if os(tvOS)
            .listRowBackground(
              Capsule()
                .fill(PlatformHelper.secondarySystemBackgroundColor)
                .opacity(movingSection == section ? 0.5 : 0))
          #endif
        }
        #if os(tvOS)
          .onMoveCommand { direction in
            guard let movingSection = movingSection else { return }
            // force focus on the moving section
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
        #else
          .onMove(perform: moveSections)
        #endif
      }

      #if os(tvOS)
        if isEditMode && !hiddenSections.isEmpty {
          Section(header: Text("Hidden Sections")) {
            ForEach(hiddenSections) { section in
              HStack {
                Text(section.displayName)
                  .font(.headline)
                Spacer()
                Button {
                  withAnimation {
                    showSection(section)
                  }
                } label: {
                  Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
              }
              .padding(.vertical, 8)
            }
          }
        }
      #else
        if !hiddenSections.isEmpty {
          Section(header: Text("Hidden Sections")) {
            ForEach(hiddenSections) { section in
              HStack {
                Label {
                  Text(section.displayName)
                } icon: {
                  Image(systemName: section.icon)
                }
                Spacer()
                Toggle("", isOn: hiddenSectionToggleBinding(for: section))
              }
            }
          }
        }
      #endif

      Section {
        Button {
          // Reset to default
          #if os(tvOS)
            movingSection = nil
            focusedHandle = nil
          #endif
          withAnimation {
            dashboard = DashboardConfiguration(
              sections: DashboardSection.allCases, libraryIds: dashboard.libraryIds)
          }
        } label: {
          HStack {
            Spacer()
            Text("Reset to Default")
            Spacer()
          }
        }
      }
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle("Dashboard")
    .animation(.default, value: dashboard)
    #if os(tvOS)
      .onAppear {
        movingSection = nil
        focusedHandle = nil
      }
    #endif
  }

}
