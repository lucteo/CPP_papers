#!/usr/bin/env python3

import argparse
import json
import re
import sys

import yaml


CITATION_RE = re.compile(r"(?<![\w.%+-])@([A-Z][A-Za-z0-9._:-]*)(?![\w.-])")
YAML_METADATA_RE = re.compile(r"^---[ \t]*\n(.*?)\n---[ \t]*$", re.MULTILINE | re.DOTALL)


def citation_ids(markdown):
    return {match.group(1) for match in CITATION_RE.finditer(markdown)}


def local_reference_ids(markdown):
    ids = set()
    for match in YAML_METADATA_RE.finditer(markdown):
        metadata = yaml.safe_load(match.group(1))
        if not isinstance(metadata, dict):
            continue

        references = metadata.get("references", [])
        if not isinstance(references, list):
            continue

        for reference in references:
            if isinstance(reference, dict) and "id" in reference:
                ids.add(str(reference["id"]))

    return ids


def main():
    parser = argparse.ArgumentParser(
        description="Filter a CSL JSON bibliography to the citation ids used by a Markdown file."
    )
    parser.add_argument("source")
    parser.add_argument("bibliography")
    parser.add_argument("output")
    args = parser.parse_args()

    with open(args.source, encoding="utf-8") as source_file:
        markdown = source_file.read()

    used_ids = citation_ids(markdown)
    local_ids = local_reference_ids(markdown)

    with open(args.bibliography, encoding="utf-8") as bibliography_file:
        bibliography = json.load(bibliography_file)

    filtered = [
        item for item in bibliography
        if str(item.get("id", "")) in used_ids
    ]
    found_ids = {str(item.get("id", "")) for item in filtered}
    missing_ids = sorted(used_ids - found_ids - local_ids)

    with open(args.output, "w", encoding="utf-8") as output_file:
        json.dump(filtered, output_file, ensure_ascii=False, indent=2)
        output_file.write("\n")

    if missing_ids:
        print(
            "warning: citation ids not found in bibliography: "
            + ", ".join(missing_ids),
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
