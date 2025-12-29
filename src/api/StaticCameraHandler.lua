--- Static camera handler with automatic focus switching
--- Maintains current behavior: 2-second focus per actor, queue-based switching
--- Uses region's predefined static cameras
--- @class StaticCameraHandler
StaticCameraHandler = class(CameraHandlerBase, function(o)
    CameraHandlerBase.init(o)
    o.FocusRequests = {}
end)

--- Reset camera handler state
function StaticCameraHandler:Reset()
    CameraHandlerBase.Reset(self)
    self.FocusRequests = {}
end

--- String representation for debugging
function StaticCameraHandler:__tostring()
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

--- Request camera focus for an actor
--- Adds actor to focus queue and triggers autofocus if this is the first request
--- @param playerId string The id of the player requesting focus
function StaticCameraHandler:requestFocus(playerId)
    local actor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(ped) return ped:getData('id') == playerId end)
    if actor and actor:getData('storyEnded') then
        if DEBUG_CAMERA then
            print("[StaticCameraHandler] requestFocus ignored for ended story actor "..playerId)
        end
        return
    end
    if not inList(playerId, self.FocusRequests) then
        table.insert(self.FocusRequests, playerId)
    end
    if DEBUG_CAMERA then
        print("[StaticCameraHandler] requestFocus "..playerId)
        print("[StaticCameraHandler] "..self:__tostring())
    end
    if not self.isFocused then --First time.
        self:autoFocus()
        for _, spectator in ipairs(CURRENT_STORY.Spectators) do
            spectator:setData('fadedCamera', true)
            spectator:fadeCamera(true, 0)
        end
    end
end

--- Triggers the focus time reached event for a given player.
--- If the context has changed, the time is set to 5000 ms, otherwise it is set to 2000 ms.
--- @param playerId string The id of the player for which focus should be freed
--- @param contextChanged boolean Flag that indicates whether the context has changed
--- @usage StaticCameraHandler:focusTimeReached(playerId, contextChanged)
--- @return nil
function StaticCameraHandler:focusTimeReached(playerId, contextChanged, time)
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
            print("[StaticCameraHandler] focus time reached for "..playerStr)
        end
        CURRENT_STORY.CameraHandler:freeFocus(playerId)
    end, time, 1, playerId)
end

--- Camera switching:
--- Have a global camera request queue with the id of the player requesting the camera. Assign camera in a first-come-first served order for
--- a minimum of 2 sec or until the action finishes
--- If the player is in the current context:
---  * Ask for the camera whenever an action is being played.
--- If the player is in a different context:
---  * Create a snapshot for all the players in the current context (pause the move actions for all players)
---      * Check for context switching camera request before executing an action but after making the camera request for the action.
---      * If at this point all actors from the current request wait for the camera change
---          - move spectator to target context
---          - restore the context snapshot for all actors (if any)
---          - resume the simulation
function StaticCameraHandler:autoFocus()
    if self.isSwitchingContext then
        return
    end
    if DEBUG_CAMERA then
        print("[StaticCameraHandler] autoFocus ")
        print("[StaticCameraHandler] "..self:__tostring())
    end
    if #self.FocusRequests == 0 then
        return
    end
    local playerId = self.FocusRequests[1]
    table.remove(self.FocusRequests, 1)
    -- if DEBUG_CAMERA then
        print("[StaticCameraHandler] assigning focus to actor "..playerId)
        print("[StaticCameraHandler] "..self:__tostring())
    -- end

    local actor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(ped) return ped:getData('id') == playerId end)
    if not actor then
        print("[StaticCameraHandler:assignFocus] Warning: the actor "..playerId.." doesn't exist")
        return
    end
    ForEach(CURRENT_STORY.CurrentEpisode.peds, function(ped) ped:setData('hasFocus', false) end)

    local regionId, regionName, episodeName = self:getCurrentRegionAndEpisode(actor)

    if DEBUG_CAMERA then
        print("[StaticCameraHandler] target region "..(regionId or 'null')..':'..(regionName or 'null')..' targetEpisode '..(episodeName or 'null'))
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
        if DEBUG then
            print("The episode name for the actor that is about to receive focus "..playerId.." is "..episodeName..". The episode in focus is "..CURRENT_STORY.CurrentFocusedEpisode.name)
        end
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
        CURRENT_STORY.CurrentFocusedEpisode:RequestPause()
        self.isSwitchingContext = true
        self:WaitUntilEpisodePausedThenAssignFocusToRegion(playerId, regionId, contextChanged)
    else
        self:assignFocusToRegion(actor, region, contextChanged)
    end
