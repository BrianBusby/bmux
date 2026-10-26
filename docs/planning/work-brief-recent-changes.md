# Work Brief recent changes

The built-in brief compares current source facts with a fingerprint of the
last brief the user viewed. The app saves the fingerprint when the Work Brief
window closes after a completed refresh. A first brief or a baseline older
than 30 days states that a previous brief is needed. The view shows currently
available items whose verified status, explicit ticket/PR link, provider
classification, or provider update time changed. It does not claim that an
item disappeared when a source fails or returns partial data.

`WorkBriefBaseline` owns pure comparison and 30-day retention. The app owns a
versioned UserDefaults record capped at 64 KiB. It contains at most 100 stable
workspace IDs and 200 provider-qualified item IDs, status codes, explicit link
IDs, and timestamps. It contains no titles, URLs, descriptions, comments,
message bodies, prompts, credentials, or generated summaries. Missing or failed
sources keep their previous fingerprint only until its own 30-day confirmation
expiry. A successful source refresh replaces that source's fingerprints.
The stored metadata is deleted by clearing the app's preferences; no PE evidence
is modified. PE continues to own durable engineering evidence.

The first tagged build cannot display changes before a second viewed brief.
Current cards retain their source links and evidence disclosure. This slice
uses the same immutable row snapshots and click-only navigation as the local
Work Brief; background refresh does not select a workspace.

Verification: pure baseline tests cover changed stable IDs, failed source
retention, and expiry; the UI package builds; the app project wires the new
store; a tagged app build and runtime dogfood are required before merge.
