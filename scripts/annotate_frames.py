"""
Overlay pose skeletons / spatial-relation markers onto screenshots, or produce
human-readable depth-visualisations, for a single spectator directory.

Input  : <story-dir>/<spectator-id>/ containing frame_XXXX_screenshot.jpg,
         frame_XXXX_pose.json, frame_XXXX_spatial_relations.json,
         frame_XXXX_depth.png, and coord_space.json (written once by
         CoordSpaceWriter).
Output : <story-dir>/<spectator-id>_annotated/ for overlay modes, or
         <story-dir>/<spectator-id>_depth_viz/ for depth visualisation.

The coord_space.json is authoritative for the viewport -> saved-image mapping;
this script does not hardcode any resolutions or crop constants.

Usage:
    python annotate_frames.py <spectator-dir>
    python annotate_frames.py <spectator-dir> --mode skeleton
    python annotate_frames.py <spectator-dir> --mode spatial
    python annotate_frames.py <spectator-dir> --mode both         # default: skel+spatial
    python annotate_frames.py <spectator-dir> --mode depth-viz    # per-frame depth visualisation
    python annotate_frames.py <spectator-dir> --frames 40-60
    python annotate_frames.py <spectator-dir> --modality 0

Depth-viz options (only apply when --mode depth-viz):
    --depth-viz-mode {turbo,magma,viridis,grayscale}  colormap (default: turbo)
    --depth-percentiles P_LO,P_HI                     percentile clip (default: 2,98)
    --depth-far-threshold F                           raw-depth exclusion (default: 0.9995)
    --depth-scale-bar / --no-depth-scale-bar          overlay a small scale bar (default: on)
"""
import argparse
import json
import os
import re
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont


# Bone connections (names must match POSE_JOINT_NAMES in ClientPoseHandler.lua).
# Each tuple is (from_bone, to_bone, side) where side in {"L", "R", "C"}.
SKELETON_EDGES = [
    ("head", "neck", "C"),
    ("neck", "spine", "C"),
    ("spine", "pelvis", "C"),
    ("neck", "left_shoulder", "L"),
    ("neck", "right_shoulder", "R"),
    ("left_shoulder", "left_elbow", "L"),
    ("left_elbow", "left_hand", "L"),
    ("right_shoulder", "right_elbow", "R"),
    ("right_elbow", "right_hand", "R"),
    ("pelvis", "left_hip", "L"),
    ("pelvis", "right_hip", "R"),
    ("left_hip", "left_knee", "L"),
    ("left_knee", "left_ankle", "L"),
    ("left_ankle", "left_foot", "L"),
    ("right_hip", "right_knee", "R"),
    ("right_knee", "right_ankle", "R"),
    ("right_ankle", "right_foot", "R"),
]

SIDE_COLOR = {
    "L": (255, 80, 80),    # red-ish — left side
    "R": (80, 160, 255),   # blue-ish — right side
    "C": (120, 255, 120),  # green — midline
}
INVISIBLE_ALPHA = 70       # for occluded/off-frame keypoints

PED_MARKER = (255, 220, 0)
OBJECT_MARKER = (0, 200, 255)
INVISIBLE_MARKER = (150, 150, 150)


def load_coord_space(spectator_dir: Path):
    """Load coord_space.json if present, else return None.

    Absence means the capture backend didn't need a transform at all (e.g. the
    multimodal path captures at GTA viewport resolution with no crop and no
    resize). Callers should treat a nil result as 'identity transform'.
    """
    path = spectator_dir / "coord_space.json"
    if not path.exists():
        return None
    with path.open() as f:
        data = json.load(f)
    # The Lua writer emits a single-element array (MTA's toJSON quirk).
    if isinstance(data, list):
        data = data[0]
    return data


