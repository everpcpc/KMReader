//
//  LibraryAddSheet.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct LibraryAddSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var libraryCreation = LibraryCreation.createDefault()
  @State private var isCreating = false
  @State private var showDirectoryBrowser = false
  @State private var selectedTab = 0

  // For directory exclusions input
  @State private var newExclusion = ""

  private var isValid: Bool {
    !libraryCreation.name.isEmpty && !libraryCreation.root.isEmpty
  }

  var body: some View {
    SheetView(
      title: String(localized: "library.add.title", defaultValue: "Add Library"),
      size: .large,
      applyFormStyle: true
    ) {
      Form {
        #if os(tvOS)
          generalSection
          scannerSection
          optionsSection
          metadataSection
        #else
          Picker("", selection: $selectedTab) {
            Text(String(localized: "library.add.tab.general", defaultValue: "General")).tag(0)
            Text(String(localized: "library.add.tab.scanner", defaultValue: "Scanner")).tag(1)
            Text(String(localized: "library.add.tab.options", defaultValue: "Options")).tag(2)
            Text(String(localized: "library.add.tab.metadata", defaultValue: "Metadata")).tag(3)
          }
          .pickerStyle(.segmented)
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets())

          switch selectedTab {
          case 0: generalSection
          case 1: scannerSection
          case 2: optionsSection
          case 3: metadataSection
          default: EmptyView()
          }
        #endif
      }
    } controls: {
      Button(action: createLibrary) {
        if isCreating {
          LoadingIcon()
        } else {
          Label(String(localized: "Create"), systemImage: "plus")
        }
      }
      .disabled(isCreating || !isValid)
    }
    .sheet(isPresented: $showDirectoryBrowser) {
      DirectoryBrowserSheet(selectedPath: $libraryCreation.root)
    }
  }

  // MARK: - General Section

  private var generalSection: some View {
    Section(header: Text(String(localized: "library.add.section.general", defaultValue: "General"))) {
      TextField(
        String(localized: "library.add.field.name", defaultValue: "Name"),
        text: $libraryCreation.name
      )

      HStack {
        TextField(
          String(localized: "library.add.field.root", defaultValue: "Root Folder"),
          text: $libraryCreation.root
        )
        #if !os(tvOS)
          Button {
            showDirectoryBrowser = true
          } label: {
            Image(systemName: "folder")
          }
        #endif
      }
    }
  }

  // MARK: - Scanner Section

  private var scannerSection: some View {
    Section(header: Text(String(localized: "library.add.section.scanner", defaultValue: "Scanner"))) {
      Toggle(
        String(
          localized: "library.add.field.emptyTrashAfterScan", defaultValue: "Empty trash after scan"
        ),
        isOn: $libraryCreation.emptyTrashAfterScan
      )

      Toggle(
        String(
          localized: "library.add.field.scanForceModifiedTime",
          defaultValue: "Force directory modified time"),
        isOn: $libraryCreation.scanForceModifiedTime
      )

      Toggle(
        String(localized: "library.add.field.scanOnStartup", defaultValue: "Scan on startup"),
        isOn: $libraryCreation.scanOnStartup
      )

      Picker(
        String(localized: "library.add.field.scanInterval", defaultValue: "Scan interval"),
        selection: $libraryCreation.scanInterval
      ) {
        ForEach(ScanInterval.allCases) { interval in
          Text(interval.localizedName).tag(interval)
        }
      }

      // Scan types
      Group {
        Toggle("CBX", isOn: $libraryCreation.scanCbx)
        Toggle("PDF", isOn: $libraryCreation.scanPdf)
        Toggle("EPUB", isOn: $libraryCreation.scanEpub)
      }

      TextField(
        String(
          localized: "library.add.field.oneshotsDirectory", defaultValue: "Oneshots directory"),
        text: $libraryCreation.oneshotsDirectory
      )

      // Directory exclusions
      VStack(alignment: .leading, spacing: 8) {
        Text(
          String(localized: "library.add.field.exclusions", defaultValue: "Directory exclusions")
        )
        .font(.subheadline)
        .foregroundColor(.secondary)

        ForEach(libraryCreation.scanDirectoryExclusions, id: \.self) { exclusion in
          HStack {
            Text(exclusion)
            Spacer()
            Button {
              libraryCreation.scanDirectoryExclusions.removeAll { $0 == exclusion }
            } label: {
              Image(systemName: "minus.circle.fill")
                .foregroundColor(.red)
            }
            .buttonStyle(.plain)
          }
        }

        HStack {
          TextField(
            String(localized: "library.add.field.newExclusion", defaultValue: "Add exclusion"),
            text: $newExclusion
          )
          Button {
            guard !newExclusion.isEmpty else { return }
            libraryCreation.scanDirectoryExclusions.append(newExclusion)
            newExclusion = ""
          } label: {
            Image(systemName: "plus.circle.fill")
              .foregroundColor(.green)
          }
          .buttonStyle(.plain)
          .disabled(newExclusion.isEmpty)
        }
      }
    }
  }

  // MARK: - Options Section

  private var optionsSection: some View {
    Section(header: Text(String(localized: "library.add.section.options", defaultValue: "Options"))) {
      Group {
        Text(String(localized: "library.add.subsection.analysis", defaultValue: "Analysis"))
          .font(.subheadline)
          .foregroundColor(.secondary)

        Toggle(
          String(localized: "library.add.field.hashFiles", defaultValue: "Hash files"),
          isOn: $libraryCreation.hashFiles
        )

        Toggle(
          String(localized: "library.add.field.hashPages", defaultValue: "Hash pages"),
          isOn: $libraryCreation.hashPages
        )

        Toggle(
          String(localized: "library.add.field.hashKoreader", defaultValue: "Hash KOReader"),
          isOn: $libraryCreation.hashKoreader
        )

        Toggle(
          String(
            localized: "library.add.field.analyzeDimensions", defaultValue: "Analyze dimensions"),
          isOn: $libraryCreation.analyzeDimensions
        )
      }

      Group {
        Text(
          String(
            localized: "library.add.subsection.fileManagement", defaultValue: "File Management")
        )
        .font(.subheadline)
        .foregroundColor(.secondary)

        Toggle(
          String(
            localized: "library.add.field.repairExtensions", defaultValue: "Repair extensions"),
          isOn: $libraryCreation.repairExtensions
        )

        Toggle(
          String(localized: "library.add.field.convertToCbz", defaultValue: "Convert to CBZ"),
          isOn: $libraryCreation.convertToCbz
        )
      }

      Picker(
        String(localized: "library.add.field.seriesCover", defaultValue: "Series cover"),
        selection: $libraryCreation.seriesCover
      ) {
        ForEach(SeriesCoverMode.allCases) { mode in
          Text(mode.localizedName).tag(mode)
        }
      }
    }
  }

  // MARK: - Metadata Section

  private var metadataSection: some View {
    Section(
      header: Text(String(localized: "library.add.section.metadata", defaultValue: "Metadata"))
    ) {
      Group {
        Text(String(localized: "library.add.subsection.comicinfo", defaultValue: "ComicInfo"))
          .font(.subheadline)
          .foregroundColor(.secondary)

        Toggle(
          String(
            localized: "library.add.field.importComicInfoBook", defaultValue: "Import book metadata"
          ),
          isOn: $libraryCreation.importComicInfoBook
        )

        Toggle(
          String(
            localized: "library.add.field.importComicInfoSeries",
            defaultValue: "Import series metadata"),
          isOn: $libraryCreation.importComicInfoSeries
        )

        Toggle(
          String(
            localized: "library.add.field.importComicInfoSeriesAppendVolume",
            defaultValue: "Append volume to series"),
          isOn: $libraryCreation.importComicInfoSeriesAppendVolume
        )

        Toggle(
          String(
            localized: "library.add.field.importComicInfoCollection",
            defaultValue: "Import collections"),
          isOn: $libraryCreation.importComicInfoCollection
        )

        Toggle(
          String(
            localized: "library.add.field.importComicInfoReadList",
            defaultValue: "Import read lists"),
          isOn: $libraryCreation.importComicInfoReadList
        )
      }

      Group {
        Text(String(localized: "library.add.subsection.epub", defaultValue: "EPUB"))
          .font(.subheadline)
          .foregroundColor(.secondary)

        Toggle(
          String(
            localized: "library.add.field.importEpubBook", defaultValue: "Import book metadata"),
          isOn: $libraryCreation.importEpubBook
        )

        Toggle(
          String(
            localized: "library.add.field.importEpubSeries", defaultValue: "Import series metadata"),
          isOn: $libraryCreation.importEpubSeries
        )
      }

      Group {
        Text(String(localized: "library.add.subsection.other", defaultValue: "Other"))
          .font(.subheadline)
          .foregroundColor(.secondary)

        Toggle(
          String(
            localized: "library.add.field.importMylarSeries", defaultValue: "Import Mylar series"),
          isOn: $libraryCreation.importMylarSeries
        )

        Toggle(
          String(
            localized: "library.add.field.importLocalArtwork", defaultValue: "Import local artwork"),
          isOn: $libraryCreation.importLocalArtwork
        )

        Toggle(
          String(
            localized: "library.add.field.importBarcodeIsbn", defaultValue: "Import barcode ISBN"),
          isOn: $libraryCreation.importBarcodeIsbn
        )
      }
    }
  }

  // MARK: - Actions

  private func createLibrary() {
    isCreating = true
    Task {
      do {
        _ = try await LibraryService.shared.createLibrary(libraryCreation)
        await LibraryManager.shared.refreshLibraries()
        ErrorManager.shared.notify(
          message: String(
            localized: "notification.library.created", defaultValue: "Library created")
        )
        dismiss()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
      isCreating = false
    }
  }
}
