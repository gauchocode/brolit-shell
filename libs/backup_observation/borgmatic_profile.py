#!/usr/bin/env python3
# Author: GauchoCode
# Version: 0.1.0
"""Backup observation Borgmatic configuration profile (pyyaml-5.x).

Read-only, non-executing parser for the supported Borgmatic subset. Unknown
YAML tags, includes and non-scalar constants are rejected explicitly; hooks
are never executed or evaluated. Also converts naive local timestamps to UTC
for the wire contract.
"""

import json
import hashlib
import hmac
import re
import sys

MAX_FILE_BYTES = 262144
TOKEN_RE = re.compile(r"\{([A-Za-z0-9_]+)\}")
LEFTOVER_TOKEN_RE = re.compile(r"\{[^{}]*\}")


def fail(status, message):
    json.dump({"status": status, "error": message}, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")
    sys.exit(0)


def parse_yml(path):
    try:
        import yaml
    except ImportError:
        fail("unsupported", "safe YAML parser is unavailable")
    try:
        parser_version = tuple(int(part) for part in yaml.__version__.split(".")[:2])
    except (AttributeError, ValueError):
        fail("unsupported", "safe YAML parser version is unknown")
    if parser_version < (5, 4):
        fail("unsupported", "safe YAML parser version is outside the tested profile")

    try:
        with open(path, "rb") as handle:
            raw = handle.read(MAX_FILE_BYTES + 1)
    except OSError:
        fail("invalid", "configuration file is unreadable")
    if len(raw) > MAX_FILE_BYTES:
        fail("invalid", "configuration file exceeds the parser budget")

    try:
        document = yaml.safe_load(raw.decode("utf-8"))
    except (yaml.YAMLError, UnicodeDecodeError):
        fail("invalid", "YAML is invalid or uses unsupported constructs")

    if not isinstance(document, dict):
        fail("invalid", "configuration is not a mapping")

    if document.get("include") or document.get("include_from"):
        fail("unsupported", "configuration includes are not supported by this profile")
    if document.get("constants") is not None and not isinstance(document.get("constants"), dict):
        fail("unsupported", "constants must be a mapping")

    constants = {}
    raw_constants = document.get("constants", {})
    if raw_constants is not None:
        for key, value in raw_constants.items():
            if not isinstance(key, str) or not re.fullmatch(r"[A-Za-z0-9_]+", key):
                fail("unsupported", "constant names must be simple identifiers")
            if isinstance(value, bool) or value is None:
                fail("unsupported", "constant values must be strings or numbers")
            if isinstance(value, (int, float)):
                value = str(value)
            if not isinstance(value, str):
                fail("unsupported", "constant values must be scalar")
            if len(value) > 512:
                fail("unsupported", "constant values exceed the length bound")
            constants[key] = value

    def substitute(text):
        resolved = TOKEN_RE.sub(lambda m: constants.get(m.group(1), m.group(0)), text)
        if LEFTOVER_TOKEN_RE.search(resolved):
            return None
        return resolved

    repositories = []
    raw_repositories = document.get("repositories", [])
    if raw_repositories is None:
        raw_repositories = []
    if not isinstance(raw_repositories, list):
        fail("invalid", "repositories must be a list")
    for entry in raw_repositories:
        if isinstance(entry, str):
            path_value, label = entry, None
        elif isinstance(entry, dict) and isinstance(entry.get("path"), str):
            path_value = entry["path"]
            label = entry.get("label") if isinstance(entry.get("label"), str) else None
        else:
            fail("unsupported", "repository entries must be paths or mappings")
        resolved = substitute(path_value)
        if resolved is None:
            fail("invalid", "repository path references an unresolved constant")
        repositories.append({"path": resolved, "label": label})

    sources = []
    raw_sources = document.get("source_directories", [])
    if isinstance(raw_sources, list):
        for entry in raw_sources:
            if not isinstance(entry, str):
                fail("unsupported", "source directories must be strings")
            resolved = substitute(entry)
            if resolved is None:
                fail("invalid", "source directory references an unresolved constant")
            sources.append(resolved)

    retention = None
    raw_retention = document.get("retention")
    if isinstance(raw_retention, dict):
        retention = {}
        for key, value in raw_retention.items():
            if isinstance(value, bool) or not isinstance(value, (int, float, str)):
                fail("unsupported", "retention values must be scalar")
            retention[str(key)] = str(value)

    database_hints = []
    if isinstance(document.get("mysql_databases"), list) and document["mysql_databases"]:
        database_hints.append("mysql")
    if isinstance(document.get("mariadb_databases"), list) and document["mariadb_databases"]:
        database_hints.append("mariadb")
    if isinstance(document.get("postgresql_databases"), list) and document["postgresql_databases"]:
        database_hints.append("postgresql")

    json.dump({
        "status": "ok",
        "error": None,
        "repositories": repositories,
        "source_directories": sources,
        "database_hints": database_hints,
        "has_hooks": isinstance(document.get("hooks"), dict),
        "retention": retention,
        "project": constants.get("project") or None,
        "hostname": constants.get("hostname") or None,
        "group": constants.get("group") or None,
    }, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")


def to_utc(naive, timezone_name):
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?", naive):
        fail("invalid", "naive timestamp has an unexpected shape")
    if not re.fullmatch(r"[A-Za-z0-9_+\-/]+", timezone_name or ""):
        fail("invalid", "timezone name has an unexpected shape")
    try:
        from datetime import datetime
        from zoneinfo import ZoneInfo
        local = datetime.fromisoformat(naive).replace(tzinfo=ZoneInfo(timezone_name))
        utc = local.astimezone(ZoneInfo("UTC"))
        rendered = utc.strftime("%Y-%m-%dT%H:%M:%S")
        millis = f"{utc.microsecond // 1000:03d}"
        json.dump({"status": "ok", "error": None, "value": f"{rendered}.{millis}Z"}, sys.stdout, separators=(",", ":"))
        sys.stdout.write("\n")
    except Exception:
        fail("invalid", "timestamp cannot be converted with the configured timezone")


def hmac_sha256():
    raw = sys.stdin.buffer.read()
    if b"\0" not in raw:
        fail("invalid", "HMAC input is malformed")
    key, message = raw.split(b"\0", 1)
    if not key or len(key) > 4096 or len(message) > 16384:
        fail("invalid", "HMAC input exceeds the bound")
    sys.stdout.write(hmac.new(key, message, hashlib.sha256).hexdigest() + "\n")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "parse-yml":
        parse_yml(sys.argv[2])
    elif len(sys.argv) == 4 and sys.argv[1] == "to-utc":
        to_utc(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 2 and sys.argv[1] == "hmac":
        hmac_sha256()
    else:
        sys.exit(2)
