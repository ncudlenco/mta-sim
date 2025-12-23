#!/usr/bin/env python3
"""
Fix all template files to have self-referential nextLocation.id.

For each template:
1. Makes all nextLocation.id values point to the location's own ID
2. Removes orphan locations that have no actions and aren't referenced

Usage:
    python fix_templates.py
"""

import json
import os
from pathlib import Path
from copy import deepcopy


def fix_template_file(filepath):
    """Fix a single template file. Returns (fixed, changes_made) tuple."""
    changes = []

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        return False, [f"Read error: {e}"]

    if not isinstance(data, list):
        return False, ["Not a template array"]

    modified = False

    for template_idx, template in enumerate(data):
        # Collect valid location IDs
        valid_location_ids = set()
        poi = template.get("poi", {})
        if poi.get("id") is not None:
            valid_location_ids.add(poi["id"])

        locations = template.get("locations", [])
        for loc in locations:
            if loc.get("id") is not None:
                valid_location_ids.add(loc["id"])

        # Fix actions in poi
        if poi.get("allActions"):
            poi_id = poi.get("id")
            for action in poi["allActions"]:
                next_loc = action.get("nextLocation", {})
                next_id = next_loc.get("id")
                if next_id is not None and next_id != poi_id:
                    changes.append(f"[template {template_idx}] poi (id={poi_id}): action {action.get('id')} nextLocation.id {next_id} -> {poi_id}")
                    action["nextLocation"]["id"] = poi_id
                    modified = True

        # Fix actions in each location
        for loc in locations:
            loc_id = loc.get("id")
            for action in loc.get("allActions", []):
                next_loc = action.get("nextLocation", {})
                next_id = next_loc.get("id")
                if next_id is not None and next_id != loc_id:
                    changes.append(f"[template {template_idx}] location (id={loc_id}): action {action.get('id')} nextLocation.id {next_id} -> {loc_id}")
                    action["nextLocation"]["id"] = loc_id
                    modified = True

        # Find and remove orphan locations (no actions, not referenced by any action)
        # A location is orphan if it has no allActions and no PossibleActions
        locations_to_remove = []
        for i, loc in enumerate(locations):
            all_actions = loc.get("allActions", [])
            possible_actions = loc.get("PossibleActions", [])
            if len(all_actions) == 0 and len(possible_actions) == 0:
                locations_to_remove.append(i)
                changes.append(f"[template {template_idx}] Removing orphan location id={loc.get('id')} (no actions)")

        # Remove orphans in reverse order to maintain indices
        for i in reversed(locations_to_remove):
            del locations[i]
            modified = True

    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=4)

    return modified, changes


def main():
    base_path = Path(__file__).parent / "files" / "supertemplates"

    if not base_path.exists():
        print(f"ERROR: Directory not found: {base_path}")
        return

    print(f"Fixing templates in: {base_path}")
    print("=" * 80)

    total_files = 0
    files_fixed = 0
    total_changes = 0

    # Find all .json files recursively
    for json_file in sorted(base_path.rglob("*.json")):
        total_files += 1
        relative_path = json_file.relative_to(base_path)

        fixed, changes = fix_template_file(json_file)

        if changes:
            files_fixed += 1
            total_changes += len(changes)
            print(f"\n[FIXED] {relative_path}")
            for change in changes:
                print(f"   {change}")
        else:
            print(f"[OK] {relative_path}")

    print("\n" + "=" * 80)
    print(f"SUMMARY: {total_files} files scanned")
    print(f"  - {files_fixed} files fixed ({total_changes} total changes)")
    print(f"  - {total_files - files_fixed} already OK")


if __name__ == "__main__":
    main()
