#!/usr/bin/env python3
"""Validates feed data files for freshness, structure, and content.

Used by GitHub Actions workflows to catch broken feeds before they silently
go stale. Exits non-zero on any failure so the workflow can react.

Usage:
  python3 .github/scripts/validate_feeds.py [--stale-hours N]

Options:
  --stale-hours N   Max age (in hours) for Strava fetched_at before data is
                    considered stale. Default: 36.
"""

import argparse
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DATA_DIR = REPO_ROOT / "_data"

STRAVA_FILE = DATA_DIR / "strava.yml"
GOODREADS_FILE = DATA_DIR / "recently_read.yml"

DEFAULT_STALE_HOURS = 36


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)


def validate_strava(stale_hours: int) -> list[str]:
    errors: list[str] = []

    if not STRAVA_FILE.exists():
        errors.append("strava.yml is missing — fetch may not have run")
        return errors

    with open(STRAVA_FILE) as f:
        data = yaml.safe_load(f)

    if not isinstance(data, dict):
        errors.append("strava.yml is not a valid YAML mapping")
        return errors

    # Freshness check
    fetched_at = data.get("fetched_at")
    if not fetched_at:
        errors.append("strava.yml missing 'fetched_at' timestamp")
    else:
        try:
            ts = datetime.fromisoformat(str(fetched_at).replace("Z", "+00:00"))
            age = datetime.now(timezone.utc) - ts
            if age > timedelta(hours=stale_hours):
                errors.append(
                    f"Strava data is {age.total_seconds() / 3600:.1f}h old "
                    f"(threshold: {stale_hours}h)"
                )
        except (ValueError, TypeError) as e:
            errors.append(f"Cannot parse fetched_at '{fetched_at}': {e}")

    # Activities check
    activities = data.get("activities")
    if not activities:
        errors.append("strava.yml has no activities — may be empty or malformed")
    elif not isinstance(activities, list):
        errors.append(f"strava.yml 'activities' is {type(activities).__name__}, expected list")
    else:
        for i, act in enumerate(activities):
            if not isinstance(act, dict):
                errors.append(f"Activity[{i}] is not a mapping")
                continue
            for key in ("id", "name", "type", "start_date"):
                if key not in act or act[key] is None:
                    errors.append(f"Activity[{i}] ('{act.get('name', '?')}') missing '{key}'")

    return errors


def validate_goodreads() -> list[str]:
    errors: list[str] = []

    if not GOODREADS_FILE.exists():
        errors.append("recently_read.yml is missing — Goodreads fetch may not have run")
        return errors

    with open(GOODREADS_FILE) as f:
        data = yaml.safe_load(f)

    if not isinstance(data, dict):
        errors.append("recently_read.yml is not a valid YAML mapping")
        return errors

    books = data.get("books")
    if not books:
        errors.append("recently_read.yml has no books — feed may be empty or broken")
    elif not isinstance(books, list):
        errors.append(f"recently_read.yml 'books' is {type(books).__name__}, expected list")
    else:
        for i, book in enumerate(books):
            if not isinstance(book, dict):
                errors.append(f"Book[{i}] is not a mapping")
                continue
            for key in ("title", "link"):
                if key not in book or not book[key]:
                    errors.append(f"Book[{i}] missing '{key}'")

    return errors


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate feed data files")
    parser.add_argument(
        "--stale-hours",
        type=int,
        default=DEFAULT_STALE_HOURS,
        help=f"Max age in hours for Strava fetched_at (default: {DEFAULT_STALE_HOURS})",
    )
    args = parser.parse_args()

    all_errors: list[str] = []

    print("Validating Strava data...")
    strava_errors = validate_strava(args.stale_hours)
    if strava_errors:
        all_errors.extend(strava_errors)
    else:
        print("  OK")

    print("Validating Goodreads data...")
    goodreads_errors = validate_goodreads()
    if goodreads_errors:
        all_errors.extend(goodreads_errors)
    else:
        print("  OK")

    if all_errors:
        print(f"\n{len(all_errors)} validation error(s):", file=sys.stderr)
        for err in all_errors:
            fail(err)
        sys.exit(1)

    print("\nAll feed data is healthy.")


if __name__ == "__main__":
    main()
