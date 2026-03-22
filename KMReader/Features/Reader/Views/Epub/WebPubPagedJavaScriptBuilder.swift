#if os(iOS) || os(macOS)
  import Foundation

  enum WebPubPagedJavaScriptBuilder {
    static func makeInjectCSSScript(
      contentCSS: String,
      readiumProperties: [String: String?],
      readiumPropertyKeys: [String],
      language: String?,
      readingProgression: WebPubReadingProgression?
    ) -> String {
      let readiumAssets = ReadiumCSSLoader.cssAssets(
        language: language,
        readingProgression: readingProgression
      )
      let readiumVariant = ReadiumCSSLoader.resolveVariantSubdirectory(
        language: language,
        readingProgression: readingProgression
      )
      let shouldSetDir = readiumVariant == "rtl"

      let readiumBefore = Data(readiumAssets.before.utf8).base64EncodedString()
      let readiumDefault = Data(readiumAssets.defaultCSS.utf8).base64EncodedString()
      let readiumAfter = Data(readiumAssets.after.utf8).base64EncodedString()
      let customCSS = Data(contentCSS.utf8).base64EncodedString()

      var properties: [String: Any] = [:]
      for (key, value) in readiumProperties {
        properties[key] = value ?? NSNull()
      }
      let propertiesJSON = WebPubJavaScriptSupport.encodeJSON(properties, fallback: "{}")
      let propertyKeysJSON = WebPubJavaScriptSupport.encodeJSON(
        readiumPropertyKeys,
        fallback: "[]"
      )
      let languageJSON = WebPubJavaScriptSupport.escapedJSONString(language)
      return """
        (function() {
          var root = document.documentElement;
          var lang = \(languageJSON);
          if (lang) {
            if (!root.hasAttribute('lang')) { root.setAttribute('lang', lang); }
            if (!root.hasAttribute('xml:lang')) { root.setAttribute('xml:lang', lang); }
            if (document.body) {
              if (!document.body.hasAttribute('lang')) { document.body.setAttribute('lang', lang); }
              if (!document.body.hasAttribute('xml:lang')) { document.body.setAttribute('xml:lang', lang); }
            }
          }
          if (\(shouldSetDir ? "true" : "false")) {
            root.setAttribute('dir', 'rtl');
            if (document.body) { document.body.setAttribute('dir', 'rtl'); }
          }

          var props = \(propertiesJSON);
          Object.keys(props).forEach(function(key) {
            var value = props[key];
            if (value === null || value === undefined) {
              root.style.removeProperty(key);
            } else {
              root.style.setProperty(key, value, 'important');
            }
          });
          var knownKeys = \(propertyKeysJSON);
          knownKeys.forEach(function(key) {
            if (!(key in props)) {
              root.style.removeProperty(key);
            }
          });

          var meta = document.querySelector('meta[name=viewport]');
          if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'viewport';
            document.head.appendChild(meta);
          }
          meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');

          var style = document.getElementById('kmreader-style');
          if (!style) {
            style = document.createElement('style');
            style.id = 'kmreader-style';
            document.head.appendChild(style);
          }
          var hasStyles = document.querySelector("link[rel~='stylesheet'], style:not(#kmreader-style)") !== null;
          var css = atob('\(readiumBefore)') + "\\n"
            + (hasStyles ? "" : atob('\(readiumDefault)') + "\\n")
            + atob('\(readiumAfter)') + "\\n"
            + atob('\(customCSS)');
          style.textContent = css;

          return true;
        })();
        """
    }

    static func makePaginationScript(
      targetPageIndex: Int,
      preferLastPage: Bool,
      waitForLoadEvents: Bool
    ) -> String {
      """
      (function() {
        var target = \(targetPageIndex);
        var preferLast = \(preferLastPage ? "true" : "false");
        var lastReportedPageCount = 0;
        var hasFinalized = false;

        var finalize = function() {
          if (hasFinalized) return;
          hasFinalized = true;

          var root = document.documentElement;
          var pageWidth = root.clientWidth || window.innerWidth;
          if (!pageWidth || pageWidth <= 0) { pageWidth = 1; }

          var currentWidth = Math.max(
            root.scrollWidth || 0,
            document.body ? (document.body.scrollWidth || 0) : 0,
            pageWidth
          );
          var total = Math.max(1, Math.ceil(currentWidth / pageWidth));
          var maxScroll = Math.max(0, currentWidth - pageWidth);
          var finalTarget = preferLast ? (total - 1) : Math.max(0, Math.min(total - 1, target));
          var offset = Math.min(pageWidth * finalTarget, maxScroll);

          window.scrollTo(offset, 0);
          if (document.documentElement) { document.documentElement.scrollLeft = offset; }
          if (document.body) { document.body.scrollLeft = offset; }

          lastReportedPageCount = total;

          setTimeout(function() {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.readerBridge) {
              window.webkit.messageHandlers.readerBridge.postMessage({
                type: 'ready',
                totalPages: total,
                currentPage: finalTarget
              });
            }
          }, 60);
        };

        var startLayoutCheck = function() {
          var root = document.documentElement;
          var lastW = root.scrollWidth || document.body.scrollWidth;
          var stableCount = 0;
          var attempt = 0;

          var check = function() {
            if (hasFinalized) return;

            attempt++;
            var currentW = root.scrollWidth || document.body.scrollWidth;
            var pageWidth = root.clientWidth || window.innerWidth;
            if (!pageWidth || pageWidth <= 0) { pageWidth = 1; }

            if (currentW === lastW && currentW > 0) {
              stableCount++;
            } else {
              stableCount = 0;
              lastW = currentW;
            }

            var isProbablyReady = (stableCount >= 4);
            if ((preferLast || target > 0) && currentW <= pageWidth && attempt < 40) {
              isProbablyReady = false;
            }

            if (isProbablyReady || attempt >= 60) {
              finalize();
            } else {
              window.requestAnimationFrame(check);
            }
          };
          window.requestAnimationFrame(check);
        };

        var globalTimeout = setTimeout(function() {
          finalize();
        }, 10000);

        var loadStarted = false;
        var startOnce = function() {
          if (loadStarted) return;
          loadStarted = true;
          clearTimeout(globalTimeout);
          startLayoutCheck();
        };

        if (!\(waitForLoadEvents ? "true" : "false")) {
          startOnce();
          return;
        }

        if (document.readyState === 'complete') {
          startOnce();
        } else {
          if (document.readyState === 'interactive' || document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', function() {
              setTimeout(startOnce, 500);
            });
          }
          window.addEventListener('load', function() {
            startOnce();
          });
        }
      })();
      """
    }
  }
#endif
