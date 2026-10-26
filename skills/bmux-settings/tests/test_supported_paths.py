"""Checks that the settings helper recognizes catalog-owned integration keys."""

import runpy
import tempfile
import unittest
from pathlib import Path


class SupportedPathsTests(unittest.TestCase):
    def test_work_brief_github_scope_is_supported(self):
        helper = runpy.run_path(
            str(Path(__file__).parents[1] / "scripts" / "bmux-settings")
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "Sources" / "BmuxSettingsJSONPathSupport.swift"
            source.parent.mkdir()
            source.write_text('let key = "app.appearance"')
            catalog = root / "Packages" / "macOS" / "BmuxSettings" / "Sources" / "BmuxSettings" / "Keys" / "IntegrationsCatalogSection.swift"
            catalog.parent.mkdir(parents=True)
            catalog.write_text('id: "integrations.workBrief.githubScopes"')
            paths = helper["supported_paths_from_source"](source)
            self.assertIn("app.appearance", paths)
            self.assertIn("integrations.workBrief.githubScopes", paths)


if __name__ == "__main__":
    unittest.main()
