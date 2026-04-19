# PoseCollector

Captures per-frame 3D bone world positions and 2D screen projections for every story actor in the current episode, keyed by `storyActorId` and camera.

Source: [src/features/artifact_collection/collectors/PoseCollector.lua](../../../src/features/artifact_collection/collectors/PoseCollector.lua)

## Purpose

Produces dense per-frame keypoint annotations aligned with the other artifact modalities (screenshot, segmentation, depth, spatial relations). Output is one JSON file per captured frame.

## Pipeline

`getPedBonePosition`, `isLineOfSightClear`, and `getScreenFromWorldPosition` are all client-only, so bone reads, occlusion checks, and 2D projection all happen on the client. The flow is:

1. Server enumerates story actors from `CURRENT_STORY.CurrentEpisode.peds` (per-spectator instance).
2. Server sends the ped element list to the spectator's client via `onPoseRequest` event (managed by [MTAPoseAdapter](../../../src/features/artifact_collection/adapters/mta/server/MTAPoseAdapter.lua)).
3. [ClientPoseHandler](../../../src/features/artifact_collection/adapters/mta/client/ClientPoseHandler.lua) per ped, per joint:
   - Reads world position via `getPedBonePosition`.
   - Projects to screen via `getScreenFromWorldPosition(x, y, z)` — engine-accurate, handles FOV/aspect/Z-up correctly. Returns `nil` for bones behind the camera.
   - Runs `isLineOfSightClear(camera → bone, ignoredElement = ped)` so the ped's own mesh doesn't occlude its own bones.
4. Client response also carries the viewport dims (`guiGetScreenSize()`).
5. Server assembles per-bone records (world coord + screen coord + `lineOfSight` flag) and computes per-bone `visible = (screen pixel inside visibleRect) AND lineOfSight`.
6. Per-pose `visible` is true iff *any* bone is visible. Actors whose `visible` is false are dropped unless `ARTIFACT_POSE_INCLUDE_OFFSCREEN` is set.
7. Server writes JSON to `[LOAD_FROM_GRAPH]_out/[storyId]/[cameraId]/frame_XXXX_pose.json`.

