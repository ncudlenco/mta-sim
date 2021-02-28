Logger = class(StoryTextLoggerBase, function(o, path, showOnScreen, story)
    StoryTextLoggerBase.init(o, path)
    o.ShowOnScreen = showOnScreen
    o.Story = story
    o.PhraseLinks = {". Then", ". Then", ". Afterwards"}
    o.FirstPhrase = true
    o.PreviousAnd = true
    o.PreviousObjectDescription = false
    o.TempDependency = false
    o.Buffer = {}
    o.PreviousPlayerCommitId = ''
end)

function Logger:GetElapsedTime()
    local seconds = tonumber(os.difftime(os.time(), self.Story.StartTime))
  
    if seconds <= 0 then
      return "00:00:00";
    else
      local hours = string.format("%02.f", math.floor(seconds/3600));
      local mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
      local secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
      return hours..":"..mins..":"..secs
    end
end

function Logger:DescribeRegion(regionName, actors)
    local where = {
        'n',
        'nside'
    }
    local subject = {
        'people',
        'persons',
        'individuals'
    }
    local verb = "are"

    if #actors == 1 then
        verb = "is"
        subject = {"person", "individual"}
    end

    local prefix = getWordPrefix(regionName)
    if not self.FirstPhrase then
        prefix = 'the'
    end
    local sentences = {
        'There ' .. verb .. ' ' .. #actors .. ' '..PickRandom(subject)..' i' .. PickRandom(where) .. ' ' .. prefix .. ' ' .. regionName .. ': ',
        #actors .. ' '..PickRandom(subject)..' ' .. verb .. ' i' .. PickRandom(where) .. ' ' .. prefix..' ' .. regionName .. ': ',
        'I'..PickRandom(where)..' '..prefix..' '..regionName..' there ' .. verb .. ' ' .. #actors..' ' .. PickRandom(subject) .. ': '
    }
    local sentence = sentences[3]
    if self.FirstPhrase then
        sentence = PickRandom(sentences)
    end
    local foundOneNewActor = false
    
    if #actors == 1 then
        local skinDescription = actors[1]:getData('skinDescription')
        sentence = sentence .. skinDescription:sub(1,1):lower() .. skinDescription:sub(2) .. ' named ' .. actors[1]:getData('name')

        return sentence
    else
        for i,a in ipairs(actors) do
            if i == #actors then
                sentence = sentence..' and '
            elseif i > 1 then
                sentence = sentence..', '
            end
            if a:getData('isIntroduced') then
                sentence = sentence..a:getData('name')
            else
                foundOneNewActor = true
                local skinDescription = a:getData('skinDescription')
                sentence = sentence..skinDescription:sub(1,1):lower() .. skinDescription:sub(2) .. ' named ' .. a:getData('name')
            end
            a:setData('isIntroduced', true)
        end

        if foundOneNewActor then
            return sentence
        else
            return nil
        end
    end
end

