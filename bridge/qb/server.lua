if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

function RegisterCallback(name, cb)
    QBCore.Functions.CreateCallback(name, cb)
end

function RegisterUsableItem(...)
    QBCore.Functions.CreateUseableItem(...)
end

function ShowNotification(target, text)
	TriggerClientEvent(GetCurrentResourceName()..":showNotification", target, text)
end

function GetIdentifier(source)
    local xPlayer = QBCore.Functions.GetPlayer(source).PlayerData
    return xPlayer.citizenid 
end

-- Inventory Fallback

CreateThread(function()
    Wait(100)
    
    if InitializeInventory then return InitializeInventory() end -- Already loaded through inventory folder.
    
    Inventory = {}

    Inventory.Items = {}
    
    Inventory.Ready = false

    Inventory.CanCarryItem = function(source, name, count)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local weight = QBCore.Player.GetTotalWeight(xPlayer.PlayerData.items)
        local item = QBCore.Shared.Items[name:lower()]
        return ((weight + (item.weight * count)) <= QBCore.Config.Player.MaxWeight)
    end

    Inventory.GetInventory = function(source)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local items = {}
        if not xPlayer then return items end
        local data = xPlayer.PlayerData.items
        for slot, item in pairs(data) do 
            items[#items + 1] = {
                name = item.name,
                label = item.label,
                count = item.amount,
                weight = item.weight
            }
        end
        return items
    end

    Inventory.UpdateInventory = function(source)
        SetTimeout(1000, function()
            TriggerClientEvent("pickle_crafting:updateInventory", source, Inventory.GetInventory(source))
        end)
    end

    Inventory.AddItem = function(source, name, count, metadata) -- Metadata is not required.
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local ok=xPlayer.Functions.AddItem(name, count, nil, metadata)
        Inventory.UpdateInventory(source)
        return ok==true
    end

    Inventory.RemoveItem = function(source, name, count)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local ok=xPlayer.Functions.RemoveItem(name, count)
        Inventory.UpdateInventory(source)
        return ok==true
    end

    Inventory.AddWeapon = function(source, name, count, metadata) -- Metadata is not required.
        return Inventory.AddItem(source, name, count, metadata)
    end

    Inventory.RemoveWeapon = function(source, name, count)
        Inventory.RemoveItem(source, name, count, metadata)
    end

    Inventory.GetItemCount = function(source, name)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local item = xPlayer.Functions.GetItemByName(name)
        return item and item.amount or 0
    end

    Inventory.HasWeapon = function(source, name, count)
        return (Inventory.GetItemCount(source, name) > 0)
    end

    RegisterCallback("pickle_crafting:getInventory", function(source, cb)
        cb(Inventory.GetInventory(source))
    end)

    for item, data in pairs(QBCore.Shared.Items) do
        Inventory.Items[item] = {label = data.label}
    end
    Inventory.Ready = true
end)