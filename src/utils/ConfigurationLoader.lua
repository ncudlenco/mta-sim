--- ConfigurationLoader: Loads and applies configuration overrides from JSON file
--- Reads optional config.json file and overwrites global variables with specified values
--- Follows separation of concerns by encapsulating all file I/O and parsing logic
---
--- @class ConfigurationLoader
--- @field configPath string Path to configuration file
--- @usage
---   local loader = ConfigurationLoader()
---   local config = loader:load()
---   if config then
---       loader:applyToGlobals(config)
---   end
---
--- @author Nicolae Cudlenco

ConfigurationLoader = class(function(o, configPath)
    --- Constructor for ConfigurationLoader
    --- @param configPath string Optional path to config file (defaults to "config.json")
    o.configPath = configPath or "config.json"
end)

--- Load configuration from JSON file
--- Reads and parses the configuration file if it exists
--- Handles file I/O errors and JSON parsing errors gracefully
---
--- @return table|nil Parsed configuration table or nil if file doesn't exist or parsing fails
--- @usage local config = loader:load()
function ConfigurationLoader:load()
    -- Check if file exists
    if not fileExists(self.configPath) then
        if DEBUG then
            print("[ConfigurationLoader] Configuration file not found: " .. self.configPath)
        end
        return nil
    end

    -- Open file
    local file = fileOpen(self.configPath)
    if not file then
        print("[ConfigurationLoader] ERROR: Failed to open configuration file: " .. self.configPath)
        return nil
    end

    -- Read file content
    local fileSize = fileGetSize(file)
    if fileSize == 0 then
        fileClose(file)
        if DEBUG then
            print("[ConfigurationLoader] Configuration file is empty: " .. self.configPath)
        end
        return nil
    end

    local jsonStr = fileRead(file, fileSize)
    fileClose(file)

    if not jsonStr then
        print("[ConfigurationLoader] ERROR: Failed to read configuration file: " .. self.configPath)
        return nil
    end

    -- Parse JSON
    local config = fromJSON(jsonStr)
    if not config then
        print("[ConfigurationLoader] ERROR: Invalid JSON in configuration file: " .. self.configPath)
        return nil
    end

    if DEBUG then
        print("[ConfigurationLoader] Successfully loaded configuration from: " .. self.configPath)
    end

    return config
end

--- Apply configuration values to global variables
--- Iterates through configuration key-value pairs and overwrites matching globals
--- Validates types and logs changes when DEBUG is enabled
---
--- @param config table Configuration table with key-value pairs to apply
--- @usage loader:applyToGlobals(config)
function ConfigurationLoader:applyToGlobals(config)
    if not config or type(config) ~= "table" then
        print("[ConfigurationLoader] ERROR: Invalid configuration object")
        return
    end

    local overrideCount = 0

    for key, value in pairs(config) do
        -- Check if global variable exists
        if _G[key] ~= nil then
            local oldValue = _G[key]
            local oldType = type(oldValue)
            local newType = type(value)

            -- Type validation: warn if types don't match but still allow override
            if oldType ~= newType then
                print(string.format("[ConfigurationLoader] WARNING: Type mismatch for '%s' (was %s, now %s)",
                    key, oldType, newType))
            end

            -- Apply override
            _G[key] = value
            overrideCount = overrideCount + 1

            if DEBUG then
                print(string.format("[ConfigurationLoader] Overridden %s: %s -> %s",
                    key, tostring(oldValue), tostring(value)))
            end
        else
            if DEBUG then
                print(string.format("[ConfigurationLoader] WARNING: Unknown configuration key '%s' (global variable doesn't exist)", key))
            end
        end
    end

    if DEBUG or overrideCount > 0 then
        print(string.format("[ConfigurationLoader] Applied %d configuration override(s)", overrideCount))
    end
end
