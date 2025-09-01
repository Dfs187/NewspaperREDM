-- server.lua (Fixed Version)
local FRAMEWORK_NAME = 'rsg-core'

-- Data and state tables
local pendingSubmissions, approvedSubmissions, locations = {}, {}, {}
local onDutyOwners = {}
local currentIssueData = { header = {}, articles = {} }
local itemPrices = Config.ITEM_PRICES
local rateLimitTracker = {}

-- Utility Functions
local Utils = {
    sanitizeInput = function(input)
        if not input or type(input) ~= 'string' then return '' end
        
        input = string.gsub(input, '<[^>]*>', '')
        input = string.gsub(input, 'javascript:', '')
        input = string.gsub(input, 'data:', '')
        
        local lowerInput = string.lower(input)
        for _, word in ipairs(Config.SECURITY.BLOCKED_WORDS) do
            if string.find(lowerInput, string.lower(word)) then
                return ''
            end
        end
        
        return input
    end,

    validateImageUrl = function(url)
        if not url or url == '' then return true end
        if not string.match(url, '^https?://') then return false end
        
        local domain = string.match(url, 'https?://([^/]+)')
        if domain then
            for _, allowedDomain in ipairs(Config.SECURITY.ALLOWED_IMAGE_DOMAINS) do
                if string.find(domain, allowedDomain, 1, true) then
                    return true
                end
            end
        end
        return false
    end,

    checkRateLimit = function(playerId)
        local currentTime = os.time()
        local playerData = rateLimitTracker[playerId]
        
        if not playerData then
            rateLimitTracker[playerId] = { timestamps = {} }
            playerData = rateLimitTracker[playerId]
        end
        
        local validTimestamps = {}
        for _, timestamp in ipairs(playerData.timestamps) do
            if currentTime - timestamp < (Config.SECURITY.RATE_LIMIT_WINDOW / 1000) then
                table.insert(validTimestamps, timestamp)
            end
        end
        playerData.timestamps = validTimestamps
        
        if #playerData.timestamps >= Config.SECURITY.MAX_SUBMISSIONS_PER_WINDOW then
            return false
        end
        
        table.insert(playerData.timestamps, currentTime)
        return true
    end,

    getPlayerInfo = function(src)
        local Player = exports[FRAMEWORK_NAME]:GetPlayer(src)
        if not Player or not Player.PlayerData or not Player.PlayerData.charinfo then return nil end
        
        local fullName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
        local citizenId = Player.PlayerData.citizenid
        
        return { player = Player, fullName = fullName, citizenId = citizenId }
    end,

    sendError = function(src, message)
        TriggerClientEvent('chat:addMessage', src, { color = {255, 0, 0}, args = {"ERROR", message} })
    end,

    sendSuccess = function(src, message)
        TriggerClientEvent('chat:addMessage', src, { color = {0, 255, 0}, args = {"SUCCESS", message} })
    end,

    isValidSubmissionType = function(submissionType)
        for _, validType in ipairs(Config.VALID_SUBMISSION_TYPES) do
            if submissionType == validType then return true end
        end
        return false
    end,

    isOwner = function(src)
        local playerInfo = Utils.getPlayerInfo(src)
        if not playerInfo then return false end
        return playerInfo.player.PlayerData.job and 
               playerInfo.player.PlayerData.job.name == "newspaper_owner" and 
               onDutyOwners[src]
    end
}

-- Enhanced data loading
local function loadData()
    local function loadJsonFile(filename, defaultValue, description)
        local data = LoadResourceFile(GetCurrentResourceName(), filename)
        if data and data ~= '' then 
            local success, decoded = pcall(json.decode, data)
            if success and decoded then
                print("^2[NEWSPAPER] Successfully loaded " .. description .. "^7")
                return decoded
            end
        end
        return defaultValue
    end

    locations = loadJsonFile('data/locations.json', { duty = vec3(0,0,0), store = vec3(0,0,0), typewriter = vec3(0,0,0), payout = vec3(0,0,0) }, "locations")
    pendingSubmissions = loadJsonFile('data/submissions.json', {}, "pending submissions")
    approvedSubmissions = loadJsonFile('data/approved.json', {}, "approved submissions")
    itemPrices = loadJsonFile('data/prices.json', Config.ITEM_PRICES, "custom prices")
