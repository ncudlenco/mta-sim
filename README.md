# GEST-Engine (mta-sim)

<p align="center">
  <a href="https://github.com/ncudlenco/mta-sim/releases"><img src="https://img.shields.io/github/v/release/ncudlenco/mta-sim?include_prereleases&style=for-the-badge" alt="Latest release"></a>
  <a href="https://github.com/ncudlenco/mta-sim/stargazers"><img src="https://img.shields.io/github/stars/ncudlenco/mta-sim?style=for-the-badge&logo=github" alt="GitHub stars"></a>
  <a href="https://github.com/ncudlenco/mta-sim/network/members"><img src="https://img.shields.io/github/forks/ncudlenco/mta-sim?style=for-the-badge&logo=github" alt="GitHub forks"></a>
  <a href="https://github.com/ncudlenco/mta-sim/watchers"><img src="https://img.shields.io/github/watchers/ncudlenco/mta-sim?style=for-the-badge&logo=github" alt="GitHub watchers"></a>
</p>

> **GEST-Engine** is a Multi Theft Auto (MTA) resource that executes formal event graph specifications — *Graphs of Events in Space and Time (GESTs)* — deterministically in GTA San Andreas, producing multi-actor narrative videos paired with dense frame-level ground-truth annotations: instance segmentation, per-frame pairwise spatial relations between all entities, exact event-to-frame temporal mappings, and natural-language descriptions — all at zero marginal annotation cost.

