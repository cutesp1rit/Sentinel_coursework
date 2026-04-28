# Sentinel Implementation Invariants

## Preserve these product invariants

1. Chat is the primary input surface for AI-assisted planning.
2. One chat request may lead to multiple suggested events.
3. Suggested events must be reviewable before adding.
4. Event export should avoid duplicates.
5. Conflicts in schedule should remain visible to the user.
6. Resource Battery and Rebalance are distinct product concepts and should not be merged into generic UI labels.
7. Achievements are first-class product data, not debug-only metadata.
8. Assistant-facing behavior may be localized, but transport contracts remain English-centric.
9. Attached images help produce suggestions, but they are not exported as calendar attachments.
10. Offline generation is unsupported; when the network is unavailable, previously added events may still be viewed.

## Expected state buckets

For screens or reducers touching async work, consider these states explicitly:
- idle
- loading
- success
- empty
- retryable error
- permission denied where relevant
- conflict state where event timing collides
- partially completed flow where suggestions exist but nothing has been exported yet

## Platform-specific invariants

- Keychain stores tokens and secrets
- SwiftData stores local app data
- EventKit is the bridge to Apple Calendar
- PhotosUI and system pickers handle attachments
- ATS stays enabled

## Commit invariant

After approved work, create a commit using:
`<branch>: [new|fix|refactor] Title In Title Case`
