Tables = {}

function UpdateTables(index, source)
    local data
    if index then 
        data = Tables[index]
    else
        data = Tables
    end
    CraftView=function(t)
        if not t then return nil end
        local copy={}
        for k,v in pairs(t) do copy[k]=v end
        copy.owner=nil
        copy.crafting={}
        for k,q in pairs(t.crafting or {}) do
            copy.crafting[k]={quantity=q.quantity,queueTime=q.queueTime,finishTime=q.finishTime,index=k}
        end
        return copy
    end
    if index then data=CraftView(data) else
        data={}
        for id,t in pairs(Tables) do data[id]=CraftView(t) end
    end
    TriggerClientEvent('pickle_crafting:updateTables',source or -1,index,data)
    SaveCraftTables()
end

function AddTable(data)
    local newIndex=data.id
    if not newIndex then
    repeat
        newIndex = math.random(1, 2147483646)
    until not Tables[newIndex]
    end
    local cfg = Config.TableTypes[data.tableType]
    if not cfg then return end
    Tables[newIndex] = {
        static = data.static or false,
        owner=data.owner,
        crafting=data.crafting or {},
        activeFire=data.activeFire,
        coords = data.coords,
        heading = data.heading,
        tableType = data.tableType,
        item = cfg.item,
        model = cfg.model,
        categories = cfg.categories,
        items = cfg.items,
        bucket = data.bucket or 0
    }
    UpdateTables(newIndex)
    return newIndex
end

function RemoveTable(index)
    Tables[index] = nil
    UpdateTables(index)
end

function InitializePlayer(source)
    TriggerClientEvent("pickle_crafting:setupInventory", source, {items = Inventory.Items})
    InitializeBlueprints(source)
    SetTimeout(1000, function()
        UpdateTables(nil, source)
    end)
end

function AwaitInventory(cb)
    CreateThread(function()
        while not Inventory.Ready do 
            Wait(10)
        end
        print("[Pickle's Crafting] Initialized Inventory")
        cb()
    end)
end

RegisterNetEvent("pickle_crafting:placeTable", function(index, coords, heading) 
    local source = source
    local tableType = Config.TableTypes[index]
    if not index or not coords or not heading then return end
    if not tableType or not tableType.item then return end
    if Inventory.GetItemCount(source, tableType.item) < 1 then return end
    if (type(coords)~='vector3' and type(coords)~='table') or type(coords.x)~='number' or type(coords.y)~='number' or type(coords.z)~='number'
        or coords.x~=coords.x or coords.y~=coords.y or coords.z~=coords.z or math.abs(coords.x)>20000 or math.abs(coords.y)>20000 or math.abs(coords.z)>20000
        or type(heading)~='number' or heading~=heading or math.abs(heading)>360
        or #(GetEntityCoords(GetPlayerPed(source))-vector3(coords.x,coords.y,coords.z))>5 then return end
    if Inventory.RemoveItem(source,tableType.item,1)~=true then return end
    AddTable({
        coords = vector3(coords.x,coords.y,coords.z),
        heading = heading,
        owner=CraftIdentity(source),
        tableType = index,
        bucket = GetPlayerRoutingBucket(source)
    })
end)

local initRate={}
RegisterNetEvent("pickle_crafting:initializePlayer", function()
    if not CraftIdentity(source) or initRate[source] and GetGameTimer()-initRate[source]<2000 then return end
    initRate[source]=GetGameTimer()
    local source = source
    if not Inventory.Ready then 
        AwaitInventory(function()
            InitializePlayer(source)
        end)
    else
        InitializePlayer(source)
    end
end)

RegisterNetEvent("pickle_crafting:removeTable", function(index)
    local table = Tables[index]
    if not table or table.static or not CraftAccess(source,table) or table.owner~=CraftIdentity(source) then return end
    if (table.crafting) then 
        local crafting = false
        for k,v in pairs(table.crafting) do 
            crafting = true
            break
        end
        if crafting then return end
    end
    if table.item then 
        if Inventory.AddItem(source,table.item,1)~=true then return end
    end
    RemoveTable(index)
end)

RegisterNetEvent("pickle_crafting:stopFire", function(index)
    if not CraftAccess(source,Tables[index]) then return end
    Tables[index].activeFire = false
    UpdateTables(index)
end)

RegisterCallback("pickle_crafting:getBucket", function(source, cb)
    cb(GetPlayerRoutingBucket(source))
end)

for i=1, #Config.Tables do 
    local data = Config.Tables[i]
    data.static = true
    data.id=-i
    local index = AddTable(data)
end

for k,v in pairs(Config.TableTypes) do 
    if v.item then 
        RegisterUsableItem(v.item, function(source)
            TriggerClientEvent("pickle_crafting:placeTable", source, k)
        end)
    end
end

exports("AddTable", AddTable)
exports("RemoveTable", RemoveTable)
CreateThread(function()
    local raw=GetResourceKvpString('savedCraftTables')
    local ok,saved=pcall(json.decode,raw or '{}')
    if ok and type(saved)=='table' then
        for id,data in pairs(saved) do
            id=tonumber(id) or id
            if Config.TableTypes[data.tableType] then
                data.coords=vector3(data.coords.x,data.coords.y,data.coords.z)
                local queue={}
                for index,q in pairs(data.crafting or {}) do
                    q.busy=nil
                    for _,field in ipairs({"granted","refunded"}) do
                        if q[field] then local g={}; for k,v in pairs(q[field]) do g[tonumber(k) or k]=v end; q[field]=g end
                    end
                    queue[tonumber(index) or index]=q
                end
                if Tables[id] then Tables[id].crafting=queue
                elseif not data.static then data.id=id; data.crafting=queue; AddTable(data) end
            end
        end
    end
    UpdateTables()
end)
