--- GameWorldExporter.lua
--- Dynamically extracts game world capabilities for the multiagent story generation system.
--- This module scans all episodes, objects, actions, and POIs to build a comprehensive
--- capabilities JSON that LLMs can use to generate grounded stories.
---
--- @class GameWorldExporter

GameWorldExporter = class(function(o)
    o.episodes = {}
    o.actionCatalog = {}
    o.objectTypes = {}
    o.actionChains = {}
    o.spatialRelations = {"near", "behind", "left", "right", "on", "in_front"}
    o.temporalRelations = {"after", "before", "starts_with", "concurrent", "next"}

    -- Canonical action→object type mappings
    -- These override aggregated template data to ensure correct action-object associations
    o.canonicalActionObjects = {
        -- Sleep = {"Bed"},
        -- WashHands = {"Sink"},
        -- GetOn = {"Bed", "Treadmill", "GymBike", "BenchPress"},
        -- GetOff = {"Bed", "Treadmill", "GymBike", "BenchPress", "Sofa"},
        -- JogTreadmill = {"Treadmill"},
        -- PedalGymBike = {"GymBike"},
        -- BenchpressWorkOut = {"BenchPress"},
        -- SitDown = {"Chair", "Sofa", "Armchair"},
        -- StandUp = {"Chair", "Sofa", "Armchair"}
    }
end)

