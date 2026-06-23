#!/usr/bin/env python3
"""Search Real World OCaml skill references without loading them all."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


LIST_KEYS = {"summary", "load_when", "skip_when", "search_terms"}


def tokenize(text: str) -> list[str]:
    return [t.lower() for t in re.findall(r"[A-Za-z0-9_.'%-]+", text)]


def parse_frontmatter(lines: list[str]) -> tuple[dict[str, object], int]:
    """Parse the small YAML subset used by reference routing metadata."""

    if not lines or lines[0].strip() != "---":
        return {}, 0

    end = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end = idx
            break

    if end is None:
        return {}, 0

    meta: dict[str, object] = {}
    current_key: str | None = None
    for raw in lines[1:end]:
        line = raw.rstrip()
        if not line:
            continue
        if line.startswith("  - ") and current_key:
            value = line[4:].strip().strip("\"'")
            meta.setdefault(current_key, [])
            if isinstance(meta[current_key], list):
                meta[current_key].append(value)
            continue
        if ":" in line and not line.startswith(" "):
            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip().strip("\"'")
            if key not in LIST_KEYS:
                current_key = None
                continue
            if value:
                meta[key] = value
                current_key = None
            else:
                meta[key] = []
                current_key = key

    return meta, end + 1


def meta_text(meta: dict[str, object]) -> str:
    parts: list[str] = []
    for key in ("summary", "load_when", "skip_when", "search_terms"):
        value = meta.get(key)
        if isinstance(value, list):
            parts.extend(str(v) for v in value)
        elif value:
            parts.append(str(value))
    return "\n".join(parts)


def first_list_item(meta: dict[str, object], key: str) -> str:
    value = meta.get(key)
    if isinstance(value, list):
        return value[0] if value else ""
    return str(value) if value else ""


def heading_for(lines: list[str], line_no: int) -> tuple[int, str]:
    for i in range(line_no - 1, -1, -1):
        if lines[i].startswith("#"):
            return i + 1, lines[i].strip()
    return 1, "# Top"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Search reference frontmatter, headings, and content for this skill."
    )
    parser.add_argument("query", nargs="*", help="Search words, e.g. GADT equality witness")
    parser.add_argument("--list", action="store_true", help="Print compact reference index")
    parser.add_argument("--limit", type=int, default=8, help="Maximum matches to print")
    args = parser.parse_args()

    skill_dir = Path(__file__).resolve().parents[1]
    refs_dir = skill_dir / "references"
    ref_paths = sorted(refs_dir.glob("*.md"))

    if args.list:
        for path in ref_paths:
            lines = path.read_text(encoding="utf-8").splitlines()
            meta, _ = parse_frontmatter(lines)
            print(f"{path.name}: {meta.get('summary', '').strip()}")
            load = first_list_item(meta, "load_when")
            terms = meta.get("search_terms")
            if load:
                print(f"  load: {load}")
            if isinstance(terms, list) and terms:
                print(f"  terms: {', '.join(str(t) for t in terms[:8])}")
        return 0

    terms = tokenize(" ".join(args.query))
    if not terms:
        parser.error("query must contain at least one word, or use --list")

    matches: list[tuple[int, str, int, str, int, str]] = []

    for path in ref_paths:
        lines = path.read_text(encoding="utf-8").splitlines()
        meta, body_start = parse_frontmatter(lines)

        routing = meta_text(meta).lower()
        meta_hits = sum(1 for term in terms if term in routing)
        if meta_hits:
            summary = str(meta.get("summary", "")).strip()
            matches.append(
                (
                    meta_hits * 20 + 8,
                    path.name,
                    1,
                    "metadata",
                    1,
                    summary or "frontmatter routing metadata",
                )
            )

        for idx, line in enumerate(lines[body_start:], start=body_start + 1):
            lower = line.lower()
            hits = sum(1 for term in terms if term in lower)
            if hits == 0:
                continue
            heading_line, heading = heading_for(lines, idx)
            score = hits * 10
            if line.startswith("#"):
                score += 6
            if idx <= 40:
                score += 3
            matches.append((score, path.name, heading_line, heading, idx, line.strip()))

    matches.sort(key=lambda m: (-m[0], m[1], m[4]))

    if not matches:
        print("No matches. Try broader terms such as module, dune, result, parser, GADT.")
        return 1

    seen: set[tuple[str, int, int]] = set()
    printed = 0
    for score, file_name, heading_line, heading, line_no, snippet in matches:
        key = (file_name, heading_line, line_no)
        if key in seen:
            continue
        seen.add(key)
        print(f"{file_name}:{line_no} score={score}")
        print(f"  section {heading_line}: {heading}")
        print(f"  {snippet}")
        printed += 1
        if printed >= args.limit:
            break

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
