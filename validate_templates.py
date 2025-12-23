#!/usr/bin/env python3
"""
Validate all template files for self-referential nextLocation.id.

For each template, checks that:
1. All nextLocation.id values reference existing location IDs in the template
2. Actions reference their own location (self-referential pattern)

Usage:
    python validate_templates.py
"""

import json
import os
from pathlib import Path


def validate_template_file(filepath):
    """Validate a single template file. Returns list of issues found."""
    issues = []

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        return [f"JSON parse error: {e}"]
    except Exception as e:
        return [f"Read error: {e}"]

    if not isinstance(data, list):
        return [f"Expected array at root, got {type(data).__name__}"]

    for template_idx, template in enumerate(data):
        # Collect all valid location IDs in this template
        valid_location_ids = set()

        # Add poi.id if exists
        poi = template.get("poi", {})
        if poi.get("id") is not None:
            valid_location_ids.add(poi["id"])

        # Add all location IDs from locations array
        locations = template.get("locations", [])
        for loc in locations:
            if loc.get("id") is not None:
                valid_location_ids.add(loc["id"])

        # Check all actions in poi
        if poi.get("allActions"):
            poi_id = poi.get("id")
            for action in poi["allActions"]:
                next_loc = action.get("nextLocation", {})
                next_id = next_loc.get("id")
                if next_id is not None:
                    if next_id not in valid_location_ids:
                        issues.append(f"[template {template_idx}] poi (id={poi_id}): action {action.get('id')} has nextLocation.id={next_id} which doesn't exist in template (valid: {sorted(valid_location_ids)})")
                    elif next_id != poi_id:
                        issues.append(f"[template {template_idx}] poi (id={poi_id}): action {action.get('id')} has nextLocation.id={next_id} != self ({poi_id}) - NOT SELF-REFERENTIAL")

        # Check all actions in each location
        for loc in locations:
            loc_id = loc.get("id")
            for action in loc.get("allActions", []):
                next_loc = action.get("nextLocation", {})
                next_id = next_loc.get("id")
                if next_id is not None:
                    if next_id not in valid_location_ids:
                        issues.append(f"[template {template_idx}] location (id={loc_id}): action {action.get('id')} has nextLocation.id={next_id} which doesn't exist in template (valid: {sorted(valid_location_ids)})")
                    elif next_id != loc_id:
                        issues.append(f"[template {template_idx}] location (id={loc_id}): action {action.get('id')} has nextLocation.id={next_id} != self ({loc_id}) - NOT SELF-REFERENTIAL")

    return issues


def main():
    base_path = Path(__file__).parent / "files" / "supertemplates"

    if not base_path.exists():
        print(f"ERROR: Directory not found: {base_path}")
        return

    print(f"Scanning templates in: {base_path}")
    print("=" * 80)

    total_files = 0
    files_with_issues = 0
    total_issues = 0

    # Find all .json files recursively
    for json_file in sorted(base_path.rglob("*.json")):
        total_files += 1
        relative_path = json_file.relative_to(base_path)

        issues = validate_template_file(json_file)

        if issues:
            files_with_issues += 1
            total_issues += len(issues)
            print(f"\n[ERROR] {relative_path}")
            for issue in issues:
                print(f"   {issue}")
        else:
            print(f"[OK] {relative_path}")

    print("\n" + "=" * 80)
    print(f"SUMMARY: {total_files} files scanned")
    print(f"  - {total_files - files_with_issues} OK")
    print(f"  - {files_with_issues} files with issues ({total_issues} total issues)")


if __name__ == "__main__":
    main()
