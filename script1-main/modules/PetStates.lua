--// Same as Core/PetStates.lua (flat path for GitHub raw load)

local PetStates = {}

local TRACKED_AILMENTS = {
    "sleepy",
    "dirty",
    "hungry",
    "thirsty",
    "toilet",
    "school",
    "beach_party",
    "camping",
    "playground",
    "salon",
    "pet_me",
    "play",
    "walk",
}

local NEED_ALIASES = {
    sleepy = {"sleepy", "tired", "needsleep", "needs_sleep", "sleep"},
    dirty = {"dirty", "stinky", "stink", "needsbath", "needs_bath", "bath"},
    hungry = {"hungry", "hunger", "feed", "needsfood", "needs_food", "starving"},
    thirsty = {"thirsty", "thirst", "needsdrink", "needs_drink", "drink", "hydration"},
    toilet = {"toilet", "pee", "poop", "restroom"},
    school = {"school"},
    beach_party = {"beach", "beach_party"},
    camping = {"camp", "camping", "sleeping_bag"},
    playground = {"playground", "park", "roundabout", "bored"},
    salon = {"salon"},
    pet_me = {"pet_me", "petme", "pet", "play", "squeaky_bone_default"},
    play = {"play", "pet_me", "squeaky_bone_default", "squeaky"},
    walk = {"walk", "walking", "go_walk"},
}

function PetStates.Init()
    local PetStateById = {}
    local listeners = {}

    local function emptyNeeds()
        local needs = {}
        for _, name in ipairs(TRACKED_AILMENTS) do
            needs[name] = false
        end
        return needs
    end

    local function notifyListeners()
        for _, callback in ipairs(listeners) do
            task.spawn(callback)
        end
    end

    local function resolvePetId(pet)
        if not pet or not pet:IsA("Model") then
            return nil
        end
        return tostring(pet:GetAttribute("unique") or pet:GetAttribute("id") or pet.Name)
    end

    local function petIdCandidates(pet)
        local candidates = {}
        local seen = {}
        local function add(value)
            if value == nil then return end
            local key = tostring(value)
            if key ~= "" and not seen[key] then
                seen[key] = true
                table.insert(candidates, key)
            end
        end
        add(pet:GetAttribute("unique"))
        add(pet:GetAttribute("id"))
        add(pet.Name)
        return candidates
    end

    local function findStateId(pet)
        if not pet then return nil end
        for _, candidate in ipairs(petIdCandidates(pet)) do
            if PetStateById[candidate] then return candidate end
        end
        for stateId in pairs(PetStateById) do
            for _, candidate in ipairs(petIdCandidates(pet)) do
                if tostring(stateId) == candidate then return stateId end
            end
        end
        local count, onlyId = 0, nil
        for stateId in pairs(PetStateById) do count = count + 1 onlyId = stateId end
        if count == 1 then return onlyId end
        return nil
    end

    local function getState(pet)
        local stateId = findStateId(pet)
        if not stateId then return nil, nil end
        return PetStateById[stateId], stateId
    end

    local function activeHas(active, key)
        return type(active) == "table" and active[tostring(key):lower()] == true
    end

    local function hasNeed(pet, needName)
        local state = getState(pet)
        if not state or not state.active then return false end
        for _, alias in ipairs(NEED_ALIASES[needName] or {needName}) do
            if activeHas(state.active, alias) then return true end
        end
        return state.needs[needName] == true
    end

    local function parsePetAilments(petId, ailmentTable)
        local active = {}
        local needs = emptyNeeds()
        for ailmentName, ailmentData in pairs(ailmentTable) do
            active[tostring(ailmentName):lower()] = true
            print("PET:", petId, "AILMENT:", ailmentName)
            if type(ailmentData) == "table" then
                if ailmentData.kind then
                    active[tostring(ailmentData.kind):lower()] = true
                end
                if ailmentData.ailment_key then
                    active[tostring(ailmentData.ailment_key):lower()] = true
                end
            end
        end
        for needName, aliases in pairs(NEED_ALIASES) do
            for _, alias in ipairs(aliases) do
                if active[alias] then needs[needName] = true break end
            end
        end
        for _, name in ipairs(TRACKED_AILMENTS) do
            if active[name] then needs[name] = true end
        end
        return {active = active, needs = needs, updatedAt = os.clock()}
    end

    local function parseAilmentsManager(data)
        if type(data) ~= "table" or type(data.ailments) ~= "table" then return end
        for key in pairs(PetStateById) do PetStateById[key] = nil end
        for petId, ailmentTable in pairs(data.ailments) do
            if type(ailmentTable) == "table" then
                PetStateById[tostring(petId)] = parsePetAilments(petId, ailmentTable)
            end
        end
        notifyListeners()
    end

    return {
        TRACKED_AILMENTS = TRACKED_AILMENTS,
        parseAilmentsManager = parseAilmentsManager,
        subscribe = function(cb) if type(cb) == "function" then table.insert(listeners, cb) end end,
        getActive = function(pet) local s = getState(pet) return s and s.active end,
        hasNeed = hasNeed,
        resolvePetId = resolvePetId,
        findStateId = findStateId,
        debugPetNeeds = function(pet, src)
            if not pet then return end
            local st, sid = getState(pet)
            print("[PET NEEDS]", src, pet.Name, sid, st and "ok" or "no state")
        end,
        isDirty = function(p) return hasNeed(p, "dirty") end,
        isSleepy = function(p) return hasNeed(p, "sleepy") end,
        isHungry = function(p) return hasNeed(p, "hungry") end,
        isThirsty = function(p) return hasNeed(p, "thirsty") end,
        isToilet = function(p) return hasNeed(p, "toilet") end,
        isSchool = function(p) return hasNeed(p, "school") end,
        isPetMe = function(p) return hasNeed(p, "pet_me") or hasNeed(p, "play") end,
        isPlay = function(p) return hasNeed(p, "play") or hasNeed(p, "pet_me") end,
        isWalk = function(p) return hasNeed(p, "walk") end,
        isSleeping = function() return false end,
        getAilmentKind = function(pet)
            local state = getState(pet)
            if not state or not state.active then
                return nil
            end
            local active = state.active
            for _, kind in ipairs({
                "squeaky_bone_default",
                "play",
                "walk",
                "pet_me",
            }) do
                if active[kind] then
                    return kind
                end
            end
            return nil
        end,
        needsPlayToy = function(pet)
            local state = getState(pet)
            if state and state.active then
                if state.active["squeaky_bone_default"] then
                    return true, "squeaky_bone_default"
                end
                if state.active["play"] then
                    return true, "play"
                end
            end
            if hasNeed(pet, "play") or hasNeed(pet, "pet_me") then
                return true, "play"
            end
            return false, nil
        end,
    }
end

return PetStates
