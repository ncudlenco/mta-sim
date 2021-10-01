Supertemplate = class(function(o, params)
    o.position = params.position or nil
    if o.position then
        o.position = Vector3(o.position.x, o.position.y, o.position.z)
    end
    o.name = params.name or ''
    o.templates = params.templates or {}
    o.offsets = params.offsets or {} --must have the same length as the templates (an offset object for each template)
end)

function Supertemplate:Serialize()
    local s = {
        name = self.name,
        position = self.position,
        templates = self.templates,
        offsets = self.offsets
    }
    if self.position.unpack then
        s.position = self.position:unpack()
    end
    return s
end

function Supertemplate.Load(name)
    local file = fileOpen("files/supertemplates/"..name.."/"..name..".json") 
    if file then
        local jsonStr = fileRead(file, fileGetSize(file))
        local raw = fromJSON(jsonStr)
        fileClose(file)

        if not raw then
            outputChatBox("Something went wrong while loading the supertemplate from file")
            return nil
        end
        local supertemplate = Supertemplate(raw)
        if not supertemplate then
            outputChatBox("Something went wrong while deserializing the template")
            return nil
        else
            outputChatBox("Supertemplate "..supertemplate.name..' was successfully loaded')
            return supertemplate
        end
    end
    error("File path expected but got null")
    return nil
end

--Things to do:
--1. Create super template: creates a folder named $supertemplatename
--2. Add template: insert existing template into a supertemplate 
--2.0 Use existing functionality to implement the possibility to create a template. It should actually be like when creating an episode
--2.1 Set properties to templates (i.e. double bed)
--3. Save
--------------------------------------------------------------------
--4. Insert supertemplate to episode: select an insertion point (relative position)
-----iterate through all templates, insert them then offset, rotate. Save offset and rotation for each template
---------------------------------------------------------------------
--5. Load supertemplate at runtime to episode
--6. Choose template random or by properties taken from the graph (optional)

--at player spawn set inventory items: mobile phone, cigarette
--when planning actions if an item is in the inventory: any location works (from graph) or last location or random location
