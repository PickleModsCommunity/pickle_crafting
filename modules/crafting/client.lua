CurrentTable = nil
CurrentUI = nil

CreateThread(function()
    while not Inventory or not Inventory.Ready do 
        Wait(0)
    end
    SendConfig()
end)

function ShowCraftingUI(index)
    if not CurrentTable then 
        if index then
            SetCurrentTable(index)   
        else
            return 
        end
    end
    local session=CurrentTable
    local tableCfg = Config.TableTypes[CurrentTable.data.tableType or "default"]
    if not CanAccessGroup(tableCfg.groups) then 
        ShowNotification(_L("no_permission"))
        return
    end
    CurrentUI = CurrentTable.index
    ServerCallback("pickle_crafting:getInventory", function(inventory)
        SendConfig()
        Wait(100)
        if not CurrentTable or CurrentTable~=session then SetNuiFocus(false,false); DeleteCraftCam(); return end
        local xpData = (Config.XPEnabled and GetXPData() or nil)
        SendNUIMessage({
            type = "show",
            data = {
                table = CurrentTable,
                inventory = inventory,
                xpData = xpData
            }
        })
    end)
    SetNuiFocus(true, true)
    CurrentCam = CreateCraftCam(SpawnedTables[CurrentTable.index], tableCfg.camera.offset, tableCfg.camera.rotation, 500)
end

function HideCraftingUI()
    CurrentUI=nil
    SetNuiFocus(false,false)
    DeleteCraftCam()
    SendNUIMessage({
        type = "hide"
    })
end

function SendConfig()
    local cfg = {
        Debug = Config.Debug,
        Language = Config.Language,
        ItemImageFolder = Config.ItemImageFolder,
        Blueprints = GetBlueprints(),
        XPCategories = Config.XPCategories,
        Items = Inventory.Items
    }
    SendNUIMessage({
        type = "updateConfig",
        data = cfg
    })
end

function DisplayQueue(tableIndex, index, quantity, time)
    SendNUIMessage({
        type = "displayQueue",
        data = {tableIndex = tableIndex, index = index, quantity = quantity, time = time}
    })
end

function RemoveQueue(tableIndex, index)
    SendNUIMessage({
        type = "removeQueue",
        data = {tableIndex = tableIndex, index = index}
    })
end

function HideQueue()
    SendNUIMessage({
        type = "hideQueue"
    })
end

function SetCurrentTable(tableIndex)
    local data = Tables[tableIndex]
    if not data then return end
    CurrentTable = {index = tableIndex, data = data}
    CreateThread(function()
        SendConfig()
        Wait(100)
        if not CurrentTable then return end
        SendNUIMessage({
            type = "initTable",
            data = CurrentTable
        })
        ServerCallback("pickle_crafting:getTime", function(time)
            if not CurrentTable then return end
            RefreshQueue(CurrentTable.index, time)
        end)
    end)
end

function HideCurrentTable()
    CurrentTable = nil
    HideQueue()
end

function RefreshQueue(tableIndex, time)
    local data = Tables[tableIndex]
    if not data then return end
    if not data.crafting then return end
    local queue = SortCraftingQueue(data.crafting)
    if #queue < 1 then return end
    for i=1, #queue do 
        local queueItem = queue[i]
        local queueIndex = queueItem.index
        if queueItem.finishTime ~= nil then 
            DisplayQueue(tableIndex, queueIndex, queueItem.quantity, queueItem.finishTime - time)
        else
            DisplayQueue(tableIndex, queueIndex, queueItem.quantity)
        end
    end
end

function RefreshInventory(inventory) 
    if not CurrentUI then return end
    SendNUIMessage({
        type = "refreshInventory",
        data = inventory
    })
end

function RefreshXP(xpData) 
    if not Config.XPEnabled then return end
    if not CurrentUI then return end
    SendNUIMessage({
        type = "refreshXP",
        data = xpData
    })
end

RegisterNUICallback("hide", function(data, cb)
    cb(true)
    CurrentUI = nil
    SetNuiFocus(false, false)
    DeleteDisplayItem()
    DeleteCraftCam()
end)

RegisterNUICallback("startCrafting", function(data, cb)
    if not CurrentTable then cb(false); return end
    local session=CurrentTable
    local table = Tables[CurrentTable.index]
    if not table then cb(false); return end
    local item = table.items[data.index]
    if not item then return end
    ServerCallback("pickle_crafting:canCraft", function(result) 
        if not result or CurrentTable~=session then return end
        if item.action and Config.Actions[item.action.name] then 
            HideCraftingUI()
            CreateThread(function()
                if (Config.Actions[item.action.name](item.action.params)) then
                    Wait(Config.ServerActionDuration or 1000)
                    if CurrentTable~=session then return end
                    TriggerServerEvent("pickle_crafting:addCraftingQueue", CurrentTable.index, data.index, data.quantity)
                end
            end)
        else 
            TriggerServerEvent("pickle_crafting:addCraftingQueue", CurrentTable.index, data.index, data.quantity)
        end
    end, CurrentTable.index, data.index, data.quantity)
    cb(true)
end)

RegisterNUICallback("cancelQueue", function(data, cb)
    cb(true)
    if not CurrentTable then return end
    TriggerServerEvent("pickle_crafting:removeCraftingQueue", CurrentTable.index, data.index)
end)

RegisterNUICallback("collectQueue", function(data, cb)
    cb(true)
    if not CurrentTable then return end
    TriggerServerEvent("pickle_crafting:collectCraftingQueue", CurrentTable.index, data.index)
end)

RegisterNUICallback("itemSelect", function(data, cb)
    cb(true)
    DeleteDisplayItem()
    if not CurrentTable then return end
    local table = CurrentTable.data
    local item = table.items[data.index]
    local cfg = Config.Props[item.name]
    if not cfg then return end
    local tableType = table.tableType
    local tableCfg = Config.TableTypes[tableType]
    local settings
    if tableCfg.model or not cfg["default_no_prop"] then 
        settings = cfg[cfg[tableType] and tableType or "default"]
    else
        settings = cfg["default_no_prop"]
    end
    DisplayItem(CurrentTable.index, settings.model, settings.offset, settings.rotation, settings.camera or tableCfg.camera)
end)

RegisterNetEvent("pickle_crafting:addCraftingQueue", function(tableIndex, index, data)
    if not CurrentTable or CurrentTable.index ~= tableIndex then return end
    DisplayQueue(CurrentTable.index, index, data.crafting[index].quantity)
end)

RegisterNetEvent("pickle_crafting:removeCraftingQueue", function(tableIndex, index)
    if not CurrentTable or CurrentTable.index ~= tableIndex then return end
    RemoveQueue(tableIndex, index)
end)

RegisterNetEvent("pickle_crafting:startCraftingQueue", function(tableIndex, index, data, time)
    if not CurrentTable or CurrentTable.index ~= tableIndex then return end
    DisplayQueue(CurrentTable.index, index, data.crafting[index].quantity, data.crafting[index].finishTime - time)
end)

RegisterNetEvent("pickle_crafting:startCraftingFire", function(tableIndex, explosion)
    if CurrentTable and CurrentTable.index==tableIndex then SendNUIMessage({type='hideQueue'}) end
    local table = Tables[tableIndex]
    if not table then return end
    
    CreateThread(function()
        Config[explosion and "Explosion" or "Fire"](tableIndex, table.coords)
    end)
end)