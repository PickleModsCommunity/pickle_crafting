local sequence=0
local function itemAt(t,index)
    return t and CraftInteger(index,1,#t.items) and t.items[index]
end
function RemoveQueue(tableIndex,index)
    local t=Tables[tableIndex]
    if not t or not t.crafting then return end
    t.crafting[index]=nil
    TriggerClientEvent('pickle_crafting:removeCraftingQueue',-1,tableIndex,index)
    SaveCraftTables()
end
function CheckParts(src,quantity,parts)
    local totals={}
    for _,p in ipairs(parts or {}) do
        local key=(p.type or 'item')..':'..p.name
        local entry=totals[key] or {name=p.name,type=p.type,amount=0}
        entry.amount=entry.amount+(p.amount or 1)*quantity; totals[key]=entry
    end
    for _,p in pairs(totals) do
        if p.type=='weapon' then if not Inventory.HasWeapon(src,p.name) then return false end
        elseif Inventory.GetItemCount(src,p.name)<p.amount then return false end
    end
    return true
end
function TakeParts(src,quantity,parts)
    local removed={}
    for _,p in ipairs(parts or {}) do
        if p.remove~=false then
            local take=p.type=='weapon' and Inventory.RemoveWeapon or Inventory.RemoveItem
            local give=p.type=='weapon' and Inventory.AddWeapon or Inventory.AddItem
            if take(src,p.name,(p.amount or 1)*quantity)~=true then
                for _,r in ipairs(removed) do r.give(src,r.name,r.amount) end
                return false
            end
            removed[#removed+1]={give=give,name=p.name,amount=(p.amount or 1)*quantity}
        end
    end
    return true
end
function CheckRewards(src,quantity,data,rewards)
    local all={data.item}
    for _,r in ipairs(rewards or {}) do all[#all+1]=r end
    for _,r in ipairs(all) do
        if r.type=='weapon' then if Inventory.HasWeapon(src,r.name) then return false end
        elseif r.type~='xp' and not Inventory.CanCarryItem(src,r.name,r.amount*quantity) then return false end
    end
    return true
end
-- Persist each successful award so a rejected later reward does not replay earlier awards.
function GiveRewards(src,quantity,data,rewards,q)
    q.granted=q.granted or {}
    if q.failedRoll==nil then q.failedRoll=data.item.chance and math.random(1,100)>data.item.chance or false end
    if q.failedRoll then return true end
    local all={data.item}
    for _,r in ipairs(rewards or {}) do all[#all+1]=r end
    for i,r in ipairs(all) do
        if not q.granted[i] then
            local ok
            if r.type=='xp' then
                if Config.XPEnabled then ok=pcall(AddPlayerXP,src,r.name,r.amount*quantity) else ok=true end
            else
                local give=r.type=='weapon' and Inventory.AddWeapon or Inventory.AddItem
                ok=give(src,r.name,r.amount*quantity,r.createItem and r.createItem(data) or nil)==true
            end
            if not ok then return false end
            q.granted[i]=true
            SaveCraftTables()
        end
    end
    return true
end
function GiveParts(src,quantity,parts,q)
    q.refunded=q.refunded or {}
    for i,p in ipairs(parts or {}) do
        if p.remove~=false and not q.refunded[i] then
            local give=p.type=='weapon' and Inventory.AddWeapon or Inventory.AddItem
            if give(src,p.name,(p.amount or 1)*quantity)~=true then return false end
            q.refunded[i]=true; SaveCraftTables()
        end
    end
    return true
end
function StartNextQueue(tableIndex)
    local t=Tables[tableIndex]
    if not t or not t.crafting or t.activeFire then return end
    local active=false
    for _,q in pairs(t.crafting) do if q.finishTime and q.finishTime>os.time() then active=true end end
    if active then return end
    local queue=SortCraftingQueue(t.crafting)
    for _,q in ipairs(queue) do
        if not q.finishTime then
            local item=t.items[q.index]
            q.finishTime=os.time()+q.quantity*(item.time or 0)
            TriggerClientEvent('pickle_crafting:startCraftingQueue',-1,tableIndex,q.index,CraftView(t),os.time())
            SaveCraftTables(); break
        end
    end
end
RegisterCallback('pickle_crafting:getTime',function(src,cb) cb(os.time()) end)
local function validate(src,tableIndex,index,quantity)
    local t=Tables[tableIndex]; local item=itemAt(t,index)
    if not item or not CraftInteger(quantity,1,Config.MaxCraftQuantity or 100) or not CraftAccess(src,t) or t.activeFire
        or (t.crafting and t.crafting[index]) then return end
    if item.blueprint and not GetPlayerBlueprint(src,item.blueprint) then return end
    if Config.XPEnabled and item.xp then
        local ok,level=pcall(GetPlayerLevel,src,item.xp.name)
        if not ok or type(level)~='number' or level<item.xp.level then return end
    end
    if not CheckParts(src,quantity,item.parts) then return end
    return t,item
end
RegisterCallback('pickle_crafting:canCraft',function(src,cb,tableIndex,index,quantity)
    local t,item=validate(src,tableIndex,index,quantity)
    if not t then cb(false); return end
    CraftPermits[src]={owner=CraftIdentity(src),tableIndex=tableIndex,index=index,quantity=quantity,
        ready=GetGameTimer()+(item.action and (Config.ServerActionDuration or 1000) or 0),expires=GetGameTimer()+120000}
    cb(true)
end)
RegisterNetEvent('pickle_crafting:addCraftingQueue',function(tableIndex,index,quantity)
    local src=source; local permit=CraftPermits[src]
    if not permit or CraftLocks[src] or permit.owner~=CraftIdentity(src) or permit.tableIndex~=tableIndex
        or permit.index~=index or permit.quantity~=quantity or GetGameTimer()<permit.ready or GetGameTimer()>permit.expires then return end
    local t,item=validate(src,tableIndex,index,quantity)
    if not t then return end
    CraftPermits[src]=nil; CraftLocks[src]=true
    local key=tostring(tableIndex)..':'..index
    if CraftLocks[key] then CraftLocks[src]=nil; return end
    CraftLocks[key]=true
    if item.action and Config.ServerPreCraft and Config.ServerPreCraft(src,tableIndex,index,quantity)~=true then
        CraftLocks[src],CraftLocks[key]=nil,nil; return
    end
    if TakeParts(src,quantity,item.parts) then
        sequence=sequence+1
        t.crafting=t.crafting or {}
        t.crafting[index]={source=src,owner=CraftIdentity(src),quantity=quantity,queueTime=os.time(),sequence=sequence}
        SaveCraftTables()
        StartNextQueue(tableIndex)
        UpdateTables(tableIndex)
    end
    CraftLocks[src],CraftLocks[key]=nil,nil
end)
local function settle(src,tableIndex,index,cancel)
    local t=Tables[tableIndex]; local item=itemAt(t,index)
    local q=t and t.crafting and t.crafting[index]
    if not q or not item or q.busy or not CraftCanOwn(src,t,q) then return end
    if not cancel and (not q.finishTime or q.finishTime>os.time()) then return end
    if cancel and q.granted and next(q.granted) then return end
    if not cancel and q.refunded and next(q.refunded) then return end
    q.busy=true
    local ok,result=pcall(function()
        if cancel then return GiveParts(src,q.quantity,item.parts,q) end
        if not CheckRewards(src,q.quantity,{item=item},item.rewards) and not q.granted then return false end
        return GiveRewards(src,q.quantity,{item=item,tableIndex=tableIndex,index=index,tableType=t.tableType},item.rewards,q)
    end)
    q.busy=nil
    if ok and result then RemoveQueue(tableIndex,index); StartNextQueue(tableIndex); UpdateTables(tableIndex) end
end
RegisterNetEvent('pickle_crafting:removeCraftingQueue',function(tableIndex,index) settle(source,tableIndex,index,true) end)
RegisterNetEvent('pickle_crafting:collectCraftingQueue',function(tableIndex,index) settle(source,tableIndex,index,false) end)
AddEventHandler('playerDropped',function() CraftPermits[source]=nil; CraftLocks[source]=nil end)
CreateThread(function()
    while true do
        Wait(1000)
        for id,t in pairs(Tables) do
            for index,q in pairs(t.crafting or {}) do
                local item=t.items[index]
                if not q.busy and item and item.destroyTime and q.finishTime and os.time()>=q.finishTime+item.destroyTime then
                    RemoveQueue(id,index)
                    if item.destroyFire then
                        t.activeFire=true; t.fireGeneration=(t.fireGeneration or 0)+1
                        TriggerClientEvent('pickle_crafting:startCraftingFire',-1,id,item.explodeOnBurn,q.source)
                        -- Other players retain their crafts and may collect/cancel after extinguishing.
                    end
                    SaveCraftTables(); UpdateTables(id)
                end
            end
            StartNextQueue(id)
        end
    end
end)
