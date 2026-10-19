import Foundation
import Testing

extension MarkdownRenderTestFixture {
    func waitForMarkdownImages(expectedCount: Int) async throws -> [[String: Any]] {
        let json = try await observeDOM(
            snapshot: """
            Array.from(document.querySelectorAll('img')).map(function(img) {
              return {found: true, alt: img.getAttribute('alt') || '', complete: !!img.complete,
                naturalWidth: img.naturalWidth || 0, naturalHeight: img.naturalHeight || 0,
                src: img.getAttribute('src') || '', currentSrc: img.currentSrc || '',
                hidden: !!img.hidden, remoteSrc: img.getAttribute('data-bmux-remote-src') || ''};
            })
            """,
            predicate: "value.length === \(expectedCount) && value.every(function(img) { return img.complete; })",
            deadline: ContinuousClock.now.advanced(by: imageTimeout)
        )
        return try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
    }

    func waitForRemoteImageButton(
        alt: String,
        expectedText: String,
        copied: Bool,
        deadline: ContinuousClock.Instant
    ) async throws -> [String: Any] {
        let arguments = try JSONSerialization.data(withJSONObject: [alt, expectedText])
        let literal = try #require(String(data: arguments, encoding: .utf8))
        let json = try await observeDOM(
            snapshot: """
            (function() {
              var args = \(literal);
              var img = Array.from(document.querySelectorAll('img')).find(function(img) { return img.alt === args[0]; });
              var id = img && img.getAttribute('data-bmux-remote-placeholder-id');
              var placeholder = id && document.querySelector('[data-bmux-remote-placeholder-for="' + id + '"]');
              var button = placeholder && placeholder.querySelectorAll('button')[0];
              return {text: button ? button.textContent : '', copied: button ? button.getAttribute('data-copied') : ''};
            })()
            """,
            predicate: "value.text === \(literal)[1] && value.copied === \(copied ? "'1'" : "null")",
            deadline: deadline
        )
        return try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    /// Every terminal path disconnects before posting; native cancellation invokes the same cleanup.
    func observationScript(id: String, snapshot: String, predicate: String, milliseconds: Double) -> String {
        """
        (function() {
          var registry = window.__bmuxFixtureObservers || (window.__bmuxFixtureObservers = Object.create(null));
          var id = '\(id)', done = false, observer, timer;
          function cleanup() {
            if (observer) { observer.disconnect(); }
            if (timer) { clearTimeout(timer); }
            document.removeEventListener('load', check, true);
            document.removeEventListener('error', check, true);
            window.removeEventListener('pagehide', pagehide);
            delete registry[id];
          }
          function finish(result) {
            if (done) { return; }
            done = true;
            cleanup();
            if (result) { window.webkit.messageHandlers.bmuxRenderingFixture.postMessage(Object.assign({id: id}, result)); }
          }
          function check() {
            if (done) { return; }
            try {
              var value = \(snapshot);
              if (\(predicate)) { finish({json: JSON.stringify(value)}); }
            } catch (error) { finish({error: String(error)}); }
          }
          function pagehide() { finish({error: 'Navigation replaced observed page'}); }
          registry[id] = function() { finish(null); };
          observer = new MutationObserver(check);
          observer.observe(document.documentElement, {subtree: true, childList: true, attributes: true, characterData: true});
          document.addEventListener('load', check, true);
          document.addEventListener('error', check, true);
          window.addEventListener('pagehide', pagehide);
          timer = setTimeout(function() { finish({error: 'DOM phase deadline exceeded'}); }, \(milliseconds));
          check();
        })();
        """
    }
}