This repository contains the Lua-based simulation engine. The Python batch orchestrator and procedural / LLM-based GEST generators that drive it at scale live in the companion repository [**multiagent_story_system**](https://github.com/ncudlenco/multiagent_story_system).

## Paper

This system is described in the ICLR 2026 Workshop paper:

> N.~Cudlenco, M.~Masala, M.~Leordeanu. **[Tiny Paper] GEST-Engine: Controllable Multi-Actor Video Synthesis with Perfect Spatiotemporal Annotations.** *ICLR 2026 the 2nd Workshop on World Models: Understanding, Modelling and Scaling.* [OpenReview](https://openreview.net/forum?id=uUofPYVMZH)

The sample corpus of **398 procedurally generated multi-actor stories** (with engine-rendered videos, dense annotations, and VEO 3.1 / WAN 2.2 neural baselines) is publicly available on HuggingFace: [**nnc-001/gtasa-01**](https://huggingface.co/datasets/nnc-001/gtasa-01).

## Checkpoints

| Tag | Date | Reference |
|---|---|---|
| [`v1.0-iclr2026`](https://github.com/ncudlenco/mta-sim/releases/tag/v1.0-iclr2026) | March 2026 | ICLR 2026 Workshop Tiny Paper — state used to generate the GTASA-01 sample corpus |

Future checkpoints will be listed here as the system evolves.

## Requirements

- **Windows 10 / 11.** MTA San Andreas is Windows-native. The native screenshot module relies on the Windows Desktop Duplication API (DXGI), so the client must run on Windows.
- **Grand Theft Auto: San Andreas PC v1.0.** A licensed copy is required. Only the original PC v1.0 release is compatible with MTA — the v1.01 / v2.0 patches, the Steam re-release, the Mobile edition and the Definitive Edition are **not** supported.
- **Multi Theft Auto: San Andreas 1.6.** Download from [multitheftauto.com](https://multitheftauto.com/). Both the MTA **server** (`MTA Server.exe`) and the MTA **client** (`Multi Theft Auto.exe`) are required — the client must connect to `localhost` to trigger simulation on the server.

## Installation

### 1. Install GTA San Andreas

Install a legitimate copy of **GTA San Andreas PC v1.0**. MTA will not run against later patched releases or the Steam / Definitive / Mobile editions.

### 2. Install Multi Theft Auto: San Andreas 1.6

Download and run the MTA:SA 1.6 installer from [multitheftauto.com](https://multitheftauto.com/), pointing it at your GTA San Andreas installation directory. The installer creates two components you will use:

- The **MTA client**: `<MTA install>/Multi Theft Auto.exe`
- The **MTA server**: `<MTA install>/server/MTA Server.exe`

### 3. Clone this repository into the MTA resources folder

The resource must be checked out under `<MTA server>/mods/deathmatch/resources/sv2l/`:

```powershell
cd "<MTA server>\mods\deathmatch\resources"
git clone https://github.com/ncudlenco/mta-sim.git sv2l
```

> The folder name **must be `sv2l`** — scripts and configuration reference this exact name, even though the GitHub repository is named `mta-sim`.

### 4. Install the custom server modules

The engine depends on two custom server-side modules declared in `meta.xml` and loaded from `mtaserver.conf`:

- **`ml_pathfind_win32.dll`** — native pathfinding backend.
- **`ml_screenshot.dll`** — native screenshot / capture backend built on the Windows Desktop Duplication API (DXGI), used to capture RGB frames and segmentation masks without dropping frames. Source: [`screenshot_module/`](screenshot_module/).

Both modules must be placed in `<MTA server>/mods/deathmatch/modules/`.

### 5. Configure the MTA server

Edit `<MTA server>/mods/deathmatch/mtaserver.conf` to match the settings required by the engine. The key changes relative to a stock MTA install are:

```xml
<!-- Required modules -->
<module src="ml_pathfind_win32.dll" />
<module src="ml_screenshot.dll" />

<!-- Allow ped modifications for custom character models -->
<allow_gta3_img_mods>peds</allow_gta3_img_mods>

<!-- Whitelist client data files that ship with GTA SA v1.0 -->
<client_file name="data/plants.dat" verify="0" />
<client_file name="data/procobj.dat" verify="0" />

<!-- Local-only server -->
<ase>0</ase>
<donotbroadcastlan>1</donotbroadcastlan>

<!-- Tight sync and no bandwidth reduction for deterministic capture -->
<bandwidth_reduction>none</bandwidth_reduction>
<player_sync_interval>50</player_sync_interval>
<camera_sync_interval>50</camera_sync_interval>
<ped_sync_interval>50</ped_sync_interval>
<unoccupied_vehicle_sync_interval>50</unoccupied_vehicle_sync_interval>
<latency_reduction>1</latency_reduction>

<!-- Stable framerate for reproducible event-frame alignment -->
<fpslimit>30</fpslimit>

<!-- Disable voice and crash dump upload -->
<voice>0</voice>
<crash_dump_upload>0</crash_dump_upload>

<!-- Enable the sv2l resource at startup -->
<resource src="sv2l" startup="1" protected="0" />
```

A complete reference `mtaserver.conf` is provided in [`deathmatch_root/mtaserver.conf`](deathmatch_root/mtaserver.conf).

### 6. Create the MTA client shortcut

For headless / scriptable operation, create a Windows shortcut to the MTA client with `mtasa://127.0.0.1:22003` as the argument. This is what the batch orchestrator uses to launch the client. The shortcut target is:

```
Target:            <MTA install>\Multi Theft Auto.exe
Arguments:         mtasa://127.0.0.1:22003
Working directory: <MTA install>
```

From PowerShell you can launch it directly:

```powershell
& "<MTA install>\Multi Theft Auto.exe" mtasa://127.0.0.1:22003
```

…or via the shortcut:

```powershell
& "<MTA install>\Multi Theft Auto.exe - Shortcut.lnk"
```

### 7. Optional: create `config.json` for runtime overrides

All engine runtime configuration lives as Lua globals in [`src/ServerGlobals.lua`](src/ServerGlobals.lua). An optional `config.json` placed at the resource root (`mods/deathmatch/resources/sv2l/config.json`) overrides any of those globals at startup via [`src/utils/ConfigurationLoader.lua`](src/utils/ConfigurationLoader.lua).

Example `config.json`:

```json
{
  "EXPORT_MODE": false,
  "SIMULATION_MODE": true,
  "LOAD_FROM_GRAPH": true,
  "INPUT_GRAPHS": ["input_graphs/my_story.json"],
  "ARTIFACT_COLLECTION_ENABLED": true,
  "ARTIFACT_ENABLE_SEGMENTATION": true,
  "ARTIFACT_ENABLE_SPATIAL_RELATIONS": true,
  "ARTIFACT_ENABLE_EVENT_FRAME_MAPPING": true,
  "SCREENSHOT_CAPTURE_FULL_SCREEN": false
}
```

See [`src/ServerGlobals.lua`](src/ServerGlobals.lua) for the complete list of override-able keys (debug flags, resolution, animation speed, artifact modalities, camera settings, etc.). **Use the exact key names as defined there** — the loader maps them 1:1.

Notable keys:

| Key | Purpose |
|---|---|
| `EXPORT_MODE` | When `true`, the engine walks all episodes, POIs, action chains, and skins, writes `simulation_environment_capabilities.json` next to `meta.xml`, and exits. Used to bootstrap the capability registry consumed by the companion batch repo. |
| `SIMULATION_MODE` | Enables the normal simulation path (camera, capture, logs). Leave `true` for all runs except pure capability export. |
| `LOAD_FROM_GRAPH` | When `true`, the engine reads the GESTs listed in `INPUT_GRAPHS` on startup. |
| `INPUT_GRAPHS` | Array of GEST JSON paths. **All paths are resolved relative to the sv2l resource root**, so the graph file must live somewhere inside the resource directory (any subfolder). |
| `ARTIFACT_COLLECTION_ENABLED` | Master switch for the multi-modal artifact collection subsystem. |
| `ARTIFACT_ENABLE_SEGMENTATION` | Per-frame HLSL instance segmentation. |
| `ARTIFACT_ENABLE_SPATIAL_RELATIONS` | Per-frame pairwise spatial relation graphs. |
| `ARTIFACT_ENABLE_EVENT_FRAME_MAPPING` | Exact `{event → [startFrame, endFrame]}` alignments. |
| `SCREENSHOT_CAPTURE_FULL_SCREEN` | Set to `true` when running inside a VMware Workstation guest to capture the whole screen instead of cropping to the MTA window. |

If `config.json` is absent, the defaults in `ServerGlobals.lua` apply.

## Usage

### Run a GEST specification

1. Place the GEST JSON anywhere inside the sv2l resource tree. A common convention is `input_graphs/<name>.json`.
2. Write `config.json` pointing at it, with `EXPORT_MODE: false` and `LOAD_FROM_GRAPH: true`.
3. Start the MTA server:

    ```powershell
    & "<MTA install>\server\MTA Server.exe"
    ```

4. Start the MTA client (connects to `mtasa://127.0.0.1:22003`):

    ```powershell
    & "<MTA install>\Multi Theft Auto.exe" mtasa://127.0.0.1:22003
    ```

5. The simulation runs to completion. Results are written **next to the input graph**, in a folder named after the graph file with a `_out` suffix. For example, if the input is:

    ```
    <sv2l>/input_graphs/story_927dae36_full.json
    ```

    …then all artifacts (RGB video, per-frame spatial relations, event-frame mapping, segmentation masks, logs, text descriptions) are written to:

    ```
    <sv2l>/input_graphs/story_927dae36_full.json_out/
    ```

### Export the capability registry

A pre-generated `simulation_environment_capabilities.json` is shipped alongside the batch orchestrator in the companion repository. That version has been **manually edited** to fix inconsistencies and is the one used by all released checkpoints.

You can regenerate a fresh capability registry by running the engine with `"EXPORT_MODE": true` in `config.json` — the file is written next to `meta.xml`. Note that the raw export may **not** be fully consistent; the shipped version in the batch repo is the canonical one.

### Batch production across multiple VMs

For corpus-scale production (hundreds of stories across many parallel VMware Workstation Pro worker VMs), use the Python orchestrator in the companion repository: see [multiagent_story_system](https://github.com/ncudlenco/multiagent_story_system) for the detailed command-line reference.

## Repository layout

```
sv2l/
├── meta.xml                    # MTA resource definition
├── src/
│   ├── ServerGlobals.lua       # Default configuration flags (override via config.json)
│   ├── utils/
│   │   └── ConfigurationLoader.lua     # Reads config.json and applies overrides
│   ├── story/                  # GEST graph execution engine
│   ├── api/                    # Action orchestration, camera, POI coordination
│   └── client/                 # Client-side scripts and authoring tools
├── files/
│   ├── episodes/               # Episode definitions (JSON)
│   ├── supertemplates/         # Reusable object/action interaction templates
│   └── data/                   # Custom 3D models and textures
├── screenshot_module/          # Native C++ DXGI Desktop Duplication capture source
├── deathmatch_root/            # Reference mtaserver.conf
├── input_graphs/               # Example GEST input files (outputs land here as *.json_out/)
└── complex_graphs/             # Additional example GEST input files
```

## Star History

<a href="https://www.star-history.com/#ncudlenco/mta-sim&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=ncudlenco/mta-sim&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=ncudlenco/mta-sim&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=ncudlenco/mta-sim&type=Date" />
 </picture>
</a>

## Citation

If you use this system in your research, please cite the ICLR 2026 Tiny Paper:

```bibtex
@inproceedings{cudlenco2026tiny,
  title={[Tiny Paper] {GEST}-Engine: Controllable Multi-Actor Video Synthesis with Perfect Spatiotemporal Annotations},
  author={Nicolae Cudlenco and Mihai Masala and Marius Leordeanu},
  booktitle={ICLR 2026 the 2nd Workshop on World Models: Understanding, Modelling and Scaling},
  year={2026},
  url={https://openreview.net/forum?id=uUofPYVMZH}
}
```

## License and intellectual property notice

The code in this repository (Lua sources, the native screenshot module, and auxiliary tooling) is released under the license indicated in the [`LICENSE`](LICENSE) file.

**Use of this system requires a licensed copy of Grand Theft Auto: San Andreas.** Rockstar Games / Take-Two Interactive own all in-game assets (3D models, textures, animations, environments) and this repository makes no claim to them. Nothing here distributes Rockstar / Take-Two intellectual property — users supply their own legitimate copy of the game. Users are responsible for complying with both Rockstar's EULA and the Multi Theft Auto terms of use. Research data derived from this system (e.g. the [GTASA-01 corpus on HuggingFace](https://huggingface.co/datasets/nnc-001/gtasa-01)) is released for non-commercial academic research only.

## Contact

For questions, bug reports, or collaboration inquiries: open an [issue](https://github.com/ncudlenco/mta-sim/issues) or email `nicolae.cudlenco@gmail.com`.
