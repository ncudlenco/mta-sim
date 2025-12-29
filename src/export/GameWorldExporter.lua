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
    o.timeframes = {"morning", "afternoon", "evening", "night", "midnight"}

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
                episode:LoadFromFile()
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
    output.camera_actions = self:BuildCameraSection()

    print("Action catalog size: " .. self:CountKeys(output.action_catalog))
    print("Object types: " .. self:CountKeys(output.object_types))
    print("Episode catalog size: " .. self:CountKeys(output.episode_catalog))
    print("Player skins - Male: " .. #output.player_skins.male .. ", Female: " .. #output.player_skins.female)

    -- Write to Python folder (relative path from resource root)
    local outputPath = "simulation_environment_capabilities.json"
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

                        local possibleNextActions = {}
                        if isArray(action.NextAction) then
                            for _, nextAction in ipairs(action.NextAction) do
                                if nextAction and nextAction.Name then
                                    table.insert(possibleNextActions, nextAction.Name)
                                end
                            end
                        elseif action.NextAction and action.NextAction.Name then
                            table.insert(possibleNextActions, action.NextAction.Name)
                        end

                        local actionData = {
                            type = action.Name or "Unknown",
                            requires_object = action.TargetItem ~= nil,
                            object_type = objectType,
                            possible_next_actions = possibleNextActions,
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
            local actionsWithActor2 = {"Give", "INV-Give", "Handshake", "Hug", "Kiss", "Talk", "LookAt", "Wave"}
            for _, intAction in ipairs(actionsWithActor2) do
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

--- Builds comprehensive camera system documentation.
--- Documents cinematic camera modes, shot types, framing, recording control, and examples.
--- @return table Complete camera capabilities documentation
function GameWorldExporter:BuildCameraSection()
    return {
        description = "Cinematic camera system for controlling shot composition, framing, and recording during story execution",

        modes = {
            static = {
                description = "Default mode preserving existing behavior",
                behavior = "Camera automatically switches focus between actors every 2 seconds using region predefined static cameras",
                camera_control = "Automatic - no manual control",
                use_case = "Automatic coverage of all actors during story execution from surveillance-style fixed cameras, assigning 2 seconds per actor when they execute actions."
            },
            cinematic = {
                description = "Graph-driven camera control using semantic commands",
                behavior = "Camera controlled explicitly by graph events at event-level granularity",
                camera_control = "Manual - full control via graph commands",
                use_case = "Precise shot composition for narrative video generation"
            }
        },

        recording_control = {
            description = "Recording (artifact collection) is independent from shot control (camera positioning)",
            commands = {
                start = {
                    description = "Begin collecting artifacts",
                    format = {recording = "start"},
                    note = "Can be combined with shot commands or used alone"
                },
                stop = {
                    description = "Stop collecting artifacts",
                    format = {recording = "stop"},
                    note = "Can be combined with shot commands or used alone"
                }
            },
            legacy_support = {
                note = "Legacy commands still supported for backward compatibility",
                commands = {
                    {action = "record"},
                    {action = "stop"}
                }
            }
        },

        shot_types = {
            follow = {
                description = "Track subject continuously as they move with 50ms updates",
                required = {"subject"},
                optional = {"framing"},
                behavior = "Camera updates every 50ms to track subject movement, continues through intermediary regions",
                example = {shot = {type = "follow", subject = "actor0"}},
                example_with_framing = {shot = {type = "follow", subject = "actor0", framing = "wide"}}
            },
            static = {
                description = "Use region predefined static camera",
                required = {},
                optional = {},
                behavior = "Uses Region:SetStaticCameraWhereActorIsInFOVOrRandom()",
                example = {shot = {type = "static"}}
            },
            free = {
                description = "Do not change camera position",
                required = {},
                optional = {},
                behavior = "Camera stays at previous position",
                example = {shot = {type = "free"}}
            },
            show = {
                description = "Medium shot of subject",
                required = {"subject"},
                optional = {"framing"},
                behavior = "One-time camera positioning for medium shot",
                example = {shot = {type = "show", subject = "actor0"}},
                example_with_region = {shot = {type = "show", subject = "living", framing = "wide"}}
            },
            close_up = {
                description = "Close-up shot of subject",
                required = {"subject"},
                optional = {},
                behavior = "Close framing on subject face or object detail",
                example = {shot = {type = "close_up", subject = "object0"}}
            },
            wide = {
                description = "Wide shot of subject or region",
                required = {},
                optional = {"subject", "framing"},
                behavior = "Wide framing of region or subject",
                example_region = {shot = {type = "wide"}},
                example_with_subject = {shot = {type = "wide", subject = "kitchen"}}
            },
            extreme_wide = {
                description = "Extreme wide establishing shot",
                required = {},
                optional = {"subject"},
                behavior = "Very wide framing for establishing shots",
                example = {shot = {type = "extreme_wide", subject = "living"}}
            },
            extreme_close_up = {
                description = "Extreme close-up detail shot",
                required = {"subject"},
                optional = {},
                behavior = "Very close framing for detail shots",
                example = {shot = {type = "extreme_close_up", subject = "object0"}}
            },
            two_shot = {
                description = "Frame two or more subjects together",
                required = {"subjects"},
                optional = {"framing"},
                behavior = "Calculates center point between all subjects, positions camera to frame all",
                example = {shot = {type = "two_shot", subjects = {"actor0", "actor1"}}},
                example_with_framing = {shot = {type = "two_shot", subjects = {"actor0", "actor1", "actor2"}, framing = "wide"}}
            },
            over_shoulder = {
                description = "Behind subject shoulder looking at target",
                required = {"subject", "target"},
                optional = {"framing"},
                behavior = "Camera positioned behind and to side of subject, looking at target",
                example = {shot = {type = "over_shoulder", subject = "actor0", target = "actor1"}}
            }
        },

        framing_types = {
            extreme_wide = {
                distance = 20,
                fov = 90,
                height = 2.5,
                use_case = "Establishing shots, full environment"
            },
            wide = {
                distance = 10,
                fov = 80,
                height = 1.7,
                use_case = "Full scene, multiple actors"
            },
            medium = {
                distance = 5,
                fov = 70,
                height = 1.7,
                use_case = "Waist up (default)",
                default = true
            },
            close_up = {
                distance = 1.5,
                fov = 50,
                height = 1.7,
                use_case = "Face, object detail"
            },
            extreme_close_up = {
                distance = 0.8,
                fov = 40,
                height = 1.7,
                use_case = "Eyes, small details"
            }
        },

        subject_types = {
            actors = {
                format = "actor0, actor1, etc.",
                resolution = "Actor id field from graph",
                example = "actor0"
            },
            objects = {
                format = "object0, cigarette, etc.",
                resolution = "Object ObjectId or id field",
                example = "object0"
            },
            regions = {
                format = "living, kitchen, bedroom, etc.",
                resolution = "Fuzzy match on Region.name field (case-insensitive substring)",
                matching_logic = "Same as action location mapping: Region.name:lower():find(subject:lower())",
                examples = {
                    living = "Matches region living_room",
                    kitchen = "Matches region kitchen_area",
                    bed = "Matches region bedroom"
                }
            }
        },

        schema = {
            camera_actions = {
                mode = {
                    type = "string",
                    values = {"static", "cinematic"},
                    default = "static",
                    required = false
                },
                event_id = {
                    recording = {
                        type = "string",
                        values = {"start", "stop"},
                        required = false
                    },
                    shot = {
                        type = {
                            type = "string",
                            values = {"follow", "static", "free", "show", "close_up", "wide", "extreme_wide", "extreme_close_up", "two_shot", "over_shoulder"},
                            required = true
                        },
                        subject = {
                            type = "string",
                            description = "Primary target entity/region",
                            required = "Varies by shot type"
                        },
                        target = {
                            type = "string",
                            description = "Secondary target (for over_shoulder)",
                            required = false
                        },
                        subjects = {
                            type = "array",
                            description = "Multiple targets (for two_shot)",
                            required = false
                        },
                        framing = {
                            type = "string",
                            values = {"extreme_wide", "wide", "medium", "close_up", "extreme_close_up"},
                            description = "Override default framing",
                            required = false
                        }
                    }
                }
            }
        },

        examples = {
            minimal_cinematic = {
                camera_actions = {
                    mode = "cinematic",
                    action0 = {
                        shot = {
                            type = "follow",
                            subject = "actor0"
                        }
                    }
                },
                note = "No recording control specified - defaults to no recording. Will only follow actor0 even if other actors exist."
            },
            minimal_static = {
                camera_actions = {
                    mode = "static"
                },
                note = "No camera commands specified - defaults to static mode with automatic 2-second actor coverage and full recording."
            },
            with_recording = {
                camera_actions = {
                    mode = "cinematic",
                    action0 = {
                        recording = "start",
                        shot = {
                            type = "follow",
                            subject = "actor0"
                        }
                    },
                    action3 = {
                        recording = "stop"
                    }
                }
            },
            multiple_shots_one_recording = {
                camera_actions = {
                    mode = "cinematic",
                    action0 = {
                        shot = {
                            type = "follow",
                            subject = "actor0"
                        }
                    },
                    action1 = {
                        recording = "start",
                        shot = {
                            type = "close_up",
                            subject = "object0"
                        }
                    },
                    action2 = {
                        shot = {
                            type = "show",
                            subject = "actor0"
                        }
                    },
                    action3 = {
                        recording = "stop",
                        shot = {
                            type = "static"
                        }
                    }
                }
            },
            region_targeting = {
                camera_actions = {
                    mode = "cinematic",
                    action0 = {
                        recording = "start",
                        shot = {
                            type = "extreme_wide",
                            subject = "bedroom"
                        }
                    },
                    action1 = {
                        shot = {
                            type = "wide",
                            subject = "living"
                        },
                        recording = "stop"
                    }
                }
            },
            multi_actor = {
                camera_actions = {
                    mode = "cinematic",
                    action0 = {
                        recording = "start",
                        shot = {
                            type = "follow",
                            subject = "actor0",
                            framing = "medium"
                        }
                    },
                    action1 = {
                        shot = {
                            type = "follow",
                            subject = "actor1",
                            framing = "wide"
                        }
                    },
                    action2 = {
                        shot = {
                            type = "two_shot",
                            subjects = {"actor0", "actor1"}
                        },
                        recording = "stop"
                    }
                }
            }
        },

        default_behavior = {
            without_camera_section = "When no camera section is present in the graph (default mode), the system uses static mode and automatically records all frames from beginning to end",
            with_camera_section_no_mode = "If camera section present but mode not specified, defaults to static mode"
        },

        validation = {
            description = "Wall-aware camera positioning ensures camera never clips through walls and stays within region bounds",
            features = {
                "Line-of-sight validation using MTA raycasting (isLineOfSightClear)",
                "Region polygon bounds checking (Region:IsPointInside2)",
                "Automatic position adjustment when camera becomes invalid",
                "Region change detection for continuous tracking"
            },
            frequency = {
                static_shots = "Validated once when shot executes",
                continuous_tracking = "Validated every 50ms (20 times per second)",
                region_changes = "Full revalidation when actor moves to new region"
            },
            adjustment_strategies = {
                incremental = "Move camera toward subject until line-of-sight is clear (best for follow shots)",
                slide = "Place camera along wall surface using surface normal (best for over-shoulder)",
                rotate = "Rotate around subject to find clear angle (best for two-shot)",
                fallback = "Use region static camera if no valid position found"
            },
            configuration = {
                ENABLE_CAMERA_VALIDATION = {type = "boolean", default = true, description = "Toggle validation system on/off"},
                CAMERA_WALL_OFFSET = {type = "number", default = 0.5, description = "Distance from walls when adjusting position (units)"},
                DEBUG_CAMERA_VALIDATION = {type = "boolean", default = false, description = "Enable detailed validation logging"}
            },
            performance = {
                cost_per_validation = "~0.2ms (line-of-sight + polygon check)",
                validation_rate = "20 validations/second for continuous tracking",
                impact = "Negligible - much lower than frame rate (60fps)"
            }
        },

        notes = {
            "Camera mode is configured at graph level, not per-event",
            "Granularity is at event level - one camera command per event",
            "Recording and shot control are independent - can be used together or separately",
            "Region resolution uses same fuzzy matching as action location mapping",
            "Continuous tracking (follow) uses 50ms timer updates with automatic validation",
            "Context switching automatically handled across linked episodes",
            "Camera position validated to prevent wall clipping and ensure line-of-sight",
            "Validation uses MTA raycasting and region polygon bounds checking",
            "Invalid camera positions automatically adjusted using intelligent strategies"
        }
    }
end

--- Extracts action chains - the valid sequences in which actions can be executed.
--- This is critical for the users to understand action dependencies.
--- @return table Action chains structure
function GameWorldExporter:ExtractActionChains()
    local chains = {
        general_instructions = {
            description = "General rules for action sequencing",
            rules = {
                "Actions MUST follow defined sequences.",
                "The exact concrete possible actions that can be performed in a POI are defined in that POI's actions list.",
                "Each action from a POI has a list of possible next actions that can be performed after it. If there is more than one possible next action, any of them can be chosen. The additional option is ALWAYS to NOT perform a next action, leaving the actor in the current state until the story ends. Otherwise, if a next action MUST be executed, it can only be from the list of possible actions.",
                "Actions that put actors in a state that does something (e.g., SitDown, TypeOnKeyboard, Sleep, TaiChi) leave the actor with an animation looping in that state (no need for additional actions of same time to make the animation longer). The animation stops when the next valid action is performed or the story ends.",
                "Interactions can ONLY happen while both actors are standing",
                "In addition to the POI-defined possible next actions, the system automatically inserts Move actions as needed when an actor changes location to perform an action in a different region.",
                "In addition to the POI-defined actions, ALWAYS is an option to perform interactions, actions with spawnable objects, or observation_actions. (See below for a foll list of interactions and observation_actions)",
                "The schema for an action event is \"event_id\": {\"Action\": \"$action_name\",\"Entities\": [$performer_id,$target_entity_id,$second_target_entity_id],\"Location\": [$region],\"Timeframe\": null|$time_frame,\"Properties\": {$additional_properties|nothing}}",
                "The $target_entity_id can be the Exists event_id of the object being acted upon or of the actor being interacted with.",
                "Give/INV-Give actions has $performer_id, $(receiver|giver)_actor_id, $object_id in Entities array respectively.",
                "Optional actions are indicated with [Optional] prefix and can be skipped.",
                "Variations provide alternative sequences for specific object types or contexts.",
                "Actors MUST adhere to movement requirements when changing locations.",
                "Multi-actor interactions require same location for both actors.",
                "Other complex interactions can creatively be simulated (e.g. sit down all actors on chairs in the same region (e.g. kitchen, same table), answer phone for actor1 followed by answer phone for actor2 - simulates one calling the other).",
                "Other complex interactions can creatively be simulated with creative temporal chains: e.g., actor0 performs TaiChi, actor1 and actor2 move to porch from bedroom, actor1 waves at actor0 in goodbye, actor2 and actor0 move to street same time, actor1 goes back inside - complex interaction simulated",
                "Story within story can be simulated with creative temporal chains: e.g., actor0 answers phone (main story), then, in another episode with another timeframe illustrate the conversation it has (story within the story), then hang up and stash phone (end of story). Type about, talk about, talk over phone about, can be triggers for next story."
            },
            note = "These rules represent a guide in generating valid action sequences that respect object lifecycles, location constraints, and interaction requirements."
        },
        -- Pickup-use-putdown chains
        pick_upable_interaction = {
            description = "Object interaction patterns - not strictly linear",
            base_sequence = {"PickUp", "Use", "PutDown"},
            variations = {
                food = {"PickUp", "Eat", "PutDown"},
                drink = {"PickUp", "Drink", "PutDown"},
                remote_control = {"PickUp", "[Optional]LookAt", "PutDown"},
            },
            note = "Picked-up objects can also be: Given to others, Received, Used (Drink/Eat) - this does not destroy/consume them, Given back. These form flexible interaction patterns beyond simple linear sequences. The picked up object MUST be put back down by the same actor."
        },

        -- Spawnable object chains
        spawnable_usage = {
            description = "Spawnable object lifecycle",
            sequence = {"TakeOut", "Use", "Stash"},
            variations = {
                cigarette = {"TakeOut", "SmokeIn", "Smoke", "SmokeOut", "Stash"},
                phone = {"TakeOut", "AnswerPhone", "TalkPhone", "HangUp", "Stash"}
            },
            note = "Spawnable objects MUST be TakenOut before use and Stashed after use. Spawnable objects MUST be used, with the spawnable objects sequence, even if the same object exists in the world already."
        },

        -- Sitting chains
        sitting = {
            description = "Sitting at location with POI-specific middle actions",
            sequence = {"SitDown", "POI-SpecificActions", "StandUp"},
            always_available = {"LookAt", "TakeOut", "Stash"},
            poi_specific_actions = {"Eat", "OpenLaptop", "TypeOnKeyboard", "PunchDesk", "LookAtWatch", "LayOnElbow", "CloseLaptop"},
            variations = {
                chair_eating = {"SitDown", "[Optional]Eat", "StandUp"},
                chair_laptop = {"SitDown", "[Optional]OpenLaptop", "[Optional]TypeOnKeyboard", "[Optional]PunchDesk", "[Optional]CloseLaptop", "[Optional]LayOnElbow", "[Optional]LookAtWatch", "StandUp"},
                sofa = {"SitDown", "[Optional]LookAt", "[Optional]TakeOut", "[Optional]Stash", "StandUp"},
                armchair = {"SitDown", "[Optional]LookAt", "[Optional]TakeOut", "[Optional]Stash", "StandUp"}
            },
            note = "While sitting: LookAt is ALWAYS available. Other actions (eat, laptop usage, etc.) are ONLY available if defined in that specific POI's allActions. The actual available actions are indicated in individual POI definitions, not as a generic list. Note that Drink is not available while sitting. Note that food actions are ONLY available on chairs with food (not laptop, sofa or armchair).\n\n Actors CAN be left in any seated state before standing up. Context switches (moving between linked episodes of other actors) while some actors are left looping in a state cause bugs on context switch back. BEST PRACTICE: Don't leave actors looping during context switches. Re-sit and follow with previously seated action off camera (include actions in graph but don't record them)."
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
            note = "GetOff IS ALWAYS required if actor needs to Move after sleeping. Actors CAN be left in sleeping state. Context switches (moving between linked episodes of other actors) while some actors are left sleeping cause bugs on context switch back. BEST PRACTICE: Don't leave actors sleeping during context switches. Re-get-on, and re-sleep off camera (include actions in graph but don't record them)."
        },

        -- Laptop chains
        laptop_usage = {
            description = "Using laptop ONLY while seated on an appropriate chair",
            sequence = {"SitDown", "OpenLaptop", "TypeOnKeyboard", "CloseLaptop", "StandUp"},
            optional_actions = {"OpenLaptop", "LayOnElbow", "PunchDesk", "LookAtWatch", "CloseLaptop"},
            note = "OpenLaptop, TypeOnKeyboard, and CloseLaptop are optional (actor can sit down and stand up without doing anything). Also includes optional actions: LayOnElbow, PunchDesk, LookAtWatch."
        },

        -- Interaction chains (require both actors present)
        interactions = {
            description = "Multi-actor interactions requiring both actors in same location",
            actions = CURRENT_STORY and CURRENT_STORY.Interactions or {},
            requirement = "Both actors must have same location for the interaction Action to be valid.",
            temporal_requirement = "CRITICAL: ALL interactions MUST have the same 'starts_with' temporal relation between the actors involved to ensure proper synchronization. Each interaction has a different starts_with relation.",
            note = "Give requires INV-Give for receiver, Handshake/Hug/Kiss/Talk requires to be duplicated for both actors to perform action. The starts_with constraint between the two interaction events is a MUST to coordinate them."
        },

        -- Observation and gesture actions
        observation_actions = {
            description = "Actions for observing and gesturing",
            actions = {"LookAt", "Wave"},
            note = "LookAt can be directed at actors OR objects but it must be used rarely since it performs no animation. Wave is typically a gesture. These actions can be performed standalone, even if they are not explicitly listed in the episode. LookAt can be performed while sitting/standing."
        },

        -- Music player actions
        music_player = {
            description = "Interacting with music player/stereo",
            sequence = {"TurnOn", "Dance", "TurnOff"},
            note = "TurnOn music player/turntable, then Dance. TurnOff is the closing action. Before moving to a different location, actor MUST TurnOff music player. Works with TurnTable, TapePlayer objects. ONLY for one actor at a time."
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

        hygiene_actions = {
            description = "Personal hygiene actions",
            actions = {"WashHands"},
            note = "Performed at sink or bathroom POIs. No special sequencing required. Sinks usually exist in the kitchen or bathroom."
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
            },
            {
                rule = "Give must be paired with INV-Give",
                description = "Give interaction must have corresponding INV-Give for receiver, with starts_with temporal relation"
            },
            {
                rule = "Interactions must be synchronized",
                description = "All multi-actor interactions must have same starts_with temporal relation to ensure proper synchronization"
            },
            {
                rule = "Talk, Hug, Kiss, Handshake must be duplicated by the other actor involved (ONLY supports 2 actors)",
                description = "All these actions require a corresponding response from the other actor"
            },
            {
                rule = "ONLY allowed actions while sitting or sleeping",
                description = "When the actor sat down or got on bed, ONLY allowed actions are those defined in sitting or bed usage action chains respectively, plus observation_actions and TakeOut/Stash."
            },
            {
                rule = "No overlapping animations can occur",
                description = "The environment does not support 2 overlapping animations: e.g. talking on the phone while sitting. If an animation is designed to keep the actor in the same state (e.g. eating while seated) it will be part of that action chain."
            },
            {
                rule = "The phone can ONLY be used to talk at it.",
                description = "The phone can ONLY be used to talk at it - this is a 90s style mobile phone, not a smart phone."
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
    if actionName:match("Sit") or actionName:match("Stand") or actionName:match("GetOn") or actionName:match("GetOff") then
        return "positional"
    elseif actionName:match("Move") then
        return "movement"
    elseif actionName:match("Pick") or actionName:match("Put") or actionName:match("TakeOut") or actionName:match("Stash") then
        return "object_management"
    elseif actionName:match("Eat") or actionName:match("Drink") then
        return "consumption"
    elseif actionName:match("Give") or actionName:match("Handshake") or actionName:match("Hug") or actionName:match("Kiss") or actionName:match("Talk") then
        return "social"
    elseif actionName:match("Open") or actionName:match("Close") or actionName:match("Type") or actionName:match("TurnOn") or actionName:match("TurnOff") then
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
