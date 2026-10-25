Blueprints={}
local owners,locks={},{}
function InitializeBlueprints(src,cb)
    local owner=CraftIdentity(src)
    if not owner then if cb then cb(false) end; return end
    if owners[src]~=owner then
        local rows=MySQL.Sync.fetchAll('SELECT blueprints FROM player_blueprints WHERE identifier=@identifier',{['@identifier']=owner})
        if CraftIdentity(src)~=owner then return end
        local ok,data=pcall(json.decode,rows[1] and rows[1].blueprints or '{}')
        Blueprints[src]=ok and type(data)=='table' and data or {}
        owners[src]=owner
    end
    TriggerClientEvent('pickle_crafting:updateBlueprints',src,Blueprints[src])
    if cb then cb(Blueprints[src]) end
end
function GetPlayerBlueprint(src,name)
    InitializeBlueprints(src)
    return owners[src]==CraftIdentity(src) and Blueprints[src] and Blueprints[src][name]==true
end
function SetPlayerBlueprint(src,name,enabled)
    InitializeBlueprints(src)
    local owner=CraftIdentity(src)
    if not owner or not Blueprints[src] then return false end
    local data={}
    for k,v in pairs(Blueprints[src]) do data[k]=v end
    data[name]=enabled or nil
    local rows=MySQL.Sync.execute('INSERT INTO player_blueprints (identifier,blueprints) VALUES (@identifier,@blueprints) ON DUPLICATE KEY UPDATE blueprints=@blueprints',{
        ['@identifier']=owner,['@blueprints']=json.encode(data)})
    if type(rows)~='number' then return false end
    if CraftIdentity(src)==owner then Blueprints[src]=data; TriggerClientEvent('pickle_crafting:updateBlueprints',src,data) end
    return true
end
RegisterNetEvent('pickle_crafting:learnBlueprint',function(name)
    local src=source; local owner=CraftIdentity(src); local cfg=Config.Blueprints[name]
    if not owner or not cfg or locks[owner] then return end
    locks[owner]=true
    if GetPlayerBlueprint(src,name) then locks[owner]=nil; return end
    local removed=false
    if cfg.item then
        if Inventory.GetItemCount(src,cfg.item)<1 then locks[owner]=nil; return end
        if cfg.remove then
            if Inventory.RemoveItem(src,cfg.item,1)~=true then locks[owner]=nil; return end
            removed=true
        end
    end
    if not SetPlayerBlueprint(src,name,true) and removed then Inventory.AddItem(src,cfg.item,1) end
    locks[owner]=nil
end)
for name,cfg in pairs(Config.Blueprints) do
    if cfg.item then RegisterUsableItem(cfg.item,function(src) TriggerClientEvent('pickle_crafting:learnBlueprint',src,name) end) end
end
AddEventHandler('playerDropped',function() Blueprints[source]=nil; owners[source]=nil end)
