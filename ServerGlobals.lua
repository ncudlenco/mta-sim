CURRENT_STORY = nil
SCREENSHOTS = {}
MAX_ACTIONS = 10000
MAX_STORY_TIME = 1200
LOG_FREQUENCY = 1000 / 50 --milliseconds / frames
WIDTH_RESOLUTION = 1920
HEIGHT_RESOLUTION = 1080
DEBUG = false
DEBUG_PATHFINDING = false
DEBUG_VALIDATION = false
DEBUG_ACTION_VALIDATION = false
DEBUG_LOGGER = false
DEBUG_SCREENSHOTS = true
DEBUG_OBJECTS = false
DEBUG_EPISODE = false
DEBUG_ACTIONS = false
DEBUG_CHAIN_LINKED_ACTIONS = false
DEBUG_CAMERA = false
TIME_STAMP = false
ACTORS_CROWDING_FACTOR = 0.2
MIN_ACTORS = 1
MAX_ACTORS = 1
RANDOM_ACTORS_NR = true
EXPECTED_SPECTATORS = 1
SIMULATION_MODE = true
LOG_DATA = SIMULATION_MODE and false

STATIC_CAMERA = SIMULATION_MODE
FREE_ROAM = not SIMULATION_MODE
DEFINING_EPISODES = not SIMULATION_MODE

DISABLE_BETWEEN_POINTS_TELEPORTATION = false
-- TODO next: run all graphs from v0_100 and write down the state for each graph
-- TODO: I remember there was still a problem with interlocking agents
-- DONE: I remember there was a problem with planning for pick upable objects (next actions might be different that the ones defined in the json): pick up, sit down, drink, get up, put down. Agents should be allowed to sit down and get up without doing any action (i.e. inner actions should be optional).

-- DONE: create and test templates for each bed, add them to a beds supertemplate
-- MOSTLY_DONE: create and test supertemplates for all objects
-- MOSTLY DONE: add all possible supertemplates (or as many as possible) in all episodes (i.e. multiple chairs at a table, all sit downable, all having food and drink items on the table)
-- DONE: create sinks supertemplate
-- DONE: create more table supertemplates
-- DONE: create all armchairs supertemplates
-- TODO: create all toilets supertemplates
-- TODO: add all these supertemplates in all episodes and rework the graphs
----Done: house9
----Done: house1_sweet -> add a Sink object somewhere underneath the floor with wash hands and sink as target
    --   "house1_preloaded",
    --   "house3_preloaded", --NOT WORKING! The pathfinding seems flawed here, when we have 2 levels?
    --   "house7", --NOT WORKING! Potential issue when the link POI is located outside a region
    --   "house8_preloaded",
    --   "house10_preloaded", -- Not Working!
    --   "house12_preloaded", -- Working but needs the objects removed. Some flakiness exists but in general it works...
    --   "garden",
    --   "office",
    --   "office2",
    --   "common",
    --   "gym1",
    --   "gym2",
    --   "gym3"


