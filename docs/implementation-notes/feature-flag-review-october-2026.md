# October 2026 feature-flag review

Review date: October 10, 2026. Next review: November 1, 2026.

The existing `workflow-guard-tests` failure on workspace-ticket-gap was caused by
four expired registry entries, before macOS compilation could run. The registry
contract in `scripts/lint-feature-flags.py` explicitly permits a conscious review
date extension. The same rule is documented in the web registry header.

Retain the existing Pro upgrade and checkout gates: the billing skill still
requires release Pro UI to remain off until launch, and live checkout needs the
production billing acceptance procedure. This integration does not establish that
acceptance and must not remove or force-enable those gates. Retain the Mobile
Connect entrypoint's remote rollout control while mobile presence/lifecycle
acceptance remains separate from this desktop launcher repair. Its existing safe
fallback remains true.

Only review dates change. Flag keys, owners, evaluation sites, defaults, overrides,
and remote PostHog configuration remain unchanged. No billing or pairing action
was exercised or authorized by this maintenance. Reassess removal or reclassification
at the next review with the corresponding release evidence.

Validation: `python3 scripts/lint-feature-flags.py`. No new user-facing strings.