--- Main export function that orchestrates the entire extraction process.
--- Outputs JSON to the multiagent_story_system/data folder.
function GameWorldExporter:ExportCapabilities()
    print("=== Starting Game Capabilities Export ===")

    local output = {
        episodes = {},
        action_catalog = {},
        object_types = {},
        action_chains = {},
        spatial_relations = self.spatialRelations,
        temporal_relations = self.temporalRelations,
        spawnable_objects = {},
        interactions = {},
        middle_actions = {},
        episode_catalog = {},
        player_skins = {},
        camera_actions = {}
    }

    -- Dynamically extract from existing global tables (no hardcoding)
    -- Create fresh arrays to avoid metatable/reference serialization issues (^T^)
    if CURRENT_STORY then
        if CURRENT_STORY.SpawnableObjects then
            for _, obj in ipairs(CURRENT_STORY.SpawnableObjects) do
                table.insert(output.spawnable_objects, obj)
            end
        end

        if CURRENT_STORY.Interactions then
            for _, interaction in ipairs(CURRENT_STORY.Interactions) do
                table.insert(output.interactions, interaction)
            end
        end

        if CURRENT_STORY.MiddleActions then
            for _, action in ipairs(CURRENT_STORY.MiddleActions) do
                table.insert(output.middle_actions, action)
            end
        end

        print("Extracted spawnable objects: " .. #output.spawnable_objects)
        print("Extracted interactions: " .. #output.interactions)
        print("Extracted middle actions: " .. #output.middle_actions)
    end

    -- Iterate through all DynamicEpisodes
    local episodeCount = 0
    if CURRENT_STORY and CURRENT_STORY.DynamicEpisodes then
        for _, episodeName in ipairs(CURRENT_STORY.DynamicEpisodes) do
            print("Processing episode: " .. episodeName)
            local episode = DynamicEpisode(episodeName)
            if episode then
                local success = episode:LoadFromFile()
                local episodeData = self:ExtractEpisodeData(episode)
                table.insert(output.episodes, episodeData)
                table.insert(self.episodes, episodeData)  -- Store for catalog building
                episodeCount = episodeCount + 1
            else
                print("WARNING: Could not load episode " .. episodeName)
            end
        end
    end
    print("Processed " .. episodeCount .. " episodes")

    -- Build catalogs DYNAMICALLY from extracted data
    output.action_catalog = self:BuildActionCatalogDynamic()
    output.object_types = self:BuildObjectTypesCatalogDynamic()
    output.action_chains = self:ExtractActionChains()
    output.episode_catalog = self:BuildEpisodeCatalog()
    output.player_skins = self:BuildPlayerSkinsSection()
    output.camera_actions = self:BuildCameraActionsSection()

    print("Action catalog size: " .. self:CountKeys(output.action_catalog))
    print("Object types: " .. self:CountKeys(output.object_types))
    print("Episode catalog size: " .. self:CountKeys(output.episode_catalog))
    print("Player skins - Male: " .. #output.player_skins.male .. ", Female: " .. #output.player_skins.female)

    -- Write to Python folder (relative path from resource root)
    local outputPath = "game_capabilities.json"
    local jsonStr = toJSON(output, true)

    if jsonStr then
        local file = fileCreate(outputPath)
        if file then
            fileWrite(file, jsonStr)
            fileClose(file)
            print("=== Export Complete ===")
            print("Output written to: " .. outputPath)
        else
            print("ERROR: Could not create output file at " .. outputPath)
        end
    else
        print("ERROR: Could not serialize data to JSON")
    end
end

--- Extracts all data from a single episode.
--- @param episode Episode The episode to extract data from
--- @return table Episode data structure
function GameWorldExporter:ExtractEpisodeData(episode)
    -- Initialize episode to process regions properly
    -- This calls ProcessRegions() internally and assigns objects/POIs to regions
    if not episode.temporaryInitialized then
        episode:Initialize(true)
    end

    local data = {
        name = episode.name or "unknown",
        regions = {},
        objects = {},
        pois = {},
        episode_links = {}
    }

    -- Extract regions with their already-populated POIs and objects from ProcessRegions()
    if episode.Regions then
        for _, region in ipairs(episode.Regions) do
            local regionData = {
                name = region.name or "unnamed",
                description = region.Description or "",
                pois = {},
                objects = {}
            }

            -- Read from region.Objects populated by ProcessRegions()
            if region.Objects then
                for _, obj in ipairs(region.Objects) do
                    table.insert(regionData.objects, ((obj.type or '') .. ' (' .. (obj.Description or "unknown") .. ')'))
                end
            end

            -- Read from region.POI populated by ProcessRegions()
            if region.POI then
                for _, poi in ipairs(region.POI) do
                    table.insert(regionData.pois, poi.Description or "unknown")
                end
            end

            table.insert(data.regions, regionData)
        end
    end

    -- Extract objects DYNAMICALLY
    -- After Initialize(true), objects have their .Region set
    if episode.Objects then
        for _, obj in ipairs(episode.Objects) do
            local objData = {
                type = obj.type or "Unknown",
                description = obj.Description or "",
                region = obj.Region and obj.Region.name or "unknown"
            }
            table.insert(data.objects, objData)

            -- Build object type catalog dynamically
            if obj.type then
                if not self.objectTypes[obj.type] then
                    self.objectTypes[obj.type] = {
                        instances = {},
                        actions = {}
                    }
                end
                table.insert(self.objectTypes[obj.type].instances, objData)
            end
        end
    end

    -- Extract POIs with actions DYNAMICALLY
    -- After Initialize(true), POIs have their .Region set
    if episode.POI then
        for _, poi in ipairs(episode.POI) do
            local poiData = {
                description = poi.Description or "",
                region = poi.Region and poi.Region.name or "unknown",
                interactions_only = poi.interactionsOnly or false,
                episode_links = poi.episodeLinks or {},
                actions = {}
            }

            -- Collect episode links for meta-episode support
            if poi.episodeLinks and #poi.episodeLinks > 0 then
                for _, linkName in ipairs(poi.episodeLinks) do
                    local found = false
                    for _, existing in ipairs(data.episode_links) do
                        if existing == linkName then
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(data.episode_links, linkName)
                    end
                end
            end

            -- Extract actions from POI's allActions (not PossibleActions)
            -- allActions contains the actual defined actions, PossibleActions includes auto-generated Move actions
            if poi.allActions then
                for _, action in ipairs(poi.allActions) do
                    -- Skip Move actions - they are auto-generated by Initialize
                    if action.Name ~= "Move" then
                        -- Extract object type ensuring it's a string (prevent ^T^ serialization)
                        local objectType = nil
                        if action.TargetItem and action.TargetItem.type then
                            if type(action.TargetItem.type) == "string" then
                                objectType = action.TargetItem.type
                            elseif type(action.TargetItem.type) == "table" and action.TargetItem.type.type then
                                objectType = tostring(action.TargetItem.type.type)
                            end
                        end

                        -- Get entities from extraction (may contain references)
                        local extractedEntities = self:ExtractActionEntities(action)

                        -- Create fresh copy with explicit string coercion to prevent ^T^ serialization
                        local cleanEntities = {}
                        for _, entity in ipairs(extractedEntities) do
                            -- Force to string to avoid any table/metatable references
                            table.insert(cleanEntities, tostring(entity))
                        end

                        local actionData = {
                            type = action.Name or "Unknown",
                            requires_object = action.TargetItem ~= nil,
                            object_type = objectType,
                            entities = cleanEntities  -- Use clean copy, not reference
                        }
                        table.insert(poiData.actions, actionData)

                        -- Build action catalog dynamically (excluding Move)
                        if action.Name then
                            if not self.actionCatalog[action.Name] then
                                -- Create separate copy for action catalog to avoid shared references
                                local catalogEntities = {}
                                for _, entity in ipairs(actionData.entities) do
                                    table.insert(catalogEntities, entity)
                                end

                                self.actionCatalog[action.Name] = {
                                    entities = catalogEntities,  -- Separate copy
                                    requires_object = actionData.requires_object,
                                    object_types = {},
                                    description = self:InferActionDescription(action.Name),
                                    category = self:InferActionCategory(action.Name)
                                }
                            end

                            -- Track which object types this action works with
                            if actionData.object_type then
                                local found = false
                                for _, existingType in ipairs(self.actionCatalog[action.Name].object_types) do
                                    if existingType == actionData.object_type then
                                        found = true
                                        break
                                    end
                                end
                                if not found then
                                    table.insert(self.actionCatalog[action.Name].object_types, actionData.object_type)
                                end
                            end
                        end
                    end
                end
            end

            table.insert(data.pois, poiData)
        end
    end

    return data
end

--- Extracts entity types required for an action.
--- Ensures all entities are strings to avoid ^T^ serialization issues.
--- For Give/Receive actions, ensures actors come before objects.
--- @param action Action The action to analyze
--- @return table List of entity types (strings only)
function GameWorldExporter:ExtractActionEntities(action)
    local entities = {}

    -- Always has actor
    table.insert(entities, "Actor")

    -- For Give/Receive actions: add Actor2 before Object
    local giveReceiveActions = {"Give", "INV-Give", "Receive"}
    local isGiveReceive = false
    if action.Name then
        for _, giveAction in ipairs(giveReceiveActions) do
            if action.Name == giveAction then
                table.insert(entities, "Actor2")
                isGiveReceive = true
                break
            end
        end
    end

    -- Add object type (after Actor2 for Give/Receive, otherwise after Actor)
    if action.TargetItem then
        local objType = action.TargetItem.type

        -- Ensure we get string, not table reference (prevents ^T^ serialization)
        if type(objType) == "string" then
            table.insert(entities, objType)
        elseif type(objType) == "table" then
            -- If it's a table, try to get a string representation
            if objType.type and type(objType.type) == "string" then
                table.insert(entities, objType.type)
            else
                -- Fallback to generic Object
                table.insert(entities, "Object")
            end
        else
            table.insert(entities, "Object")
        end
    end

    -- Check if is interaction (has second actor) - only add if not already added
    if not isGiveReceive then
        local interactionActions = {"Handshake", "Hug", "Kiss", "Talk", "LookAt"}
        if action.Name then
            for _, intAction in ipairs(interactionActions) do
                if action.Name == intAction then
                    table.insert(entities, "Actor2")
                    break
                end
            end
        end
    end

    return entities
end

--- Builds the action catalog from accumulated data.
--- Uses canonical mappings when available to override aggregated template data.
--- @return table Action catalog
function GameWorldExporter:BuildActionCatalogDynamic()
    local catalog = {}

    for actionName, actionData in pairs(self.actionCatalog) do
        -- Use canonical mapping if available, otherwise use aggregated types from templates
        local compatibleObjects = self.canonicalActionObjects[actionName] or actionData.object_types

        -- Derive correct entities from canonical mapping
        local entities = actionData.entities
        if self.canonicalActionObjects[actionName] and #self.canonicalActionObjects[actionName] > 0 then
            -- Build entities from canonical mapping: Actor + first canonical object type
            entities = {"Actor", self.canonicalActionObjects[actionName][1]}

            -- Check if this is an interaction action (needs Actor2)
            local interactionActions = {"Give", "INV-Give", "Handshake", "Hug", "Kiss", "Talk", "LookAt"}
            for _, intAction in ipairs(interactionActions) do
                if actionName == intAction then
                    table.insert(entities, "Actor2")
                    break
                end
            end
        end

        catalog[actionName] = {
            entities = entities,
            description = actionData.description,
            category = actionData.category,
            requires_object = actionData.requires_object,
            compatible_objects = compatibleObjects
        }
    end

    return catalog
end

--- Builds the object types catalog from accumulated data.
--- @return table Object types catalog
function GameWorldExporter:BuildObjectTypesCatalogDynamic()
    local catalog = {}

    for objectType, objectData in pairs(self.objectTypes) do
        -- Determine if spawnable
        local isSpawnable = false
        if CURRENT_STORY and CURRENT_STORY.SpawnableObjects then
            for _, spawnableType in ipairs(CURRENT_STORY.SpawnableObjects) do
                if objectType == spawnableType then
                    isSpawnable = true
                    break
                end
            end
        end

        catalog[objectType] = {
            spawnable = isSpawnable,
            actions = self:ExtractActionsForObjectType(objectType),
            instance_count = #objectData.instances
        }
    end

    return catalog
end

--- Finds all actions compatible with a specific object type.
--- Uses canonical mappings when available to ensure correct associations.
--- @param objectType string The object type
--- @return table List of action names
function GameWorldExporter:ExtractActionsForObjectType(objectType)
    local actions = {}

    for actionName, actionData in pairs(self.actionCatalog) do
        if actionData.requires_object then
            -- Use canonical mapping if available, otherwise use aggregated types
            local compatibleTypes = self.canonicalActionObjects[actionName] or actionData.object_types

            for _, compatibleType in ipairs(compatibleTypes) do
                if compatibleType == objectType then
                    table.insert(actions, actionName)
                    break
                end
            end
        end
    end

    return actions
end

--- Builds a compact episode catalog with just names, links, and region names.
--- Provides a lightweight index of episode structure without full POI/object/action details.
--- @return table Episode catalog keyed by episode name
function GameWorldExporter:BuildEpisodeCatalog()
    local catalog = {}

    for _, episode in ipairs(self.episodes) do
        local regionNames = {}
        for _, region in ipairs(episode.regions or {}) do
            table.insert(regionNames, region.name or "unnamed")
        end

        -- Create fresh copy of episode links to avoid ^T^ serialization
        local episodeLinks = {}
        if episode.episode_links then
            for _, linkName in ipairs(episode.episode_links) do
                table.insert(episodeLinks, tostring(linkName))
            end
        end

        catalog[episode.name] = {
            linked_episodes = episodeLinks,
            regions = regionNames
        }
    end

    return catalog
end

--- Builds player skins section from SetPlayerSkin.PlayerSkins.
--- Organizes skins by gender for easier selection during story generation.
--- @return table Player skins organized by gender {male = {...}, female = {...}}
function GameWorldExporter:BuildPlayerSkinsSection()
    local skins = {
        male = {},
        female = {}
    }

    for _, skin in ipairs(SetPlayerSkin.PlayerSkins) do
        local skinData = {
            id = skin.Id,
            description = skin.Description
        }

        if skin.Gender == 1 then
            table.insert(skins.male, skinData)
        elseif skin.Gender == 2 then
            table.insert(skins.female, skinData)
        end
    end

    return skins
end

--- Builds camera actions section with recording behavior documentation.
--- Explains how record/stop commands control frame capture during video generation.
--- @return table Camera actions and behavior documentation
function GameWorldExporter:BuildCameraActionsSection()
    return {
        actions = {"record", "stop"},
        behavior = {
            with_camera_section = "When a camera section is present in the graph, the system starts in non-recording mode. No frames are recorded for any events before the first 'record' command. Use 'stop' to pause recording - no frames will be captured between 'stop' and the next 'record' command.",
            without_camera_section = "When no camera section is present in the graph (legacy mode), the system automatically records all frames from the beginning to the end of the story."
        },
        focus_management = "Camera automatically handles focus switching between actors, episode transitions, and fade effects. Focus duration: 2 seconds normal, 5 seconds for context changes (cross-episode transitions)."
    }
end

--- Extracts action chains - the valid sequences in which actions can be executed.
--- This is critical for the LLM to understand action dependencies.
--- @return table Action chains structure
function GameWorldExporter:ExtractActionChains()
    local chains = {
        -- Pickup-use-putdown chains
        object_interaction = {
            description = "Object interaction patterns - not strictly linear",
            base_sequence = {"PickUp", "Use", "PutDown"},
            variations = {
                food = {"PickUp", "Eat", "PutDown"},
                drink = {"PickUp", "Drink", "PutDown"}
            },
            note = "Picked-up objects can also be: Given to others, Received, Used (Drink/Eat), Given back. These form flexible interaction patterns beyond simple linear sequences."
        },

        -- Spawnable object chains
        spawnable_usage = {
            description = "Spawnable object lifecycle",
            sequence = {"TakeOut", "Use", "Stash"},
            variations = {
                cigarette = {"TakeOut", "SmokeIn", "Smoke", "SmokeOut", "Stash"},
                phone = {"TakeOut", "AnswerPhone", "TalkPhone", "HangUp", "Stash"}
            }
        },

        -- Sitting chains
        sitting = {
            description = "Sitting at location with POI-specific middle actions",
            sequence = {"SitDown", "POI-SpecificActions", "StandUp"},
            always_available = {"LookAt"},
            poi_specific_actions = {"Eat", "OpenLaptop", "TypeOnKeyboard", "CloseLaptop", "PunchDesk", "LookAtWatch", "LayOnElbow"},
            note = "While sitting: LookAt is ALWAYS available. Other actions (eat, laptop usage, etc.) are ONLY available if defined in that specific POI's allActions. The actual available actions are indicated in individual POI definitions, not as a generic list."
        },

        -- Movement chains
        movement = {
            description = "Location change requirement",
            pattern = "Must use Move before acting in different location. Otherwise, a move action is inserted automatically by the system.",
            note = "Move action has two locations in Entities array: [source, target]"
        },

        -- Bed chains
        bed_usage = {
            description = "Getting into bed and sleeping",
            sequence = {"GetOn", "Sleep", "GetOff"},
            note = "GetOff IS ALWAYS required if actor needs to Move after lying/sleeping. Actors CAN be left in sleeping state at story end, BUT context switches while sleeping/sitting cause bugs on context switch back. BEST PRACTICE: Don't leave actors sitting/sleeping during context switches. WORST CASE: Re-sit/re-sleep off camera (include actions in graph but don't record them)."
        },

        -- Laptop chains
        laptop_usage = {
            description = "Using laptop typically while seated",
            sequence = {"SitDown", "OpenLaptop", "TypeOnKeyboard", "CloseLaptop", "StandUp"},
            optional_actions = {"OpenLaptop", "LayOnElbow", "PunchDesk", "LookAtWatch", "CloseLaptop"},
            note = "OpenLaptop, TypeOnKeyboard, and CloseLaptop are optional (actor can sit down and stand up without doing anything). Also includes optional actions: LayOnElbow, PunchDesk, LookAtWatch."
        },

        -- Interaction chains (require both actors present)
        interactions = {
            description = "Multi-actor interactions requiring both actors in same location",
            actions = CURRENT_STORY and CURRENT_STORY.Interactions or {},
            requirement = "Both actors must be in same location",
            temporal_requirement = "CRITICAL: ALL interactions MUST have the same 'starts_with' temporal relation between the actors involved to ensure proper synchronization. Each interaction has a different starts_with relation.",
            note = "Give requires INV-Give for receiver, Handshake/Hug/Kiss requires both actors to perform action. The starts_with constraint ensures actors perform interactions simultaneously."
        },

        -- Observation and gesture actions
        observation_actions = {
            description = "Actions for observing and gesturing",
            actions = {"LookAt", "Wave"},
            note = "LookAt can be directed at actors, objects, or locations. Wave is typically a gesture. These actions can be performed standalone. LookAt can be performed while sitting/standing."
        },

        -- Music player actions
        music_player = {
            description = "Interacting with music player/stereo",
            sequence = {"TurnOn", "Dance", "TurnOff"},
            note = "TurnOn music player/turntable, then Dance. TurnOff is the closing action. Before moving to a different location, actor MUST TurnOff music player. Works with TurnTable, TapePlayer objects."
        },

        -- Gym equipment usage
        gym_equipment = {
            description = "Using gym exercise equipment",
            base_sequence = {"GetOn", "ExerciseAction", "GetOff"},
            equipment_types = {
                treadmill = {"GetOn", "JogTreadmill", "GetOff"},
                gym_bike = {"GetOn", "PedalGymBike", "GetOff"},
                bench_press = {"GetOn", "BenchpressWorkOut", "GetOff"}
            },
            note = "GetOn required before using equipment. GetOff ALWAYS required before moving away. Actor cannot move while on equipment without GetOff."
        },

        -- Dumbbells usage
        dumbbells_usage = {
            description = "Using dumbbells for exercise",
            sequence = {"PickUp", "DumbbellsWorkOut", "PutDown"},
            note = "Dumbbells use pickup pattern, not equipment mounting. PickUp from floor, perform workout, PutDown to floor."
        },

        -- Exercise and fitness actions
        exercise_actions = {
            description = "Standalone exercise and fitness activities",
            actions = {"TaiChi", "Punch"},
            note = "TaiChi is performed standing in open space (no equipment). Punch requires PunchingBag object. These don't require equipment mounting (GetOn/GetOff)."
        },

        -- Important action ordering rules
        ordering_rules = {
            {
                rule = "Exists events must come first",
                description = "All actors and objects must have Exists events before being used"
            },
            {
                rule = "Move before action in new location",
                description = "Actor must Move to location before performing actions there"
            },
            {
                rule = "PickUp before use",
                description = "Must PickUp object before Eat/Drink/etc"
            },
            {
                rule = "TakeOut before spawnable use",
                description = "Must TakeOut spawnable object before using it"
            },
            {
                rule = "SitDown before seated actions",
                description = "Must SitDown before actions that require sitting (OpenLaptop, Eat at table, etc)"
            },
            {
                rule = "StandUp before moving from seated",
                description = "Must StandUp before moving from seated actions"
            },
            {
                rule = "GetOn before gym equipment use",
                description = "Must GetOn equipment (treadmill, gym bike, bench press) before performing exercise actions"
            },
            {
                rule = "GetOff before moving from equipment",
                description = "Must GetOff gym equipment before actor can move to different location"
            },
            {
                rule = "GetOn before Sleep",
                description = "Must GetOn before Sleep action"
            },
            {
                rule = "GetOff before moving from bed",
                description = "Must GetOff if actor needs to Move after sleeping"
            },
            {
                rule = "PickUp before dumbbells workout",
                description = "Must PickUp dumbbells before DumbbellsWorkOut action"
            },
            {
                rule = "PutDown before moving from dumbbells",
                description = "Must PutDown dumbbells before actor can move to different location"
            },
            {
                rule = "TurnOff before moving from music player",
                description = "Must TurnOff music player/turntable before actor can move to different location"
            }
        }
    }

    return chains
end

--- Infers a human-readable description from an action name.
--- @param actionName string The action name in CamelCase
--- @return string Description
function GameWorldExporter:InferActionDescription(actionName)
    -- Generate description from action name (camelCase parsing)
    local words = {}
    for word in actionName:gmatch("[A-Z][a-z]*") do
        table.insert(words, word:lower())
    end

    if #words == 0 then
        return "Actor performs " .. actionName
    end

    return "Actor " .. table.concat(words, " ")
end

--- Infers the category of an action from its name.
--- @param actionName string The action name
--- @return string Category
function GameWorldExporter:InferActionCategory(actionName)
    -- Categorize based on name patterns
    if actionName:match("Sit") or actionName:match("Stand") or actionName:match("GetOn") then
        return "positional"
    elseif actionName:match("Move") then
        return "movement"
    elseif actionName:match("Pick") or actionName:match("Put") or actionName:match("TakeOut") or actionName:match("Stash") then
        return "interaction"
    elseif actionName:match("Eat") or actionName:match("Drink") then
        return "consumption"
    elseif actionName:match("Give") or actionName:match("Handshake") or actionName:match("Hug") or actionName:match("Kiss") or actionName:match("Talk") then
        return "social"
    elseif actionName:match("Open") or actionName:match("Close") or actionName:match("Type") then
        return "object_interaction"
    elseif actionName:match("Sleep") or actionName:match("Smoke") or actionName:match("TaiChi") or actionName:match("WorkOut") then
        return "activity"
    elseif actionName:match("Look") then
        return "observation"
    elseif actionName:match("Answer") or actionName:match("HangUp") or actionName:match("TalkPhone") then
        return "communication"
    elseif actionName:match("Wash") then
        return "hygiene"
    elseif actionName:match("Wave") or actionName:match("Laugh") then
        return "emotion"
    else
        return "general"
    end
end


--- Utility function to count keys in a table.
--- @param t table The table
--- @return number Count of keys
function GameWorldExporter:CountKeys(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end
