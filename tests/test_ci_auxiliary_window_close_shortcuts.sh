#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 scripts/lint_auxiliary_window_close_shortcuts.py

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/Sources"

cat > "$TMP_DIR/Sources/bmuxApp.swift" <<'SWIFT'
private let bmuxAuxiliaryWindowIdentifiers: Set<String> = [
    "bmux.settings",
]
SWIFT

cat > "$TMP_DIR/Sources/NewWindow.swift" <<'SWIFT'
import AppKit

/*
window.identifier = NSUserInterfaceItemIdentifier("bmux.blockCommentOnly")
*/

func makeWindow() {
    let window = NSWindow()
    window.identifier =
        NSUserInterfaceItemIdentifier("bmux.newWindow")
}
SWIFT

if python3 scripts/lint_auxiliary_window_close_shortcuts.py --repo-root "$TMP_DIR" >"$TMP_DIR/missing.out" 2>&1; then
    echo "Expected missing auxiliary-window close owner to fail" >&2
    exit 1
fi
grep -q "bmux.newWindow" "$TMP_DIR/missing.out"
grep -q "Sources/NewWindow.swift:9" "$TMP_DIR/missing.out"

cat > "$TMP_DIR/Sources/bmuxApp.swift" <<'SWIFT'
private let bmuxAuxiliaryWindowIdentifiers: Set<String> = [
    // "bmux.newWindow",
    /*
    "bmux.newWindow",
    */
    "bmux.settings",
]
SWIFT

if python3 scripts/lint_auxiliary_window_close_shortcuts.py --repo-root "$TMP_DIR" >"$TMP_DIR/commented-owner.out" 2>&1; then
    echo "Expected commented-out auxiliary-window close owner to be ignored" >&2
    exit 1
fi
grep -q "bmux.newWindow" "$TMP_DIR/commented-owner.out"

cat > "$TMP_DIR/Sources/bmuxApp.swift" <<'SWIFT'
private let bmuxAuxiliaryWindowIdentifiers: Set<String> = [
    // MARK: - Main Windows [user-closable]
    // This comment intentionally contains a lone ] bracket.
    "bmux.newWindow",
    "bmux.settings",
]
SWIFT

python3 scripts/lint_auxiliary_window_close_shortcuts.py --repo-root "$TMP_DIR"

cat > "$TMP_DIR/Sources/NewWindow.swift" <<'SWIFT'
import AppKit

func makeWindow() {
    let window = NSWindow()
    /*
    window.identifier = NSUserInterfaceItemIdentifier("bmux.blockCommentOnly")
    */
    // window.identifier = NSUserInterfaceItemIdentifier("bmux.commentOnly")
    _ = window
}
SWIFT

python3 scripts/lint_auxiliary_window_close_shortcuts.py --repo-root "$TMP_DIR"

cat > "$TMP_DIR/Sources/bmuxApp.swift" <<'SWIFT'
private let bmuxAuxiliaryWindowIdentifiers: Set<String> = [
    "bmux.settings",
]
SWIFT

cat > "$TMP_DIR/Sources/NewWindow.swift" <<'SWIFT'
import AppKit

func makeWindow() {
    let window = NSWindow()
    window.identifier = NSUserInterfaceItemIdentifier("bmux.bootstrap")
}
SWIFT

python3 scripts/lint_auxiliary_window_close_shortcuts.py --repo-root "$TMP_DIR"

# Identifier assigned through a named constant (the MobilePairingWindowController
# pattern) must be resolved and enforced, not silently skipped.
cat > "$TMP_DIR/Sources/bmuxApp.swift" <<'SWIFT'
private let bmuxAuxiliaryWindowIdentifiers: Set<String> = [
    "bmux.settings",
]
SWIFT

cat > "$TMP_DIR/Sources/NewWindow.swift" <<'SWIFT'
import AppKit

final class ConstantWindowController {
    static let windowIdentifier = "bmux.constantWindow"

    func makeWindow() {
        let window = NSWindow()
        window.identifier = NSUserInterfaceItemIdentifier(Self.windowIdentifier)
    }
}
SWIFT

if python3 scripts/lint_auxiliary_window_close_shortcuts.py --repo-root "$TMP_DIR" >"$TMP_DIR/constant.out" 2>&1; then
    echo "Expected constant-assigned auxiliary-window identifier to fail when missing" >&2
    exit 1
fi
grep -q "bmux.constantWindow" "$TMP_DIR/constant.out"
grep -q "Sources/NewWindow.swift:8" "$TMP_DIR/constant.out"

cat > "$TMP_DIR/Sources/bmuxApp.swift" <<'SWIFT'
private let bmuxAuxiliaryWindowIdentifiers: Set<String> = [
    "bmux.constantWindow",
    "bmux.settings",
]
SWIFT

python3 scripts/lint_auxiliary_window_close_shortcuts.py --repo-root "$TMP_DIR"
