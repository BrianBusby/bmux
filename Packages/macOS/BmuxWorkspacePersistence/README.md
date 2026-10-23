# BmuxWorkspacePersistence

Infrastructure for workspace state that must survive process exit. The Explorer
close journal writes a minimal identity synchronously before PE archive
enrichment starts. It returns the latest close per logical workspace and keeps
older records until Explorer history is explicitly cleared. A durable clear
marker prevents a concurrent late write from making an older close visible or
leaving its title file after a completed clear. Clear compacts superseded
markers so repeated clears do not lengthen close-time marker reads.

The app constructs `WorkspaceExplorerCloseJournal` with the PE database URL and
injects it through the close-journal protocol into the provenance runtime.
Tests pass a temporary database URL
and an injected `FileManager`; no app launch or user state is required.
