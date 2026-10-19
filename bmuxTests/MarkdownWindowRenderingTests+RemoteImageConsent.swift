import AppKit
import Testing
import WebKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

extension MarkdownWindowRenderingTests {
    @Test
    func blocksRemoteImagesUntilUserAction() async throws {
        let markdownURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-markdown-remote-image-\(UUID().uuidString).md")

        let frame = NSRect(x: 0, y: 0, width: 420, height: 260)
        let configuration = WKWebViewConfiguration()
        let coordinator = MarkdownWebRenderer.Coordinator()
        let remoteImageHandler = MarkdownRemoteImageHoldingSchemeHandler()
        coordinator.filePath = markdownURL.path
        configuration.setURLSchemeHandler(coordinator, forURLScheme: MarkdownWebRenderer.localImageURLScheme)
        configuration.setURLSchemeHandler(remoteImageHandler, forURLScheme: MarkdownWebRenderer.remoteImageURLScheme)
        let webView = MarkdownWebView(frame: frame, configuration: configuration)
        coordinator.webView = webView
        let fixture = MarkdownRenderTestFixture(webView: webView)
        defer {
            coordinator.webView = nil
            coordinator.cancelImageLoads()
            remoteImageHandler.cancelOpenTasks()
            fixture.close()
        }

        try await fixture.loadShell(baseURL: markdownURL)

        let expectedBlockedTitle = String(
            localized: "markdown.web.remoteImageBlocked",
            defaultValue: "Remote image blocked"
        )
        let expectedConsentMessage = String(
            localized: "markdown.web.remoteImageConsentMessage",
            defaultValue: "bmux will not contact this image URL until you load this image."
        )
        let expectedLoadButton = String(
            localized: "markdown.web.remoteImageLoadImage",
            defaultValue: "Load this image"
        )
        let expectedLoadingButton = String(
            localized: "markdown.web.remoteImageLoading",
            defaultValue: "Loading"
        )
        let expectedCopyURLButton = String(
            localized: "markdown.web.remoteImageCopyURL",
            defaultValue: "Copy image URL"
        )
        let expectedCopiedButton = String(
            localized: "markdown.web.remoteImageCopied",
            defaultValue: "Copied"
        )
        let expectedOpenURLButton = String(
            localized: "markdown.web.remoteImageOpenURL",
            defaultValue: "Open image URL"
        )
        let expectedHTTPSOnlyMessage = String(
            localized: "markdown.web.remoteImageHTTPSOnly",
            defaultValue: "Only HTTPS remote images can be loaded in the viewer."
        )
        let expectedNotAllowedMessage = String(
            localized: "markdown.web.remoteImageNotAllowed",
            defaultValue: "This remote image URL cannot be loaded in the viewer."
        )
        func expectedURLText(_ url: String) -> String {
            String(
                localized: "markdown.web.remoteImageURL",
                defaultValue: "Image URL: {url}"
            ).replacingOccurrences(of: "{url}", with: url)
        }

        try await fixture.renderMarkdown(
            """
            Inline markdown file marker: `README.md`

            ```
            README.md
            ```

            <style>body { background-image: url(https://images.example.com/style.png); }</style>

            <table background="https://images.example.com/background.png"><tr><td background="https://images.example.com/cell.png">legacy background</td></tr></table>

            <details><summary>Visible details summary</summary>Hidden details text</details>

            ![HTTPS remote](https://images.example.com/pixel.png)
            [![Linked remote](https://images.example.com/linked.png)](README.md)
            ![Duplicate linked remote](https://images.example.com/linked.png)
            ![HTTP remote](http://images.example.com/pixel.png)
            ![Localhost remote](https://localhost/pixel.png)
            ![Credential remote](https://user:pass@images.example.com/secret.png)
            <img alt="Expanded IPv6 mapped remote" src="https://[0:0:0:0:0:ffff:7f00:1]/image.png">
            <img alt="Spoofed internal" data-bmux-remote-src="https%3A%2F%2Fspoof.example%2Fpixel.png">
            """
        )

        let before = try await fixture.remoteImageSnapshot()
        let beforeImages = try #require(before["images"] as? [[String: Any]])
        let beforePlaceholders = try #require(before["placeholders"] as? [String])
        let beforeURLs = try #require(before["remoteImageURLs"] as? [String])
        let beforeButtons = try #require(before["buttons"] as? [String])
        let beforeCodeFiles = try #require(before["codeFiles"] as? [String])
        let beforeStyleCount = try #require(before["styleCount"] as? Int)
        let beforeBackgroundAttrCount = try #require(before["backgroundAttrCount"] as? Int)
        let beforeRenderedText = try #require(before["renderedText"] as? String)
        #expect((beforeImages.count) == (8))
        #expect((beforePlaceholders.count) == (7))
        #expect((beforeURLs.count) == (7))
        #expect(beforeURLs.contains(expectedURLText("https://images.example.com/pixel.png")))
        #expect((beforeURLs.filter { $0 == expectedURLText("https://images.example.com/linked.png") }.count) == (2))
        #expect(beforeURLs.contains(expectedURLText("http://images.example.com/pixel.png")))
        #expect(beforeURLs.contains(expectedURLText("https://localhost/pixel.png")))
        #expect(beforeURLs.contains(expectedURLText("https://user:pass@images.example.com/secret.png")))
        #expect(beforeURLs.contains(expectedURLText("https://[::ffff:7f00:1]/image.png")))
        #expect((beforeButtons.filter { $0 == expectedLoadButton }.count) == (3))
        #expect((beforeButtons.filter { $0 == expectedCopyURLButton }.count) == (7))
        #expect((beforeButtons.filter { $0 == expectedOpenURLButton }.count) == (7))
        #expect((beforeCodeFiles) == (["README.md"]))
        #expect((beforeStyleCount) == (0))
        #expect((beforeBackgroundAttrCount) == (0))
        #expect(!(beforeRenderedText.contains(expectedBlockedTitle)))
        #expect(!(beforeRenderedText.contains(expectedLoadButton)))
        #expect(!(beforeRenderedText.contains(expectedCopyURLButton)))
        #expect(!(beforeRenderedText.contains(expectedOpenURLButton)))
        #expect(beforeRenderedText.contains("Visible details summary"))
        #expect(!(beforeRenderedText.contains("Hidden details text")))
        let remoteManagedImages = beforeImages.filter { !((($0["remoteSrc"] as? String) ?? "").isEmpty) }
        #expect((remoteManagedImages.count) == (7))
        for image in remoteManagedImages {
            #expect((image["src"] as? String) == (""))
            #expect((image["currentSrc"] as? String) == (""))
            #expect((image["hidden"] as? Bool) == (true))
            #expect(image["remoteSrc"] as? String != nil)
        }
        let spoofedImage = try #require(beforeImages.first { $0["alt"] as? String == "Spoofed internal" })
        #expect((spoofedImage["remoteSrc"] as? String) == (""))
        #expect((spoofedImage["hidden"] as? Bool) == (false))
        #expect(beforePlaceholders.contains { $0.contains(expectedConsentMessage) })
        #expect(beforePlaceholders.contains { $0.contains(expectedHTTPSOnlyMessage) })
        #expect(beforePlaceholders.contains { $0.contains(expectedNotAllowedMessage) })
        #expect(beforePlaceholders.contains { $0.contains("http://images.example.com/pixel.png") })
        let copyDeadline = ContinuousClock.now.advanced(by: fixture.buttonTimeout)
        let copiedHTTPImageURL = try await webView.evaluateJavaScript(
            """
            (function() {
              window.__copiedRemoteImageURLs = [];
              Object.defineProperty(navigator, 'clipboard', {
                configurable: true,
                value: {
                  writeText: function(value) {
                    window.__copiedRemoteImageURLs.push(String(value));
                    return Promise.resolve();
                  }
                }
              });
              var img = document.querySelector('img[alt="HTTP remote"]');
              var id = img && img.getAttribute('data-bmux-remote-placeholder-id');
              var placeholder = id && document.querySelector('[data-bmux-remote-placeholder-for="' + id + '"]');
              var button = placeholder && placeholder.querySelectorAll('button')[0];
              if (button) { button.click(); }
              return window.__copiedRemoteImageURLs;
            })();
            """
        )
        let copiedHTTPImageURLs = try #require(copiedHTTPImageURL as? [String])
        #expect((copiedHTTPImageURLs) == (["http://images.example.com/pixel.png"]))
        let copiedHTTPButton = try await fixture.waitForRemoteImageButton(
            alt: "HTTP remote", expectedText: expectedCopiedButton, copied: true, deadline: copyDeadline
        )
        #expect((copiedHTTPButton["text"] as? String) == (expectedCopiedButton))
        #expect((copiedHTTPButton["copied"] as? String) == ("1"))
        let restoredHTTPButton = try await fixture.waitForRemoteImageButton(
            alt: "HTTP remote",
            expectedText: expectedCopyURLButton, copied: false, deadline: copyDeadline
        )
        #expect((restoredHTTPButton["text"] as? String) == (expectedCopyURLButton))
        #expect(restoredHTTPButton["copied"] as? String == nil)
        let openedHTTPImageURL = try await webView.evaluateJavaScript(
            """
            (function() {
              var opened = [];
              window.open = function(url, target, features) {
                opened.push({ url: String(url), target: String(target || ''), features: String(features || '') });
                return null;
              };
              var img = document.querySelector('img[alt="HTTP remote"]');
              var id = img && img.getAttribute('data-bmux-remote-placeholder-id');
              var placeholder = id && document.querySelector('[data-bmux-remote-placeholder-for="' + id + '"]');
              var button = placeholder && placeholder.querySelectorAll('button')[1];
              if (button) { button.click(); }
              return opened;
            })();
            """
        )
        let openedHTTPImageURLs = try #require(openedHTTPImageURL as? [[String: Any]])
        #expect((openedHTTPImageURLs.first?["url"] as? String) == ("http://images.example.com/pixel.png"))
        #expect((openedHTTPImageURLs.first?["target"] as? String) == ("_blank"))
        let linkedPlaceholderClickResult = try await webView.evaluateJavaScript(
            """
            (function() {
              var img = document.querySelector('img[alt="Linked remote"]');
              var id = img && img.getAttribute('data-bmux-remote-placeholder-id');
              var placeholder = id && document.querySelector('[data-bmux-remote-placeholder-for="' + id + '"]');
              var target = placeholder && (placeholder.querySelector('strong') || placeholder);
              if (!target) { return null; }
              return target.dispatchEvent(new MouseEvent('click', {
                bubbles: true,
                cancelable: true
              }));
            })();
            """
        )
        let linkedPlaceholderClickAllowed = try #require(linkedPlaceholderClickResult as? Bool)
        #expect(!(linkedPlaceholderClickAllowed))
        let linkedPlaceholderInsideAnchor = try await webView.evaluateJavaScript(
            """
            (function() {
              var img = document.querySelector('img[alt="Linked remote"]');
              var id = img && img.getAttribute('data-bmux-remote-placeholder-id');
              var placeholder = id && document.querySelector('[data-bmux-remote-placeholder-for="' + id + '"]');
              return !!(placeholder && placeholder.closest('a'));
            })();
            """
        )
        #expect((linkedPlaceholderInsideAnchor as? Bool) == (false))

        _ = try await webView.evaluateJavaScript(
            """
            (function() {
              var img = document.querySelector('img[alt="Linked remote"]');
              var id = img && img.getAttribute('data-bmux-remote-placeholder-id');
              var placeholder = id && document.querySelector('[data-bmux-remote-placeholder-for="' + id + '"]');
              var button = placeholder && placeholder.querySelector('button');
              if (button) { button.click(); }
            })();
            """
        )
        let loading = try await fixture.remoteImageSnapshot()
        let loadingImages = try #require(loading["images"] as? [[String: Any]])
        let loadingPlaceholders = try #require(loading["placeholders"] as? [String])
        let loadingButtons = try #require(loading["buttons"] as? [String])
        let loadingButtonStates = try #require(loading["buttonStates"] as? [[String: Any]])
        let loadingHTTPSImage = try #require(loadingImages.first { $0["alt"] as? String == "HTTPS remote" })
        let loadingLinkedImage = try #require(loadingImages.first { $0["alt"] as? String == "Linked remote" })
        let loadingDuplicateImage = try #require(loadingImages.first { $0["alt"] as? String == "Duplicate linked remote" })
        let loadingExpandedIPv6Image = try #require(loadingImages.first { $0["alt"] as? String == "Expanded IPv6 mapped remote" })
        #expect((loadingHTTPSImage["src"] as? String) == (""))
        #expect((loadingHTTPSImage["hidden"] as? Bool) == (true))
        #expect((loadingLinkedImage["src"] as? String ?? "").hasPrefix("bmux-remote-image://"))
        #expect((loadingLinkedImage["hidden"] as? Bool) == (true))
        #expect((loadingDuplicateImage["src"] as? String ?? "").hasPrefix("bmux-remote-image://"))
        #expect((loadingDuplicateImage["hidden"] as? Bool) == (true))
        #expect((loadingExpandedIPv6Image["src"] as? String) == (""))
        #expect((loadingExpandedIPv6Image["hidden"] as? Bool) == (true))
        #expect((loadingPlaceholders.count) == (7))
        #expect((loadingButtons.filter { $0 == expectedLoadButton }.count) == (1))
        #expect((loadingButtons.filter { $0 == expectedLoadingButton }.count) == (2))
        #expect((loadingButtons.filter { $0 == expectedCopyURLButton }.count) == (7))
        #expect((loadingButtons.filter { $0 == expectedOpenURLButton }.count) == (7))
        let activeLoadingButtons = loadingButtonStates.filter { $0["loading"] as? String == "1" }
        #expect((activeLoadingButtons.count) == (2))
        #expect(activeLoadingButtons.allSatisfy { $0["text"] as? String == expectedLoadingButton })
        #expect(activeLoadingButtons.allSatisfy { $0["disabled"] as? Bool == true })

        _ = try await webView.evaluateJavaScript(
            """
            (function() {
              Array.prototype.slice.call(document.querySelectorAll('img[src^="bmux-remote-image://"]')).forEach(function(img) {
                img.dispatchEvent(new Event('load'));
              });
            })();
            """
        )
        let after = try await fixture.remoteImageSnapshot()
        let afterImages = try #require(after["images"] as? [[String: Any]])
        let afterPlaceholders = try #require(after["placeholders"] as? [String])
        let afterButtons = try #require(after["buttons"] as? [String])
        let httpsImage = try #require(afterImages.first { $0["alt"] as? String == "HTTPS remote" })
        let linkedImage = try #require(afterImages.first { $0["alt"] as? String == "Linked remote" })
        let duplicateImage = try #require(afterImages.first { $0["alt"] as? String == "Duplicate linked remote" })
        let httpImage = try #require(afterImages.first { $0["alt"] as? String == "HTTP remote" })
        let localhostImage = try #require(afterImages.first { $0["alt"] as? String == "Localhost remote" })
        let credentialImage = try #require(afterImages.first { $0["alt"] as? String == "Credential remote" })
        let expandedIPv6Image = try #require(afterImages.first { $0["alt"] as? String == "Expanded IPv6 mapped remote" })

        #expect((httpsImage["src"] as? String) == (""))
        #expect((httpsImage["hidden"] as? Bool) == (true))
        #expect((linkedImage["src"] as? String ?? "").hasPrefix("bmux-remote-image://"))
        #expect((linkedImage["hidden"] as? Bool) == (false))
        #expect((duplicateImage["src"] as? String ?? "").hasPrefix("bmux-remote-image://"))
        #expect((duplicateImage["hidden"] as? Bool) == (false))
        #expect((httpImage["src"] as? String) == (""))
        #expect((httpImage["hidden"] as? Bool) == (true))
        #expect((localhostImage["src"] as? String) == (""))
        #expect((localhostImage["hidden"] as? Bool) == (true))
        #expect((credentialImage["src"] as? String) == (""))
        #expect((credentialImage["hidden"] as? Bool) == (true))
        #expect((expandedIPv6Image["src"] as? String) == (""))
        #expect((expandedIPv6Image["hidden"] as? Bool) == (true))
        #expect((afterPlaceholders.count) == (5))
        #expect((afterButtons.filter { $0 == expectedLoadButton }.count) == (1))
        #expect((afterButtons.filter { $0 == expectedCopyURLButton }.count) == (5))
        #expect((afterButtons.filter { $0 == expectedOpenURLButton }.count) == (5))
        #expect(afterPlaceholders.contains { $0.contains(expectedHTTPSOnlyMessage) })
        #expect(afterPlaceholders.contains { $0.contains(expectedNotAllowedMessage) })

        try await fixture.renderMarkdown(
            "![Different same-host remote](https://images.example.com/auto.png)\n"
        )
        let differentSameHost = try await fixture.remoteImageSnapshot()
        let differentSameHostImages = try #require(differentSameHost["images"] as? [[String: Any]])
        let differentSameHostPlaceholders = try #require(differentSameHost["placeholders"] as? [String])
        let differentSameHostButtons = try #require(differentSameHost["buttons"] as? [String])
        let differentSameHostImage = try #require(differentSameHostImages.first)
        #expect((differentSameHostImage["src"] as? String) == (""))
        #expect((differentSameHostImage["hidden"] as? Bool) == (true))
        #expect((differentSameHostPlaceholders.count) == (1))
        #expect((differentSameHostButtons.filter { $0 == expectedLoadButton }.count) == (1))
        #expect((differentSameHostButtons.filter { $0 == expectedCopyURLButton }.count) == (1))
        #expect((differentSameHostButtons.filter { $0 == expectedOpenURLButton }.count) == (1))

        try await fixture.renderMarkdown(
            "![Auto approved remote](https://images.example.com/linked.png)\n"
        )
        let autoLoading = try await fixture.remoteImageSnapshot()
        let autoLoadingImages = try #require(autoLoading["images"] as? [[String: Any]])
        let autoLoadingPlaceholders = try #require(autoLoading["placeholders"] as? [String])
        let autoLoadingButtons = try #require(autoLoading["buttons"] as? [String])
        let autoLoadingButtonStates = try #require(autoLoading["buttonStates"] as? [[String: Any]])
        let autoLoadingImage = try #require(autoLoadingImages.first)
        #expect((autoLoadingImage["src"] as? String ?? "").hasPrefix("bmux-remote-image://"))
        #expect((autoLoadingImage["hidden"] as? Bool) == (true))
        #expect((autoLoadingPlaceholders.count) == (1))
        #expect((autoLoadingButtons.filter { $0 == expectedLoadButton }.count) == (0))
        #expect((autoLoadingButtons.filter { $0 == expectedLoadingButton }.count) == (1))
        #expect((autoLoadingButtons.filter { $0 == expectedCopyURLButton }.count) == (1))
        #expect((autoLoadingButtons.filter { $0 == expectedOpenURLButton }.count) == (1))
        #expect((autoLoadingButtonStates.filter { $0["loading"] as? String == "1" }.count) == (1))

        _ = try await webView.evaluateJavaScript(
            """
            (function() {
              var img = document.querySelector('img[alt="Auto approved remote"]');
              if (img) { img.dispatchEvent(new Event('error')); }
            })();
            """
        )
        let autoFailed = try await fixture.remoteImageSnapshot()
        let autoFailedImages = try #require(autoFailed["images"] as? [[String: Any]])
        let autoFailedPlaceholders = try #require(autoFailed["placeholders"] as? [String])
        let autoFailedButtons = try #require(autoFailed["buttons"] as? [String])
        let autoFailedImage = try #require(autoFailedImages.first)
        #expect((autoFailedImage["src"] as? String) == (""))
        #expect((autoFailedImage["hidden"] as? Bool) == (true))
        #expect((autoFailedPlaceholders.count) == (1))
        #expect((autoFailedButtons.filter { $0 == expectedLoadButton }.count) == (1))
        #expect((autoFailedButtons.filter { $0 == expectedLoadingButton }.count) == (0))
        #expect((autoFailedButtons.filter { $0 == expectedCopyURLButton }.count) == (1))
        #expect((autoFailedButtons.filter { $0 == expectedOpenURLButton }.count) == (1))
    }
}
