Logger = class(StoryTextLoggerBase, function(o, path, showOnScreen, story)
    StoryTextLoggerBase.init(o, path)
    o.ShowOnScreen = showOnScreen
    o.Story = story
    o.PhraseLinks = {". Then", ". Then", ". Afterwards"}
    o.FirstPhrase = true
    o.PreviousAnd = true
    o.TempDependency = false
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

function Logger:DescribeObjects(player, regionName, objects, locationMap, describeAll)
    local sentenceStart = {
        'As '..player:getData('genderNominative')..' enters the '..regionName,
        'In the '..regionName,
        'Inside the '..regionName
    }
    local sentenceLinks = {
        'there was',
        player:getData('genderNominative')..' sees',
        player:getData('genderNominative')..' observes',
        player:getData('genderNominative')..' notices'
    }
    local rightLinks = {
        'at '..player:getData('genderGenitive')..' right side', 
        'in '..player:getData('genderGenitive')..' right',
        'in the right side'
    }
    local leftLinks = {
        'at '..player:getData('genderGenitive')..' left side', 
        'in '..player:getData('genderGenitive')..' left',
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

        local numObjects = #objects
        if numObjects > 0 then
            if #objects > 1 and not describeAll then
                numObjects = math.random(2, #objects)
            end
            local shuffledObjects = Shuffle(objects)

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

            if isFirstSentence then
                objectsDescription = objectsDescription .. PickRandom(sentenceStart) .. ' ' .. nextSentence
            else
                objectsDescription = objectsDescription .. '. ' .. nextSentence:sub(1,1):upper()..nextSentence:sub(2)
            end

            for i=1, numObjects do
                local objectDescription = shuffledObjects[i].Description or shuffledObjects[i]
                if i == 1 then
                    objectsDescription = objectsDescription .. " " .. getWordPrefix(objectDescription) .. " " .. objectDescription
                elseif i == numObjects then
                    objectsDescription = objectsDescription .. " and " .. getWordPrefix(objectDescription) .. " " .. objectDescription
                else
                    objectsDescription = objectsDescription .. ", " .. getWordPrefix(objectDescription) .. " " .. objectDescription
                end
            end

            isFirstSentence = false
        end
    end

    return objectsDescription
end

function Logger:Log(text, ...)
    local player = nil
    local withoutLink = false
    for i,v in ipairs(arg) do
        if i == 1 then
            player = v
        elseif i == 2 then
            withoutLink = v
        end
    end

    if TIME_STAMP then
        local logText = self:GetElapsedTime().." "..text.."\n" -- with stamp
    else
        if self.FirstPhrase or withoutLink then -- if its the frist phrase add the skin description
            logText = text
            self.FirstPhrase = false
        else
            text = string.sub(text, string.len(player:getData('skinDescription')) + 1)
            
            if self.TempDependency then
                logText = text
                self.PreviousAnd = false
            elseif string.sub(text, 1, 4) == " and" then
                logText = text
                self.PreviousAnd = true
            else 
                math.randomseed(os.time())
                dice = math.random()

                if dice > 0.4 and self.PreviousAnd == false then -- chance of getting a link between phrases with "and"
                    logText = " and" .. text
                    self.PreviousAnd = true
                else
                    phraseLink = PickRandom(self.PhraseLinks) -- chance of getting a link with "dot"
                    logText = phraseLink .. " " .. player:getData('genderNominative') .. text
                    self.PreviousAnd = false
                end
            end

            if string.match(text, ". When") then
                self.TempDependency = true
            else
                self.TempDependency = false
            end
        end
    end

    if LOG_DATA then
        local file = File(self.Path)
        if file then                               -- check if it was successfully opened
            file:setPos(file:getSize())            -- move position to the end of the file
            file:write(logText)                    -- append data
            file:flush()                           -- Flush the appended data into the file.
            file:close()                           -- close the file once we're done with it
        else
            outputConsole("Unable to open "..self.Path)
        end
    end
    if self.ShowOnScreen then
        if player then
            if player.outputChat then
                player:outputChat(logText, 255, 0, 0, false)
            else
                outputChatBox(logText, 255, 0, 0, false)
            end
        end
    end
end