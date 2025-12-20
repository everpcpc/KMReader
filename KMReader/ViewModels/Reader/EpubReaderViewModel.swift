//
//  EpubReaderViewModel.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import Foundation
  import OSLog
  import Observation
  import ReadiumAdapterGCDWebServer
  import ReadiumNavigator
  import ReadiumShared
  import ReadiumStreamer
  import SwiftUI
  import UIKit
  import WebKit

  @MainActor
  @Observable
  class EpubReaderViewModel: EPUBNavigatorDelegate {
    var isLoading = false
    var errorMessage: String?
    var downloadProgress: Double = 0.0
    var publication: Publication?
    var navigatorViewController: EPUBNavigatorViewController?
    var currentLocator: Locator?
    var tableOfContents: [ReadiumShared.Link] = []
    var preferences: EPUBPreferences = .empty

    private var bookId: String = ""
    private var epubFileURL: URL?
    private let assetRetriever: AssetRetriever
    private let publicationOpener: PublicationOpener
    private let httpServer: HTTPServer
    private var lastUpdateTime: Date = Date()
    private let updateThrottleInterval: TimeInterval = 2.0  // Update at most once every 2 seconds
    private let logger = Logger(
      subsystem: Bundle.main.bundleIdentifier ?? "KMReader", category: "EpubReaderViewModel")

    let incognito: Bool

    init(incognito: Bool) {
      self.incognito = incognito

      // Initialize Readium components
      let httpClient = DefaultHTTPClient()
      self.assetRetriever = AssetRetriever(httpClient: httpClient)

      let parser = DefaultPublicationParser(
        httpClient: httpClient,
        assetRetriever: assetRetriever,
        pdfFactory: DefaultPDFDocumentFactory()
      )
      self.publicationOpener = PublicationOpener(parser: parser)

      // Create HTTP server for serving publication resources
      self.httpServer = GCDHTTPServer(assetRetriever: assetRetriever)
    }

    func load(bookId: String) async {
      if self.bookId != bookId && !self.bookId.isEmpty {
        await BookFileCache.shared.clear(bookId: self.bookId)
      }

      self.bookId = bookId
      isLoading = true
      errorMessage = nil
      downloadProgress = 0.0
      publication = nil
      navigatorViewController = nil

      do {
        // Check if EPUB file is already cached or downloaded
        let epubURL: URL

        // 1. Check OfflineManager
        if let offlineURL = await OfflineManager.shared.getOfflineEpubURL(
          instanceId: AppConfig.currentInstanceId, bookId: bookId
        ) {
          epubURL = offlineURL
        }
        // 2. Check BookFileCache
        else if let cachedURL = await BookFileCache.shared.cachedEpubFileURL(bookId: bookId) {
          epubURL = cachedURL
        } else {
          // Download the entire EPUB file
          epubURL = try await BookFileCache.shared.ensureEpubFile(bookId: bookId) {
            try await BookService.shared.downloadEpubFile(bookId: bookId)
          }
        }

        epubFileURL = epubURL
        downloadProgress = 1.0

        // Retrieve asset from URL using AssetRetriever
        // Convert URL to AbsoluteURL via AnyURL
        guard let absoluteURL = AnyURL(url: epubURL).absoluteURL else {
          throw AppErrorType.invalidFileURL(url: epubURL.absoluteString)
        }
        let asset = try await assetRetriever.retrieve(url: absoluteURL).get()

        // Open publication using PublicationOpener
        let publication = try await publicationOpener.open(
          asset: asset,
          allowUserInteraction: false
        ).get()

        self.publication = publication
        await loadTableOfContents(from: publication)

        // Get progression if not in incognito mode
        var initialLocation: Locator? = nil
        if !incognito {
          if let progression = try? await BookService.shared.getWebPubProgression(bookId: bookId) {
            initialLocation = locatorFromR2Locator(progression.locator, in: publication)
          }
        }

        // Create EPUBNavigatorViewController
        let navigator = try EPUBNavigatorViewController(
          publication: publication,
          initialLocation: initialLocation,
          httpServer: httpServer
        )

        // Set delegate to listen for location changes
        navigator.delegate = self

        self.navigatorViewController = navigator
        navigator.submitPreferences(preferences)

        isLoading = false
      } catch {
        let message = error.localizedDescription
        errorMessage = message
        ErrorManager.shared.alert(error: error)
        isLoading = false
      }
    }

    func retry() async {
      await load(bookId: bookId)
    }

    func goToNextPage() {
      guard let navigator = navigatorViewController else { return }
      Task {
        _ = await navigator.goForward(options: .animated)
      }
    }

    func goToPreviousPage() {
      guard let navigator = navigatorViewController else { return }
      Task {
        _ = await navigator.goBackward(options: .animated)
      }
    }

    func goToChapter(link: ReadiumShared.Link) {
      guard let navigator = navigatorViewController else { return }
      Task {
        _ = await navigator.go(to: link, options: .animated)
      }
    }

    func applyPreferences(_ stored: EpubReaderPreferences, colorScheme: ColorScheme? = nil) {
      preferences = stored.toPreferences(colorScheme: colorScheme)
      navigatorViewController?.submitPreferences(preferences)
    }

    // Convert R2Locator to Readium Locator
    private func locatorFromR2Locator(_ r2Locator: R2Locator, in publication: Publication)
      -> Locator?
    {
      guard let hrefURL = AnyURL(string: r2Locator.href) else {
        return nil
      }

      // Try to find the link in the publication
      let link = publication.linkWithHREF(hrefURL)

      // Use the link's media type if available, otherwise use the type from R2Locator
      let mediaType = link?.mediaType ?? MediaType(r2Locator.type) ?? MediaType.html

      // Use the link's URL if available, otherwise use the href directly
      let href = link?.url() ?? hrefURL

      // Convert R2Locator locations to Readium Locations
      let locations = Locator.Locations(
        fragments: r2Locator.locations?.fragments ?? [],
        progression: r2Locator.locations?.progression.map { Double($0) },
        totalProgression: r2Locator.locations?.totalProgression.map { Double($0) },
        position: r2Locator.locations?.position
      )

      // Convert R2Locator text to Readium Text
      let text = Locator.Text(
        after: r2Locator.text?.after,
        before: r2Locator.text?.before,
        highlight: r2Locator.text?.highlight
      )

      return Locator(
        href: href,
        mediaType: mediaType,
        title: r2Locator.title,
        locations: locations,
        text: text
      )
    }

    // MARK: - NavigatorDelegate

    func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
      // Update current locator for UI display
      currentLocator = locator

      // Only update progression if not in incognito mode
      guard !incognito, !bookId.isEmpty else {
        return
      }

      // Throttle updates to avoid too many API calls
      let now = Date()
      guard now.timeIntervalSince(lastUpdateTime) >= updateThrottleInterval else {
        return
      }
      lastUpdateTime = now

      // Update progression in background
      Task {
        await updateProgression(locator: locator)
      }
    }

    func navigator(_ navigator: Navigator, didJumpTo locator: Locator) {
      // Update current locator for UI display
      currentLocator = locator

      // Also update when jumping to a location
      guard !incognito, !bookId.isEmpty else {
        return
      }

      let now = Date()
      guard now.timeIntervalSince(lastUpdateTime) >= updateThrottleInterval else {
        return
      }
      lastUpdateTime = now

      Task {
        await updateProgression(locator: locator)
      }
    }

    // MARK: - EPUBNavigatorDelegate

    func navigator(
      _ navigator: EPUBNavigatorViewController,
      viewportDidChange viewport: EPUBNavigatorViewController.Viewport?
    ) {
      // Handle viewport changes if needed
    }

    func navigator(
      _ navigator: EPUBNavigatorViewController,
      setupUserScripts userContentController: WKUserContentController
    ) {
      // Setup custom user scripts if needed
    }

    func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
      let message = error.localizedDescription
      errorMessage = message
      ErrorManager.shared.alert(error: error)
    }

    func navigator(_ navigator: Navigator, presentExternalURL url: URL) {
      // Open external URLs in default browser
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      }
    }

    func navigator(
      _ navigator: Navigator, shouldNavigateToNoteAt link: ReadiumShared.Link, content: String,
      referrer: String?
    ) -> Bool {
      // Default behavior: navigate to note
      return true
    }

    func navigator(
      _ navigator: Navigator, didFailToLoadResourceAt href: RelativeURL, withError error: ReadError
    ) {
      // Handle resource loading errors if needed
    }

    // MARK: - Private Methods

    private func updateProgression(locator: Locator) async {
      // Convert Readium Locator to R2Locator
      let r2Locator = r2LocatorFromLocator(locator)

      // Create R2Progression
      let progression = R2Progression(
        modified: Date(),
        device: R2Device(
          id: PlatformHelper.deviceIdentifier,
          name: PlatformHelper.deviceModel
        ),
        locator: r2Locator
      )

      let activeBookId = bookId
      let logger = self.logger

      // Update progression off the main actor to keep navigation responsive
      Task.detached(priority: .utility) {
        do {
          try await BookService.shared.updateWebPubProgression(
            bookId: activeBookId,
            progression: progression
          )
        } catch {
          // Silently fail - progression update is not critical
          logger.error("Failed to update progression: \(error.localizedDescription)")
        }
      }
    }

    // Convert Readium Locator to R2Locator
    private func r2LocatorFromLocator(_ locator: Locator) -> R2Locator {
      let location = R2Locator.Location(
        fragments: locator.locations.fragments.isEmpty ? nil : locator.locations.fragments,
        progression: locator.locations.progression.map { Float($0) },
        position: locator.locations.position,
        totalProgression: locator.locations.totalProgression.map { Float($0) }
      )

      let text = R2Locator.Text(
        after: locator.text.after,
        before: locator.text.before,
        highlight: locator.text.highlight
      )

      return R2Locator(
        href: locator.href.string,
        type: locator.mediaType.string,
        title: locator.title,
        locations: location,
        text: text,
        koboSpan: nil
      )
    }

    private func loadTableOfContents(from publication: Publication) async {
      if let toc = try? await publication.tableOfContents().get() {
        self.tableOfContents = toc
      } else {
        self.tableOfContents = publication.readingOrder
      }
    }
  }
#endif
