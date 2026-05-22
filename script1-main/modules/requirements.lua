--// Scans house for autofarm-required furniture (no moving / locking)

local Requirements = {}

local COLOR_OK = Color3.fromRGB(96, 165, 250)
local COLOR_MISSING = Color3.fromRGB(120, 125, 138)
local COLOR_WARN = Color3.fromRGB(230, 175, 90)

local ITEMS = {
    {
        key = "food",
        label = "Food Bowl",
        need = "hungry",
        find = "FindFood",
        module = "care",
    },
    {
        key = "drink",
        label = "Water Bowl",
        need = "thirsty",
        find = "FindDrink",
        module = "care",
    },
    {
        key = "toilet",
        label = "Toilet",
        need = "toilet",
        find = "FindToilet",
        module = "care",
    },
    {
        key = "shower",
        label = "Shower",
        need = "dirty",
        find = "FindShower",
        module = "care",
    },
    {
        key = "bed",
        label = "Pet Bed",
        need = "sleepy",
        find = "FindBed",
        module = "sleep",
    },
    {
        key = "toy",
        label = "squeaky_bone_default",
        need = "play",
        toy = true,
    },
}

local lastScan = {}

local function formatRow(label, ready)
    if ready then
        return "●  " .. label .. "  ·  ready"
    end
    return "○  " .. label .. "  ·  missing"
end

function Requirements.scan(Care, Sleep, Toys, player)
    local results = {}
    local missing = {}
    local readyCount = 0

    for _, item in ipairs(ITEMS) do
        local found = false
        local detail = nil

        if item.toy then
            if Toys and Toys.hasEquipToy then
                found = Toys.hasEquipToy()
                if found and Toys.resolveUniqueId then
                    detail = Toys.resolveUniqueId()
                end
            elseif Toys and Toys.findToyByName then
                detail = Toys.findToyByName(player)
                found = detail ~= nil and detail ~= ""
            end
        else
            local finder = item.module == "sleep" and Sleep and Sleep[item.find]
                or (Care and Care[item.find])
            if finder then
                local id, target = finder()
                found = id ~= nil and target ~= nil
                detail = id
            end
        end

        results[item.key] = {
            key = item.key,
            label = item.label,
            need = item.need,
            found = found,
            detail = detail,
            toy = item.toy == true,
        }

        if found then
            readyCount = readyCount + 1
        else
            table.insert(missing, item.label)
        end
    end

    lastScan = {
        results = results,
        missing = missing,
        readyCount = readyCount,
        total = #ITEMS,
        scannedAt = os.clock(),
    }

    return lastScan
end

function Requirements.getLastScan()
    return lastScan
end

function Requirements.has(itemKey)
    if lastScan.results and lastScan.results[itemKey] then
        return lastScan.results[itemKey].found == true
    end
    return false
end

function Requirements.canHandleNeed(needKey)
    local map = {
        hungry = "food",
        thirsty = "drink",
        toilet = "toilet",
        dirty = "shower",
        sleepy = "bed",
        play = "toy",
        pet_me = "toy",
        walk = nil,
    }
    local itemKey = map[needKey]
    if not itemKey then
        return true
    end
    if not lastScan.results or not next(lastScan.results) then
        return true
    end
    return Requirements.has(itemKey)
end

function Requirements.allCareReady()
    if not lastScan.results or not next(lastScan.results) then
        return false, {"Scan not run"}
    end
    if #lastScan.missing == 0 then
        return true, nil
    end
    return false, lastScan.missing
end

function Requirements.getSummaryText()
    if not lastScan.results or not next(lastScan.results) then
        return "Status: not scanned", COLOR_WARN
    end
    if #lastScan.missing == 0 then
        return "Status: all requirements met", COLOR_OK
    end
    return "Status: " .. #lastScan.missing .. " missing", COLOR_WARN
end

Requirements.formatRow = formatRow
Requirements.COLOR_OK = COLOR_OK
Requirements.COLOR_MISSING = COLOR_MISSING
Requirements.COLOR_WARN = COLOR_WARN
Requirements.ITEMS = ITEMS

return Requirements
