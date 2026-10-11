#!/usr/bin/env python3
# Author: GauchoCode
"""Network-free metadata regressions; run in the isolated Docker harness only."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROFILE = ROOT / "libs/backup_observation/borgmatic_profile.py"
FIXTURES = ROOT / "tests/backup_observation/fixtures"
CANARY = Path("/tmp/brolit-template-hook-canary")
OUTPUT_KEYS = {
    "status", "error", "repositories", "source_directories", "database_hints",
    "has_hooks", "retention", "project", "hostname", "group",
}


class BorgmaticProfileTests(unittest.TestCase):
    def parse(self, path):
        result = subprocess.run(
            [sys.executable, str(PROFILE), "parse-yml", str(path)],
            env={"PATH": "/usr/bin:/bin", "LC_ALL": "C"},
            capture_output=True, text=True, timeout=10, check=True,
        )
        self.assertEqual(result.stderr, "")
        self.assertNotIn("fixture-secret-canary", result.stdout)
        self.assertNotIn("touch /tmp", result.stdout)
        self.assertFalse(CANARY.exists(), "a configuration hook was executed")
        return json.loads(result.stdout)

    def parse_document(self, document):
        # JSON is also safe YAML, avoiding a second serializer/parser in tests.
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.yml"
            path.write_text(json.dumps(document))
            return self.parse(path)

    def test_repository_templates(self):
        for template, hints, retention in (
            ("postgres", ["postgresql"], {"keep_monthly": "6", "keep_yearly": "1"}),
            ("docker", [], {"keep_monthly": "6", "keep_yearly": "1"}),
            ("mysql", ["mysql"], {"keep_within": "1m", "keep_monthly": "6", "keep_yearly": "1"}),
            ("default", [], {"keep_within": "1m", "keep_monthly": "6", "keep_yearly": "1"}),
        ):
            with self.subTest(template=template):
                result = self.parse(ROOT / f"config/borg/borgmatic.template-{template}.yml")
                self.assertEqual(result["status"], "ok")
                self.assertEqual(set(result), OUTPUT_KEYS)
                self.assertEqual(result["database_hints"], hints)
                self.assertTrue(result["has_hooks"])
                self.assertEqual(result["retention"], retention)

    def test_sanitized_generated_templates(self):
        for template, hints in (("postgres", ["postgresql"]), ("docker", [])):
            with self.subTest(template=template):
                result = self.parse(FIXTURES / f"templates/{template}.yml")
                self.assertEqual(result["status"], "ok")
                self.assertEqual(set(result), OUTPUT_KEYS)
                self.assertEqual(result["database_hints"], hints)
                self.assertTrue(result["has_hooks"])
                self.assertEqual(result["retention"], {"keep_monthly": "6", "keep_yearly": "1"})
                self.assertEqual(len(result["repositories"]), 2)
                self.assertEqual(result["source_directories"], [f"/var/www/fixture-{template}.example"])
                self.assertNotEqual(result["repositories"][0]["path"], result["repositories"][1]["path"])

    def test_existing_nested_metadata_profile(self):
        result = self.parse(FIXTURES / "templates-existing-profile.yml")
        self.assertEqual(result["status"], "ok")
        self.assertEqual(result["database_hints"], ["mysql", "mariadb", "postgresql"])
        self.assertEqual(result["source_directories"], [])
        self.assertTrue(result["has_hooks"])
        self.assertEqual(result["retention"], {"keep_daily": "1", "keep_weekly": "0"})

    def test_no_metadata_stays_unknown(self):
        result = self.parse_document({})
        self.assertEqual(result["database_hints"], [])
        self.assertFalse(result["has_hooks"])
        self.assertIsNone(result["retention"])

    def test_each_top_level_hook_is_presence_only(self):
        for key in ("before_backup", "after_backup", "on_error"):
            with self.subTest(key=key):
                result = self.parse_document({key: ["pg_dumpall $(touch /tmp/brolit-template-hook-canary)"]})
                self.assertEqual(result["status"], "ok")
                self.assertTrue(result["has_hooks"])
                self.assertEqual(result["database_hints"], [])

    def test_empty_hooks_and_databases_are_not_positive_hints(self):
        result = self.parse_document({"before_backup": [], "postgres_databases": []})
        self.assertEqual(result["database_hints"], [])
        self.assertFalse(result["has_hooks"])

    def test_malformed_hooks_fail_safely(self):
        for value in ("touch /tmp/brolit-template-hook-canary", {}, [True], [{}]):
            with self.subTest(value=value):
                self.assertEqual(self.parse_document({"before_backup": value})["status"], "unsupported")

    def test_malformed_database_declarations_fail_safely(self):
        for key in ("mysql_databases", "mariadb_databases", "postgresql_databases", "postgres_databases"):
            for value in ({"name": "all"}, ["all"], [{}], [{"name": {"database": None}}], [{"name": ""}]):
                with self.subTest(key=key, value=value):
                    self.assertEqual(self.parse_document({key: value})["status"], "unsupported")

    def test_all_documented_flat_retention_keys(self):
        document = {f"keep_{unit}": count for count, unit in enumerate(
            ("secondly", "minutely", "hourly", "daily", "weekly", "monthly", "yearly"))}
        document["keep_within"] = "1m"
        result = self.parse_document(document)
        self.assertEqual(result["retention"], {key: str(value) for key, value in document.items()})

    def test_malformed_flat_retention_fails_without_echoing(self):
        for value in (True, [], {}, 1.5, "fixture-secret-canary", "$(touch /tmp/brolit-template-hook-canary)"):
            with self.subTest(value=value):
                self.assertEqual(self.parse_document({"keep_monthly": value})["status"], "unsupported")

    def test_conflicting_retention_is_not_guessed(self):
        result = self.parse_document({"retention": {"keep_monthly": 1}, "keep_monthly": 6})
        self.assertEqual(result["status"], "unsupported")

    def test_equal_retention_merges_without_losing_nested_keys(self):
        result = self.parse_document({"retention": {"keep_monthly": 6, "keep_daily": 1}, "keep_monthly": 6, "keep_yearly": 1})
        self.assertEqual(result["retention"], {"keep_monthly": "6", "keep_daily": "1", "keep_yearly": "1"})

    def test_unsupported_include_and_recursive_constants_remain_rejected(self):
        for document in (
            {"include": "fixture-secret-canary"},
            {"constants": {"project": "{project}"}, "source_directories": ["/var/www/{project}"]},
            {"constants": {"project": {"value": "fixture-secret-canary"}}},
        ):
            with self.subTest(document=document):
                self.assertIn(self.parse_document(document)["status"], ("invalid", "unsupported"))


if __name__ == "__main__":
    if CANARY.exists():
        raise SystemExit("Canary already exists; use a fresh isolated Docker tmpfs")
    unittest.main()
