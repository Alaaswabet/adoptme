--// Locks house furniture once, makes it invisible, follows player (no re-scan)

local FurnitureHub = {}

local RunService = game:GetService("RunService")

local STATION_CONFIG = {
    food = {find = "FindFood", partName = "UseBlock", offset = CFrame.new(-4, 0, -4)},
    drink = {find = "FindDrink", partName = "UseBlock", offset = CFrame.new(4, 0, -4)},
    toilet = {find = "FindToilet", partName = "Seat1", offset = CFrame.new(-4, 0, 4)},
    shower = {find = "FindShower", partName = "UseBlock", offset = CFrame.new(4, 0, 4)},
    bed = {find = "FindBed", partName = "Seat1", offset = CFrame.new(0, 0, -5), module = "sleep"},
}

local stations = {}
local cacheLocked = false
local followConn = nil
local preppedModels = {}

local function getFurnitureModel(fromInst)
    if not fromInst then
        return nil
    end
    local model = fromInst
    while model and not model:IsA("Model") do
        model = model.Parent
    end
    if model and model:IsA("Model") then
        return model
    end
    return fromInst
end

local function getActivatePart(model, partName)
    if not model then
        return nil
    end
    local named = model:FindFirstChild(partName, true)
    if named and named:IsA("BasePart") then
        return named
    end
    if model:IsA("BasePart") then
        return model
    end
    return model:FindFirstChildWhichIsA("BasePart", true)
end

local function makeInvisible(model)
    if not model or preppedModels[model] then
        return
    end
    preppedModels[model] = true
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Anchored = true
            desc.CanCollide = false
            desc.Transparency = 1
            desc.CastShadow = false
            desc.LocalTransparencyModifier = 1
        elseif desc:IsA("Decal") or desc:IsA("Texture") then
            desc.Transparency = 1
        end
    end
    if model:IsA("BasePart") then
        model.Anchored = true
        model.CanCollide = false
        model.Transparency = 1
        model.CastShadow = false
    end
end

local function placeStation(station, hrp)
    if not station or not station.model or not hrp then
        return
    end
    if not station.model.Parent then
        return
    end

    local targetCF = hrp.CFrame * station.offset
    pcall(function()
        if station.model:IsA("Model") then
            station.model:PivotTo(targetCF)
        elseif station.activatePart and station.activatePart.Parent then
            station.activatePart.CFrame = targetCF
        end
    end)
end

local function updateFollow(player)
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    for _, station in pairs(stations) do
        placeStation(station, hrp)
    end
end

-- Only scans workspace the first time (while you are at your house). Never re-scans after lock.
function FurnitureHub.cacheAll(Care, Sleep, force)
    if cacheLocked and not force then
        return stations
    end

    local findBed = Sleep and Sleep.FindBed
    local newStations = {}

    for key, cfg in pairs(STATION_CONFIG) do
        if not stations[key] then
            local finder = cfg.module == "sleep" and findBed or (Care and Care[cfg.find])
            if finder then
                local id, target = finder()
                if id and target then
                    local model = getFurnitureModel(target)
                    if model and model.Parent then
                        makeInvisible(model)
                        newStations[key] = {
                            id = id,
                            model = model,
                            activatePart = getActivatePart(model, cfg.partName) or target,
                            partName = cfg.partName,
                            offset = cfg.offset,
                        }
                    end
                end
            end
        else
            newStations[key] = stations[key]
        end
    end

    for key, entry in pairs(newStations) do
        stations[key] = entry
    end

    if next(stations) then
        cacheLocked = true
    end

    return stations
end

function FurnitureHub.isLocked()
    return cacheLocked
end

function FurnitureHub.clearLock()
    cacheLocked = false
    stations = {}
    preppedModels = {}
end

function FurnitureHub.startFollow(player)
    if followConn then
        return
    end
    followConn = RunService.Heartbeat:Connect(function()
        updateFollow(player)
    end)
end

function FurnitureHub.stopFollow()
    if followConn then
        followConn:Disconnect()
        followConn = nil
    end
end

function FurnitureHub.refresh(player)
    updateFollow(player)
end

function FurnitureHub.use(needType, player, pet, ActivateFurniture)
    if not pet or not ActivateFurniture then
        return false
    end

    local station = stations[needType]
    if not station or not station.activatePart or not station.activatePart.Parent then
        return false
    end

    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        placeStation(station, hrp)
    end

    local cf = station.activatePart.CFrame
    local function callRemoteSafe(remote, ...)
        if not remote then return false, "remote missing" end
        local args = {...}
        if remote:IsA("RemoteFunction") then
            return pcall(function() return remote:InvokeServer(unpack(args)) end)
        elseif remote:IsA("RemoteEvent") then
            return pcall(function() remote:FireServer(unpack(args)) end)
        else
            return false, "unsupported remote type"
        end
    end

    return callRemoteSafe(ActivateFurniture, player, station.id, station.partName, {cframe = cf}, pet)
end

return FurnitureHub