def _sniff_image_size(spectator_dir: Path):
    """Find any frame_XXXX_screenshot.jpg (or segmentation.png) to learn the
    saved-image dimensions. Used as the identity-transform fallback when
    coord_space.json is absent."""
    for pat in ("frame_*_screenshot.jpg", "frame_*_segmentation.png",
                "frame_*_depth.png"):
        for p in sorted(spectator_dir.glob(pat)):
            with Image.open(p) as im:
                return im.size  # (w, h)
    raise RuntimeError(f"No screenshots/segmentation/depth frames found in {spectator_dir}")


def _sniff_projection_size(spectator_dir: Path):
    """Find the `resolution` block in the first spatial/pose JSON to learn
    the viewport dims the server actually projected against. Returns (w, h)
    or None if no JSON is available."""
    for pat in ("frame_*_spatial_relations.json", "frame_*_pose.json"):
        for p in sorted(spectator_dir.glob(pat)):
            try:
                with p.open() as f:
                    data = json.load(f)
                if isinstance(data, list):
                    data = data[0]
                res = data.get("resolution")
                if res and res.get("width") and res.get("height"):
                    return int(res["width"]), int(res["height"])
            except Exception:
                continue
    return None


def build_transform(coord_space, spectator_dir: Path, modality_id: int):
    """Return a callable (x_vp, y_vp) -> (x_img, y_img) for the chosen modality.

    If coord_space is None, derive the transform from the JSONs and images
    directly: the JSON's `resolution` block is the space the server projected
    into, and the saved image's dimensions are where we draw. These may not
    match (e.g. multimodal capture at 1920×1080 while the server fell back to
    WIDTH_RESOLUTION=1917×1040), so we scale both axes accordingly.
    """
    if coord_space is None:
        # Server now projects client-side via getScreenFromWorldPosition, so
        # screen.x/y in every JSON are already in the saved-image pixel space.
        # When coord_space.json is missing we just trust the JSONs and draw at
        # 1:1 against whatever the actual screenshot dims are.
        img_w, img_h = _sniff_image_size(spectator_dir)
        vr = {"x": 0, "y": 0, "w": img_w, "h": img_h}
        saved = {"w": img_w, "h": img_h}

        def _t(x_vp, y_vp):
            return (x_vp, y_vp)

        return _t, vr, saved

    vr = coord_space["visibleRect"]
    saved = coord_space["savedDims"].get(str(modality_id)) \
        or coord_space["savedDims"].get(modality_id)
    if not saved:
        raise ValueError(f"No savedDims for modality {modality_id}. "
                         f"Available: {list(coord_space['savedDims'].keys())}")
    sx = saved["w"] / vr["w"]
    sy = saved["h"] / vr["h"]
    vx, vy = vr["x"], vr["y"]

    def _t(x_vp, y_vp):
        return ((x_vp - vx) * sx, (y_vp - vy) * sy)

    return _t, vr, saved


def inside_visible_rect(x_vp, y_vp, vr) -> bool:
    return (vr["x"] <= x_vp < vr["x"] + vr["w"]
            and vr["y"] <= y_vp < vr["y"] + vr["h"])


def load_frame_payload(path: Path):
    """Load a JSON file and strip the outer single-element array wrapper."""
    if not path.exists():
        return None
    with path.open() as f:
        data = json.load(f)
    if isinstance(data, list):
        return data[0] if data else None
    return data


def parse_frame_range(s: str):
    if not s or s == "all":
        return None
    m = re.match(r"^(\d+)(?:-(\d+))?$", s)
    if not m:
        raise argparse.ArgumentTypeError(f"Invalid --frames value: {s}")
    lo = int(m.group(1))
    hi = int(m.group(2)) if m.group(2) else lo
    return lo, hi


def frame_id_from_name(name: str):
    m = re.match(r"^frame_(\d+)_", name)
    return int(m.group(1)) if m else None


