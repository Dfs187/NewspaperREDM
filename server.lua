-- Updated Utility Functions

function validateInput(input)
    -- Improved validation logic
    return type(input) == "string" and input ~= ""
end

function loadConfig()
    -- Load configuration settings
    local config = {}  
    -- Load config settings from a file or environment
    return config
end

-- Other utility functions...