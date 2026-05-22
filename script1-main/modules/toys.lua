--// Toy unique id comes from equip_manager (id/kind = squeaky_bone_default) — never hardcoded

local Toys = {}

Toys.TOY_ID = "squeaky_bone_default"
Toys.TOY_KIND = "squeaky_bone_default"

local equipToys = {}
local cachedEntry = nil

local THROW_COUNT = 3
local THROW_COOLDOWN = 5

local function lower(s)
    return tostring(s or ""):lower()
end

local function isSqueakyBone(entry)
    if type(entry) ~= "table" then
        return false
    end
    return lower(entry.id) == lower(Toys.TOY_ID) or lower(entry.kind) == lower(Toys.TOY_KIND)
end

-- Called when DataAPI/DataChanged sends equip_manager (see Cobalt firesignal example)
function Toys.parseEquipManager(data)
    equipToys = {}
    cachedEntry = nil

    if type(data) ~= "table" or type(data.toys) ~= "table" then
        return nil
    end

    for _, toy in pairs(data.toys) do
        if type(toy) == "table" and toy.unique then
            table.insert(equipToys, toy)
            if isSqueakyBone(toy) then
                cachedEntry = toy
            end
        end
    end

    return cachedEntry
end

function Toys.getEquipToyEntry()
    if cachedEntry and isSqueakyBone(cachedEntry) then
        return cachedEntry
    end
    for _, toy in ipairs(equipToys) do
        if isSqueakyBone(toy) then
            cachedEntry = toy
            return toy
        end
    end
    return nil
end

function Toys.hasEquipToy()
    return Toys.getEquipToyEntry() ~= nil
end

function Toys.resolveUniqueId()
    local entry = Toys.getEquipToyEntry()
    if entry and entry.unique then
        return tostring(entry.unique), entry
    end
    return nil, nil
end

function Toys.findToyByName(_player)
    return Toys.resolveUniqueId()
end

function Toys.getToyId(_player)
    local uid = Toys.resolveUniqueId()
    return uid or ""
end

function Toys.getToyDisplayName()
    return Toys.TOY_ID
end

function Toys.equip(Remotes, uniqueId)
    uniqueId = uniqueId or Toys.resolveUniqueId()
    if not uniqueId then
        return false, "no toy in equip_manager"
    end
    return pcall(function()
        Remotes.ToolEquip:InvokeServer(uniqueId, {
            use_sound_delay = true,
            equip_as_last = false,
        })
    end)
end

function Toys.unequip(Remotes, uniqueId, fromThrow)
    uniqueId = uniqueId or Toys.resolveUniqueId()
    if not uniqueId then
        return false
    end
    return pcall(function()
        if fromThrow then
            Remotes.ToolUnequip:InvokeServer(uniqueId, {from_throw_toy = true})
        else
            Remotes.ToolUnequip:InvokeServer(uniqueId, nil)
        end
    end)
end

function Toys.useStart(Remotes, uniqueId)
    uniqueId = uniqueId or Toys.resolveUniqueId()
    if not uniqueId then
        return false
    end
    return pcall(function()
        Remotes.ServerUseTool:InvokeServer(uniqueId, "START")
    end)
end

function Toys.useEnd(Remotes, uniqueId)
    uniqueId = uniqueId or Toys.resolveUniqueId()
    if not uniqueId then
        return false
    end
    return pcall(function()
        Remotes.ServerUseTool:InvokeServer(uniqueId, "END", nil)
    end)
end

-- Cobalt: PetObjectAPI/CreatePetObject + ThrowToyReaction + unique_id from equip_manager
function Toys.throwToy(Remotes, uniqueId)
    uniqueId = uniqueId or Toys.resolveUniqueId()
    if not uniqueId then
        return false, "no toy in equip_manager"
    end
    return pcall(function()
        Remotes.CreatePetObject:InvokeServer("__Enum_PetObjectCreatorType_1", {
            reaction_name = "ThrowToyReaction",
            unique_id = uniqueId,
        })
    end)
end

function Toys.throwOnce(Remotes, uniqueId)
    uniqueId = uniqueId or Toys.resolveUniqueId()
    if not uniqueId then
        return false, "no toy in equip_manager"
    end
    Toys.equip(Remotes, uniqueId)
    task.wait(0.35)
    Toys.throwToy(Remotes, uniqueId)
    task.wait(0.4)
    Toys.unequip(Remotes, uniqueId, true)
    return true
end

function Toys.throwThreeTimes(Remotes, uniqueId, stillNeedsFn)
    uniqueId = uniqueId or Toys.resolveUniqueId()
    if not uniqueId then
        return false, "no toy in equip_manager"
    end
    for i = 1, THROW_COUNT do
        if stillNeedsFn and not stillNeedsFn() then
            break
        end
        pcall(function()
            Toys.throwOnce(Remotes, uniqueId)
        end)
        if i < THROW_COUNT then
            task.wait(THROW_COOLDOWN)
        end
    end
    return true
end

function Toys.playUntilDone(Remotes, uniqueId, stillNeedsFn)
    uniqueId = uniqueId or Toys.resolveUniqueId()
    if not uniqueId then
        return false, "no toy in equip_manager"
    end
    Toys.equip(Remotes, uniqueId)
    task.wait(0.35)
    Toys.useStart(Remotes, uniqueId)
    local timeout = os.clock() + 50
    while stillNeedsFn() and os.clock() < timeout do
        task.wait(0.45)
    end
    Toys.useEnd(Remotes, uniqueId)
    task.wait(0.2)
    Toys.unequip(Remotes, uniqueId, false)
    return true
end

local WALK_KEYS = {
    Enum.KeyCode.W,
    Enum.KeyCode.A,
    Enum.KeyCode.S,
    Enum.KeyCode.D,
}

local KEY_HOLD = 0.16
local KEY_GAP = 0.03
local BURST_COUNT = 8

local function pressKey(keyCode, down)
    pcall(function()
        game:GetService("VirtualInputManager"):SendKeyEvent(down, keyCode, false, game)
    end)
end

local function releaseAllKeys()
    for _, key in ipairs(WALK_KEYS) do
        pressKey(key, false)
    end
end

local function tapKey(keyCode)
    pressKey(keyCode, true)
    task.wait(KEY_HOLD)
    pressKey(keyCode, false)
    task.wait(KEY_GAP)
end

local function nextWalkKey()
    local roll = math.random(1, 10)
    if roll <= 5 then
        return Enum.KeyCode.W
    elseif roll <= 7 then
        return math.random(1, 2) == 1 and Enum.KeyCode.A or Enum.KeyCode.D
    elseif roll == 8 then
        return Enum.KeyCode.S
    end
    return WALK_KEYS[math.random(1, #WALK_KEYS)]
end

local function walkBurst()
    releaseAllKeys()
    for _ = 1, BURST_COUNT do
        tapKey(nextWalkKey())
    end
    releaseAllKeys()
end

function Toys.walkWithPet(player, HoldBaby, pet, stillNeedsFn)
    if not pet then
        return false
    end
    pcall(function()
        HoldBaby:FireServer(pet)
    end)
    task.wait(0.35)

    local char = player.Character
    if not char or not char:FindFirstChildOfClass("Humanoid") then
        return false
    end

    local timeout = os.clock() + 70
    while stillNeedsFn() and os.clock() < timeout do
        walkBurst()
        pcall(function()
            HoldBaby:FireServer(pet)
        end)
        task.wait(0.12)
    end

    releaseAllKeys()
    return true
end

return Toys
