Tables = {}
SpawnedTables = {}
SpawnedDisplay = nil
CurrentCamera = nil

local PlacingProp = false
local CurrentBucket = 0

function GetTableFromEntity(entity)
    for k,v in pairs(SpawnedTables) do 
        if SpawnedTables[k] == entity then return k end
    end
end

function DoesTableExist(index)
    if not Tables[index] then return end
    if SpawnedTables[index] and DoesEntityExist(SpawnedTables[index]) then 
        return SpawnedTables[index]
    end
end

function SpawnTable(index)
    local object = SpawnedTables[index]
    if DoesTableExist(index) then return object end
    local data = Tables[index]
    if not data.model then 
        object = CreateProp(`ng_proc_brick_01a`, data.coords.x, data.coords.y, data.coords.z, false, true, false)
        SetEntityAlpha(object, 0, false)
        SetEntityCollision(object, false, true)
    else
        object = CreateProp(data.model, data.coords.x, data.coords.y, data.coords.z, false, true, false)
    end
    SpawnedTables[index] = object
    SetEntityHeading(object, data.heading)
    FreezeEntityPosition(object, true)
    return object
end

function DeleteTable(index)
    if not SpawnedTables[index] then return end
    DeleteEntity(SpawnedTables[index])
    SpawnedTables[index]=nil
    DeleteDisplayItem()
end

function RemoveTable(index)
    Tables[index] = nil
    DeleteTable(index)
end

function CreateCraftCam(entity, offset, rotation, time)
    local rot = GetEntityRotation(entity, 2) + rotation
    local pos = GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
    if CurrentCam then 
        SetCamCoord(CurrentCam, pos.x, pos.y, pos.z)
        SetCamRot(CurrentCam, rot.x, rot.y, rot.z, 2)
        return CurrentCam
    else
        local cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, 45.00, false, 0)
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 500, true, true)
        CreateThread(function()
            while CurrentCam do 
                SetEntityLocallyInvisible(PlayerPedId())
                Wait(0)
            end
        end)
        return cam
    end
end

function DeleteCraftCam(cam)
    cam=cam or CurrentCam
    if not cam then return end
	SetCamActive(cam, false)
	RenderScriptCams(false, true, 1, true, true)
    DestroyCam(cam)
    CurrentCam = nil
end

function DisplayItem(index, model, offset, rotation, camera)
    local table_ent = SpawnedTables[index]
    if not table_ent then return end
    if SpawnedDisplay then DeleteDisplayItem() end
    local coords = GetOffsetFromEntityInWorldCoords(table_ent, offset.x, offset.y, offset.z)
    local object = CreateProp(model, coords.x, coords.y, coords.z, false, true, false)
    SetEntityHeading(object, 0.0)
    FreezeEntityPosition(object, true)
    CurrentCam = CreateCraftCam(table_ent, camera.offset, camera.rotation)
    SpawnedDisplay = object
    CreateThread(function()
        local heading = rotation.z
        while SpawnedDisplay and SpawnedDisplay == object do 
            heading = heading + 1
            if heading >= 360 then 
                heading = 0.0
            end
            SetEntityRotation(object, rotation.x, rotation.y, heading, 2, 1)
            Wait(0)
        end
    end)
end

function DeleteDisplayItem()
    if not SpawnedDisplay then return end
    DeleteEntity(SpawnedDisplay)
    SpawnedDisplay = nil
end

function GetClosestTable(coords)
    local closest = nil
    local pcoords = coords or GetEntityCoords(PlayerPedId())
    for k,v in pairs(Tables) do 
        local data = v
        local dist = #(pcoords-v.coords)
        if (not closest or closest.dist > dist) then 
            closest = {index = k, dist = dist}
        end
    end
    if (closest) then 
        return closest.index, closest.dist
    end
end

function GetDirectionFromRotation(rotation)
    local dm = (math.pi / 180)
    return vector3(-math.sin(dm * rotation.z) * math.abs(math.cos(dm * rotation.x)), math.cos(dm * rotation.z) * math.abs(math.cos(dm * rotation.x)), math.sin(dm * rotation.x))
end

function GetDirectionCoords()
    local range = 1000.0
	local coords = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local dir = GetDirectionFromRotation(rot)
	local ecoords = vector3(coords.x + dir.x * range, coords.y + dir.y * range, coords.z + dir.z * range)
    local retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(StartShapeTestRay(coords.x, coords.y, coords.z, ecoords.x, ecoords.y, ecoords.z, -1, -1, 1))
	return hit, endCoords, entityHit 