def iter_frames(spectator_dir: Path, frame_range):
    """Yield frame IDs that have a screenshot, sorted, within the optional range."""
    for p in sorted(spectator_dir.glob("frame_*_screenshot.jpg")):
        fid = frame_id_from_name(p.name)
        if fid is None:
            continue
        if frame_range is not None and not (frame_range[0] <= fid <= frame_range[1]):
            continue
        yield fid


def _iter_depth_frames(spectator_dir: Path, frame_range):
    """Yield frame IDs for every frame_XXXX_depth.png, within the optional
    range. Mirrors iter_frames() but keyed on the depth filename pattern."""
    for p in sorted(spectator_dir.glob("frame_*_depth.png")):
        fid = frame_id_from_name(p.name)
        if fid is None:
            continue
        if frame_range is not None and not (frame_range[0] <= fid <= frame_range[1]):
            continue
        yield fid


def try_font(size: int):
    for name in ("arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def draw_skeleton(draw: ImageDraw.ImageDraw, pose: dict, transform):
    bones = {b["name"]: b for b in pose.get("bones", []) or []}
    pts = {}
    for name, b in bones.items():
        s = b.get("screen") or {}
        if s.get("x") is None or s.get("y") is None:
            continue
        x, y = transform(s["x"], s["y"])
        pts[name] = (x, y, bool(b.get("visible")))

    # Edges first (under the joints).
    for a, b, side in SKELETON_EDGES:
        if a not in pts or b not in pts:
            continue
        ax, ay, av = pts[a]
        bx, by, bv = pts[b]
        color = SIDE_COLOR[side]
        # If both endpoints invisible, fade. If one invisible, draw dashed-ish.
        if av and bv:
            draw.line([(ax, ay), (bx, by)], fill=color + (255,), width=3)
        else:
            draw.line([(ax, ay), (bx, by)], fill=color + (INVISIBLE_ALPHA,), width=2)

    # Joints on top.
    for name, (x, y, v) in pts.items():
        r = 4
        fill = (255, 255, 255) if v else (180, 180, 180)
        outline = (0, 0, 0)
        draw.ellipse([x - r, y - r, x + r, y + r],
                     fill=fill + (255 if v else INVISIBLE_ALPHA,),
                     outline=outline)

    # Actor label at the head (or neck fallback) in viewport-coord order.
    label = pose.get("storyActorId") or "?"
    action = pose.get("currentActionName")
    if action:
        label = f"{label} · {action}"
    anchor = pts.get("head") or pts.get("neck") or next(iter(pts.values()), None)
    if anchor:
        x, y, _ = anchor
        draw.text((x + 8, y - 12), label,
                  fill=(255, 255, 255, 255),
                  stroke_width=2, stroke_fill=(0, 0, 0, 255),
                  font=FONT_SMALL)


def _build_spatial_index(spectator_dir: Path):
    """Sorted list of (frame_id, path) for every frame_XXXX_spatial_relations.json
    in the directory. Spatial-relations captures are deduplicated on the Lua
    side (only written when content changes), so many frame IDs have no exact
    match — callers should fall back to the most recent one at or before the
    target frame."""
    out = []
    for p in sorted(spectator_dir.glob("frame_*_spatial_relations.json")):
        fid = frame_id_from_name(p.name)
        if fid is not None:
            out.append((fid, p))
    return out


def _spatial_for_frame(spatial_index, spatial_cache, frame_id):
    """Return the loaded spatial-relations payload applicable to `frame_id`:
    the most recent `(fid, path)` in `spatial_index` with `fid <= frame_id`.
    Uses `spatial_cache` (path -> data) to avoid re-reading the same JSON
    across a deduplicated run of frames."""
    latest_path = None
    for fid, path in spatial_index:
        if fid > frame_id:
            break
        latest_path = path
    if latest_path is None:
        return None
    cached = spatial_cache.get(latest_path)
    if cached is None:
        cached = load_frame_payload(latest_path)
        spatial_cache[latest_path] = cached
    return cached


def _pose_bbox_by_actor(pose: dict):
    """Build {storyActorId -> screenRect} from the per-pose bone screen coords.
    This gives pose-accurate ped bounding boxes (head-to-foot of the *current*
    pose, not the T-pose mesh bbox `getElementBoundingBox` returns, which on
    peds is just the feet/collision volume). Bones with nil screen coords are
    skipped."""
    out = {}
    for p in pose.get("poses", []) or []:
        actor_id = p.get("storyActorId")
        if not actor_id:
            continue
        xs, ys = [], []
        for b in p.get("bones", []) or []:
            s = b.get("screen") or {}
            if s.get("x") is not None and s.get("y") is not None:
                xs.append(s["x"])
                ys.append(s["y"])
        if len(xs) < 2:
            continue
        out[actor_id] = {
            "x": min(xs), "y": min(ys),
            "w": max(xs) - min(xs), "h": max(ys) - min(ys),
        }
    return out


def draw_spatial_entities(draw: ImageDraw.ImageDraw, spatial: dict, transform, vr,
                          pose_bboxes: dict = None, draw_object_bboxes: bool = False):
    pose_bboxes = pose_bboxes or {}
    for ent in spatial.get("entities", []) or []:
        s = ent.get("spatial") or {}
        sc = s.get("screen") or {}

        # Peds get a pose-bone-derived bbox (head-to-foot envelope of the
        # actual animated pose). Objects get the raw getElementBoundingBox
        # rectangle only when the caller opts in via draw_object_bboxes — the
        # mesh bbox often doesn't enclose the visible silhouette (authored
        # origins are frequently offset from the mesh) so it's misleading as
        # a default. The full `spatial.bbox` block stays in the JSON either
        # way for programmatic consumers.
        rect = None
        if ent.get("elementType") == "ped":
            actor_id = ent.get("storyActorId")
            if actor_id and actor_id in pose_bboxes:
                rect = pose_bboxes[actor_id]
        elif draw_object_bboxes:
            bbox = s.get("bbox") or {}
            rect = bbox.get("screenRectClipped") or bbox.get("screenRect")

        # Note: the center screen coord (`sc`) may be nil if the bbox center
        # projects behind the camera; in that case the entity can still have
        # visible corners to draw. We only skip when there is literally
        # nothing to render.
        has_center = sc.get("x") is not None and sc.get("y") is not None
        has_rect = bool(rect) and rect.get("w", 0) > 0 and rect.get("h", 0) > 0
        if not has_center and not has_rect:
            continue

        visible = bool(s.get("visible"))
        if ent.get("elementType") == "ped":
            base = PED_MARKER
            label = ent.get("storyActorId") or "ped"
        else:
            base = OBJECT_MARKER
            label = ent.get("objectType") or ent.get("storyObjectId") or ent.get("elementType")

        color = base if visible else INVISIBLE_MARKER
        alpha = 255 if visible else 120

        # 2D bbox outline (no fill — fill is reserved for the segmentation
        # instance layer). Drawn first so the center dot+label sit on top.
        if has_rect:
            bx0, by0 = transform(rect["x"], rect["y"])
            bx1, by1 = transform(rect["x"] + rect["w"], rect["y"] + rect["h"])
            if bx1 < bx0:
                bx0, bx1 = bx1, bx0
            if by1 < by0:
                by0, by1 = by1, by0
            if bx1 - bx0 >= 2 and by1 - by0 >= 2:
                draw.rectangle([bx0, by0, bx1 - 1, by1 - 1],
                               outline=color + (alpha,), width=2)

        if has_center:
            x, y = transform(sc["x"], sc["y"])
            r = 6
            draw.ellipse([x - r, y - r, x + r, y + r],
                         outline=color + (alpha,), width=2)
            draw.line([(x - r - 2, y), (x + r + 2, y)], fill=color + (alpha,), width=1)
            draw.line([(x, y - r - 2), (x, y + r + 2)], fill=color + (alpha,), width=1)

            dist = s.get("distance")
            dist_str = f"  {dist:.1f}m" if isinstance(dist, (int, float)) else ""
            draw.text((x + 8, y + 4), f"{label}{dist_str}",
                      fill=(255, 255, 255, alpha),
                      stroke_width=2, stroke_fill=(0, 0, 0, 255),
                      font=FONT_SMALL)
        elif has_rect:
            # Center behind camera but bbox is still drawable — put the label
            # at the rect's top-left corner so you can still identify it.
            bx0, by0 = transform(rect["x"], rect["y"])
            dist = s.get("distance")
            dist_str = f"  {dist:.1f}m" if isinstance(dist, (int, float)) else ""
            draw.text((bx0 + 4, by0 + 2), f"{label}{dist_str}",
                      fill=(255, 255, 255, alpha),
                      stroke_width=2, stroke_fill=(0, 0, 0, 255),
                      font=FONT_SMALL)


def draw_visible_rect(draw: ImageDraw.ImageDraw, transform, vr, saved):
    """Outline the visibleRect on the saved image (post-resize). Since the
    resize stretches vr -> saved, the outline should hug the image border."""
    x0, y0 = transform(vr["x"], vr["y"])
    x1, y1 = transform(vr["x"] + vr["w"], vr["y"] + vr["h"])
    draw.rectangle([x0, y0, x1 - 1, y1 - 1],
                   outline=(200, 200, 200, 120), width=1)


def annotate_frame(frame_id: int, spectator_dir: Path, out_dir: Path,
                   mode: str, transform, vr, saved,
                   spatial_index=None, spatial_cache=None,
                   draw_object_bboxes: bool = False):
    screenshot = spectator_dir / f"frame_{frame_id:04d}_screenshot.jpg"
    pose_path = spectator_dir / f"frame_{frame_id:04d}_pose.json"

    if not screenshot.exists():
        return False

    img = Image.open(screenshot).convert("RGBA")
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")

    draw_visible_rect(draw, transform, vr, saved)

    # Load pose once so we can both draw skeletons and feed pose-derived
    # ped bboxes into the spatial overlay.
    pose = load_frame_payload(pose_path) if mode in ("skeleton", "both", "spatial") else None
    pose_bboxes = _pose_bbox_by_actor(pose) if pose else {}

    if mode in ("spatial", "both"):
        # Spatial-relations files are deduplicated — the most recent entry at
        # or before the current frame is still valid for every frame after it
        # until the next entry supersedes it.
        if spatial_index is not None and spatial_cache is not None:
            spatial = _spatial_for_frame(spatial_index, spatial_cache, frame_id)
        else:
            # Fallback for direct callers: exact-frame lookup only.
            exact = spectator_dir / f"frame_{frame_id:04d}_spatial_relations.json"
            spatial = load_frame_payload(exact)
        if spatial:
            draw_spatial_entities(draw, spatial, transform, vr, pose_bboxes,
                                  draw_object_bboxes=draw_object_bboxes)

    if mode in ("skeleton", "both") and pose:
        for p in pose.get("poses", []) or []:
            draw_skeleton(draw, p, transform)

    # Frame ID watermark top-left.
    draw.text((10, 10), f"frame {frame_id:04d}",
              fill=(255, 255, 255, 255),
              stroke_width=2, stroke_fill=(0, 0, 0, 255),
              font=FONT_LARGE)

    composite = Image.alpha_composite(img, overlay).convert("RGB")
    out_path = out_dir / f"frame_{frame_id:04d}_annotated.jpg"
    composite.save(out_path, quality=92)
    return True


# ---------------------------------------------------------------------------
# Depth visualisation
# ---------------------------------------------------------------------------

DEPTH_FAR_THRESHOLD = 0.9995       # pixels >= this are treated as sky / unpinned
DEPTH_NEUTRAL_GREY = (128, 128, 128)


def _load_depth_raw(path: Path) -> np.ndarray:
    """Load frame_XXXX_depth.png as a float32 array in [0, 1].

    GTA:SA depth captures land on disk as 8-bit grayscale, 8-bit RGB (R==G==B),
    or 16-bit `I`-mode PNGs depending on the backend. Normalise based on mode
    so any of those produce the same [0, 1] range without silently rescaling.
    """
    im = Image.open(path)
    if im.mode == "L":
        return np.array(im, dtype=np.float32) / 255.0
    if im.mode in ("I", "I;16"):
        return np.array(im, dtype=np.float32) / 65535.0
    # RGB / RGBA: depth is encoded as grayscale replicated to channels; take
    # the L-conversion (itu601 weights don't matter when R==G==B).
    return np.array(im.convert("L"), dtype=np.float32) / 255.0


def _apply_depth_colormap(vis_linear: np.ndarray, colormap: str) -> np.ndarray:
    """Map a [0, 1] float image to (H, W, 3) uint8 via matplotlib cmap
    or a grayscale path. Near-camera pixels are passed in bright
    (vis_linear near 1.0), which is the convention used downstream."""
    if colormap == "grayscale":
        g = (vis_linear * 255).astype(np.uint8)
        return np.stack([g, g, g], axis=-1)
    import matplotlib  # imported lazily — keeps overlay modes mpl-free
    cmap = matplotlib.colormaps[colormap]
    rgba = cmap(vis_linear)
    return (rgba[..., :3] * 255).astype(np.uint8)


def _draw_depth_scale_bar(img: Image.Image, p_lo: float, p_hi: float,
                          colormap: str):
    """Overlay a small horizontal scale bar in the bottom-right corner with
    the two percentile values labelled. Purely informational."""
    W, H = img.size
    bar_w = min(260, W // 5)
    bar_h = 16
    margin = 20
    x0 = W - margin - bar_w
    y0 = H - margin - bar_h - 18
    x1 = x0 + bar_w
    y1 = y0 + bar_h

    # Generate a strip of the colormap at full range.
    strip = np.linspace(1.0, 0.0, bar_w, dtype=np.float32)  # near..far
    strip = np.tile(strip[np.newaxis, :], (bar_h, 1))
    strip_rgb = _apply_depth_colormap(strip, colormap)
    img.paste(Image.fromarray(strip_rgb), (x0, y0))

    draw = ImageDraw.Draw(img)
    draw.rectangle([x0 - 1, y0 - 1, x1, y1], outline=(255, 255, 255, 255), width=1)
    font = try_font(12)
    # Near (bright end, left) and far (dark end, right).
    draw.text((x0, y1 + 2), f"near {p_lo:.3f}",
              fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0),
              font=font)
    far_label = f"far {p_hi:.3f}"
    try:
        tw = draw.textlength(far_label, font=font)
    except AttributeError:
        tw = font.getsize(far_label)[0] if hasattr(font, "getsize") else 80
    draw.text((x1 - tw, y1 + 2), far_label,
              fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0),
              font=font)


