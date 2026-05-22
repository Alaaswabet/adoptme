--// Rayfield live ailment labels (AilmentViewer-style)

local AilmentsPanel = {}

local COLOR_OFF = Color3.fromRGB(255, 80, 80)
local COLOR_ON = Color3.fromRGB(80, 255, 120)
local COLOR_MUTED = Color3.fromRGB(160, 160, 170)

function AilmentsPanel.Create(tab, PetState, getSelectedPet)
    local ailmentsToTrack = PetState.TRACKED_AILMENTS
    local ailmentLabels = {}
    local PetIdLabel
    local RawKeysLabel

    tab:CreateSection("Pet Ailments")
    PetIdLabel = tab:CreateLabel("Pet ID: —", 0, COLOR_MUTED, false)
    tab:CreateDivider()

    for _, name in ipairs(ailmentsToTrack) do
        ailmentLabels[name] = tab:CreateLabel(name .. ": false", 0, COLOR_OFF, false)
    end

    tab:CreateDivider()
    RawKeysLabel = tab:CreateLabel("Raw keys: (waiting for data)", 0, COLOR_MUTED, false)

    local function setAilmentLabel(name, isActive)
        local label = ailmentLabels[name]
        if not label then
            return
        end
        if isActive then
            label:Set(name .. ": true", 0, COLOR_ON, false)
        else
            label:Set(name .. ": false", 0, COLOR_OFF, false)
        end
    end

    local function refresh()
        local pet = getSelectedPet()
        if not pet then
            PetIdLabel:Set("Pet ID: no pet selected", 0, COLOR_MUTED, false)
            for _, name in ipairs(ailmentsToTrack) do
                setAilmentLabel(name, false)
            end
            RawKeysLabel:Set("Raw keys: —", 0, COLOR_MUTED, false)
            return
        end

        local stateId = PetState.findStateId(pet)
        local resolveId = PetState.resolvePetId(pet)
        PetIdLabel:Set(
            "Pet ID: " .. (stateId or resolveId or "?") .. (stateId and stateId ~= resolveId and (" (attr: " .. resolveId .. ")") or ""),
            0,
            COLOR_MUTED,
            false
        )

        local active = PetState.getActive(pet)
        for _, name in ipairs(ailmentsToTrack) do
            local isActive = false
            if type(PetState.hasNeed) == "function" then
                isActive = PetState.hasNeed(pet, name)
            end
            if not isActive then
                if name == "hungry" and type(PetState.isHungry) == "function" then
                    isActive = PetState.isHungry(pet)
                elseif name == "thirsty" and type(PetState.isThirsty) == "function" then
                    isActive = PetState.isThirsty(pet)
                elseif name == "toilet" and type(PetState.isToilet) == "function" then
                    isActive = PetState.isToilet(pet)
                elseif name == "dirty" and type(PetState.isDirty) == "function" then
                    isActive = PetState.isDirty(pet)
                elseif name == "sleepy" and type(PetState.isSleepy) == "function" then
                    isActive = PetState.isSleepy(pet)
                end
            end
            if not isActive and active and active[tostring(name):lower()] then
                isActive = true
            end
            setAilmentLabel(name, isActive)
        end

        if active then
            local keys = {}
            for key in pairs(active) do
                table.insert(keys, key)
            end
            table.sort(keys)
            RawKeysLabel:Set(
                #keys > 0 and ("Raw keys: " .. table.concat(keys, ", ")) or "Raw keys: (none)",
                0,
                COLOR_MUTED,
                false
            )
        else
            RawKeysLabel:Set("Raw keys: no ailments_manager data for this pet", 0, COLOR_MUTED, false)
        end
    end

    return {
        refresh = refresh,
    }
end

return AilmentsPanel