LOAD_FROM_GRAPH = true
INPUT_GRAPHS = {
    -- 'random/v1_1actor/g0', --success
    -- 'random/v1_1actor/g1', --fail: we don't have an episode where the actor can open the laptop and dance; Done: solve the relative insertion point for supertemplates then fill the houses with all these objects.
    -- 'random/v1_1actor/g2', --fail: Dance must have as entities only the actor. Remote - no episodes with this object. PickUp followed by SitDown -> not supported.
    -- 'random/v1_1actor/g3', --success
    -- 'random/v1_1actor/g4', --success
    -- 'random/v1_1actor/g5', --fail: TODO: verify why
    -- 'random/v1_1actor/g6', --success
    -- 'random/v1_1actor/g7', --fail: TODO: verify why
    -- 'random/v1_1actor/g8', --success
    -- 'random/v1_1actor/g9', --success
    -- 'random/v2_2actors_nointeractions/g0', --please do not use the same object and action as the first action, the engine doesn't handle this; also, do not link actions of different actors with next -> this is not implemented
    -- 'random/v2_2actors_nointeractions/g1', --success
    -- 'random/v2_2actors_nointeractions/g2', -- fail: same first location not supported, next between different actors not implemented. BUG for multiple successive sleep actions, if possible, do not generate same action twice.
    -- 'random/v2_2actors_nointeractions/g3', --fail: there is no phone currently in a gym
    -- 'random/v2_2actors_nointeractions/g4', --fail: sit down has Chair as targer. Remote does not exist. Next between different actors not implemented.
    -- 'random/v2_2actors_nointeractions/g5', --success
    -- 'random/v2_2actors_nointeractions/g6', --fail: Remote, Dance target
    -- 'random/v2_2actors_nointeractions/g7', --fail: next across actors
    -- 'random/v2_2actors_nointeractions/g8', --fail: next across actors
    -- 'random/v2_2actors_nointeractions/g9', --fail: Remote, SitDown with target Desk
    -- 'random/v3_2actors_withinteractions/g0', --success
    -- 'random/v3_2actors_withinteractions/g1', --fail: TODO: verify why
    -- 'random/v3_2actors_withinteractions/g2', --success
    -- 'random/v3_2actors_withinteractions/g3', --success
    -- 'random/v3_2actors_withinteractions/g4', --success
    -- 'random/v3_2actors_withinteractions/g5', --success
    -- 'random/v3_2actors_withinteractions/g6', --success
    -- 'random/v3_2actors_withinteractions/g7', --fail: TODO: verify why
    -- 'random/v3_2actors_withinteractions/g8', --fail: TODO: verify why
    -- 'random/v3_2actors_withinteractions/g9', --fail: TODO: verify why
    -- 'random/v3_3actors/g0',--fail: TODO: verify why
    -- 'random/v3_3actors/g1', --success
    -- 'random/v3_3actors/g2', --success
    -- 'random/v3_3actors/g3',--fail: TODO: verify why
    -- 'random/v3_3actors/g4',--fail: TODO: verify why
    -- 'random/v3_3actors/g5',--fail: TODO: verify why
    -- 'random/v3_3actors/g6',--fail: TODO: verify why
    -- 'random/v3_3actors/g7',--fail: TODO: verify why
    -- 'random/v3_3actors/g8', --success
    -- 'random/v3_3actors/g9',--fail: TODO: verify why
    -- 'random/v4_1action/g0', --success
    -- 'random/v4_1action/g1', --success
    -- 'random/v4_1action/g10',  --success
    -- 'random/v4_1action/g12', --fail: PickUp remote -> doesn't exist
    -- 'random/v4_1action/g13', --success
    -- 'random/v4_1action/g2', --success
    -- 'random/v4_1action/g20', --success
    -- 'random/v4_1action/g27',  --success --Fixed the reverse_object_map assignment during validation and simulation: search for the first non-interaction event with the object as target. Use an object part of such a chain.
    -- 'random/v4_1action/g3', --fails: SitDown -> the target should be chair, not desk (and I cannot allow this anymore without having a chair with only 2 actions -> sit down and stand up)
    -- 'random/v4_1action/g4',  --success -- Dance entities should be only with the actor
    -- 'random/v4_1action/g44', --success
    -- 'random/v4_1action/g56', --success
    -- 'random/v4_1action/g6',  --success
    -- 'random/v4_1action/g63', --success
    -- 'random/v4_1action/g7',  --success
    -- 'random/v4_1action/g8',  --success
    -- 'random/v5_1action_interaction/g0', --success
    -- 'random/v5_1action_interaction/g1', --success
    -- 'random/v5_1action_interaction/g7', --success
    -- 'random/v5_1action_interaction/g13', --success: Replace Joke with Laugh
    -- 'random/v5_1action_interaction/g28', --success

    -- 'random/v1_nomove/v1_1actor/g0',
    -- 'random/v1_nomove/v1_1actor/g1',
    -- 'random/v1_nomove/v1_1actor/g2',
    -- 'random/v1_nomove/v1_1actor/g3',
    -- 'random/v1_nomove/v1_1actor/g4',
    -- 'random/v1_nomove/v1_1actor/g5',
    -- 'random/v1_nomove/v1_1actor/g6',
    -- 'random/v1_nomove/v1_1actor/g7',
    -- 'random/v1_nomove/v1_1actor/g8',
    -- 'random/v1_nomove/v1_1actor/g9',
    -- 'random/v1_nomove/v2_2actors_nointeractions/g0',
    -- 'random/v1_nomove/v2_2actors_nointeractions/g1',
    -- 'random/v1_nomove/v2_2actors_nointeractions/g2',
    -- 'random/v1_nomove/v2_2actors_nointeractions/g3',
    -- 'random/v1_nomove/v2_2actors_nointeractions/g4',
    -- 'random/v1_nomove/v2_2actors_nointeractions/g5',
    -- 'random/v1_nomove/v2_2actors_nointeractions/g6',
    -- 'random/v1_nomove/v2_2actors_nointeractions/g7',
    -- 'random/v1_nomove/v2_2actors_nointeractions/g8',
    -- 'random/v1_nomove/v2_2actors_nointeractions/g9',
    -- 'random/v1_nomove/v3_2actors_withinteractions/g0', -- Syncronization problem for sleep of bed -> fixed by choosing a location for which no one is waiting for when performing interactions
    -- 'random/v1_nomove/v3_2actors_withinteractions/g1', --no valid episode found
    -- 'random/v1_nomove/v3_2actors_withinteractions/g2',
    -- 'random/v1_nomove/v3_2actors_withinteractions/g3',
    -- 'random/v1_nomove/v3_2actors_withinteractions/g4',
    -- 'random/v1_nomove/v3_2actors_withinteractions/g5',
    -- 'random/v1_nomove/v3_2actors_withinteractions/g6',
    -- 'random/v1_nomove/v3_2actors_withinteractions/g7',
    -- 'random/v1_nomove/v3_2actors_withinteractions/g8',
    -- 'random/v1_nomove/v3_2actors_withinteractions/g9',
    -- 'random/v1_nomove/v4_3actors/g0',
    -- 'random/v1_nomove/v4_3actors/g1',
    -- 'random/v1_nomove/v4_3actors/g2',
    -- 'random/v1_nomove/v4_3actors/g3',
    -- 'random/v1_nomove/v4_3actors/g4',
    -- 'random/v1_nomove/v4_3actors/g5',
    -- 'random/v1_nomove/v4_3actors/g6',
    -- 'random/v1_nomove/v4_3actors/g7',
    -- 'random/v1_nomove/v4_3actors/g8',
    -- 'random/v1_nomove/v4_3actors/g9',
    -- 'test_3.json',
    -- 'complex_graphs/c1',
    -- 'complex_graphs/c1',
    -- 'complex_graphs/c1',
    -- 'complex_graphs/c2.json',
    -- 'complex_graphs/c2.json',
    -- 'complex_graphs/c2.json',
    'complex_graphs/c3.json',
    'complex_graphs/c3.json',
    'complex_graphs/c3.json',
    -- 'complex_graphs/c4.json',
    -- 'complex_graphs/c4.json',
    -- 'complex_graphs/c4.json',
    -- 'complex_graphs/c10.json',
    -- 'complex_graphs/c10.json',
    -- 'complex_graphs/c10.json',
    -- 'test_1',
    -- 'test_1',
    -- 'test_1',
    -- 'test_order',
    -- 'test_order',
    -- 'test_order',
    -- 'test_order',
    -- 'test_order',
    -- 'test_3.json',
    -- 'test_4.json',
    -- 'test_5.txt',
    -- 'random/v0_100/g0', --V
    -- 'random/v0_100/g1', --V
    -- 'random/v0_100/g2', -- skipped - needs mobile phone in bedroom
    -- 'random/v0_100/g3', -- skipped - needs mobile phone in kitchen
    -- 'random/v0_100/g4', -- worked but in an instance one actor was waiting and another was infinitely washing hands
    -- 'random/v0_100/g5', -- gym: interlocking -> one actor is on the Tai Chi location and wants to punch, the other is on the Punch location and wants to Tai Chi
    -- 'random/v0_100/g6',
    -- 'random/v0_100/g7',
    -- 'random/v0_100/g8', -- invalid
    -- 'random/v0_100/g9',
    -- 'random/v0_100/g10',
    -- 'random/v0_100/g11',
    -- 'random/v0_100/g12',
    -- 'random/v0_100/g13',
    -- 'random/v0_100/g14',
    -- 'random/v0_100/g15',
    -- 'random/v0_100/g16',
    -- 'random/v0_100/g17',
    -- 'random/v0_100/g18',
    -- 'random/v0_100/g19',
    -- 'random/v0_100/g20',
    -- 'random/v0_100/g21',
    -- 'random/v0_100/g22',
    -- 'random/v0_100/g23',
    -- 'random/v0_100/g24',
    -- 'random/v0_100/g25',
    -- 'random/v0_100/g26',
    -- 'random/v0_100/g27',
    -- 'random/v0_100/g28',
    -- 'random/v0_100/g29',
    -- 'random/v0_100/g30',
    -- 'random/v0_100/g31',
    -- 'random/v0_100/g32',
    -- 'random/v0_100/g33',
    -- 'random/v0_100/g34',
    -- 'random/v0_100/g35',
    -- 'random/v0_100/g36',
    -- 'random/v0_100/g37',
    -- 'random/v0_100/g38',
    -- 'random/v0_100/g39',
    -- 'random/v0_100/g40',
    -- 'random/v0_100/g41',
    -- 'random/v0_100/g42',
    -- 'random/v0_100/g43',
    -- 'random/v0_100/g44',
    -- 'random/v0_100/g45',
    -- 'random/v0_100/g46',
    -- 'random/v0_100/g47',
    -- 'random/v0_100/g48',
    -- 'random/v0_100/g49',
    -- 'random/v0_100/g50',
    -- 'random/v0_100/g51',
    -- 'random/v0_100/g52',
    -- 'random/v0_100/g53',
    -- 'random/v0_100/g54',
    -- 'random/v0_100/g55',
    -- 'random/v0_100/g56',
    -- 'random/v0_100/g57',
    -- 'random/v0_100/g58',
    -- 'random/v0_100/g59',
    -- 'random/v0_100/g60',
    -- 'random/v0_100/g61',
    -- 'random/v0_100/g62',
    -- 'random/v0_100/g63',
    -- 'random/v0_100/g64',
    -- 'random/v0_100/g65',
    -- 'random/v0_100/g66',
    -- 'random/v0_100/g67',
    -- 'random/v0_100/g68',
    -- 'random/v0_100/g69',
    -- 'random/v0_100/g70',
    -- 'random/v0_100/g71',
    -- 'random/v0_100/g72',
    -- 'random/v0_100/g73',
    -- 'random/v0_100/g74',
    -- 'random/v0_100/g75',
    -- 'random/v0_100/g76',
    -- 'random/v0_100/g77',
    -- 'random/v0_100/g78',
    -- 'random/v0_100/g79',
    -- 'random/v0_100/g80',
    -- 'random/v0_100/g81',
    -- 'random/v0_100/g82',
    -- 'random/v0_100/g83',
    -- 'random/v0_100/g84',
    -- 'random/v0_100/g85',
    -- 'random/v0_100/g86',
    -- 'random/v0_100/g87',
    -- 'random/v0_100/g88',
    -- 'random/v0_100/g89',
    -- 'random/v0_100/g90',
    -- 'random/v0_100/g91',
    -- 'random/v0_100/g92',
    -- 'random/v0_100/g93',
    -- 'random/v0_100/g94',
    -- 'random/v0_100/g95',
    -- 'random/v0_100/g96',
    -- 'random/v0_100/g97',
    -- 'random/v0_100/g98',
    -- 'random/v0_100/g99',
}
SPECTATORS = {}