-- client.lua (Fixed Version)
local RSGCore = nil
local locations = nil
local onDuty = false

-- Utility Functions
local ClientUtils = {
    sendMessage = function(message, msgType)
        local color = msgType == 'error' and {255, 0, 0} or {0, 255, 0}
        local prefix = msgType == 'error' and "ERROR" or "SYSTEM"
        TriggerEvent('chat:addMessage', { color = color, args = {prefix, message} })
    end,
    sendNuiMessage = function(data)
        if data then
            SendNUIMessage(json.encode(data))
        end
    end,
    hasRequiredJob = function(jobName)
        return RSGCore and RSGCore.PlayerData and RSGCore.PlayerData.job and RSGCore.PlayerData.job.name == jobName
    end
}

-- Framework Loading
CreateThread(function()
    local attempts = 0
    while not RSGCore and attempts < Config.CONSTANTS.FRAMEWORK_LOAD_ATTEMPTS do 
        Wait(Config.CONSTANTS.FRAMEWORK_WAIT_TIME)
        RSGCore = exports['rsg-core']:GetCoreObject()
        attempts = attempts + 1
    end
    
    if RSGCore then
        print("^2[NEWSPAPER] Framework loaded successfully^7")
        TriggerServerEvent('newspaper:requestLocations')
    else
        print("^1[NEWSPAPER] Failed to load framework.^7")
    end
end)

-- Event Handlers from Server
RegisterNetEvent('newspaper:receiveLocations', function(locs)
    locations = locs
end)

RegisterNetEvent('newspaper:dutyStatus', function(status)
    onDuty = status
end)

RegisterNetEvent('newspaper:showSubmissionForm', function(itemType)
    ClientUtils.sendNuiMessage({ type = 'showSubmissionUI', submissionType = itemType })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('newspaper:showAdPlacementForm', function()
    ClientUtils.sendNuiMessage({ type = 'showAdPlacementUI' })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('newspaper:showPublicUI', function(issueData)
    ClientUtils.sendNuiMessage({type = 'showPublicUI', issueData = issueData})
    SetNuiFocus(true, true)
end)

-- New events for owner dashboard communication
RegisterNetEvent('newspaper:receivePendingSubmissions', function(submissions)
    ClientUtils.sendNuiMessage({type = 'updateSubmissions', submissions = submissions})
end)

RegisterNetEvent('newspaper:publishSuccess', function()
    ClientUtils.sendNuiMessage({type = 'publishSuccess'})
end)

RegisterNetEvent('newspaper:priceUpdateSuccess', function()
    ClientUtils.sendNuiMessage({type = 'priceUpdateSuccess'})
end)

-- Main Interaction Thread (Optimized)
CreateThread(function()
    local lastPosition = vector3(0, 0, 0)
    while true do
        Wait(500) -- Check twice per second instead of every second
        
        if locations and RSGCore and RSGCore.PlayerData then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            
            -- Only check if player has moved significantly
            if #(playerCoords - lastPosition) > 0.5 then
                lastPosition = playerCoords
                local inRange = false

                -- Duty Point Interaction
                if locations.duty and #(playerCoords - locations.duty) < Config.CONSTANTS.INTERACTION_DISTANCE then
                    inRange = true
                    if ClientUtils.hasRequiredJob("newspaper_owner") then
                        local helpText = onDuty and "Press [E] for Owner Menu." or "Press [E] to go On-Duty."
                        exports['rsg-core']:showHelpText(helpText)
                        
                        -- Handle interaction in separate thread for responsiveness
                        CreateThread(function()
                            while #(GetEntityCoords(PlayerPedId()) - locations.duty) < Config.CONSTANTS.INTERACTION_DISTANCE do
                                Wait(0)
                                if IsControlJustReleased(0, 38) then -- Key E
                                    if onDuty then
                                        ClientUtils.sendNuiMessage({ type = 'owner_ui' })
                                        SetNuiFocus(true, true)
                                    else
                                        TriggerServerEvent('newspaper:toggleDuty')
                                    end
                                    Wait(1000) -- Prevent spam
                                end
                            end
                        end)
                    else
                        exports['rsg-core']:showHelpText("Press [E] to buy the newspaper.")
                        CreateThread(function()
                            while #(GetEntityCoords(PlayerPedId()) - locations.duty) < Config.CONSTANTS.INTERACTION_DISTANCE do
                                Wait(0)
                                if IsControlJustReleased(0, 38) then -- Key E
                                    TriggerServerEvent('newspaper:purchaseIssue')
                                    Wait(1000) -- Prevent spam
                                end
                            end
                        end)
                    end
                end

                -- Store Point Interaction
                if locations.store and #(playerCoords - locations.store) < Config.CONSTANTS.INTERACTION_DISTANCE then
                    inRange = true
                    exports['rsg-core']:showHelpText("Press [E] to access the submission store.")
                    CreateThread(function()
                        while #(GetEntityCoords(PlayerPedId()) - locations.store) < Config.CONSTANTS.INTERACTION_DISTANCE do
                            Wait(0)
                            if IsControlJustReleased(0, 38) then -- Key E
                                ClientUtils.sendNuiMessage({type = 'showStoreUI'})
                                SetNuiFocus(true, true)
                                Wait(1000) -- Prevent spam
                            end
                        end
                    end)
                end

                if not inRange then 
                    exports['rsg-core']:hideHelpText() 
                end
            end
        end
    end
end)

-- NUI Callback Handlers
RegisterNUICallback('closeUI', function(_, cb)
    SetNuiFocus(false, false)
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('purchaseItem', function(data, cb)
    TriggerServerEvent('newspaper:purchaseItem', data)
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('submitArticle', function(data, cb)
    TriggerServerEvent('newspaper:submitArticle', data)
    SetNuiFocus(false, false)
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('submitAd', function(data, cb)
    TriggerServerEvent('newspaper:submitAd', data)
    SetNuiFocus(false, false)
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('craftCopies', function(data, cb)
    TriggerServerEvent('newspaper:craftCopies', data)
    SetNuiFocus(false, false)
    if cb then cb({ ok = true }) end
end)

-- New NUI callbacks for owner dashboard
RegisterNUICallback('getPendingSubmissions', function(_, cb)
    TriggerServerEvent('newspaper:getPendingSubmissions')
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('approveSubmission', function(data, cb)
    TriggerServerEvent('newspaper:approveSubmission', data)
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('rejectSubmission', function(data, cb)
    TriggerServerEvent('newspaper:rejectSubmission', data)
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('publishNewspaper', function(data, cb)
    TriggerServerEvent('newspaper:publishNewspaper', data)
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('updatePrices', function(data, cb)
    TriggerServerEvent('newspaper:updatePrices', data)
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('writeMyOwnArticle', function(_, cb)
    TriggerServerEvent('newspaper:writeMyOwnArticle')
    if cb then cb({ ok = true }) end
end)

-- Usable Item
CreateThread(function()
    Wait(5000) -- Wait for scripts to be ready
    if exports['rsg-core'] then
        exports['rsg-core']:CreateUsableItem("newspaper", function()
            TriggerServerEvent('newspaper:requestCurrentIssue')
        end)
    end
end)