end

function PlaceProp(prop, cb)
    if PlacingProp then return cb(nil, true) end 
    if not cb then return end
    PlacingProp = true
    local coords = GetEntityCoords(PlayerPedId())
    local heading = 0.0
    FreezeEntityPosition(prop, true)
    SetEntityCollision(prop, false, false)
    Citizen.CreateThread(function()
        while PlacingProp do
            local hit, hitCoords, entity = GetDirectionCoords()
            if hit and hitCoords then 
                coords = vector3(hitCoords.x, hitCoords.y, hitCoords.z + 0.04)
                heading = GetGameplayCamRot(2).z
                SetEntityCoords(prop, coords.x, coords.y, coords.z)
                SetEntityRotation(prop, 0, 0, heading, 2)
                if IsControlJustPressed(1, 51) then
                    PlacingProp = false
                end
            end
            Wait(0) 
        end
        if not cb then return end
        cb(coords, heading)
    end)
end

RegisterNetEvent("pickle_crafting:placeTable", function(index)
    if PlacingProp then return end 
    local tableType = Config.TableTypes[index]
    local model = tableType.model
    local coords = GetEntityCoords(PlayerPedId())
    local prop = CreateProp(model, coords.x, coords.y, coords.z, false, true, false)
    PlaceProp(prop, function(coords, heading)
        if not coords then return end
        DeleteEntity(prop)
        TriggerServerEvent("pickle_crafting:placeTable", index, coords, heading)
    end)
end)

RegisterNetEvent("pickle_crafting:updateTables", function(index, data)
    if index == nil then 
        Tables = data
    else
        Tables[index] = data
        if not data then 
            RemoveTable(index)
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
      return
    end
    Wait(1000)
    TriggerServerEvent("pickle_crafting:initializePlayer")
end)
  

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    for k,v in pairs(SpawnedTables) do 
        DeleteTable(k)
    end
    DeleteDisplayItem()
end)

CreateThread(function()
    while not Inventory or not Inventory.Ready do 
        Wait(0)
    end 
    
    while true do 
        local wait = 1500
        local pcoords = GetEntityCoords(PlayerPedId())
        local viewing = false
        local index, dist = GetClosestTable()
        local table = Tables[index]
        if Config.EnableTarget and index then
            if (dist < Config.DisplayDistance) then
                if CurrentTable and CurrentTable.index ~= index then 
                    HideCurrentTable()
                    Wait(1000)
                    SetCurrentTable(index)
                elseif (not CurrentTable) then 
                    SetCurrentTable(index)
                end
            elseif CurrentTable then
                HideCurrentTable()
            end
        elseif index and dist < Config.DisplayDistance then 
            wait = 0
            viewing = true
            if CurrentTable and CurrentTable.index ~= index then 
                HideCurrentTable()
                Wait(1000)
                SetCurrentTable(index)
            elseif (not CurrentTable) then 
                SetCurrentTable(index)
            end
            if (dist < Config.DisplayDistance and not CurrentUI) then 
                if table.activeFire then
                    if not ShowInteractText(_L("interact_fire")) and IsControlJustPressed(1, 51) then
                        TriggerServerEvent("pickle_crafting:stopFire", index)
                        Config.ExtinguishFire(index, table.coords)
                    end
                else
                    if table.static and not ShowInteractText(_L("interact")) and IsControlJustPressed(1, 51) then
                        ShowCraftingUI(index)
                    elseif not table.static and not ShowInteractText(_L("interact_2")) then
                        if (IsControlJustPressed(1, 51)) then 
                            ShowCraftingUI(index)
                        elseif (IsControlJustPressed(1, 47)) then
                            TriggerServerEvent("pickle_crafting:removeTable", index)
                        end 
                    end
                end
            end
        end
        if not Config.EnableTarget and not viewing and CurrentTable then 
            HideCurrentTable()
        end
        for k,v in pairs(Tables) do 
            local data = v
            local dist = #(pcoords-v.coords)
            if ((not data.bucket or data.bucket == CurrentBucket) and dist < Config.RenderDistance) then 
                SpawnTable(k)
            else
                DeleteTable(k)
            end
        end
        Wait(wait)
    end
end)

CreateThread(function()
    while true do 
        Wait(1000 * Config.BucketRefreshTime)
        ServerCallback("pickle_crafting:getBucket", function(bucket_id)
            CurrentBucket = bucket_id
        end)
    end
end)