end

-- Enhanced data saving
local function saveData(dataType)
    local dataMap = {
        locations = { data = locations, filename = 'data/locations.json' },
        submissions = { data = pendingSubmissions, filename = 'data/submissions.json' },
        approved = { data = approvedSubmissions, filename = 'data/approved.json' },
        prices = { data = itemPrices, filename = 'data/prices.json' }
    }
    
    local config = dataMap[dataType]
    if not config then return false end
    
    local success, encodedData = pcall(json.encode, config.data)
    if not success then return false end
    
    return SaveResourceFile(GetCurrentResourceName(), config.filename, encodedData, -1)
end

loadData()

-- Server Events
RegisterNetEvent('newspaper:requestLocations', function()
    TriggerClientEvent('newspaper:receiveLocations', source, locations)
end)

RegisterNetEvent('newspaper:toggleDuty', function()
    local src = source
    local playerInfo = Utils.getPlayerInfo(src)
    if not playerInfo then return end
    
    if playerInfo.player.PlayerData.job and playerInfo.player.PlayerData.job.name == "newspaper_owner" then
        onDutyOwners[src] = not onDutyOwners[src]
        Utils.sendSuccess(src, onDutyOwners[src] and "You are now on duty." or "You are now off duty.")
        TriggerClientEvent('newspaper:dutyStatus', src, onDutyOwners[src])
    else
        Utils.sendError(src, "You are not authorized to go on duty.")
    end
end)

RegisterNetEvent('newspaper:purchaseItem', function(data)
    local src = source
    local playerInfo = Utils.getPlayerInfo(src)
    if not playerInfo then return end

    local itemType = data and data.itemType
    if not itemType or not Utils.isValidSubmissionType(itemType) then
        Utils.sendError(src, "Invalid item type.")
        return
    end

    local price = itemPrices[itemType] or Config.ITEM_PRICES[itemType]
    if not price then
        Utils.sendError(src, "Item price not found.")
        return
    end

    if playerInfo.player.Functions.RemoveMoney('cash', price) then
        if itemType == 'ad_placement' then
            TriggerClientEvent('newspaper:showAdPlacementForm', src)
        else
            TriggerClientEvent('newspaper:showSubmissionForm', src, itemType)
        end
    else
        Utils.sendError(src, "You cannot afford this item ($" .. price .. ")")
    end
end)

RegisterNetEvent('newspaper:submitArticle', function(data)
    local src = source
    local playerInfo = Utils.getPlayerInfo(src)
    if not playerInfo then return end

    if not Utils.checkRateLimit(src) then
        Utils.sendError(src, "You are submitting too frequently. Please wait.")
        return
    end

    local sanitizedTitle = Utils.sanitizeInput(data.title)
    local sanitizedContent = Utils.sanitizeInput(data.content)
    
    if sanitizedTitle == '' or sanitizedContent == '' or not Utils.isValidSubmissionType(data.submissionType) then
        Utils.sendError(src, "Submission contains invalid or prohibited content.")
        return
    end
    
    if data.image and not Utils.validateImageUrl(data.image) then
        Utils.sendError(src, "Invalid or unauthorized image URL.")
        return
    end

    table.insert(pendingSubmissions, {
        title = sanitizedTitle,
        content = sanitizedContent,
        author = playerInfo.fullName,
        authorId = playerInfo.citizenId,
        type = data.submissionType,
        image = data.image,
        timestamp = os.time(),
        submitterId = src
    })
    
    if saveData('submissions') then
        Utils.sendSuccess(src, "Submission sent for review.")
    else
        Utils.sendError(src, "Failed to save submission.")
    end
end)