Because bone world positions are identical across clients for streamed-in peds, any one spectator's client can service the read — we use the collector's own spectator for locality (and because `getScreenFromWorldPosition` uses that spectator's camera).

We deliberately do **not** call `isElementOnScreen`: its underlying bounding-sphere-vs-extended-frustum test routinely returns true for elements geometrically behind the camera.

## Joint set (20 keypoints)

Joint indices match `POSE_JOINTS` in `ClientPoseHandler.lua`, which mirrors `bone_0[1..20]` from [bone_attach_c.lua](../../../src/utils/bone_attach_c.lua):

| # | Name | MTA bone ID |
|---|------|-------------|
| 1  | head            | 5  |
| 2  | neck            | 4  |
| 3  | spine           | 3  |
| 4  | pelvis          | 1  |
| 5  | left_clavicle   | 4  |
| 6  | right_clavicle  | 4  |
| 7  | left_shoulder   | 32 |
| 8  | right_shoulder  | 22 |
| 9  | left_elbow      | 33 |
| 10 | right_elbow     | 23 |
| 11 | left_hand       | 34 |
| 12 | right_hand      | 24 |
| 13 | left_hip        | 41 |
| 14 | right_hip       | 51 |
| 15 | left_knee       | 42 |
| 16 | right_knee      | 52 |
| 17 | left_ankle      | 43 |
| 18 | right_ankle     | 53 |
| 19 | left_foot       | 44 |
| 20 | right_foot      | 54 |

Left/right clavicles share bone ID 4 (neck) because the GTA:SA skeleton has no dedicated clavicle bone — downstream consumers can treat them as neck duplicates or use shoulders directly.

## Output schema

```json
{
  "frameId": 42,
  "timestamp": 1234567890,
  "storyId": "story_abc",
  "cameraId": "spectator_0",
  "camera": { "position": {...}, "lookAt": {...}, "fov": 70.0, "roll": 0.0 },
  "resolution": { "width": 1920, "height": 1080 },
  "poses": [
    {
      "storyActorId": "a0",
      "streamed": true,
      "visible": true,
      "currentEventId": "a0_12",
      "currentActionName": "Walk",
      "bones": [
        {
          "name": "head",
          "world": {"x": 1.2, "y": 3.4, "z": 5.6},
          "screen": {"x": 958.0, "y": 240.5},
          "visible": true
        },
        ...
      ]
    }
  ]
}
```

Bones are indexed 1..20 (Lua 1-based). A bone is omitted only if the client couldn't read it (ped not streamed in, bone ID invalid). `screen.x` / `screen.y` are `null` for bones that project behind the camera.

**`visible` is the single authoritative "is this keypoint rendered in the frame" flag.** It is true iff:
- the projected pixel lies inside `visibleRect` (post-crop region), AND
- the camera-to-bone raycast (`isLineOfSightClear`, ignoring the ped itself) is unobstructed.

Per-pose `visible` is true iff *any* bone is visible. `screen.x/y` is reported even when `visible` is false — pixel coords for occluded or off-screen bones can still be useful for partial-pose reconstruction; the consumer should gate on `visible` rather than recomputing.

## Configuration

Flags in [src/ServerGlobals.lua](../../../src/ServerGlobals.lua):

- `ARTIFACT_ENABLE_POSE` — master toggle.
- `ARTIFACT_POSE_FPS` — target pose capture rate; if less than the global FPS, frames are skipped to match.
- `ARTIFACT_POSE_INCLUDE_OFFSCREEN` — when `false`, poses with no visible bones are dropped from the output.

## Coordinate space and the saved image

The `screen.x/y` values in the pose JSON are in **GTA viewport coords** (origin at the top-left of the GTA window's client area, axes in pixels). Since the engine's `getScreenFromWorldPosition` produces them directly, they inherit the real camera's aspect, FOV, and handedness — no server-side projection math, no `WIDTH_RESOLUTION` dependency.

The viewport size is reported back to the server in the client response so every JSON's `resolution` block reflects the actual GTA render resolution at capture time.

The saved PNG/MP4 frame may or may not equal the full viewport:

- **Multimodal capture path**: saved image == viewport, no crop. Identity transform between `screen.x/y` and saved-image pixel.
- **Desktop Duplication path**: native module strips OS chrome (detected via `GetClientRect`/`ClientToScreen`) plus a viewport-side crop (default `VIEWPORT_CROP_BOTTOM = 15` for the MTA watermark). `coord_space.json` describes the mapping.

A bone's `visible` flag already accounts for the crop — bones projecting into the watermark zone correctly read `visible: false`.

To map a viewport-coord pixel to a saved-image pixel for modality `m`:

```
x_saved = (x_viewport - visibleRect.x) * savedDims[m].w / visibleRect.w
y_saved = (y_viewport - visibleRect.y) * savedDims[m].h / visibleRect.h
```

For the multimodal path the above reduces to the identity transform.

Every transform parameter is dumped once per `(storyId, cameraId)` to `coord_space.json` next to the pose JSONs by [CoordSpaceWriter](../../../src/features/artifact_collection/CoordSpaceWriter.lua). Example schema:

```json
{
  "schemaVersion": 1,
  "viewport":       {"w": 1920, "h": 1080},
  "chrome":         {"left": 0, "top": 0, "right": 0, "bottom": 0},
  "cropInViewport": {"left": 0, "top": 0, "right": 0, "bottom": 0},
  "visibleRect":    {"x": 0, "y": 0, "w": 1920, "h": 1080},
  "savedDims":      {"0": {"w": 1920, "h": 1080}, "1": {"w": 1920, "h": 1080}, "2": {"w": 1920, "h": 1080}}
}
```

Modality IDs in `savedDims` correspond to `ModalityType` in [ArtifactCollectionConfig](../../../src/features/artifact_collection/config/ArtifactCollectionConfig.lua) (`0=raw, 1=segmentation, 2=depth`).

## Related components

- [SpatialRelationsCollector](../../../src/features/artifact_collection/collectors/SpatialRelationsCollector.lua) — uses the same client-side projection path (`getScreenFromWorldPosition`) for entity bbox centers and corners, so pose keypoints and spatial-relation entities overlay consistently on the saved frame.
- [ArtifactCollectionFactory](../../../src/features/artifact_collection/factories/ArtifactCollectionFactory.lua) — `createPoseCollector()` wires the adapter, the shared `CoordSpaceWriter`, and registers the collector per spectator.
- [NativeCaptureMetadata](../../../src/features/artifact_collection/NativeCaptureMetadata.lua) — caches either the native screenshot module's metadata (Desktop Duplication) or a synthesised identity record built from the client's viewport (multimodal), so `CoordSpaceWriter` always has something to write.
- Native module (Desktop Duplication path only): [DesktopDuplicationBackend](../../../screenshot_module/mta/DesktopDuplicationBackend.cpp) auto-detects OS chrome at runtime; [main.cpp](../../../screenshot_module/mta/main.cpp) holds the viewport-side crop constants (`VIEWPORT_CROP_TOP/LEFT/RIGHT/BOTTOM`).
