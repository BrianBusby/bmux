import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct SidebarWidthPersistencePolicyTests {
    @Test(arguments: [
        (nil, 340.0), (-20.0, 290.0), (10_000.0, 600.0), (410.0, 410.0),
        (Double.nan, 340.0), (Double.infinity, 340.0), (-Double.infinity, 340.0)
    ] as [(Double?, Double)])
    func defaultBounds(candidate: Double?, expected: Double) throws {
        let suiteName = "SidebarWidthPersistencePolicyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(SessionPersistencePolicy.defaultMinimumSidebarWidth == 290)
        #expect(SessionPersistencePolicy.resolvedMinimumSidebarWidth(defaults: defaults) == 290)
        #expect(SessionPersistencePolicy.sanitizedSidebarWidth(candidate, defaults: defaults) == expected)
    }

    @Test @MainActor
    func contentViewClampUsesDefaultMinimum() {
        #expect(ContentView.clampedSidebarWidth(184, maximumWidth: 600) == 290)
    }

    @Test(arguments: [("180", 180.0), ("-20", 120.0), ("10000", 260.0), ("invalid", 290.0), ("nan", 290.0)], [false, true])
    func configuredBounds(value: (String, Double), storeAsNumber: Bool) throws {
        let suiteName = "SidebarWidthPersistencePolicyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let (storedMinimum, expectedMinimum) = value
        let storedValue: Any = storeAsNumber ? (Double(storedMinimum).map { $0 as Any } ?? storedMinimum) : storedMinimum
        defaults.set(storedValue, forKey: SessionPersistencePolicy.sidebarMinimumWidthKey)

        #expect(SessionPersistencePolicy.resolvedMinimumSidebarWidth(defaults: defaults) == expectedMinimum)
        #expect(SessionPersistencePolicy.sanitizedSidebarWidth(-20, defaults: defaults) == expectedMinimum)
        #expect(SessionPersistencePolicy.sanitizedSidebarWidth(10_000, defaults: defaults) == 600)
        #expect(SessionPersistencePolicy.sanitizedSidebarWidth(nil, defaults: defaults) == 340)
    }
}
