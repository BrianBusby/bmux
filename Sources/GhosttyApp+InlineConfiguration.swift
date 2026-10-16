import Foundation

extension GhosttyApp {
    func loadInlineGhosttyConfig(
        _ contents: String,
        into config: ghostty_config_t,
        prefix: String,
        logLabel _: String
    ) {
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let syntheticPath = "/__bmux_inline__/\(prefix).conf"
        trimmed.withCString { contents in
            syntheticPath.withCString { path in
                ghostty_config_load_string(
                    config,
                    contents,
                    UInt(trimmed.lengthOfBytes(using: .utf8)),
                    path
                )
            }
        }
    }

}
