# Provenance Engine Integration Contract

External adopters should import:

```swift
import ProvenanceEngineContracts
import ProvenanceEngineSDK
```

Create an in-process SQLite client through `ProvenanceEngineClientFactory`:

```swift
let client = try ProvenanceEngineClientFactory()
    .sqliteClient(databaseURL: databaseURL)
let response = try await client.worktrees(ProvenanceWorktreeListRequest())
```

For default engine-owned storage, use:

```swift
let client = try ProvenanceEngineClientFactory().defaultSQLiteClient()
```

Do not construct `ProvenanceSQLiteRepository` from adopter code. Do not read engine SQLite tables directly. Seed integration tests by appending public `ProvenanceEventRecord` values through `ProvenanceEngineClient.appendEvent`.

The accepted worktree read contract is:

- Request: `ProvenanceWorktreeListRequest(repositoryID:limit:)`
- Response: `ProvenanceWorktreeListResponse`
- Row: `ProvenanceWorktreeListEntry`
- Worktree DTO: `ProvenanceWorktreeRecord`
- Repository DTO: `ProvenanceRepositoryRecord`

Rollback should be a scoped Git revert in the adopter repository that removes the package dependency and restores the previous local read path.
