from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_cloud_vm_terminal_startup_uses_persistent_attach_retries():
    workspace = (ROOT / "Sources" / "Workspace.swift").read_text()
    restore = (ROOT / "Sources" / "SessionRemoteWorkspaceSnapshot+Restore.swift").read_text()
    cli = (ROOT / "CLI" / "bmux.swift").read_text()

    for source in (workspace, restore, cli):
        assert 'BMUX_SSH_RECONNECT_LIMIT=\\"${BMUX_SSH_RECONNECT_LIMIT:-86400}\\"' in source
        assert (
            'BMUX_DEFAULT_FREESTYLE_ATTACH_RETRY_LIMIT=\\"${BMUX_DEFAULT_FREESTYLE_ATTACH_RETRY_LIMIT:-$BMUX_SSH_RECONNECT_LIMIT}\\"'
            in source
        )
        assert (
            'BMUX_DEFAULT_FREESTYLE_ATTACH_RETRY_DELAY_SECONDS=\\"${BMUX_DEFAULT_FREESTYLE_ATTACH_RETRY_DELAY_SECONDS:-$BMUX_SSH_RECONNECT_DELAY_SECONDS}\\"'
            in source
        )
        assert '\\"$bmux_freestyle_cli\\" --socket \\"$BMUX_SOCKET_PATH\\" vm-pty-attach' in source
        assert "bmux_freestyle_attach" in source


def test_cloud_vm_retry_message_does_not_show_huge_retry_denominator():
    cli = (ROOT / "CLI" / "bmux.swift").read_text()

    assert "Waiting for the local bmux web server" in cli
    assert "Waiting for the Cloud VM service" in cli
    assert "Waiting for the Cloud VM control plane" in cli
    assert "provider control plane" in cli
    assert "local bmux web server is offline" in cli
    assert "bmuxd websocket health check failed" in cli
    assert "operation was aborted" in cli
    assert "requires a bmuxd rpc endpoint" in cli
    assert "let response = try defaultFreestyleAttachInfoWithRetryIfNeeded(" in cli
    assert "private static func retryAttemptLabel(attempt: Int, retryLimit: Int) -> String" in cli
    assert "if retryLimit >= 86_400" in cli


def test_dev_env_preserves_explicit_cloud_vm_image_overrides():
    env_loader = (ROOT / "web" / "scripts" / "load-dev-env.sh").read_text()

    assert 'bmux_existing_freestyle_snapshot_set="${FREESTYLE_SANDBOX_SNAPSHOT+x}"' in env_loader
    assert 'export FREESTYLE_SANDBOX_SNAPSHOT="$bmux_existing_freestyle_snapshot"' in env_loader
    assert 'bmux_existing_e2b_template_set="${E2B_BMUXD_WS_TEMPLATE+x}"' in env_loader
    assert 'export E2B_BMUXD_WS_TEMPLATE="$bmux_existing_e2b_template"' in env_loader