RegisterNetEvent('newspaper:purchaseIssue', function()
    local src = source
    local playerInfo = Utils.getPlayerInfo(src)
    if not playerInfo then return end

    if playerInfo.player.Functions.RemoveMoney('cash', Config.NEWSPAPER_PRICE) then
        if not playerInfo.player.Functions.AddItem('newspaper', 1) then
            playerInfo.player.Functions.AddMoney('cash', Config.NEWSPAPER_PRICE)
            Utils.sendError(src, "Failed to add newspaper to inventory.")
        else
            Utils.sendSuccess(src, "You purchased a newspaper.")
        end
    else
        Utils.sendError(src, "You cannot afford this ($" .. Config.NEWSPAPER_PRICE .. ")")
    end
end)

RegisterNetEvent('newspaper:requestCurrentIssue', function()
    TriggerClientEvent('newspaper:showPublicUI', source, currentIssueData)
end)

-- Fixed Server Events (were incorrectly using NUICallback)
RegisterNetEvent('newspaper:getPendingSubmissions', function()
    local src = source
    if not Utils.isOwner(src) then
        Utils.sendError(src, "Unauthorized access.")
        return
    end
    TriggerClientEvent('newspaper:receivePendingSubmissions', src, pendingSubmissions or {})
end)

RegisterNetEvent('newspaper:approveSubmission', function(data)
    local src = source
    if not Utils.isOwner(src) then
        Utils.sendError(src, "Unauthorized access.")
        return
    end
    
    local index = tonumber(data and data.index)
    if index and pendingSubmissions[index] then
        local submission = table.remove(pendingSubmissions, index)
        table.insert(approvedSubmissions, submission)
        saveData('submissions')
        saveData('approved')
        if submission.submitterId then
            Utils.sendSuccess(submission.submitterId, "Your submission '" .. submission.title .. "' was approved!")
        end
    end
    TriggerClientEvent('newspaper:receivePendingSubmissions', src, pendingSubmissions)
end)

RegisterNetEvent('newspaper:rejectSubmission', function(data)
    local src = source
    if not Utils.isOwner(src) then
        Utils.sendError(src, "Unauthorized access.")
        return
    end
    
    local index = tonumber(data and data.index)
    if index and pendingSubmissions[index] then
        local submission = table.remove(pendingSubmissions, index)
        saveData('submissions')
        if submission.submitterId then
            Utils.sendError(submission.submitterId, "Your submission '" .. submission.title .. "' was rejected.")
        end
    end
    TriggerClientEvent('newspaper:receivePendingSubmissions', src, pendingSubmissions)
end)

RegisterNetEvent('newspaper:publishNewspaper', function(data)
    local src = source
    if not Utils.isOwner(src) then
        Utils.sendError(src, "Unauthorized access.")
        return
    end
    
    currentIssueData.header = {
        date = Utils.sanitizeInput(data.headerDetails.date),
        volume = Utils.sanitizeInput(data.headerDetails.volume),
        number = Utils.sanitizeInput(data.headerDetails.number),
        title = Utils.sanitizeInput(data.headerDetails.title or 'The New Dawn Gazette')
    }
    currentIssueData.articles = approvedSubmissions
    approvedSubmissions = {}
    saveData('approved')
    TriggerClientEvent('chat:addMessage', -1, { color = {255, 215, 0}, args = {"GAZETTE", "A new issue has been published!"} })
    TriggerClientEvent('newspaper:publishSuccess', src)
end)

RegisterNetEvent('newspaper:updatePrices', function(data)
    local src = source
    if not Utils.isOwner(src) then
        Utils.sendError(src, "Unauthorized access.")
        return
    end
    
    if not data or not data.prices then
        Utils.sendError(src, "Invalid price data.")
        return
    end
    
    for key, value in pairs(data.prices) do
        local numValue = tonumber(value)
        if numValue and numValue >= 0 then
            if itemPrices[key] then 
                itemPrices[key] = numValue
            elseif key == 'newspaper' then 
                Config.NEWSPAPER_PRICE = numValue 
            end
        end
    end
    
    if saveData('prices') then
        Utils.sendSuccess(src, "Prices updated.")
        TriggerClientEvent('newspaper:priceUpdateSuccess', src)
    else
        Utils.sendError(src, "Failed to save prices.")
    end
end)