def visualise_depth_frame(frame_id: int, spectator_dir: Path, out_dir: Path,
                          colormap: str, p_lo: float, p_hi: float,
                          far_threshold: float, draw_scale_bar: bool) -> bool:
    """Read raw depth for a frame and write a display-ready PNG alongside.

    Pipeline (per frame):
      1. Load raw non-linear post-projection depth as float32 in [0, 1].
      2. Build a validity mask of pixels below `far_threshold` (sky /
         far-plane pinned pixels are excluded — they'd dominate any
         normalisation stretch and flatten the rest).
      3. If <1% of pixels are valid, emit a flat neutral-grey image.
      4. Compute percentiles (p_lo, p_hi) on the valid subset.
      5. Contrast-stretch the full image to [0, 1] with those percentiles.
      6. Invert so near=bright / far=dark (MiDaS / Depth-Anything convention).
      7. Apply the chosen colormap; mask invalid pixels back to neutral
         grey so sky doesn't grab one extreme of the colormap.
    """
    depth_path = spectator_dir / f"frame_{frame_id:04d}_depth.png"
    if not depth_path.exists():
        return False

    depth = _load_depth_raw(depth_path)
    H, W = depth.shape
    valid = depth < far_threshold
    valid_frac = float(valid.mean())

    out_path = out_dir / f"frame_{frame_id:04d}_depth_vis.png"

    if valid_frac < 0.01:
        # Nothing useful — far-plane-dominated frame. Emit flat grey.
        Image.fromarray(np.full((H, W, 3), DEPTH_NEUTRAL_GREY, dtype=np.uint8)) \
            .save(out_path)
        return True

    valid_vals = depth[valid]
    lo = float(np.percentile(valid_vals, p_lo))
    hi = float(np.percentile(valid_vals, p_hi))

    if hi - lo < 1e-6:
        # Degenerate percentile clip (all valid pixels at one value).
        Image.fromarray(np.full((H, W, 3), DEPTH_NEUTRAL_GREY, dtype=np.uint8)) \
            .save(out_path)
        return True

    stretched = np.clip((depth - lo) / (hi - lo), 0.0, 1.0)
    vis_linear = 1.0 - stretched  # near-camera = bright, far = dark

    rgb = _apply_depth_colormap(vis_linear, colormap)
    rgb[~valid] = DEPTH_NEUTRAL_GREY  # sky / far-plane pixels → neutral grey

    img = Image.fromarray(rgb, mode="RGB")
    if draw_scale_bar:
        _draw_depth_scale_bar(img, lo, hi, colormap)
    img.save(out_path)
    return True


