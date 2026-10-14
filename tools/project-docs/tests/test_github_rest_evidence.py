from __future__ import annotations

import contextlib
import http.client
import io
import json
import unittest
import urllib.error
from unittest.mock import Mock, call, patch

import project_docs


class GitHubRestEvidenceTests(unittest.TestCase):
    def error(self, status, *, body=b"upstream response", headers=None):
        return urllib.error.HTTPError("https://api.github.com/evidence", status, "failure",
                                      headers or {}, io.BytesIO(body))

    def response(self, payload):
        return io.BytesIO(json.dumps(payload).encode())

    @contextlib.contextmanager
    def transport(self, outcomes):
        opener = Mock(side_effect=outcomes)
        with patch("urllib.request.urlopen", opener), patch("time.sleep") as delay:
            yield opener, delay

    def test_transient_server_errors_recover_real_commit_lookup(self):
        for status in (500, 502, 503, 504):
            with self.subTest(status=status):
                failure = self.error(status)
                response = self.response({"sha": "abc"})
                with self.transport([failure, response]) as (opener, delay):
                    # Use the unchanged constructor/API: the old implementation
                    # fails by raising network at the first HTTP error.
                    provider = project_docs.GitHubRestEvidenceProvider(token="fixture-token")
                    self.assertTrue(provider.commit_exists("example/project", "abc"))
                    self.assertEqual(opener.call_count, 2)
                    self.assertEqual(delay.call_args_list, [call(1)])
                    requests = [item.args[0] for item in opener.call_args_list]
                    self.assertEqual(requests[0].full_url, "https://api.github.com/repos/example/project/commits/abc")
                    self.assertEqual(requests[0].header_items(), requests[1].header_items())
                    self.assertEqual(requests[0].get_header("Authorization"), "Bearer fixture-token")
                    self.assertTrue(all(item.kwargs == {"timeout": 20} for item in opener.call_args_list))
                    self.assertTrue(failure.fp.closed)
                    self.assertTrue(response.closed)

    def test_errors_are_closed_before_bounded_delays(self):
        failures = [self.error(500), self.error(503)]
        with self.transport([*failures, self.response({"state": "open", "number": 42})]) as (opener, delay):
            def inspect_close(_):
                self.assertTrue(failures[opener.call_count - 1].fp.closed)
            delay.side_effect = inspect_close
            evidence = project_docs.GitHubRestEvidenceProvider().pull_request("example/project", 42)
            self.assertEqual(evidence.number, 42)
            self.assertEqual(evidence.state, "open")
            self.assertEqual(delay.call_args_list, [call(1), call(2)])
            self.assertEqual(opener.call_count, 3)

    def test_persistent_server_failure_preserves_final_error_and_stops(self):
        failures = [self.error(500), self.error(503), self.error(504)]
        with self.transport([*failures, self.response({"sha": "must-not-be-used"})]) as (opener, delay):
            with self.assertRaises(project_docs.GitHubProviderError) as raised:
                project_docs.GitHubRestEvidenceProvider().commit_exists("example/project", "abc")
            self.assertEqual(raised.exception.kind, "network")
            self.assertEqual(raised.exception.message,
                             "GitHub API request failed for /repos/example/project/commits/abc: HTTP 504")
            self.assertIs(raised.exception.__cause__, failures[-1])
            self.assertEqual(opener.call_count, 3)
            self.assertEqual(delay.call_args_list, [call(1), call(2)])

    def test_nontransient_http_classification_is_immediate(self):
        cases = [(400, "network", {}, b""), (401, "auth", {}, b""),
                 (403, "auth", {}, b""), (403, "rate_limit", {"X-RateLimit-Remaining": "0"}, b""),
                 (403, "rate_limit", {}, b"API rate limit exceeded"),
                 (429, "rate_limit", {}, b""), (501, "network", {}, b""), (505, "network", {}, b"")]
        for status, kind, headers, body in cases:
            with self.subTest(status=status, kind=kind):
                with self.transport([self.error(status, headers=headers, body=body)]) as (opener, delay):
                    with self.assertRaises(project_docs.GitHubProviderError) as raised:
                        project_docs.GitHubRestEvidenceProvider().repository_exists("example/project")
                    self.assertEqual(raised.exception.kind, kind)
                    self.assertEqual(opener.call_count, 1)
                    delay.assert_not_called()

    def test_server_error_then_auth_rate_limit_or_missing_stops(self):
        for status, kind in ((401, "auth"), (403, "auth"), (404, None), (429, "rate_limit")):
            with self.subTest(status=status):
                with self.transport([self.error(500), self.error(status), self.response({})]) as (opener, delay):
                    provider = project_docs.GitHubRestEvidenceProvider()
                    if kind is None:
                        self.assertFalse(provider.repository_exists("example/project"))
                    else:
                        with self.assertRaises(project_docs.GitHubProviderError) as raised:
                            provider.repository_exists("example/project")
                        self.assertEqual(raised.exception.kind, kind)
                    self.assertEqual(opener.call_count, 2)
                    self.assertEqual(delay.call_args_list, [call(1)])

    def test_missing_evidence_does_not_retry_or_become_present(self):
        with self.transport([self.error(404), self.response({})]) as (opener, delay):
            self.assertFalse(project_docs.GitHubRestEvidenceProvider().commit_exists("example/project", "abc"))
            self.assertEqual(opener.call_count, 1)
            delay.assert_not_called()

    def test_other_network_errors_remain_immediate(self):
        for error in (urllib.error.URLError("unavailable"), TimeoutError("deadline"),
                      http.client.RemoteDisconnected("closed")):
            with self.subTest(error=type(error).__name__):
                with self.transport([error]) as (opener, delay):
                    with self.assertRaises(project_docs.GitHubProviderError) as raised:
                        project_docs.GitHubRestEvidenceProvider().repository_exists("example/project")
                    self.assertEqual(raised.exception.kind, "network")
                    self.assertIs(raised.exception.__cause__, error)
                    self.assertEqual(opener.call_count, 1)
                    delay.assert_not_called()

    def test_successful_default_branch_is_cached_after_recovery(self):
        responses = [self.error(500), self.response({"default_branch": "main"}),
                     self.error(502), self.response({"status": "ahead"}), self.response({"status": "identical"})]
        with self.transport(responses) as (opener, delay):
            provider = project_docs.GitHubRestEvidenceProvider()
            self.assertTrue(provider.commit_reachable_from_default_branch("example/project", "abc"))
            self.assertTrue(provider.commit_reachable_from_default_branch("example/project", "def"))
            self.assertEqual([item.args[0].full_url for item in opener.call_args_list], [
                "https://api.github.com/repos/example/project", "https://api.github.com/repos/example/project",
                "https://api.github.com/repos/example/project/compare/abc...main",
                "https://api.github.com/repos/example/project/compare/abc...main",
                "https://api.github.com/repos/example/project/compare/def...main"])
            self.assertEqual(delay.call_args_list, [call(1), call(1)])

    def test_final_failure_never_logs_token_or_response_body(self):
        secret = b"sensitive-upstream-body fixture-token"
        failures = [self.error(500, body=secret) for _ in range(3)]
        stdout, stderr = io.StringIO(), io.StringIO()
        with self.transport(failures), contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            with self.assertRaises(project_docs.GitHubProviderError) as raised:
                project_docs.GitHubRestEvidenceProvider(token="fixture-token").repository_exists("example/project")
        combined = stdout.getvalue() + stderr.getvalue() + str(raised.exception)
        self.assertNotIn("fixture-token", combined)
        self.assertNotIn("sensitive-upstream-body", combined)


if __name__ == "__main__":
    unittest.main()
