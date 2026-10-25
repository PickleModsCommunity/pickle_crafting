local prior=GetResourceKvpString('craftTables')
if prior then SetResourceKvp('savedCraftTables',prior) end
CraftLocks, CraftPermits = {}, {}
function CraftIdentity(src)
    if not GetPlayerName(src) then return end
    local ok,id=pcall(GetIdentifier,src)
    return ok and id or nil
end
function CraftInteger(n,a,b) return type(n)=='number' and n%1==0 and n>=a and n<=b end
function CraftAccess(src,t)
    local ped=GetPlayerPed(src)
    if not t or ped==0 or GetEntityHealth(ped)<=0 or GetPlayerRoutingBucket(src)~=(t.bucket or 0)
        or #(GetEntityCoords(ped)-t.coords)>5 then return false end
    local cfg=Config.TableTypes[t.tableType]
    if cfg.groups then
        local p=ESX and ESX.GetPlayerFromId(src) or QBCore and QBCore.Functions.GetPlayer(src)
        local job=p and (ESX and p.job or p.PlayerData.job)
        if not job then return false end
        local rank=type(job.grade)=='table' and job.grade.level or job.grade
        if not cfg.groups[job.name] or rank<cfg.groups[job.name] then return false end
    end
    return CraftIdentity(src)~=nil
end
function CraftCanOwn(src,t,q)
    if not CraftAccess(src,t) then return false end
    if q.owner==CraftIdentity(src) then return true end
    if Config.TheftDistance<=0 then return false end
    local owner
    for _,id in ipairs(GetPlayers()) do
        local src=tonumber(id)
        if CraftIdentity(src)==q.owner then owner=src; break end
    end
    if not owner then return true end
    return GetPlayerRoutingBucket(owner)~=(t.bucket or 0) or #(GetEntityCoords(GetPlayerPed(owner))-t.coords)>Config.TheftDistance
end
function SaveCraftTables()
    local saved={}
    for id,t in pairs(Tables) do
        if t.static or Config.PersistentTables or next(t.crafting or {}) then
        saved[tostring(id)]={tableType=t.tableType,coords=t.coords,heading=t.heading,bucket=t.bucket,owner=t.owner,
            static=t.static,crafting=t.crafting,activeFire=t.activeFire,fireGeneration=t.fireGeneration}
        end
    end
    SetResourceKvp('craftTables',json.encode(saved))
end
