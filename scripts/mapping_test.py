"""
Diagnostic: for a chosen segmentation frame, measure how well the raw PNG pixel
colors match the input colors in segmentation_mapping.json.

Identity mapping works iff most PNG pixels are at (near-)zero distance from a
mapping color. If distances are large and/or bimodal we need a calibrated
transform (gamma / LUT) before the lookup.

Usage:
    python mapping_test.py <spectator-dir> [--frame N]
"""
import argparse
import json
from collections import Counter
from pathlib import Path
import numpy as np
from PIL import Image


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("spectator_dir", type=Path)
    p.add_argument("--frame", type=int, default=70)
    args = p.parse_args()

    spec = args.spectator_dir.resolve()
    seg_path = spec / f"frame_{args.frame:04d}_segmentation.png"
    map_path = spec / "segmentation_mapping.json"

    with map_path.open() as f:
        mapping = json.load(f)
    if isinstance(mapping, list) and len(mapping) == 1:
        mapping = mapping[0]

    # Build table of mapping colors.
    color_rows = []
    for tex, entry in mapping.items():
        c = entry.get("color")
        if c and len(c) == 3:
            color_rows.append((tex, tuple(int(v) for v in c)))
    mapping_colors = np.array([c for _, c in color_rows], dtype=np.int32)
    print(f"{len(color_rows)} mapping entries with colors")

    arr = np.array(Image.open(seg_path).convert("RGB"), dtype=np.int32)
    H, W, _ = arr.shape
    flat = arr.reshape(-1, 3)
    uniq, inv, counts = np.unique(flat, axis=0, return_inverse=True, return_counts=True)
    print(f"frame {args.frame}: {H}x{W} = {H*W} px, {len(uniq)} unique colors")

    # For each unique color, nearest mapping color by L2 distance.
    diff = uniq[:, None, :] - mapping_colors[None, :, :]       # (U, M, 3)
    dist = np.sqrt((diff * diff).sum(axis=2))                  # (U, M)
    nearest_idx = np.argmin(dist, axis=1)
    nearest_dist = dist[np.arange(len(uniq)), nearest_idx]

    # Pixel-weighted histogram of distance-to-nearest-mapping.
    total = int(counts.sum())
    print()
    print("pixels whose nearest-mapping distance <= T:")
    print(f"{'T':>4} {'n_px':>12} {'%':>7} {'n_colors':>10}")
    for T in (0, 1, 2, 5, 10, 20, 50, 100):
        mask = nearest_dist <= T
        px = int(counts[mask].sum())
        ncol = int(mask.sum())
        print(f"{T:>4} {px:>12} {100*px/total:>6.2f}% {ncol:>10}")

    # Top-30 most-common unique PNG colors: nearest mapping match.
    print()
    print("top-30 unique colors by pixel count:")
    print(f"{'rank':>4} {'png rgb':>18} {'count':>10} {'nearest tex':<25} {'map rgb':>18} {'dist':>7}")
    order = np.argsort(-counts)[:30]
    for rank, i in enumerate(order, 1):
        tex, mc = color_rows[nearest_idx[i]]
        print(f"{rank:>4} {str(tuple(uniq[i].tolist())):>18} {int(counts[i]):>10} "
              f"{tex:<25} {str(mc):>18} {nearest_dist[i]:>7.1f}")

    # Identify unmapped-region dominant color and ped/object pixels.
    # Print how many pixels match any of the ped textures (shared across all peds).
    ped_texs = {"cj_ped_head", "cj_ped_torso", "cj_ped_legs", "cj_ped_feet"}
    ped_indices = [i for i, (tex, _) in enumerate(color_rows) if tex in ped_texs]
    print()
    print("pixels assigned (nearest) to each ped texture (at <=20 RGB distance):")
    for i in ped_indices:
        tex, mc = color_rows[i]
        ent_mask = (nearest_idx == i) & (nearest_dist <= 20)
        px = int(counts[ent_mask].sum())
        print(f"  {tex:<20} map {mc}  -> {px} px")


if __name__ == "__main__":
    main()
