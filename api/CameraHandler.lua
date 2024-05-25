CameraHandler = class(function(o)
    o.FocusRequests = {'actor0'}
    o.isFocused = false
end
)

function CameraHandler:Reset()
    self.FocusRequests = {'actor0'}
    self.isFocused = false
end

function CameraHandler:__tostring()
    local isFocusedStr = 'false'
    if self.isFocused then
        isFocusedStr = 'true'
    end
    local FocusRequestsStr = 'nil'
    if self.FocusRequests then
        FocusRequestsStr = '['..join(', ', self.FocusRequests)..']'
    end
    return '{\n\tFocusRequests: '..FocusRequestsStr..'\n\tisFocused: '..isFocusedStr..'\n\t}'
end

function CameraHandler:requestFocus(playerId)
    if not inList(playerId, self.FocusRequests) then
        table.insert(self.FocusRequests, playerId)
    end
    if DEBUG_CAMERA then
        print("[CameraHandler] requestFocus "..playerId)
        print("[CameraHandler] "..self:__tostring())
    end
    if not self.isFocused then --First time.
        self:autoFocus()
        for _, spectator in ipairs(CURRENT_STORY.Spectators) do
            spectator:setData('fadedCamera', true)
            spectator:fadeCamera(true)
        end
    end
end


--- Gets the current region of a given actor.
--- @param actor table The actor whose current region and episode is to be retrieved.
-- The function first retrieves the regionId, regionName, and episodeName from the actor's data.
-- If any of these data points are not set, the function attempts to fix this by triggering a region hit from the closest point of interest (POI) with respect to the actor.
-- If a closest POI is found, it triggers a region hit for the actor and updates the regionId, regionName, and episodeName.
-- The function then returns the regionId, regionName, and episodeName.
--- @usage local regionId, regionName, episodeName = CameraHandler:getCurrentRegionAndEpisode(actor)
--- @return integer|nil regionid, string|nil regionName, string|nil episodeName The id and name of the region, and the name of the episode the actor is currently in.
function CameraHandler:getCurrentRegionAndEpisode(actor)
    local regionId = actor:getData('currentRegionId')
    local regionName = actor:getData('currentRegion')
    local episodeName = actor:getData('currentEpisode')

    -- if the actor does not yet have a region assigned, try to fix it by triggering a region hit from the closest POI
    if not regionId or not regionName or not episodeName then
        print('[CameraHandler] Trying to fix the actor '..actor:getData('id'))
        local closestPoi = nil
        local minDist = 99999
        for _, poi in ipairs(CURRENT_STORY.CurrentEpisode.POI) do
            if poi.Region then
                local distance = math.abs((poi.position - actor.position).length)
                if distance < minDist then
                    closestPoi = poi
                    minDist = distance
                end
            end
        end
        if closestPoi == nil then
            return regionId, regionName, episodeName
        end
        closestPoi.Region:OnPlayerHit(actor)
        regionId = actor:getData('currentRegionId')
        regionName = actor:getData('currentRegion')
        episodeName = actor:getData('currentEpisode')
    end

    return regionId, regionName, targetEpisode
end

--- Switches the interior of picked objects in a given region for a specific actor.
--- @param actor any The actor who has picked the objects.
--- @param region table The region where the objects are located.
-- The function first retrieves the picked objects from the actor's data.
-- If the region and picked objects exist, it iterates over each picked object.
-- For each object, it finds the corresponding object in the current episode's objects.
-- If the object instance is found, it switches the interior to the interior of the given region's episode.
--- @usage CameraHandler:switchPickedObjectsInterior(actor, region)
function CameraHandler:switchPickedObjectsInterior(actor, region)
    local pickedObjects = actor:getData('pickedObjects')
    if region and pickedObjects then
        for _, o in ipairs(pickedObjects) do
            print("Switching interior for object "..o[1])
            local object = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(obj) return obj.ObjectId == o[1] end)
            if object and object.instance then
                print("Found object instance, switching to interior "..region.Episode.InteriorId..' of episode '..region.Episode.name)
                object.instance.interior = region.Episode.InteriorId
            end
        end
    end
end