RegisterNetEvent('newspaper:submitAd', function(data)
    local src = source
    local playerInfo = Utils.getPlayerInfo(src)
    if not playerInfo then return end

    if not Utils.checkRateLimit(src) then
        Utils.sendError(src, "You are submitting too frequently.")
        return
    end
    
    if not data or not data.adContent or not Utils.validateImageUrl(data.adContent.imageUrl) then
        Utils.sendError(src, "Invalid or unauthorized image URL.")
        return
    end

    table.insert(pendingSubmissions, {
        title = "Advertisement",
        content = Utils.sanitizeInput(data.adContent.imageUrl),
        author = playerInfo.fullName,
        authorId = playerInfo.citizenId,
        type = data.adType,
        image = Utils.sanitizeInput(data.adContent.imageUrl),
        timestamp = os.time(),
        submitterId = src
    })
    
    if saveData('submissions') then
        Utils.sendSuccess(src, "Advertisement sent for review.")
    else
        Utils.sendError(src, "Failed to save advertisement.")
    end
end)

RegisterNetEvent('newspaper:craftCopies', function(data)
    local src = source
    local playerInfo = Utils.getPlayerInfo(src)
    if not playerInfo then return end
    
    -- Validate owner and on duty
    if not Utils.isOwner(src) then
        Utils.sendError(src, "Only newspaper owners can print copies.")
        return
    end

    local quantity = tonumber(data.quantity)
    if not quantity or quantity < Config.CONSTANTS.MIN_CRAFT_QUANTITY or quantity > Config.CONSTANTS.MAX_CRAFT_QUANTITY then
        Utils.sendError(src, "Invalid quantity. Must be between 1 and 100.")
        return
    end

    if playerInfo.player.Functions.AddItem('newspaper', quantity) then
        Utils.sendSuccess(src, "You printed " .. quantity .. " copies.")
    else
        Utils.sendError(src, "Failed to add newspapers to inventory.")
    end
end)

RegisterNetEvent('newspaper:writeMyOwnArticle', function()
    local src = source
    if not Utils.isOwner(src) then
        Utils.sendError(src, "Unauthorized access.")
        return
    end
    TriggerClientEvent('newspaper:showSubmissionForm', src, 'latest_news')
end)

-- Admin Commands
RegisterCommand("setlocation", function(source, args)
    if not IsPlayerAceAllowed(source, 'rsgcore.admin') then
        Utils.sendError(source, "You do not have permission.")
        return
    end
    local locType = args[1] and string.lower(args[1])
    local isValid = false
    for _, validType in ipairs(Config.VALID_LOCATION_TYPES) do
        if locType == validType then isValid = true break end
    end
    if not isValid then
        Utils.sendError(source, "Invalid location type. Use: " .. table.concat(Config.VALID_LOCATION_TYPES, ', '))
        return
    end
    locations[locType] = GetEntityCoords(GetPlayerPed(source))
    if saveData('locations') then
        Utils.sendSuccess(source, "Location '" .. locType .. "' set.")
    else
        Utils.sendError(source, "Failed to save location.")
    end
end, false)

RegisterCommand("setnewspaperowner", function(source, args)
    if not IsPlayerAceAllowed(source, 'rsgcore.admin') then
        Utils.sendError(source, "You do not have permission.")
        return
    end
    local targetId = tonumber(args[1])
    if not targetId then
        Utils.sendError(source, "Invalid player ID.")
        return
    end
    local Player = exports[FRAMEWORK_NAME]:GetPlayer(targetId)
    if not Player then
        Utils.sendError(source, "Player not found.")
        return
    end
    if Player.Functions.SetJob("newspaper_owner", 0) then
        Utils.sendSuccess(source, "Player " .. Player.PlayerData.charinfo.firstname .. " is now a newspaper owner.")
        Utils.sendSuccess(targetId, "You have been assigned as a newspaper owner.")
    else
        Utils.sendError(source, "Failed to assign job.")
    end
end, false)

-- Player Disconnect Handler
AddEventHandler('playerDropped', function()
    local src = source
    if onDutyOwners[src] then onDutyOwners[src] = nil end
    if rateLimitTracker[src] then rateLimitTracker[src] = nil end
end)