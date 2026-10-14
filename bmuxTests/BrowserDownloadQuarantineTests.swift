import Foundation
import CoreServices
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite struct BrowserDownloadQuarantineTests {
    @Test(arguments: ["http", "https"])
    func quarantineMetadataSubmitsOnlySanitizedWebURLs(scheme: String) throws {
        let source = try #require(URL(string: "\(scheme)://user:pass@example.test:8443/report%20copy.csv?token=secret#section"))
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let metadata = BrowserDownloadQuarantineMetadata(
            sourceURL: source, agentName: "Download Agent",
            agentBundleIdentifier: "com.bmux.fixture.download", timestamp: timestamp
        )
        let properties = try #require(metadata.resourceValues.quarantineProperties)
        let expected = "\(scheme)://example.test:8443/report%20copy.csv"
        #expect((properties[kLSQuarantineDataURLKey as String] as? URL)?.absoluteString == expected)
        #expect((properties[kLSQuarantineOriginURLKey as String] as? URL)?.absoluteString == expected)
        #expect(properties[kLSQuarantineTypeKey as String] as? String == kLSQuarantineTypeWebDownload as String)
        #expect(properties[kLSQuarantineAgentNameKey as String] as? String == "Download Agent")
        #expect(properties[kLSQuarantineAgentBundleIdentifierKey as String] as? String == "com.bmux.fixture.download")
        #expect(properties[kLSQuarantineTimeStampKey as String] as? Date == timestamp)
    }

    @Test(arguments: ["file:///private/report.csv", "data:text/plain,private", "ftp://user:pass@example.test/report"])
    func quarantineMetadataOmitsNonWebURLs(source: String) throws {
        let metadata = BrowserDownloadQuarantineMetadata(
            sourceURL: try #require(URL(string: source)), agentName: "Download Agent",
            agentBundleIdentifier: nil, timestamp: Date(timeIntervalSince1970: 0)
        )
        let properties = try #require(metadata.resourceValues.quarantineProperties)
        #expect(properties[kLSQuarantineDataURLKey as String] == nil)
        #expect(properties[kLSQuarantineOriginURLKey as String] == nil)
        #expect(properties[kLSQuarantineAgentBundleIdentifierKey as String] == nil)
        #expect(properties[kLSQuarantineTypeKey as String] as? String == kLSQuarantineTypeWebDownload as String)
    }

    @Test func quarantineMetadataOmitsEmptyBundleIdentifier() throws {
        let metadata = BrowserDownloadQuarantineMetadata(
            sourceURL: try #require(URL(string: "https://example.test/report.csv")),
            agentName: "Download Agent", agentBundleIdentifier: "", timestamp: Date(timeIntervalSince1970: 0)
        )
        let properties = try #require(metadata.resourceValues.quarantineProperties)
        #expect(properties[kLSQuarantineAgentBundleIdentifierKey as String] == nil)
    }

    @Test func webDownloadQuarantineMetadataMarksRemoteDownloads() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(
            "bmux-download-quarantine-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        defer { try? fileManager.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("report.csv", isDirectory: false)
        try Data("download".utf8).write(to: fileURL)
        let sourceURL = try #require(URL(string: "https://user:pass@example.test/report.csv?token=secret#section"))

        try fileURL.bmuxApplyWebDownloadQuarantine(sourceURL: sourceURL)

        let properties = try #require(
            fileURL.resourceValues(forKeys: [.quarantinePropertiesKey]).quarantineProperties
        )
        #expect(properties[kLSQuarantineTypeKey as String] as? String == kLSQuarantineTypeWebDownload as String)
        #expect(properties[kLSQuarantineAgentNameKey as String] as? String != nil)
        #expect(properties[kLSQuarantineTimeStampKey as String] is Date)
        // LaunchServices may omit URL metadata on readback. Exact outgoing values are tested separately.
        for key in [kLSQuarantineDataURLKey, kLSQuarantineOriginURLKey] {
            if let value = properties[key as String] {
                let url = try #require(value as? URL)
                #expect(url.absoluteString == "https://example.test/report.csv")
            }
        }
    }

    @Test(arguments: [nil, URL(fileURLWithPath: "/tmp/source.txt")])
    func webDownloadQuarantineMetadataSkipsMissingAndLocalFileSources(sourceURL: URL?) throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(
            "bmux-download-quarantine-local-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        defer { try? fileManager.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("local-copy.txt", isDirectory: false)
        try Data("download".utf8).write(to: fileURL)

        try fileURL.bmuxApplyWebDownloadQuarantine(sourceURL: sourceURL)

        let properties = try fileURL.resourceValues(forKeys: [.quarantinePropertiesKey]).quarantineProperties
        #expect(properties == nil)
    }

}