function Logger:DescribeObjects(player, regionName, objects, locationMap, describeAll)
    local sentenceStart = {
        -- '. As '..player:getData('genderNominative')..' enters the '..regionName,
        'In the '..regionName,
        'Inside the '..regionName
    }
    local sentenceLinks = {
        'there is',
        -- player:getData('genderNominative')..' sees',
        -- player:getData('genderNominative')..' observes',
        -- player:getData('genderNominative')..' notices'
    }
    local rightLinks = {
        'at the right side',
        'in right',
        'in the right side'
    }
    local leftLinks = {
        'at the left side', 
        'in left',
        'in the left side'
    }
    local frontLinks = {
        'straight ahead', 
        'in front'
    }

    local turns = {1}
    if locationMap then 
        turns = {'right','left','front','unknown'} 
        locationMap.right.links = rightLinks
        locationMap.left.links = leftLinks
        locationMap.front.links = frontLinks
    end
    local turn = nil
    local isFirstSentence = true
    local objectsDescription = ''
    
    while #turns > 0 do
        if locationMap then
            local idx = math.random(#turns)
            turn = turns[idx]
            objects = locationMap[turn]
            table.remove(turns, idx)
        end

        local objectsHashTable = {}
        for _,o in ipairs(objects) do
            if o and not o:is_a(SampStoryObjectBase) and trim(o) ~= '' then
                o = SampStoryObjectBase({description = trim(o)})
            end
            if o.type ~= "Cigarette" and o.type ~= "MobilePhone" and o.type then
                local objectDescription = o.Description
                if objectDescription then
                    objectDescription = trim(objectDescription)
                    if objectDescription ~= '' then
                        if not objectsHashTable[objectDescription] then
                            objectsHashTable[objectDescription] = {pluralTemplate = o.pluralTemplate, nr = 1}
                        else
                            objectsHashTable[objectDescription].nr = objectsHashTable[objectDescription].nr + 1
                        end
                    end
                end
            end
        end

        local objs = Select(objectsHashTable, function(v,k) 
            if v.nr == 1 or not v.pluralTemplate then 
                if DEBUG_LOGGER then
                    print("Logger: Correct prefix " .. getWordPrefix(k) .. ' ' .. k)
                end

                return {noun = getWordPrefix(k) .. ' ' .. k, isPlural = false}
            else 
                return {noun = v.pluralTemplate:gsub('{count}', ''..num2word(v.nr)), isPlural = true}
            end
        end)

        local numObjects = #objs
        if numObjects > 0 then
            if #objs > 1 and not describeAll then
                numObjects = math.random(2, #objs)
            end
            local shuffledObjects = Shuffle(objs)

            local destiny = math.random(1,2)
            local nextSentence = ''
            if destiny == 1 or not objects.links then
                nextSentence = PickRandom(sentenceLinks)
                if objects.links then
                    nextSentence = nextSentence .. ' ' ..PickRandom(objects.links)
                end
            else
                nextSentence = PickRandom(objects.links) .. ' ' .. PickRandom(sentenceLinks)
            end

            if shuffledObjects[1].isPlural then
                nextSentence = nextSentence:gsub('is', 'are')
            end

            if isFirstSentence then
                objectsDescription = objectsDescription .. PickRandom(sentenceStart) .. ' ' .. nextSentence
            else
                objectsDescription = objectsDescription .. '. ' .. nextSentence:sub(1,1):upper()..nextSentence:sub(2)
            end

            for i=1, numObjects do
                local objectDescription = shuffledObjects[i].noun
                if i == 1 then
                    objectsDescription = objectsDescription .. " " 
                elseif i == numObjects then
                    objectsDescription = objectsDescription .. " and "
                else
                    objectsDescription = objectsDescription .. ", "
                end
                objectsDescription = objectsDescription .. objectDescription
            end

            isFirstSentence = false
        end
    end

    return objectsDescription
end

function Logger:Log(text, ...)
    local isImpersonal = false
    local commit = false
    local player = nil
    local withoutLink = false
    local tempDependency = false
    local temporalLinks = {}
    local skipNominative = false
    local forceCommit = false
    local action = nil
    for i,v in ipairs(arg) do
        if i == 1 then
            if v.is_a and v:is_a(StoryActionBase) then
                action = v
                player = action.Performer
                forceCommit = action.IsClosing
            else
                player = v
            end
        elseif i == 2 then
            if v == 'skipNominative' then
                skipNominative = true
            elseif v == 'forceCommit' then
                forceCommit = true
            else
                withoutLink = v
            end
        elseif i == 3 then
            tempDependency = v
        elseif i == 4 then
            temporalLinks = v
        end
    end 

    text = trim(text)

    if not self.Buffer[player:getData('id')] then
        self.Buffer[player:getData('id')] = {text = '', TempDependency = false, NextTemporalLinks = {}, firstAction = true}
    end
    self.Buffer[player:getData('id')].TempDependency = tempDependency
    self.Buffer[player:getData('id')].NextTemporalLinks = temporalLinks

    local logText = ''
    if TIME_STAMP then
        logText = self:GetElapsedTime().." "..text.."\n" -- with stamp
    else
        if self.FirstPhrase or withoutLink then -- if its the frist phrase add the skin description
            isImpersonal = true
            self.PreviousObjectDescription = true
            logText = text ..'.'
            if self.Buffer[player:getData('id')].text == '' then
                self.Buffer[player:getData('id')].text = logText
            end
            commit = true
            logText = ''
            self.FirstPhrase = false
            if DEBUG_LOGGER then
                CURRENT_STORY.Actor:outputChat('First phrase or without link', 255, 255, 255, false)
            end
        else
            if self.Buffer[player:getData('id')].TempDependency then
                self.Buffer[player:getData('id')].TempDependency = false
                self.Buffer[player:getData('id')].text = self.Buffer[player:getData('id')].text..'.'
                logText = 'When {nomitative_lwc} '..PickRandom(self.Buffer[player:getData('id')].NextTemporalLinks)..' '..player:getData('genderNominative')..' '..text
                commit = true
                self.PreviousAnd = false
                if DEBUG_LOGGER then
                    CURRENT_STORY.Actor:outputChat('Temporal dependency', 255, 255, 255, false)
                end
            --this only happens for the open door action, when the actor opens the door to enter the room
            elseif string.sub(text, 1, 4) == " and" then
                logText = text
                self.PreviousAnd = true
                if DEBUG_LOGGER then
                    CURRENT_STORY.Actor:outputChat('sentence started with and', 255, 255, 255, false)
                end
            else 
                math.randomseed(os.time())
                dice = math.random()

                --20% to end the sentence
                if dice > 0.8 or self.Buffer[player:getData('id')].firstAction or forceCommit then
                    if self.Buffer[player:getData('id')].text ~= '' then
                        self.Buffer[player:getData('id')].text = self.Buffer[player:getData('id')].text..'.'
                    end
                    if self.Buffer[player:getData('id')].firstAction then
                        logText = player:getData('name') .. ' '..text
                    else
                        logText = '{nominative_upc} '.. text
                    end
                    commit = not self.Buffer[player:getData('id')].firstAction
                    self.Buffer[player:getData('id')].firstAction = false
                    self.PreviousObjectDescription = false
                    if DEBUG_LOGGER then
                        local strc = 'false'
                        if commit then
                            strc = 'true'
                        end
                        CURRENT_STORY.Actor:outputChat('first action or rolled dice to end sentence. commit: '..strc, 255, 255, 255, false)
                    end
                --30% to link the sentence with an and
                elseif dice < 0.3 and self.PreviousAnd == false then -- chance of getting a link between phrases with "and"
                    logText = " and " .. text
                    self.PreviousAnd = true
                    if DEBUG_LOGGER then
                        CURRENT_STORY.Actor:outputChat('rolled dice to link with and', 255, 255, 255, false)
                    end
                --50% here
                else
                    phraseLink = PickRandom(self.PhraseLinks) -- chance of getting a link with "dot"
                    logText = phraseLink .. " " .. player:getData('genderNominative') .. ' '..text
                    self.PreviousAnd = false
                    if DEBUG_LOGGER then
                        CURRENT_STORY.Actor:outputChat('rolled dice to link with '..phraseLink, 255, 255, 255, false)
                    end
                end
            end
        end
    end

    if commit then
        self:FlushBuffer(player)
        self.Buffer[player:getData('id')].text = logText
    else
        self.Buffer[player:getData('id')].text = self.Buffer[player:getData('id')].text .. logText
    end
end

function Logger:FlushBuffer(player, endSentence)
    if not self.isImpersonal then
        local nominative = player:getData('genderNominative')
        if self.PreviousPlayerCommitId ~= player:getData('id') then
            nominative = player:getData('name')
        end
        self.Buffer[player:getData('id')].text = self.Buffer[player:getData('id')].text:gsub("{nominative_upc}", nominative:sub(1,1):upper() .. nominative:sub(2))
        self.Buffer[player:getData('id')].text = self.Buffer[player:getData('id')].text:gsub("{nomitative_lwc}", nominative)
        self.PreviousPlayerCommitId = player:getData('id')
    end
    if endSentence then
        self.Buffer[player:getData('id')].text = self.Buffer[player:getData('id')].text..'.'
    end
    if LOG_DATA then
        local file = File(self.Path)
        if file then                               -- check if it was successfully opened
            file:setPos(file:getSize())            -- move position to the end of the file
            file:write(self.Buffer[player:getData('id')].text..' ')                    -- append data
            file:flush()                           -- Flush the appended data into the file.
            file:close()                           -- close the file once we're done with it
        else
            outputConsole("Unable to open "..self.Path)
        end
    end
    if self.ShowOnScreen then
        if CURRENT_STORY.Actor then
            if CURRENT_STORY.Actor.outputChat then
                CURRENT_STORY.Actor:outputChat(self.Buffer[player:getData('id')].text, 255, 0, 0, false)
            else
                outputChatBox(self.Buffer[player:getData('id')].text, 255, 0, 0, false)
            end
        end
    end
end