def _parse_percentiles(s: str):
    parts = s.split(",")
    if len(parts) != 2:
        raise argparse.ArgumentTypeError(
            f"--depth-percentiles expects 'LO,HI', got {s!r}")
    try:
        lo, hi = float(parts[0]), float(parts[1])
    except ValueError:
        raise argparse.ArgumentTypeError(
            f"--depth-percentiles values must be numeric, got {s!r}")
    if not (0 <= lo < hi <= 100):
        raise argparse.ArgumentTypeError(
            f"--depth-percentiles requires 0 <= LO < HI <= 100, got {s!r}")
    return lo, hi


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("spectator_dir", type=Path,
                        help="Path to <story>/<spectator-id>/ containing screenshots + JSON + coord_space.json")
    parser.add_argument("--mode",
                        choices=("skeleton", "spatial", "both", "depth-viz"),
                        default="both",
                        help="What to produce. 'both' (default) = skeleton + spatial markers "
                             "+ bboxes over screenshot. 'skeleton' or 'spatial' to isolate one "
                             "overlay layer. 'depth-viz' produces human-readable depth PNGs "
                             "into a sibling directory.")
    parser.add_argument("--frames", type=parse_frame_range, default=None,
                        help="Frame range, e.g. '41', '41-60', or 'all' (default: all)")
    parser.add_argument("--modality", type=int, default=0,
                        help="Modality ID whose saved dims to use for transform (default: 0 = raw)")
    parser.add_argument("--out", type=Path, default=None,
                        help="Output directory (default: <spectator_dir>_annotated, or "
                             "<spectator_dir>_depth_viz when --mode depth-viz)")
    parser.add_argument("--object-bboxes", dest="object_bboxes",
                        action="store_true", default=False,
                        help="Also draw getElementBoundingBox rectangles for non-ped "
                             "entities (diagnostic / visual-inspection only — the mesh "
                             "bbox often doesn't enclose the visible silhouette for "
                             "models with off-centre authored origins).")

    # Depth-viz-only options.
    parser.add_argument("--depth-viz-mode", dest="depth_viz_mode",
                        choices=("turbo", "magma", "viridis", "grayscale"),
                        default="turbo",
                        help="Colormap for --mode depth-viz (default: turbo)")
    parser.add_argument("--depth-percentiles", dest="depth_percentiles",
                        type=_parse_percentiles, default=(2.0, 98.0),
                        help="Percentile clip for depth-viz, as 'LO,HI' (default: 2,98)")
    parser.add_argument("--depth-far-threshold", dest="depth_far_threshold",
                        type=float, default=DEPTH_FAR_THRESHOLD,
                        help=f"Depth value above which a pixel is treated as "
                             f"sky/far-plane (default: {DEPTH_FAR_THRESHOLD})")
    parser.add_argument("--depth-scale-bar", dest="depth_scale_bar",
                        action=argparse.BooleanOptionalAction, default=True,
                        help="Draw a small scale bar in the bottom-right corner "
                             "of the depth visualisation (default: on)")

    args = parser.parse_args()

    spectator_dir = args.spectator_dir.resolve()
    if not spectator_dir.is_dir():
        parser.error(f"Not a directory: {spectator_dir}")

    # --- depth-viz: independent of coord_space / screenshots / overlays ---
    if args.mode == "depth-viz":
        out_dir = args.out or spectator_dir.with_name(spectator_dir.name + "_depth_viz")
        out_dir.mkdir(parents=True, exist_ok=True)

        global FONT_SMALL, FONT_LARGE
        FONT_SMALL = try_font(14)
        FONT_LARGE = try_font(20)

        p_lo, p_hi = args.depth_percentiles
        print(f"depth-viz: cmap={args.depth_viz_mode}, percentiles=({p_lo},{p_hi}), "
              f"far_threshold={args.depth_far_threshold}, scale_bar={args.depth_scale_bar}")
        print(f"writing to {out_dir}")

        count = 0
        for fid in _iter_depth_frames(spectator_dir, args.frames):
            if visualise_depth_frame(
                fid, spectator_dir, out_dir,
                colormap=args.depth_viz_mode,
                p_lo=p_lo, p_hi=p_hi,
                far_threshold=args.depth_far_threshold,
                draw_scale_bar=args.depth_scale_bar,
            ):
                count += 1
        print(f"depth-visualised {count} frames")
        return

    coord_space = load_coord_space(spectator_dir)
    transform, vr, saved = build_transform(coord_space, spectator_dir, args.modality)

    out_dir = args.out or spectator_dir.with_name(spectator_dir.name + "_annotated")
    out_dir.mkdir(parents=True, exist_ok=True)

    FONT_SMALL = try_font(14)
    FONT_LARGE = try_font(20)
    globals()["FONT_SMALL"] = FONT_SMALL
    globals()["FONT_LARGE"] = FONT_LARGE

    if coord_space is None:
        print(f"no coord_space.json — identity transform, saved image {saved['w']}x{saved['h']} "
              f"(JSON coords assumed to be in saved-image pixel space)")
    else:
        print(f"viewport {coord_space['viewport']}, visibleRect {vr}, saved {saved}, "
              f"scale=({saved['w']/vr['w']:.4f}, {saved['h']/vr['h']:.4f})")
    print(f"writing to {out_dir}")

    # Build a single spatial-relations index + cache up-front so every frame
    # can pick the most recent applicable JSON (spatial captures are deduped
    # so only a subset of frame IDs have their own file on disk).
    spatial_index = _build_spatial_index(spectator_dir)
    spatial_cache = {}
    if args.mode in ("spatial", "both"):
        print(f"spatial_relations index: {len(spatial_index)} files")

    count = 0
    for fid in iter_frames(spectator_dir, args.frames):
        if annotate_frame(fid, spectator_dir, out_dir, args.mode, transform, vr, saved,
                          spatial_index=spatial_index, spatial_cache=spatial_cache,
                          draw_object_bboxes=args.object_bboxes):
            count += 1

    print(f"annotated {count} frames")


if __name__ == "__main__":
    main()
