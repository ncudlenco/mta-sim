# CLAUDE.md

Onboarding instructions for AI coding agents (and human contributors) working in this repository. For an end-user introduction to the project, see the [README](README.md).

## Project overview

**GEST-Engine (mta-sim)** is a Multi Theft Auto resource that executes formal *Graphs of Events in Space and Time (GESTs)* deterministically inside GTA San Andreas, producing multi-actor narrative videos paired with dense frame-level ground-truth annotations (instance segmentation, pairwise spatial relations, exact event-to-frame temporal mappings, natural-language descriptions). It is the simulation half of a two-repo system; the Python orchestrator and LLM-based GEST generators live in [multiagent_story_system](https://github.com/ncudlenco/multiagent_story_system).

The engine is written in Lua against the MTA scripting API and is structured to keep core engine logic isolated from GTA-specific business logic so that future ports to other engines (FiveM/GTA V is the next target) can reuse the orchestration core.

## Source layout

All Lua source lives under [src/](src/), organized into six subsystems:

- [src/api/](src/api/) — high-level façade exposed to the rest of the engine: [`ActionsOrchestrator`](src/api/ActionsOrchestrator.lua) (temporal coordination of multi-actor actions), [`CameraHandler`](src/api/CameraHandler.lua) and friends (`CameraHandlerBase`, `CinematicCameraHandler`, `StaticCameraHandler`), [`PedHandler`](src/api/PedHandler.lua), [`POICoordinator`](src/api/POICoordinator.lua), and the abstract bases `IStoryItem`, `StoryBase`, `StoryActionBase`.
- [src/story/](src/story/) — story execution core: [`GraphStory`](src/story/GraphStory.lua) (parses input GEST JSON, drives execution), [`EventPlanner`](src/story/EventPlanner.lua), [`Generator`](src/story/Generator.lua), [`Logger`](src/story/Logger.lua), plus subdirectories `Actions/`, `Camera/`, `Episodes/`, `Locations/`, `Needs/`, `Objects/`.
- [src/client/](src/client/) — client-side scripts (the MTA client connects to the localhost server and runs these for camera control, frame capture, and developer-mode 3D editing tools).
- [src/export/](src/export/) — [`GameWorldExporter`](src/export/GameWorldExporter.lua) traverses the running game world and serializes available actions, regions, objects and skins to `simulation_environment_capabilities.json` for downstream agents.
- [src/features/](src/features/) — opt-in feature modules, currently `artifact_collection/` (frame capture and per-frame ground-truth dumping).
- [src/utils/](src/utils/) — shared utilities including [`class.lua`](src/utils/class.lua) (the custom class-like OOP helper), [`EventBus`](src/utils/EventBus.lua), [`SpatialCoordinator`](src/utils/SpatialCoordinator.lua), `ConfigurationLoader`, `UnionFind`, `Plane3`, `Extent3`, `VectorUtils`, etc.

Non-source directories worth knowing:

- [files/episodes/](files/episodes/) — JSON episode definitions (POIs, available actions, object layouts).
- [files/supertemplates/](files/supertemplates/) — reusable interaction templates assembled from sub-templates.
- [files/data/](files/data/) — custom 3D models (`.dff`/`.txd`) loaded by the resource.
- [input_graphs/](input_graphs/) — sample input GESTs the engine consumes.
- [screenshot_module/](screenshot_module/) — native C++ module that uses the Windows Desktop Duplication API (DXGI) to capture frames out-of-process; built independently with CMake. See [screenshot_module/README.md](screenshot_module/README.md).
- [scripts/](scripts/) — Python helpers (postprocessing, validation).
- [meta.xml](meta.xml) — MTA resource manifest. `<oop>true</oop>` is set, so MTA's element instances behave as class instances.

## Running the engine

The system is launched as a normal MTA resource. The [README](README.md) covers full installation and end-to-end usage; the points below are the ones an agent typically needs:

- The engine **requires both the MTA server and the MTA client running simultaneously**. The server hosts the resource and processes the GEST; the client connects to `localhost`, which is what triggers actual execution. Starting the server alone does nothing — it sits idle waiting for a client.
- The Python orchestrator in [multiagent_story_system](https://github.com/ncudlenco/multiagent_story_system) automates this by writing a `config.json` next to this resource and managing both processes. For manual runs, edit `src/ServerGlobals.lua` (or drop a `config.json` next to it) to set `EXPORT_MODE`, `SIMULATION_MODE`, `LOAD_FROM_GRAPH`, `INPUT_GRAPHS`, `ARTIFACT_COLLECTION_ENABLED`, etc.
- Two operational modes:
  - **Export mode**: dumps the game world's available capabilities (actions, regions, objects, skins) to `simulation_environment_capabilities.json` and exits. Used to seed downstream LLM agents with ground-truth game vocabulary.
  - **Simulation mode**: loads a GEST JSON, validates it against the loaded episodes, plans locations, and runs the orchestrator until all events fire or the story errors out.

There is no usable automated test suite. Verification is done by running an actual simulation against a known input graph and inspecting the resulting `clientscript.log` and `server.log`.

## Code conventions

- **Lua, OOP via [class.lua](src/utils/class.lua).** New components extend an existing base class or use the helper to declare a new one. Keep state on `self`; avoid module-level mutable globals.
- **LDoc** for documentation comments. See [the LDoc manual](https://stevedonovan.github.io/ldoc/manual/doc.md.html). Document every public function (`@param`, `@return`, short description). The `docs/` directory holds LDoc-style component reference docs that are kept in sync with the code.
- **DRY, YAGNI, SOLID.** Keep the engine core decoupled from GTA-specific logic. The medium-term goal is to port the orchestrator to FiveM/GTA V; anything that bakes in San Andreas-only assumptions makes that harder.
- **Naming**: PascalCase for classes and files containing classes; camelCase for functions and locals; UPPER_SNAKE_CASE for global config flags in [src/ServerGlobals.lua](src/ServerGlobals.lua).
- **Logging**: route through [`src/story/Logger.lua`](src/story/Logger.lua). Subsystem debug flags (`DEBUG_VALIDATION`, `DEBUG_ACTIONS_ORCHESTRATOR`, etc.) live in `ServerGlobals.lua` and gate verbose output.
- **No backwards-compatibility narration.** When you change something, write the new code and docs as the only solution. Do not leave "previously this was…" comments or migration notes.

## Critical context

- **Lua debugging is limited.** There is no working step debugger in the MTA environment that we rely on. Debugging is done by inserting `outputServerLog` / `outputDebugString` calls and reading `server.log` / `clientscript.log`. Plan accordingly: prefer small, isolated changes you can verify quickly.
- **Iteration cycles are slow.** A full simulation run for a non-trivial GEST takes minutes and requires the GTA window to be focused for client-side capture. Don't expect tight TDD-style loops.
- **The MTA engine is hard to mock.** Past attempts at a Lua-side test framework with mocked MTA functions were abandoned because the surface area is too large and the hardest bugs are timing-dependent in the real engine. Functional verification is the standard.
- **Async / temporal correctness is the dominant source of bugs.** Most non-trivial issues are race conditions between actor pathfinding, action triggering, and constraint satisfaction. When something fails, the suspect is usually a constraint that fired in the wrong order, not a code-level bug.
- **Root-cause analysis discipline**: when investigating a failure, start by reading `server.log` (and `clientscript.log` for client-side issues) line by line from the moment the GEST is loaded, then ground each hypothesis in the actual code path. Never guess from symptoms alone — Lua silent failures are common and the log usually has the answer.

## Companion documentation

LDoc-style component references and architecture diagrams (kept up to date with the code) live in the repository:

- [arch/system-overview.md](arch/system-overview.md), [arch/component-details.md](arch/component-details.md), [arch/data-flow.md](arch/data-flow.md) — high-level architecture diagrams.
- [docs/ServerGlobals.md](docs/ServerGlobals.md), [docs/ServerCommands.md](docs/ServerCommands.md) — global configuration and developer commands.
- [docs/api/ActionsOrchestrator.md](docs/api/ActionsOrchestrator.md), [docs/api/CameraHandler.md](docs/api/CameraHandler.md) — temporal coordination and camera management.
- [docs/story/GraphStory.md](docs/story/GraphStory.md), [docs/story/Episodes/MetaEpisode.md](docs/story/Episodes/MetaEpisode.md), [docs/story/Locations/Location.md](docs/story/Locations/Location.md) — graph execution, multi-episode wrapping, location planning.
- [docs/client/EpisodeCommands.md](docs/client/EpisodeCommands.md), [docs/client/MappingCommands.md](docs/client/MappingCommands.md), [docs/client/Template.md](docs/client/Template.md), [docs/client/Supertemplate.md](docs/client/Supertemplate.md) — client-side developer tooling for episode editing, pathfinding graph creation, and template authoring.
- [docs/utils/SpatialCoordinator.md](docs/utils/SpatialCoordinator.md) — spatial coordination utility.
- [docs/action-flow-sequence-diagram.md](docs/action-flow-sequence-diagram.md), [docs/action-planning-execution-flow.md](docs/action-planning-execution-flow.md) — execution flow traces.

When something is stale or wrong, fix the code first, then fix the doc. When a new component is added, add an LDoc-style reference under `docs/` that mirrors the source path.
