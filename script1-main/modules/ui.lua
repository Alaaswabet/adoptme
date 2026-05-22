--// Pet Controller UI — loadstring-safe (no require)

local UI = {}

local Rayfield = nil
do
    local ok, lib = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    if ok then
        Rayfield = lib
    else
        warn("[ui] Rayfield load failed:", lib)
    end
end

local COLOR_INACTIVE = Color3.fromRGB(120, 125, 138)
local COLOR_ACTIVE = Color3.fromRGB(96, 165, 250)
local COLOR_HEADER = Color3.fromRGB(210, 214, 222)
local COLOR_DIM = Color3.fromRGB(155, 160, 172)
local COLOR_WARN = Color3.fromRGB(230, 175, 90)

local AILMENT_DISPLAY = {
    sleepy = "Sleepy",
    dirty = "Bath",
    hungry = "Hunger",
    thirsty = "Thirst",
    toilet = "Toilet",
    school = "School",
    beach_party = "Beach Party",
    camping = "Camping",
    playground = "Playground",
    salon = "Salon",
    pet_me = "Pet Me",
    play = "Play",
    walk = "Walk",
}

local function setLabel(label, text, color)
    if not label then
        return
    end
    pcall(function()
        label:Set(text, 0, color or COLOR_DIM, false)
    end)
end

local function formatNeed(name, active)
    local title = AILMENT_DISPLAY[name] or name
    if active then
        return "●  " .. title .. "  ·  active"
    end
    return "○  " .. title .. "  ·  clear"
end

