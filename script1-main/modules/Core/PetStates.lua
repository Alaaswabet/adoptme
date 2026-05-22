--// Single source of truth — same rules as AilmentViewer (keys + kind)

local PetStates = {}

local TRACKED_AILMENTS = {
    "sleepy",
    "dirty",
    "hungry",
    "thirsty",
    "toilet",
    "school",
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
            if value == nil then
                return
            end
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
        if not pet then
            return nil
        end
        for _, candidate in ipairs(petIdCandidates(pet)) do
            if PetStateById[candidate] then
                return candidate
            end
        end
        for stateId in pairs(PetStateById) do
            local stateKey = tostring(stateId)
            for _, candidate in ipairs(petIdCandidates(pet)) do
                if stateKey == candidate then
                    return stateKey
                end
            end
        end
        local count, onlyId = 0, nil
        for stateId in pairs(PetStateById) do
            count = count + 1
            onlyId = stateId
        end
        if count == 1 then
            return onlyId
        end
        return nil
    end

    local function getState(pet)
        local stateId = findStateId(pet)
        if not stateId then
            return nil, nil
        end
        return PetStateById[stateId], stateId
    end

    local function activeHas(active, key)
        return type(active) == "table" and active[tostring(key):lower()] == true
    end

    local function hasNeed(pet, needName)
        local state = getState(pet)
        if not state or not state.active then
            return false
        end
        local aliases = NEED_ALIASES[needName] or {needName}
        for _, alias in ipairs(aliases) do
            if activeHas(state.active, alias) then
                return true
            end
        end
        return state.needs[needName] == true
    end

    local function parsePetAilments(petId, ailmentTable)
        local active = {}
        local needs = emptyNeeds()

        for ailmentName, ailmentData in pairs(ailmentTable) do
            local keyName = tostring(ailmentName):lower()
            active[keyName] = true
            print("PET:", petId, "AILMENT:", ailmentName)

            if type(ailmentData) == "table" then
                if ailmentData.kind then
                    local kind = tostring(ailmentData.kind):lower()
                    active[kind] = true
                    print("PET:", petId, "kind=", kind)
                end
                if ailmentData.ailment_key then
                    active[tostring(ailmentData.ailment_key):lower()] = true
                end
            end
        end

        for needName, aliases in pairs(NEED_ALIASES) do
            for _, alias in ipairs(aliases) do
                if active[alias] then
                    needs[needName] = true
                    break
                end
            end
        end

        for _, name in ipairs(TRACKED_AILMENTS) do
            if active[name] then
                needs[name] = true
            end
        end

        return {
            active = active,
            needs = needs,
            updatedAt = os.clock(),
        }
    end

    local function parseAilmentsManager(data)
        if type(data) ~= "table" or type(data.ailments) ~= "table" then
            return
        end

        for key in pairs(PetStateById) do
            PetStateById[key] = nil
        end

        for petId, ailmentTable in pairs(data.ailments) do
            if type(ailmentTable) == "table" then
                PetStateById[tostring(petId)] = parsePetAilments(petId, ailmentTable)
            end
        end

        notifyListeners()
    end

    local function subscribe(callback)
        if type(callback) == "function" then
            table.insert(listeners, callback)
        end
    end

    local function getNeeds(pet)
        local state = getState(pet)
        return state and state.needs or nil
    end

    local function getActive(pet)
        local state = getState(pet)
        return state and state.active or nil
    end

    local function debugPetNeeds(pet, source)
        if not pet then
            print("[PET NEEDS DEBUG]", source or "?", "no pet")
            return
        end
        local state, stateId = getState(pet)
        if not state then
            print(
                "[PET NEEDS DEBUG]",
                source or "?",
                "pet=" .. pet.Name,
                "resolveId=" .. tostring(resolvePetId(pet)),
                "stateId=nil"
            )
            return
        end
        local rawParts = {}
        for key in pairs(state.active) do
            table.insert(rawParts, key)
        end
        table.sort(rawParts)
        local needParts = {}
        for _, name in ipairs(TRACKED_AILMENTS) do
            table.insert(needParts, name .. "=" .. tostring(hasNeed(pet, name)))
        end
        print(
            "[PET NEEDS DEBUG]",
            source or "?",
            "pet=" .. pet.Name,
            "stateId=" .. tostring(stateId),
            "| keys:", table.concat(rawParts, ", "),
            "| " .. table.concat(needParts, " ")
        )
    end

    return {
        TRACKED_AILMENTS = TRACKED_AILMENTS,
        NEED_ALIASES = NEED_ALIASES,
        PetStateById = PetStateById,
        parseAilmentsManager = parseAilmentsManager,
        subscribe = subscribe,
        getState = getState,
        getNeeds = getNeeds,
        getActive = getActive,
        hasNeed = hasNeed,
        resolvePetId = resolvePetId,
        findStateId = findStateId,
        debugPetNeeds = debugPetNeeds,
        isDirty = function(pet) return hasNeed(pet, "dirty") end,
        isSleepy = function(pet) return hasNeed(pet, "sleepy") end,
        isHungry = function(pet) return hasNeed(pet, "hungry") end,
        isThirsty = function(pet) return hasNeed(pet, "thirsty") end,
        isToilet = function(pet) return hasNeed(pet, "toilet") end,
        isSchool = function(pet) return hasNeed(pet, "school") end,
        isPetMe = function(pet) return hasNeed(pet, "pet_me") or hasNeed(pet, "play") end,
        isPlay = function(pet) return hasNeed(pet, "play") or hasNeed(pet, "pet_me") end,
        isWalk = function(pet) return hasNeed(pet, "walk") end,
        isSleeping = function()
            return false
        end,
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