end

--- Assigns focus to a given actor in a given region. If the region is not found, the function attempts to fix this by triggering a region hit from the closest point of interest (POI) with respect to the actor.
---@param actor table The actor to assign focus to.
---@param region table|nil The region to assign focus to.
---@param contextChanged boolean Flag that indicates whether the context has changed.
---@usage StaticCameraHandler:assignFocusToRegion(actor, region)
function StaticCameraHandler:assignFocusToRegion(actor, region, contextChanged)
    if region then
        ForEach(CURRENT_STORY.CurrentEpisode.peds, function(ped) ped:setData('hasFocus', false) end)
        actor:setData('hasFocus', true)
        self.isFocused = true
        region:AssignFocus(actor)
        self:focusTimeReached(actor:getData('id'), contextChanged)

        if contextChanged then
            -- Resume the actions of the actors in the new focused episode
            CURRENT_STORY.CurrentFocusedEpisode:Resume()
            self:FadeForAll(true, 1500)
        end
    else
        local regionId, regionName, episodeName = self:getCurrentRegionAndEpisode(actor)
        print('Warning! [StaticCameraHandler] could not find a region with id '..(regionId or 'null')..':'..(regionName or 'null')..' in episode '..(episodeName or 'null')..' for actor '..(actor:getData('id') or 'null'))
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
        if closestPoi then
            closestPoi.Region:OnPlayerHit(actor)
        end
    end
end

---Forces the current camera to update the perspective of the player with the given ID.
---@param playerId string The ID of the player to update the perspective for.
---@usage StaticCameraHandler:updatePerspective(playerId)
function StaticCameraHandler:updatePerspective(playerId)
    print('Update perspective '..playerId)

    local actor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(ped) return ped:getData('id') == playerId end)
    if not actor then
        print("[StaticCameraHandler:assignFocus] Warning: the actor "..playerId.." doesn't exist")
        return
    end

    if actor:getData('hasFocus') and not inList(playerId, self.FocusRequests) then
        table.insert(self.FocusRequests, 1, playerId)
        self:autoFocus()
    end
end

--- Clear all focus requests for a specific player
--- @param playerId string The ID of the player to clear requests for
function StaticCameraHandler:clearFocusRequests(playerId)
    local idx = LastIndexOf(self.FocusRequests, playerId)
    while idx > 0 do
        table.remove(self.FocusRequests, idx)
        idx = LastIndexOf(self.FocusRequests, playerId)
    end
end

--- Frees the focus from the player with the given ID.
--- @param playerId string The ID of the player to free the focus from.
--- If there are no more focus requests, it finds all paused peds in the current episode and assigns focus to a random paused ped.
--- If there are no focus requests after this, it unfocuses the camera alltogether.
--- Otherwise, it calls autoFocus to automatically assign focus to the next player in the queue.
--- @usage StaticCameraHandler:freeFocus(playerId)
function StaticCameraHandler:freeFocus(playerId)
    if DEBUG_CAMERA then
        print("[StaticCameraHandler] freeFocus "..playerId)
        print("[StaticCameraHandler] "..self:__tostring())
    end
    local idx = LastIndexOf(self.FocusRequests, playerId)
    if idx > 0 and #self.FocusRequests > 1 then
        table.remove(self.FocusRequests, idx)
    end

    -- if #self.FocusRequests == 0 then
    --     local pausedPeds = Where(CURRENT_STORY.CurrentEpisode.peds, function(ped) return ped:getData('paused') end)
    --     if #pausedPeds > 0 then
    --         local pausedPlayer = PickRandom(pausedPeds):getData('id')
    --         print('Assigning focus to paused player '..pausedPlayer)
    --         self:requestFocus(pausedPlayer) --If the current player's time expired and there are other players waiting
    --     else
    --         --problem
    --     end
    -- end
    if #self.FocusRequests == 0 then
        self.isFocused = false
    else
        self:autoFocus()
    end
end
