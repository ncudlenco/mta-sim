CURRENT_STORY = nil
SCREENSHOTS = {}
MAX_ACTIONS = 1000
MAX_STORY_TIME = 360
LOG_FREQUENCY = 1000 / 30 --in milliseconds
DEBUG = true
DEBUG_PATHFINDING = false
DEBUG_VALIDATION = false
DEBUG_LOGGER = false
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
LOG_DATA = true
SIMULATION_MODE = true

STATIC_CAMERA = SIMULATION_MODE
FREE_ROAM = not SIMULATION_MODE
DEFINING_EPISODES = not SIMULATION_MODE

DISABLE_BETWEEN_POINTS_TELEPORTATION = false

LOAD_FROM_GRAPH = true
INPUT_GRAPHS = {
    'random/v1_1actor/g0',
    'random/v1_1actor/g1',
    'random/v1_1actor/g2',
    'random/v1_1actor/g3',
    'random/v1_1actor/g4',
    'random/v1_1actor/g5',
    'random/v1_1actor/g6',
    'random/v1_1actor/g7',
    'random/v1_1actor/g8',
    'random/v1_1actor/g9',
    'random/v2_2actors_nointeractions/g0',
    'random/v2_2actors_nointeractions/g1',
    'random/v2_2actors_nointeractions/g2',
    'random/v2_2actors_nointeractions/g3',
    'random/v2_2actors_nointeractions/g4',
    'random/v2_2actors_nointeractions/g5',
    'random/v2_2actors_nointeractions/g6',
    'random/v2_2actors_nointeractions/g7',
    'random/v2_2actors_nointeractions/g8',
    'random/v2_2actors_nointeractions/g9',
    'random/v3_2actors_withinteractions/g0',
    'random/v3_2actors_withinteractions/g1',
    'random/v3_2actors_withinteractions/g2',
    'random/v3_2actors_withinteractions/g3',
    'random/v3_2actors_withinteractions/g4',
    'random/v3_2actors_withinteractions/g5',
    'random/v3_2actors_withinteractions/g6',
    'random/v3_2actors_withinteractions/g7',
    'random/v3_2actors_withinteractions/g8',
    'random/v3_2actors_withinteractions/g9',
    'random/v3_3actors/g0',
    'random/v3_3actors/g1',
    'random/v3_3actors/g2',
    'random/v3_3actors/g3',
    'random/v3_3actors/g4',
    'random/v3_3actors/g5',
    'random/v3_3actors/g6',
    'random/v3_3actors/g7',
    'random/v3_3actors/g8',
    'random/v3_3actors/g9',
    'random/v4_1action/g0',
    'random/v4_1action/g1',
    'random/v4_1action/g10',
    'random/v4_1action/g12', --PickUp remote -> doesn't exist
    'random/v4_1action/g13',
    'random/v4_1action/g2',
    'random/v4_1action/g20',
    'random/v4_1action/g27', --Fixed the reverse_object_map assignment during validation and simulation: search for the first non-interaction event with the object as target. Use an object part of such a chain.
    'random/v4_1action/g3', --SitDown -> the target should be chair, not desk (and I cannot allow this anymore without having a chair with only 2 actions -> sit down and stand up)
    'random/v4_1action/g4', -- Dance entities should be only with the actor
    'random/v4_1action/g44',
    'random/v4_1action/g56',
    'random/v4_1action/g6',
    'random/v4_1action/g63',
    'random/v4_1action/g7',
    'random/v4_1action/g8',
    'random/v5_1action_interaction/g0',
    'random/v5_1action_interaction/g1',
    'random/v5_1action_interaction/g7',
    'random/v5_1action_interaction/g13', --Replace Joke with Laugh
    'random/v5_1action_interaction/g28',
}
SPECTATORS = {}