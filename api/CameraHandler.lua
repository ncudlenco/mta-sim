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

-- Camera switching:
-- Have a global camera request queue with the id of the player requesting the camera. Assign camera in a first-come-first served order for
-- a minimum of 2 sec or until the action finishes
-- If the player is in the current context:
--  * Ask for the camera whenever an action is being played.
-- If the player is in a different context:
--  * Create a snapshot for all the players in the current context (stop the move animations for all players)
--      ** Check for context switching camera request before executing an action but after making the camera request for the action.
--      ** If at this point all actors from the current request wait for the camera change
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

    local regionId = actor:getData('currentRegionId')
    local regionName = actor:getData('currentRegion')
    local focusedActorEpisode = actor:getData('currentEpisode')

    if not regionId or not regionName or not focusedActorEpisode then
        print('[CameraHandler] Trying to fix the actor '..playerId)
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
        regionId = actor:getData('currentRegionId')
        regionName = actor:getData('currentRegion')
        focusedActorEpisode = actor:getData('currentEpisode')
    end

    if DEBUG_CAMERA then
        print("[CameraHandler] target region "..(regionId or 'null')..':'..(regionName or 'null')..' targetEpisode '..(focusedActorEpisode or 'null'))
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
    local contextChanged = CURRENT_STORY.CurrentFocusedEpisode and CURRENT_STORY.CurrentFocusedEpisode.name ~= focusedActorEpisode
    local region = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Regions, function(r) return r.Id == regionId end)

    if contextChanged then
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

        for _, other_actor in ipairs(CURRENT_STORY.CurrentEpisode.peds) do
            if not other_actor:getData('storyEnded') and other_actor:getData('id') ~= actor:getData('id')
                and other_actor:getData('currentEpisode') == CURRENT_STORY.CurrentFocusedEpisode.name then
                print('actor '..other_actor:getData('id')..' is in old focused episode')
                if #CURRENT_STORY.History[other_actor:getData('id')] > 0 then
                    local lastAction = CURRENT_STORY.History[other_actor:getData('id')][#CURRENT_STORY.History[other_actor:getData('id')]]
                    local isMove = 'false'
                    if lastAction:is_a(Move) then
                        isMove = 'true'
                    end
                    local isNotFinished = 'false'
                    if lastAction:is_a(Move) and not lastAction:isFinished(other_actor) then
                        isNotFinished = 'true'
                    end
                    print('actor '..other_actor:getData('id')..' last action '..lastAction.Name..' ('..isMove..') is not finished: '..isNotFinished)

                    if lastAction:is_a(Move) and not lastAction:isFinished(other_actor) then
                        lastAction:pause(other_actor)
                        --Make sure some time will be allocated to this guy afterwards
                        self:requestFocus(other_actor:getData('id'))
                        print('actor '..other_actor:getData('id')..' is now paused and has a focus request prepped')
                    end
                end
            end
        end
    end

    if region then
        ForEach(CURRENT_STORY.CurrentEpisode.peds, function(ped) ped:setData('hasFocus', false) end)
        actor:setData('hasFocus', true)
        self.isFocused = true
        region:AssignFocus()
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

        for _, other_actor in ipairs(CURRENT_STORY.CurrentEpisode.peds) do
            if other_actor:getData('currentEpisode') == CURRENT_STORY.CurrentFocusedEpisode.name then --Newly focused episode
                if other_actor:getData('paused') and #CURRENT_STORY.History[other_actor:getData('id')] > 0 then
                    local lastAction = CURRENT_STORY.History[other_actor:getData('id')][#CURRENT_STORY.History[other_actor:getData('id')]]
                    if lastAction:is_a(Move) then
                        self:requestFocus(other_actor:getData('id')) --reduntant focus requests
                        lastAction:resume(other_actor)
                    end
                end
                other_actor:setData('paused', false)
            end
        end
    else
        print('Warning! [CameraHandler] could not find a region with id '..(regionId or 'null')..':'..(regionName or 'null')..' in episode '..(focusedActorEpisode or 'null')..' for actor '..(actor:getData('id') or 'null'))
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