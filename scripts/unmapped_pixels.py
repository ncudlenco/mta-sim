"""
Investigate what the pixels that don't byte-match any calibration PNG actually
are. Hypotheses to test:

  1. AA / MSAA edge pixels — blended colors at triangle boundaries → close to
     a calibration color but not byte-equal.
  2. Shader-missed pixels — rendering passes that bypass the shader entirely
     (post-process, overlays, alpha-blended effects) → colors far from any
     calibration.
  3. Multi-layer blending — alpha-blended textures stacking multiple shader
     outputs → intermediate colors between calibration colors.

Reports for a chosen frame:
  * Per-pixel "nearest calibration distance" histogram.
  * Top unmapped colors and their nearest calibration match.
  * Writes a visualization showing where the unmapped pixels are.

Usage:
    python unmapped_pixels.py <spectator-dir> --frame 59
"""
import argparse
import json
import re
from pathlib import Path
import numpy as np
from PIL import Image


def load_cals(spec: Path, fid: int):
    pat = re.compile(r"^frame_(\d+)_calibration_([0-9a-f]{6})\.png$", re.IGNORECASE)
    out = []
    for p in spec.glob(f"frame_{fid:04d}_calibration_*.png"):
        m = pat.match(p.name)
        if not m:
            continue
        h = m.group(2).lower()
        color = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
        out.append((color, np.array(Image.open(p).convert("RGB"), dtype=np.uint8)))
    return out


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("spectator_dir", type=Path)
    p.add_argument("--frame", type=int, default=59)
    p.add_argument("--out", type=Path, default=None)
    args = p.parse_args()

    spec = args.spectator_dir.resolve()
    seg = np.array(Image.open(spec / f"frame_{args.frame:04d}_segmentation.png").convert("RGB"), dtype=np.uint8)
    H, W, _ = seg.shape

    cals = load_cals(spec, args.frame)
    print(f"loaded {len(cals)} calibration PNGs for frame {args.frame}")

    # Mark matched pixels.
    def pack(a):
        return (a[..., 0].astype(np.uint32) << 16) | (a[..., 1].astype(np.uint32) << 8) | a[..., 2].astype(np.uint32)

    seg_p = pack(seg)
    matched = np.zeros((H, W), dtype=bool)
    for color, cal in cals:
        if cal.shape != seg.shape:
            continue
        matched |= (pack(cal) == seg_p)

    n_matched = int(matched.sum())
    n_total = H * W
    n_unmatched = n_total - n_matched
    print(f"matched={n_matched} ({100*n_matched/n_total:.1f}%)  unmatched={n_unmatched} ({100*n_unmatched/n_total:.1f}%)")

    # Per-unmatched-pixel nearest calibration distance.
    unmatched_px = seg[~matched].astype(np.int32)
    if len(unmatched_px) == 0:
        print("no unmatched pixels")
        return

    # Sample up to 200k unmatched pixels for speed (representative if spatially random).
    sample = unmatched_px if len(unmatched_px) <= 200_000 else unmatched_px[np.random.choice(len(unmatched_px), 200_000, replace=False)]

    # Build calibration color set.
    cal_colors = np.array([c for c, _ in cals], dtype=np.int32)
    diff = sample[:, None, :] - cal_colors[None, :, :]
    dists = np.sqrt((diff * diff).sum(axis=2))
    nearest_dist = dists.min(axis=1)

    print(f"\nnearest-calibration distance over {len(sample):,} unmatched pixels:")
    for thresh in (0, 2, 5, 10, 20, 50, 100, 200):
        frac = (nearest_dist <= thresh).mean()
        print(f"  <= {thresh:>4}: {100*frac:>6.2f}%  (cumulative)")

    # Top unmatched colors.
    uniq, counts = np.unique(unmatched_px.reshape(-1, 3), axis=0, return_counts=True)
    order = np.argsort(-counts)
    print(f"\ntop-30 unmatched colors (by pixel count):")
    print(f"  {'count':>10}  {'seg rgb':<18}  {'nearest cal rgb':<18}  {'dist':>6}")
    for i in order[:30]:
        c = tuple(uniq[i].tolist())
        cdiff = cal_colors - np.array(c, dtype=np.int32)
        d = np.sqrt((cdiff * cdiff).sum(axis=1))
        nearest = cal_colors[int(np.argmin(d))].tolist()
        print(f"  {int(counts[i]):>10}  {str(c):<18}  {str(tuple(nearest)):<18}  {float(d.min()):>6.1f}")

    # Write a visualisation: matched = gray, unmatched = red-scale by distance-to-nearest-cal.
    vis = np.zeros((H, W, 3), dtype=np.uint8)
    vis[matched] = (80, 80, 80)

    # For unmatched, color by nearest distance (0=green, far=red).
    flat = seg.reshape(-1, 3).astype(np.int32)
    mask_flat = (~matched).reshape(-1)
    unmatched_indices = np.where(mask_flat)[0]
    sample_idx = unmatched_indices
    if len(sample_idx) > 500_000:
        sample_idx = np.random.choice(sample_idx, 500_000, replace=False)
    sd = flat[sample_idx]
    dd = np.sqrt(((sd[:, None, :] - cal_colors[None, :, :]) ** 2).sum(axis=2)).min(axis=1)
    # Color ramp: 0..20 = green, 20..100 = yellow, 100+ = red
    rr = np.clip(dd * 2.0, 0, 255).astype(np.uint8)
    gg = np.clip(255 - dd * 2.0, 0, 255).astype(np.uint8)
    flat_vis = vis.reshape(-1, 3)
    flat_vis[sample_idx] = np.stack([rr, gg, np.zeros_like(rr)], axis=1)

    out = args.out or (spec / f"frame_{args.frame:04d}_unmapped_debug.png")
    Image.fromarray(vis).save(out)
    print(f"\nwrote {out}")


if __name__ == "__main__":
    main()