--- Triggers the focus time reached event for a given player. If the context has changed, the time is set to 5000 ms, otherwise it is set to 2000 ms.
--- @param playerId string The id of the player for which focus should be freed
--- @param contextChanged boolean Flag that indicates whether the context has changed
--- @usage CameraHandler:focusTimeReached(playerId, contextChanged)
--- @return nil
function CameraHandler:focusTimeReached(playerId, contextChanged, time)
    local time = 2000
    if contextChanged then
        time = 5000
    end
    Timer(function(playerId)
        if DEBUG_CAMERA then
            local playerStr = 'null'
            if playerId then
                playerStr = ''..playerId
            end
            print("[CameraHandler] focus time reached for "..playerStr)
        end
        CURRENT_STORY.CameraHandler:freeFocus(playerId)
    end, time, 1, playerId)
end

--- Camera switching:
--REDACTED-LEAKED-PAT
-- Have a global camera request queue with the id of the player requesting the camera. Assign camera in a first-come-first served order for
-- a minimum of 2 sec or until the action finishes
-- If the player is in the current context:
--  * Ask for the camera whenever an action is being played.
-- If the player is in a different context:
--  * Create a snapshot for all the players in the current context (pause the move actions for all players)
--      * Check for context switching camera request before executing an action but after making the camera request for the action.
--      * If at this point all actors from the current request wait for the camera change
--          - move spectator to target context
--          - restore the context snapshot for all actors (if any)
--          - resume the simulation
function CameraHandler:autoFocus()
    if DEBUG_CAMERA then
        print("[CameraHandler] autoFocus ")
        print("[CameraHandler] "..self:__tostring())
    end
    if #self.FocusRequests == 0 then
        return
    end
    local playerId = self.FocusRequests[1]
    table.remove(self.FocusRequests, 1)
    -- if DEBUG_CAMERA then
        print("[CameraHandler] assigning focus to actor "..playerId)
        print("[CameraHandler] "..self:__tostring())
    -- end

    local actor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(ped) return ped:getData('id') == playerId end)
    if not actor then
        print("[CameraHandler:assignFocus] Warning: the actor "..playerId.." doesn't exist")
        return
    end
    ForEach(CURRENT_STORY.CurrentEpisode.peds, function(ped) ped:setData('hasFocus', false) end)

    local regionId, regionName, episodeName = self:getCurrentRegionAndEpisode(actor)

    if DEBUG_CAMERA then
        print("[CameraHandler] target region "..(regionId or 'null')..':'..(regionName or 'null')..' targetEpisode '..(episodeName or 'null'))
    end

    --context1
    --switch
    --context2
    --doesn't go back anymore...
    --if the actor's episode is not in focus and the story is already focused on another episode
    --stop actors in currently focused episode
    ----all I care about is that they should not perform move actions
    ----allow static actions to continue
    ----stop move actions for all players in focused episode (iterate throuhg all, look at last action in history, if Move then call pause, set
    ----internally a paused flag to player)
    ----in on global action finished, if next action is Move then pause action for that player - first pause, then play (so it will be added in history)
    ----in Move if a player is paused -> do not play move animation (see how pause and resume can be implemented for Move)
    ----with these the current camera change may continue
    --continue animations in newly switched episode
    ----for all paused actors in new episode, resume move actions
    local contextChanged = CURRENT_STORY.CurrentFocusedEpisode and CURRENT_STORY.CurrentFocusedEpisode.name ~= episodeName
    local region = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Regions, function(r) return r.Id == regionId end)

    -- Before making the switch to the other context
    if contextChanged then
        -- Pause all actions of the actors in the old focused episode (only move actions that are not finished for now)
        -- This needs to be enhanced: most of the time, other complex actions are not finished yet and it takes a while to finish them.
        -- A strategy needs to be defined regarding when precisely to switch focus to the new episode, because this may result in actions being interrupted due to game optimizations of the streamed entities.
        -- One potential solution might be:
        -- 1. Set a flag in the old episode that indicates that the episode is paused.
        -- 2. Do not perform a context switch until all actions in the old episode are finished (each action must define its own definition of finished)
        -- 2.1 E.g. For the action Sleep, the action is finished when the player gets off the bed (but if I wish to say while actor X is sleeping, things are happening outside, this strategy doesn't work)
        -- Option 2.
        -- 1. Set a flag in the old episode that indicates that the episode is paused.
        -- 2. Wait for all actions in the old episode to finish but do not allow new actions to be started.
        -- 3. When resuming, there should be a custom behavior for Actions involving actors sitting on them (e.g. Sleep, Sit, TypeOnKeyboard etc.)
        -- 3.1 The actor should re-execute the previous opening action (e.g. Sleep -> GetOn) - but the screen should be faded out still
        -- 3.2 The last paused action should be re-executed as fast as possible (while the screen is still faded).
        -- 3.3 The screen should be faded in after the last action is finished and the episode is resumed.
        -- 4. The chain of actions should resume normally, choosing the next actions for all actors in that episode.
        CURRENT_STORY.CurrentFocusedEpisode:Pause(actor)
    end

    self:assignFocusToRegion(actor, region, contextChanged)
end

--- Assigns focus to a given actor in a given region. If the region is not found, the function attempts to fix this by triggering a region hit from the closest point of interest (POI) with respect to the actor.
---@param actor table The actor to assign focus to.
---@param region table|nil The region to assign focus to.
---@param contextChanged boolean Flag that indicates whether the context has changed.
---@usage CameraHandler:assignFocusToRegion(actor, region)
function CameraHandler:assignFocusToRegion(actor, region, contextChanged)
    if region then
        ForEach(CURRENT_STORY.CurrentEpisode.peds, function(ped) ped:setData('hasFocus', false) end)
        actor:setData('hasFocus', true)
        self.isFocused = true
        region:AssignFocus(actor)
        self:focusTimeReached(actor:getData('id'), contextChanged)

        -- Resume the actions of the actors in the new focused episode
        CURRENT_STORY.CurrentFocusedEpisode:Resume()
    else
        print('Warning! [CameraHandler] could not find a region with id '..(regionId or 'null')..':'..(regionName or 'null')..' in episode '..(episodeName or 'null')..' for actor '..(actor:getData('id') or 'null'))
        print('Trying to fix the actor '..(actor:getData('id') or 'null'))
        local closestPoi = nil
        local minDist = 99999
        for _, poi in ipairs(CURRENT_STORY.CurrentEpisode.POI) do
            if poi.Region then
                local distance = math.abs((poi.position - actor.position).length)
                if distance < minDist then
                    closestPoi = poi
                    minDist = distance
                end
            end
        end
        closestPoi.Region:OnPlayerHit(actor)
    end
end

---Forces the current camera to update the perspective of the player with the given ID.
---@param playerId string The ID of the player to update the perspective for.
---@usage CameraHandler:updatePerspective(playerId)
function CameraHandler:updatePerspective(playerId)
    print('Update perspective '..playerId)

    local actor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(ped) return ped:getData('id') == playerId end)
    if not actor then
        print("[CameraHandler:assignFocus] Warning: the actor "..playerId.." doesn't exist")
        return
    end

    if actor:getData('hasFocus') and not inList(playerId, self.FocusRequests) then
        table.insert(self.FocusRequests, 1, playerId)
        self:autoFocus()
    end