function UI.Init(Pets, Sleep, Care, Remotes, PetState, Toys, Requirements)
    if not Rayfield then
        warn("[ui] No Rayfield")
        return
    end
    if not PetState then
        warn("[ui] No PetState")
        return
    end
    if not Pets or not Sleep or not Care or not Remotes then
        warn("[ui] Missing modules")
        return
    end

    Toys = Toys or {
        getToyId = function()
            return ""
        end,
        parseEquipManager = function() end,
        playUntilDone = function() end,
        throwThreeTimes = function() end,
        walkWithPet = function() end,
    }

    local player = game:GetService("Players").LocalPlayer

    local REQ_ITEMS = {
        {key = "food", label = "Food Bowl", need = "hungry", find = "FindFood", module = "care"},
        {key = "drink", label = "Water Bowl", need = "thirsty", find = "FindDrink", module = "care"},
        {key = "toilet", label = "Toilet", need = "toilet", find = "FindToilet", module = "care"},
        {key = "shower", label = "Shower", need = "dirty", find = "FindShower", module = "care"},
        {key = "bed", label = "Pet Bed", need = "sleepy", find = "FindBed", module = "sleep"},
        {key = "toy", label = "squeaky_bone_default", need = "play", toy = true},
    }

    local lastReqScan = {results = {}, missing = {}}

    local function formatReqRow(label, ready)
        if ready then
            return "●  " .. label .. "  ·  ready"
        end
        return "○  " .. label .. "  ·  missing"
    end

    local function scanHouse()
        local results = {}
        local missing = {}
        for _, item in ipairs(REQ_ITEMS) do
            local found = false
            if item.toy then
                if Toys.hasEquipToy then
                    found = Toys.hasEquipToy()
                elseif Toys.findToyByName then
                    local uid = Toys.findToyByName(player)
                    found = uid ~= nil and uid ~= ""
                end
            else
                local finder = item.module == "sleep" and Sleep[item.find] or Care[item.find]
                if finder then
                    local id, target = finder()
                    found = id ~= nil and target ~= nil
                end
            end
            results[item.key] = {key = item.key, label = item.label, found = found}
            if found then
                -- ok
            else
                table.insert(missing, item.label)
            end
        end
        lastReqScan = {results = results, missing = missing}
        return lastReqScan
    end

    local function getReqSummary()
        if not lastReqScan.results or not next(lastReqScan.results) then
            return "Status: not scanned", COLOR_WARN
        end
        if #lastReqScan.missing == 0 then
            return "Status: all requirements met", COLOR_ACTIVE
        end
        return "Status: " .. #lastReqScan.missing .. " missing", COLOR_WARN
    end

    local function canHandleNeed(needKey)
        local map = {
            hungry = "food",
            thirsty = "drink",
            toilet = "toilet",
            dirty = "shower",
            sleepy = "bed",
            play = "toy",
            pet_me = "toy",
        }
        local itemKey = map[needKey]
        if not itemKey then
            return true
        end
        if not lastReqScan.results or not next(lastReqScan.results) then
            return true
        end
        local row = lastReqScan.results[itemKey]
        return row and row.found == true
    end

    local function allCareReady()
        if not lastReqScan.results or not next(lastReqScan.results) then
            return false, {"Scan not run"}
        end
        if #lastReqScan.missing == 0 then
            return true, nil
        end
        return false, lastReqScan.missing
    end

    local builtinRequirements = {
        scan = function()
            return scanHouse()
        end,
        getLastScan = function()
            return lastReqScan
        end,
        getSummaryText = getReqSummary,
        formatRow = formatReqRow,
        canHandleNeed = canHandleNeed,
        allCareReady = allCareReady,
        ITEMS = REQ_ITEMS,
    }

    if type(Requirements) ~= "table" or type(Requirements.scan) ~= "function" then
        warn("[ui] requirements.lua missing or invalid — using built-in scanner")
        Requirements = builtinRequirements
    end

    print("[ui] Init v10 — TP care + requirements tab")

    local HoldBaby = Remotes.HoldBaby
    local EjectBaby = Remotes.EjectBaby
    local ActivateFurniture = Remotes.ActivateFurniture
    local UnsubscribeFromHouse = Remotes.UnsubscribeFromHouse
    local DataChanged = Remotes.DataChanged

    local selectedPetName = nil
    local PetDropdown = nil
    local autofarmEnabled = false
    local autofarmLoop = nil
    local actionBusy = false
    local track = PetState.TRACKED_AILMENTS

    local function refreshPetDropdown()
        if not PetDropdown then
            return
        end
        local options = {}
        for _, p in ipairs(Pets.GetPets()) do
            table.insert(options, p.Name)
        end
        if #options == 0 then
            return
        end
        PetDropdown:Refresh(options)
        if not selectedPetName or not table.find(options, selectedPetName) then
            selectedPetName = options[1]
        end
        PetDropdown:Set({selectedPetName})
    end

    local function getPet()
        if selectedPetName then
            local p = Pets.FindPetByName(selectedPetName)
            if p and p.Parent and p:IsDescendantOf(workspace) then
                return p
            end
        end
        refreshPetDropdown()
        if selectedPetName then
            local p = Pets.FindPetByName(selectedPetName)
            if p and p.Parent and p:IsDescendantOf(workspace) then
                return p
            end
        end
        return nil
    end

    local function resolveCFrame(target, partName)
        if not target then
            return nil
        end
        if target:IsA("BasePart") then
            return target.CFrame
        end
        local named = target:FindFirstChild(partName)
        if named and named:IsA("BasePart") then
            return named.CFrame
        end
        if target.PrimaryPart then
            return target.PrimaryPart.CFrame
        end
        local bp = target:FindFirstChildOfClass("BasePart")
        return bp and bp.CFrame
    end

    local function callRemote(remote, ...)
        if not remote then
            return false, "remote missing"
        end
        if remote:IsA("RemoteFunction") then
            return pcall(function()
                return remote:InvokeServer(...)
            end)
        elseif remote:IsA("RemoteEvent") then
            return pcall(function()
                remote:FireServer(...)
            end)
        end
        return false, "unsupported remote type"
    end

    local function enterHouseViaDoor()
        print("[ui] enterHouseViaDoor: attempting house exit + entry")

        if not exitHouseToMainArea() then
            print("[ui] enterHouseViaDoor: exitHouseToMainArea failed")
            return false
        end

        local char = player.Character or player.CharacterAdded:Wait()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            print("[ui] enterHouseViaDoor: missing HumanoidRootPart")
            return false
        end

        -- Try common path first
        local function findHouseDoorTouch()
            local p = workspace:FindFirstChild("HouseExteriors")
            if p and p["1"] and p["1"].Micro and p["1"].Micro.Doors and p["1"].Micro.Doors.MainDoor then
                local wp = p["1"].Micro.Doors.MainDoor:FindFirstChild("WorkingParts")
                if wp then
                    local t = wp:FindFirstChild("TouchToEnter")
                    if t then return t end
                end
            end
            -- Fallback: search descendants for TouchToEnter under HouseExteriors
            if workspace:FindFirstChild("HouseExteriors") then
                for _, v in pairs(workspace.HouseExteriors:GetDescendants()) do
                    if v.Name == "TouchToEnter" and v:IsA("BasePart") then
                        return v
                    end
                end
            end
            return nil
        end

        local doorPart = findHouseDoorTouch()
        -- Try a few times: sometimes HouseExteriors take a moment to populate after exitHouseToMainArea
        local doorPart = nil
        for i = 1, 4 do
            doorPart = findHouseDoorTouch()
            if doorPart then break end
            print("[ui] enterHouseViaDoor: TouchToEnter not found, retrying ("..i..")")
            task.wait(1)
        end
        if not doorPart then
            print("[ui] enterHouseViaDoor: Door TouchToEnter not found after retries")
            -- Fallback: try to find MainDoor model and teleport near it
            local fallback = workspace:FindFirstChild("HouseExteriors")
                and workspace.HouseExteriors["1"]
                and workspace.HouseExteriors["1"].Micro
                and workspace.HouseExteriors["1"].Micro.Doors
                and workspace.HouseExteriors["1"].Micro.Doors.MainDoor
            if fallback then
                local fp = resolveTeleportPart(fallback)
                if fp then
                    print("[ui] enterHouseViaDoor: falling back to MainDoor part", safeName(fp))
                    -- place player above the fallback part
                    local char = player.Character or player.CharacterAdded:Wait()
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        char:PivotTo(fp.CFrame + Vector3.new(0, 5, 0))
                        task.wait(1)
                        return true
                    end
                end
            end
            setStatus("Door not found")
            return false
        end

        print("[ui] enterHouseViaDoor: flying to door", safeName(doorPart))
        -- start above the door so you "fly"
        char:PivotTo(hrp.CFrame + Vector3.new(0, 10, 0))

        local RunService = game:GetService("RunService")
        local speed = 120
        local stopDistance = 2
        local conn

        conn = RunService.Heartbeat:Connect(function(dt)
            if not hrp or not hrp.Parent then
                conn:Disconnect()
                return
            end

            local direction = (doorPart.Position - hrp.Position)
            local distance = direction.Magnitude

            if distance <= stopDistance then
                conn:Disconnect()
                return
            end

            direction = direction.Unit
            hrp.CFrame = hrp.CFrame + direction * speed * dt
        end)

        task.wait(5)
        print("[ui] enterHouseViaDoor: arrived at door")
        return true
    end

    local function useFurniture(needType, pet)
        pet = pet or getPet()
        if not pet then
            return false
        end

        local id, target, partName
        local findFunc = nil

        if needType == "food" then
            findFunc = Care.FindFood
            partName = "UseBlock"
        elseif needType == "drink" then
            findFunc = Care.FindDrink
            partName = "UseBlock"
        elseif needType == "shower" then
            findFunc = Care.FindShower
            partName = "UseBlock"
        elseif needType == "toilet" then
            findFunc = Care.FindToilet
            partName = "Seat1"
        elseif needType == "bed" then
            findFunc = Sleep.FindBed
            partName = "Seat1"
        else
            return false
        end

        -- Try to find furniture locally
        id, target = findFunc()

        -- Helper: get ancestor text for target to verify it's the correct furniture
        local function getAncestorTextLocal(instance)
            local parts = {}
            local current = instance
            while current do
                table.insert(parts, current.Name:lower())
                current = current.Parent
            end
            return table.concat(parts, " ")
        end

        local NEED_KEYWORDS = {
            food = {"food", "petfood", "bowl", "feeder", "kitchen"},
            drink = {"water", "bowl", "fountain", "tap", "waterbowl"},
            shower = {"shower", "bath", "bathtub", "petbathtub"},
            toilet = {"toilet", "restroom", "wc"},
            bed = {"bed", "sleep", "mattress"},
        }

        -- If a target was found, ensure it matches the need more specifically
        if id and target then
            local okMatch = false
            local keywords = NEED_KEYWORDS[needType]
            if keywords then
                local text = getAncestorTextLocal(target)
                for _,kw in ipairs(keywords) do
                    if text:find(kw, 1, true) then
                        okMatch = true
                        break
                    end
                end
            else
                okMatch = true
            end
            if not okMatch then
                    print("[ui] useFurniture: found target does not match needType, ignoring:", needType, id, safeName(target))
                id, target = nil, nil
            end
        end

        -- If the found target is part of HouseInteriors, prefer entering the house first
        if target and workspace:FindFirstChild("HouseInteriors") and target:IsDescendantOf(workspace.HouseInteriors) then
            print("[ui] useFurniture: target inside HouseInteriors — entering house for", needType)
            setStatus("TPing to house for " .. needType)
            if not enterHouseViaDoor() then
                print("[ui] enterHouseViaDoor failed")
                return false
            end
            id, target = findFunc()
            print("[ui] re-scan after entering house — found:", id, safeName(target))
        end

        -- If not found, attempt entering house and rescanning a few times
        if not id or not target then
            local found = false
            for i = 1, 3 do
                setStatus("TPing to house for " .. needType)
                    print("[ui] useFurniture: attempt", i, "to enter house and rescan for", needType)
                if not enterHouseViaDoor() then
                    print("[ui] useFurniture: enterHouseViaDoor failed on attempt", i)
                else
                    id, target = findFunc()
                    -- verify match again after re-scan
                    if id and target then
                        local text = getAncestorTextLocal(target)
                        local keywords = NEED_KEYWORDS[needType]
                        local okMatch = false
                        if keywords then
                            for _,kw in ipairs(keywords) do
                                if text:find(kw, 1, true) then okMatch = true break end
                            end
                        else
                            okMatch = true
                        end
                        if not okMatch then
                            print("[ui] useFurniture: rescan target doesn't match needType, ignoring:", id, safeName(target))
                            id, target = nil, nil
                        end
                    end
                    print("[ui] useFurniture: rescan result:", id, safeName(target))
                    if id and target then
                        found = true
                        break
                    end
                end
                task.wait(1)
            end
            if not found then
                return false
            end
        end

        if not id or not target then
            return false
        end

        local cf = resolveCFrame(target, partName)
        if not cf then
            return false
        end

        return callRemote(ActivateFurniture, id, partName, {cframe = cf}, pet)
    end

    local ToyIdLabel = nil

    local function getToyId()
        if Toys.getToyId then
            return Toys.getToyId(player) or ""
        end
        return ""
    end

    local function refreshToyLabel()
        if not ToyIdLabel then
            return
        end
        local name = (Toys.getToyDisplayName and Toys.getToyDisplayName()) or "squeaky_bone_default"
        if Toys.hasEquipToy and Toys.hasEquipToy() then
            setLabel(ToyIdLabel, "Toy: " .. name .. "  ·  equip_manager", COLOR_ACTIVE)
        else
            setLabel(ToyIdLabel, "Toy: " .. name .. "  ·  open toys menu", COLOR_WARN)
        end
    end

    local function stillPlay(pet)
        if PetState.needsPlayToy then
            local needs = PetState.needsPlayToy(pet)
            return needs == true
        end
        return PetState.isPlay(pet) or PetState.isPetMe(pet)
    end

    local function stillWalk(pet)
        return PetState.isWalk(pet)
    end

    local function runAction(fn)
        if actionBusy then
            return
        end
        actionBusy = true
        task.spawn(function()
            pcall(fn)
            actionBusy = false
        end)
    end

    local Window = Rayfield:CreateWindow({
        Name = "Pet Controller",
        Icon = 0,
        LoadingTitle = "Pet Controller",
        LoadingSubtitle = "v10",
        Theme = "Default",
        ToggleUIKeybind = Enum.KeyCode.F2,
        ConfigurationSaving = {Enabled = true, FolderName = "PetController", FileName = "config"},
    })

    local ControlsTab = Window:CreateTab("Controls", 0)
    local NeedsTab = Window:CreateTab("Pet Needs", 0)
    local ReqTab = Window:CreateTab("Requirements", 0)
    local TpTab = Window:CreateTab("TP", 0)

    ControlsTab:CreateSection("Status")
    local StatusLabel = ControlsTab:CreateLabel("Status: Ready")

    local function setStatus(t)
        setLabel(StatusLabel, "Status: " .. t, COLOR_DIM)
    end

    local function safeName(o)
        if not o then return "nil" end
        if type(o) ~= "userdata" then return tostring(o) end
        if pcall(function() return o:GetFullName() end) then
            return o:GetFullName()
        end
        if pcall(function() return tostring(o.Name) end) then
            return tostring(o.Name)
        end
        return tostring(o)
    end

    NeedsTab:CreateSection("Pet Status")
    local PetIdLabel = NeedsTab:CreateLabel("Selected: —")
    local AutofarmLabel = NeedsTab:CreateLabel("Queue: —")
    local ailLabels = {}
    for _, n in ipairs(track) do
        ailLabels[n] = NeedsTab:CreateLabel(formatNeed(n, false))
    end
    local RawLabel = NeedsTab:CreateLabel("Signals: waiting")

    ReqTab:CreateSection("Autofarm Setup")
    local ReqSummaryLabel = ReqTab:CreateLabel("Status: not scanned")
    local reqLabels = {}
    for _, item in ipairs(Requirements.ITEMS or {}) do
        reqLabels[item.key] = ReqTab:CreateLabel(Requirements.formatRow(item.label, false))
    end

    local function refreshRequirements()
        local ok, err = pcall(function()
            Requirements.scan(Care, Sleep, Toys, player)
        end)
        if not ok then
            warn("[ui] refreshRequirements:", err)
            setLabel(ReqSummaryLabel, "Status: scan error", COLOR_WARN)
            return
        end
        local summary, summaryColor = Requirements.getSummaryText()
        setLabel(ReqSummaryLabel, summary, summaryColor)
        local scan = (Requirements.getLastScan and Requirements.getLastScan()) or lastReqScan
        for _, item in ipairs(Requirements.ITEMS or REQ_ITEMS) do
            local row = scan.results and scan.results[item.key]
            local ready = row and row.found
            setLabel(
                reqLabels[item.key],
                Requirements.formatRow(item.label, ready),
                ready and COLOR_ACTIVE or COLOR_INACTIVE
            )
        end
    end

    ReqTab:CreateButton({
        Name = "Scan House",
        Callback = function()
            pcall(refreshRequirements)
            setStatus("Requirements scanned")
        end,
    })

    TpTab:CreateSection("Teleport Tests")
    TpTab:CreateButton({
        Name = "TP Beach",
        Callback = function()
            task.spawn(function()
                teleportToNamedTargetAsync("beach")
            end)
        end,
    })
    TpTab:CreateButton({
        Name = "TP School",
        Callback = function()
            task.spawn(function()
                teleportToNamedTargetAsync("school")
            end)
        end,
    })
    TpTab:CreateButton({
        Name = "TP Camping",
        Callback = function()
            task.spawn(function()
                teleportToNamedTargetAsync("camping")
            end)
        end,
    })
    TpTab:CreateButton({
        Name = "TP Playground",
        Callback = function()
            task.spawn(function()
                teleportToNamedTargetAsync("playground")
            end)
        end,
    })
    TpTab:CreateButton({
        Name = "TP Salon",
        Callback = function()
            task.spawn(function()
                teleportToNamedTargetAsync("salon")
            end)
        end,
    })

    local function refreshAilments()
        local pet = getPet()
        if not pet then
            setLabel(PetIdLabel, "Selected: none", COLOR_DIM)
            for _, n in ipairs(track) do
                setLabel(ailLabels[n], formatNeed(n, false), COLOR_INACTIVE)
            end
            setLabel(RawLabel, "Signals: —", COLOR_DIM)
            setLabel(AutofarmLabel, "Queue: —", COLOR_DIM)
            return
        end
        setLabel(
            PetIdLabel,
            "Selected: " .. pet.Name .. "  |  " .. tostring(PetState.findStateId(pet) or "?"),
            COLOR_HEADER
        )
        local list = {}
        for _, n in ipairs(track) do
            local on = PetState.hasNeed(pet, n)
            setLabel(ailLabels[n], formatNeed(n, on), on and COLOR_ACTIVE or COLOR_INACTIVE)
            if on then
                table.insert(list, AILMENT_DISPLAY[n] or n)
            end
        end
        local act = PetState.getActive(pet)
        if act then
            local k = {}
            for key in pairs(act) do
                table.insert(k, key)
            end
            table.sort(k)
            setLabel(RawLabel, "Signals: " .. table.concat(k, ", "), COLOR_DIM)
        else
            setLabel(RawLabel, "Signals: awaiting ailments_manager", COLOR_DIM)
        end
        setLabel(
            AutofarmLabel,
            "Queue: " .. (#list > 0 and table.concat(list, " → ") or "all clear"),
            #list > 0 and COLOR_WARN or COLOR_HEADER
        )
    end

    PetState.subscribe(refreshAilments)

    if DataChanged and DataChanged:IsA("RemoteEvent") then
        DataChanged.OnClientEvent:Connect(function(_, dtype, data)
            if dtype == "ailments_manager" then
                PetState.parseAilmentsManager(data)
            elseif dtype == "equip_manager" then
                if Toys.parseEquipManager then
                    Toys.parseEquipManager(data)
                end
                refreshToyLabel()
            end
        end)
    end

    local function resolveToyOrWarn()
        local uid = getToyId()
        if uid == "" then
            setStatus("No squeaky_bone_default in equip_manager — open toys")
            return nil
        end
        return uid
    end

    local function doPlay(pet)
        local uid = resolveToyOrWarn()
        if not uid then
            return
        end
        if not stillPlay(pet) then
            setStatus("No play need detected")
            return
        end
        setStatus("Playing squeaky_bone_default")
        Toys.playUntilDone(Remotes, uid, function()
            return stillPlay(pet)
        end)
        setStatus("Play finished")
    end

    -- manual test: one throw; autofarm uses throwThreeTimes
    local function doThrow(pet, forTest)
        local uid = resolveToyOrWarn()
        if not uid then
            return
        end
        if not forTest and not stillPlay(pet) then
            setStatus("No play need detected")
            return
        end
        if forTest then
            setStatus("Throw test (equip → throw → unequip)")
            local ok, err = Toys.throwOnce(Remotes, uid)
            setStatus(ok and "Throw test done" or ("Throw failed: " .. tostring(err)))
            return
        end
        setStatus("Throwing (3x, 5s apart)")
        Toys.throwThreeTimes(Remotes, uid, function()
            return stillPlay(pet)
        end)
        setStatus("Throw finished")
    end

    local function doWalk(pet)
        setStatus("Walking pet")
        Toys.walkWithPet(player, HoldBaby, pet, function()
            return stillWalk(pet)
        end)
        setStatus("Walk done")
    end

    local function petHasActiveKey(pet, ...)
        local active = PetState.getActive(pet)
        if not active then
            return false
        end
        for i = 1, select("#", ...) do
            local key = tostring(select(i, ...)):lower()
            if active[key] then
                return true
            end
        end
        return false
    end

    local function resolveTeleportPart(target)
        if not target then
            return nil
        end
        if target:IsA("BasePart") then
            return target
        end
        if target:IsA("Model") then
            if target.PrimaryPart then
                return target.PrimaryPart
            end
            return target:FindFirstChildWhichIsA("BasePart", true)
        end
        return target:FindFirstChildWhichIsA("BasePart", true)
    end

    local function findDescendantByNames(root, names)
        if not root then
            return nil
        end
        for _, name in ipairs(names) do
            local found = root:FindFirstChild(name, true)
            if found then
                return found
            end
        end
        return nil
    end

    local function teleportToSafePart(target)
        local part = resolveTeleportPart(target)
        if not part then
            return false
        end

        local platform = Instance.new("Part")
        platform.Name = "PetControllerSafeBaseplate"
        platform.Anchored = true
        platform.CanCollide = true
        platform.Transparency = 1
        platform.Size = Vector3.new(8, 1, 8)
        platform.CFrame = part.CFrame * CFrame.new(0, -3, 0)
        platform.Parent = workspace

        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = platform.CFrame * CFrame.new(0, 3, 0)
        end

        spawn(function()
            wait(5)
            if platform and platform.Parent then
                platform:Destroy()
            end
        end)

        return true
    end

    local function findCustomTeleportTarget(pet)
        if PetState.isSchool(pet) or petHasActiveKey(pet, "school") then
            -- prefer the WorkingParts TouchToEnter if available (two possible Interiors layouts)
            local t1 = workspace:FindFirstChild("Interiors")
                and workspace.Interiors:FindFirstChild("School")
                and workspace.Interiors.School:FindFirstChild("Doors")
                and workspace.Interiors.School.Doors:FindFirstChild("MainDoor")
                and workspace.Interiors.School.Doors.MainDoor:FindFirstChild("WorkingParts")
                and workspace.Interiors.School.Doors.MainDoor.WorkingParts:FindFirstChild("TouchToEnter")
            if t1 then return t1 end

            local t2 = workspace:FindFirstChild("Interiors")
                and workspace.Interiors:FindFirstChild("MainMap!Default")
                and workspace.Interiors["MainMap!Default"].Doors
                and workspace.Interiors["MainMap!Default"].Doors:FindFirstChild("School/MainDoor")
                and workspace.Interiors["MainMap!Default"].Doors["School/MainDoor"]:FindFirstChild("WorkingParts")
                and workspace.Interiors["MainMap!Default"].Doors["School/MainDoor"].WorkingParts:FindFirstChild("TouchToEnter")
            if t2 then return t2 end

            -- fallback to the MainDoor model if no touch part exists
            return workspace:FindFirstChild("Interiors")
                and workspace.Interiors:FindFirstChild("School")
                and workspace.Interiors.School:FindFirstChild("Doors")
                and workspace.Interiors.School.Doors:FindFirstChild("MainDoor")
        end

        if petHasActiveKey(pet, "salon") then
            return workspace:FindFirstChild("Interiors")
                and workspace.Interiors:FindFirstChild("MainMap!Default")
                and workspace.Interiors["MainMap!Default"].Doors
                and workspace.Interiors["MainMap!Default"].Doors:FindFirstChild("Salon/MainDoor")
                and workspace.Interiors["MainMap!Default"].Doors["Salon/MainDoor"]:FindFirstChild("WorkingParts")
                and workspace.Interiors["MainMap!Default"].Doors["Salon/MainDoor"].WorkingParts:FindFirstChild("TouchToEnter")
        end

        if petHasActiveKey(pet, "beach", "beach_party") then
            local furniture = workspace:FindFirstChild("HouseInteriors")
                and workspace.HouseInteriors:FindFirstChild("furniture")
            local beachNode = furniture and furniture:FindFirstChild("nil/nil/MainMap!Default/false/f-28")
            return beachNode and beachNode:FindFirstChild("Beach2024Log") or beachNode
        end

        if petHasActiveKey(pet, "camp", "camping", "sleeping_bag") then
            local furniture = workspace:FindFirstChild("HouseInteriors")
                and workspace.HouseInteriors:FindFirstChild("furniture")
            local campNode = furniture and furniture:FindFirstChild("nil/nil/MainMap!Default/false/f-5")
            return campNode and campNode:FindFirstChild("SleepingBag") or campNode
        end

        if petHasActiveKey(pet, "playground", "park", "roundabout", "bored") then
            return workspace:FindFirstChild("StaticMap")
                and workspace.StaticMap:FindFirstChild("Park")
                and workspace.StaticMap.Park:FindFirstChild("Roundabout")
                and workspace.StaticMap.Park.Roundabout:FindFirstChild("SeatsSpinModel")
                and workspace.StaticMap.Park.Roundabout.SeatsSpinModel:FindFirstChild("Collisions")
                and workspace.StaticMap.Park.Roundabout.SeatsSpinModel.Collisions:FindFirstChild("Collider")
        end

        return nil
    end

    local function getSpecialNeedName(pet)
        if PetState.isSchool(pet) or petHasActiveKey(pet, "school") then
            return "school"
        end
        if petHasActiveKey(pet, "salon") then
            return "salon"
        end
        if petHasActiveKey(pet, "beach", "beach_party") then
            return "beach"
        end
        if petHasActiveKey(pet, "camp", "camping", "sleeping_bag") then
            return "camping"
        end
        if petHasActiveKey(pet, "playground", "park", "roundabout", "bored") then
            return "playground"
        end
        return "special area"
    end

    local function getTeleportTarget(name)
        if name == "beach" then
            local furniture = workspace:FindFirstChild("HouseInteriors")
                and workspace.HouseInteriors:FindFirstChild("furniture")
            local beachNode = furniture and furniture:FindFirstChild("nil/nil/MainMap!Default/false/f-28")
            if not beachNode then
                return nil
            end
            return beachNode:FindFirstChild("Beach2024Log", true) or beachNode
        elseif name == "school" then
            -- prefer TouchToEnter working part when available
            local t1 = workspace:FindFirstChild("Interiors")
                and workspace.Interiors:FindFirstChild("School")
                and workspace.Interiors.School:FindFirstChild("Doors")
                and workspace.Interiors.School.Doors:FindFirstChild("MainDoor")
                and workspace.Interiors.School.Doors.MainDoor:FindFirstChild("WorkingParts")
                and workspace.Interiors.School.Doors.MainDoor.WorkingParts:FindFirstChild("TouchToEnter")
            if t1 then return t1 end

            local t2 = workspace:FindFirstChild("Interiors")
                and workspace.Interiors:FindFirstChild("MainMap!Default")
                and workspace.Interiors["MainMap!Default"].Doors
                and workspace.Interiors["MainMap!Default"].Doors:FindFirstChild("School/MainDoor")
                and workspace.Interiors["MainMap!Default"].Doors["School/MainDoor"]:FindFirstChild("WorkingParts")
                and workspace.Interiors["MainMap!Default"].Doors["School/MainDoor"].WorkingParts:FindFirstChild("TouchToEnter")
            if t2 then return t2 end

            return workspace:FindFirstChild("Interiors")
                and workspace.Interiors:FindFirstChild("School")
                and workspace.Interiors.School:FindFirstChild("Doors")
                and workspace.Interiors.School.Doors:FindFirstChild("MainDoor")
        elseif name == "camping" then
            local furniture = workspace:FindFirstChild("HouseInteriors")
                and workspace.HouseInteriors:FindFirstChild("furniture")
            local campNode = furniture and furniture:FindFirstChild("nil/nil/MainMap!Default/false/f-5")
            if not campNode then
                return nil
            end
            return campNode:FindFirstChild("SleepingBag", true) or campNode
        elseif name == "salon" then
            return workspace:FindFirstChild("Interiors")
                and workspace.Interiors:FindFirstChild("MainMap!Default")
                and workspace.Interiors["MainMap!Default"].Doors
                and workspace.Interiors["MainMap!Default"].Doors:FindFirstChild("Salon/MainDoor")
                and workspace.Interiors["MainMap!Default"].Doors["Salon/MainDoor"]:FindFirstChild("WorkingParts")
                and workspace.Interiors["MainMap!Default"].Doors["Salon/MainDoor"].WorkingParts:FindFirstChild("TouchToEnter")
        elseif name == "playground" then
            return workspace:FindFirstChild("StaticMap")
                and workspace.StaticMap:FindFirstChild("Park")
                and workspace.StaticMap.Park:FindFirstChild("Roundabout")
                and workspace.StaticMap.Park.Roundabout:FindFirstChild("SeatsSpinModel")
                and workspace.StaticMap.Park.Roundabout.SeatsSpinModel:FindFirstChild("Collisions")
                and workspace.StaticMap.Park.Roundabout.SeatsSpinModel.Collisions:FindFirstChild("Collider")
        end
        return nil
    end

    local function exitHouseToMainArea()
        -- Unsubscribe from house to load special areas
        if UnsubscribeFromHouse then
            local ok, err = callRemote(UnsubscribeFromHouse, true)
            if not ok then
                warn("[ui] UnsubscribeFromHouse failed:", err)
            end
        end
        task.wait(2)

        local char = player.Character
        if not char then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        -- TP to main area (beach/camp loading point)
        local targetCF = CFrame.new(2978.0874, 6534.81934, 12039.1875, 0.999999702, 0, 0.000776898232, 0, 1, 0, -0.000776898232, 0, 0.999999702)
        char:PivotTo(targetCF)
        
        -- Wait for beach/camp furniture to load
        task.wait(6)
        return true
    end

    local function teleportForSpecialNeed(pet)
        setStatus("TPing to " .. getSpecialNeedName(pet))

        -- Exit house to load special areas
        if not exitHouseToMainArea() then
            setStatus("Failed to exit house")
            return false
        end

        -- Find target AFTER exiting and waiting
        local target = findCustomTeleportTarget(pet)
        if not target then
            setStatus("Special area target not found")
            return false
        end

        -- If the target is a door touch part (TouchToEnter), fly to it instead of safe-plate teleport
        local tpPart = resolveTeleportPart(target)
        if tpPart and tpPart.Name == "TouchToEnter" then
            local RunService = game:GetService("RunService")
            local attempts = 3
            for attempt = 1, attempts do
                print("[ui] teleportForSpecialNeed: flying to TouchToEnter attempt", attempt)
                local char = player.Character or player.CharacterAdded:Wait()
                local hrp = char:WaitForChild("HumanoidRootPart")
                local speed = 120
                local stopDistance = 2
                local conn
                -- start above the door
                char:PivotTo(hrp.CFrame + Vector3.new(0, 10, 0))
                task.wait(0.5)
                conn = RunService.Heartbeat:Connect(function(dt)
                    if not hrp or not hrp.Parent then
                        conn:Disconnect()
                        return
                    end
                    if not tpPart or not tpPart.Parent then
                        conn:Disconnect()
                        return
                    end
                    local direction = (tpPart.Position - hrp.Position)
                    local distance = direction.Magnitude
                    if distance <= stopDistance then
                        conn:Disconnect()
                        return
                    end
                    direction = direction.Unit
                    hrp.CFrame = hrp.CFrame + direction * speed * dt
                end)

                -- Wait up to 15s for the TouchToEnter to disappear (indicates the salon/school opened)
                local start = os.clock()
                local success = false
                while os.clock() - start < 15 do
                    if not tpPart or not tpPart.Parent then
                        success = true
                        break
                    end
                    task.wait(0.5)
                end
                if conn then
                    pcall(function() conn:Disconnect() end)
                end
                if success then
                    print("[ui] teleportForSpecialNeed: TouchToEnter disappeared — success")
                    return true
                else
                    print("[ui] teleportForSpecialNeed: TouchToEnter still present after 15s, retrying")
                    task.wait(1)
                    -- refresh target reference in case the instance changed
                    target = findCustomTeleportTarget(pet)
                    tpPart = resolveTeleportPart(target)
                end
            end
            return false
        end

        -- TP to furniture object
        if teleportToSafePart(target) then
            task.wait(1)
            return true
        end

        setStatus("Teleport failed to special area")
        return false
    end

    local function teleportToNamedTargetAsync(name)
        setStatus("Loading " .. name .. " furniture")

        -- Exit house to load special areas
        print("[ui] teleportToNamedTargetAsync: exiting house to load", name)
        if not exitHouseToMainArea() then
            setStatus("Failed to exit house")
            print("[ui] exitHouseToMainArea failed for", name)
            return
        end

        -- Find target AFTER exiting and waiting
        local target = getTeleportTarget(name)
        print("[ui] getTeleportTarget returned:", target and target:GetFullName() or "nil")
        if not target then
            setStatus("TP target not found: " .. name)
            return
        end

        -- If the target is a door touch part, fly to it and wait for it to disappear (max 15s), retry a few times
        local tpPart = resolveTeleportPart(target)
        if tpPart and tpPart.Name == "TouchToEnter" then
            local RunService = game:GetService("RunService")
            local attempts = 3
            for attempt = 1, attempts do
                print("[ui] teleportToNamedTargetAsync: flying to TouchToEnter for", name, "attempt", attempt)
                setStatus("Flying to " .. name .. " door")
                local char = player.Character or player.CharacterAdded:Wait()
                local hrp = char:WaitForChild("HumanoidRootPart")
                local speed = 120
                local stopDistance = 2
                local conn
                char:PivotTo(hrp.CFrame + Vector3.new(0, 10, 0))
                task.wait(0.5)
                conn = RunService.Heartbeat:Connect(function(dt)
                    if not hrp or not hrp.Parent then
                        conn:Disconnect()
                        return
                    end
                    if not tpPart or not tpPart.Parent then
                        conn:Disconnect()
                        return
                    end
                    local direction = (tpPart.Position - hrp.Position)
                    local distance = direction.Magnitude
                    if distance <= stopDistance then
                        conn:Disconnect()
                        return
                    end
                    direction = direction.Unit
                    hrp.CFrame = hrp.CFrame + direction * speed * dt
                end)

                local start = os.clock()
                local success = false
                while os.clock() - start < 15 do
                    if not tpPart or not tpPart.Parent then
                        success = true
                        break
                    end
                    task.wait(0.5)
                end
                if conn then pcall(function() conn:Disconnect() end) end
                if success then
                    setStatus("Arrived at " .. name .. " door")
                    return
                else
                    print("[ui] teleportToNamedTargetAsync: TouchToEnter still present after 15s, retrying")
                    task.wait(1)
                    target = getTeleportTarget(name)
                    tpPart = resolveTeleportPart(target)
                end
            end
            setStatus("Failed to reach " .. name .. " door")
            return
        end

        -- TP to furniture object
        print("[ui] teleportToNamedTargetAsync: teleportToSafePart for", name)
        if teleportToSafePart(target) then
            task.wait(1)
            setStatus("Teleported to " .. name)
        else
            setStatus("Teleport failed: " .. name)
        end
    end

    local function autofarm()
        if actionBusy then
            return
        end
        local pet = getPet()
        if not pet then
            return
        end
        refreshAilments()

        if PetState.isHungry(pet) then
            setStatus("Feeding")
            local ok = false
            for i=1,3 do
                if useFurniture("food", pet) then ok = true break end
                setStatus("Missing: Food Bowl — retrying ("..i..")")
                task.wait(1)
            end
            if not ok then setStatus("Missing: Food Bowl") end
            return
        end
        if PetState.isThirsty(pet) then
            setStatus("Drinking")
            local ok = false
            for i=1,3 do
                if useFurniture("drink", pet) then ok = true break end
                setStatus("Missing: Water Bowl — retrying ("..i..")")
                task.wait(1)
            end
            if not ok then setStatus("Missing: Water Bowl") end
            return
        end
        if PetState.isToilet(pet) then
            setStatus("Toilet")
            local ok = false
            for i=1,3 do
                if useFurniture("toilet", pet) then ok = true break end
                setStatus("Missing: Toilet — retrying ("..i..")")
                task.wait(1)
            end
            if not ok then setStatus("Missing: Toilet") end
            return
        end
        if PetState.isDirty(pet) then
            setStatus("Shower")
            local ok = false
            for i=1,3 do
                if useFurniture("shower", pet) then ok = true break end
                setStatus("Missing: Shower — retrying ("..i..")")
                task.wait(1)
            end
            if not ok then setStatus("Missing: Shower") end
            return
        end
        if PetState.isSleepy(pet) then
            setStatus("Sleep")
            local ok = false
            for i=1,3 do
                if useFurniture("bed", pet) then ok = true break end
                setStatus("Missing: Pet Bed — retrying ("..i..")")
                task.wait(1)
            end
            if not ok then setStatus("Missing: Pet Bed") end
            return
        end
        if teleportForSpecialNeed(pet) then
            return
        end
        if stillWalk(pet) then
            runAction(function()
                doWalk(pet)
            end)
            return
        end
        if stillPlay(pet) then
            if not Requirements.canHandleNeed("play") then
                setStatus("Missing: squeaky_bone_default")
                return
            end
            runAction(function()
                doThrow(pet)
            end)
            return
        end
        setStatus("Nothing needed")
    end

    ControlsTab:CreateSection("Pet Selection")
    PetDropdown = ControlsTab:CreateDropdown({
        Name = "Select Pet",
        Options = {"No pets available"},
        CurrentOption = {"No pets available"},
        MultipleOptions = false,
        Flag = "PetDropdown",
        Callback = function(o)
            selectedPetName = (o[1] ~= "No pets available") and o[1] or nil
            refreshAilments()
        end,
    })

    ControlsTab:CreateButton({
        Name = "Refresh Pets",
        Callback = function()
            local o = {}
            for _, p in ipairs(Pets.GetPets()) do
                table.insert(o, p.Name)
            end
            if #o > 0 then
                PetDropdown:Refresh(o)
                PetDropdown:Set({o[1]})
                selectedPetName = o[1]
            end
            refreshAilments()
        end,
    })

    NeedsTab:CreateButton({
        Name = "Refresh Ailments",
        Callback = function()
            refreshAilments()
            local p = getPet()
            if p then
                PetState.debugPetNeeds(p, "manual")
            end
        end,
    })

    ControlsTab:CreateSection("Care")
    ControlsTab:CreateButton({
        Name = "Hold",
        Callback = function()
            local p = getPet()
            if p then
                local ok, err = callRemote(HoldBaby, p)
                if not ok then
                    warn("[ui] HoldBaby failed:", err)
                end
            end
        end,
    })
    ControlsTab:CreateButton({
        Name = "Drop",
        Callback = function()
            local p = getPet()
            if p then
                local ok, err = callRemote(EjectBaby, p)
                if not ok then
                    warn("[ui] EjectBaby failed:", err)
                end
            end
        end,
    })
    ControlsTab:CreateButton({
        Name = "Feed",
        Callback = function()
            local p = getPet()
            if not p then
                return
            end
            useFurniture("food", p)
        end,
    })
    ControlsTab:CreateButton({
        Name = "Drink",
        Callback = function()
            local p = getPet()
            if not p then
                return
            end
            useFurniture("drink", p)
        end,
    })
    ControlsTab:CreateButton({
        Name = "Shower",
        Callback = function()
            local p = getPet()
            if not p then
                return
            end
            useFurniture("shower", p)
        end,
    })
    ControlsTab:CreateButton({
        Name = "Toilet",
        Callback = function()
            local p = getPet()
            if not p then
                return
            end
            useFurniture("toilet", p)
        end,
    })
    ControlsTab:CreateButton({
        Name = "Sleep",
        Callback = function()
            local p = getPet()
            if not p then
                return
            end
            useFurniture("bed", p)
        end,
    })

    ControlsTab:CreateSection("Autofarm")
    ControlsTab:CreateToggle({
        Name = "Autofarm",
        CurrentValue = false,
        Flag = "Autofarm",
        Callback = function(on)
            autofarmEnabled = on
            if on then
                refreshRequirements()
                local ok, missing = Requirements.allCareReady()
                if not ok and missing and #missing > 0 then
                    setStatus("Missing: " .. table.concat(missing, ", "))
                end
                if not autofarmLoop then
                    autofarmLoop = task.spawn(function()
                        while autofarmEnabled do
                            pcall(autofarm)
                            task.wait(2)
                        end
                        autofarmLoop = nil
                    end)
                end
                setStatus("Autofarm ON")
            else
                setStatus("Autofarm OFF")
            end
        end,
    })

    local pets = Pets.GetPets()
    if #pets > 0 then
        local o = {}
        for _, p in ipairs(pets) do
            table.insert(o, p.Name)
        end
        PetDropdown:Refresh(o)
        selectedPetName = o[1]
        PetDropdown:Set({o[1]})
    end

    refreshRequirements()
    refreshAilments()
    Rayfield:LoadConfiguration()
    pcall(function()
        Rayfield:Notify({
            Title = "Loaded v10",
            Content = "TP to furniture for care. Check Requirements tab before autofarm.",
            Duration = 5,
        })
    end)
end

return UI