end

--- Frees the focus from the player with the given ID.
--- @param playerId string The ID of the player to free the focus from.
-- If there are no more focus requests, it finds all paused peds in the current episode and assigns focus to a random paused ped.
-- If there are no focus requests after this, it unfocuses the camera alltogether.
-- Otherwise, it calls autoFocus to automatically assign focus to the next player in the queue.
--- @usage CameraHandler:freeFocus(playerId)
function CameraHandler:freeFocus(playerId)
    if DEBUG_CAMERA then
        print("[CameraHandler] freeFocus "..playerId)
        print("[CameraHandler] "..self:__tostring())
    end
    local idx = LastIndexOf(self.FocusRequests, playerId)
    if idx > 0 and #self.FocusRequests > 1 then
        table.remove(self.FocusRequests, idx)
    end

    if #self.FocusRequests == 0 then
        local pausedPeds = Where(CURRENT_STORY.CurrentEpisode.peds, function(ped) return ped:getData('paused') end)
        if #pausedPeds > 0 then
            local pausedPlayer = PickRandom(pausedPeds):getData('id')
            print('Assigning focus to paused player '..pausedPlayer)
            self:requestFocus(pausedPlayer) --If the current player's time expired and there are other players waiting
        else
            --problem
        end
    end
    if #self.FocusRequests == 0 then
        self.isFocused = false
    else
        self:autoFocus()
    end
end