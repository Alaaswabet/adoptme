--// Pet Controller UI (modular) — PetStates is the only needs source

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- Dependencies injected by the loader (loaded via loader.lua)
local Detection
local PetStates
local Helpers
local UIWindow
local UIStatus
local AilmentsPanel

local UI = {}

function UI.Init(Pets, Sleep, Care, Remotes, PetState, Toys, Requirements, DetectionModule, PetStatesModule, HelpersModule, UIWindowModule, UIStatusModule, AilmentsPanelModule)
    -- inject dependencies provided by loader
    Detection = DetectionModule
    PetStates = PetStatesModule
    Helpers = HelpersModule
    UIWindow = UIWindowModule
    UIStatus = UIStatusModule
    AilmentsPanel = AilmentsPanelModule

    PetState = PetState or (PetStates and PetStates.Init and PetStates.Init())

    local player = game:GetService("Players").LocalPlayer
    local HoldBaby = Remotes.HoldBaby
    local EjectBaby = Remotes.EjectBaby
    local ActivateFurniture = Remotes.ActivateFurniture
    local UnsubscribeFromHouse = Remotes.UnsubscribeFromHouse
    local DataChanged = Remotes.DataChanged

    local function callRemoteSafe(remote, ...)
        if not remote then
            return false, "remote missing"
        end
        local args = {...}
        if remote:IsA("RemoteFunction") then
            return pcall(function() return remote:InvokeServer(unpack(args)) end)
        elseif remote:IsA("RemoteEvent") then
            return pcall(function() remote:FireServer(unpack(args)) end)
        else
            return false, "unsupported remote type"
        end
    end

    -- Defensive: ensure Detection and PetStates provide expected API
    local PetStateApi
    if Detection and type(Detection.Init) == "function" then
        PetStateApi = Detection.Init(PetState)
    else
        PetStateApi = {
            debugPetNeeds = function() end,
            isHungry = function() return false end,
            isThirsty = function() return false end,
            isToilet = function() return false end,
            isDirty = function() return false end,
            isSleepy = function() return false end,
            isWalk = function() return false end,
            subscribe = function() end,
            parseAilmentsManager = function() end,
            findStateId = function() return nil end,
            resolvePetId = function() return nil end,
            getActive = function() return nil end,
            hasNeed = function() return false end,
        }
    end

    -- Ensure UIWindow is initialized with Rayfield if it exports an Init() function
    if UIWindow and type(UIWindow.Init) == "function" then
        UIWindow = UIWindow.Init(Rayfield)
    end

    -- Defensive: UIStatus may be nil; provide a no-op fallback
    local status
    if UIStatus and type(UIStatus.Init) == "function" then
        status = UIStatus.Init(PetStateApi)
    else
        status = {
            updateStatus = function() end,
            getPetStatusText = function() return "Pet Status: unknown" end,
            refreshSelectedPetStatus = function() end,
            setStatusLabels = function() end,
        }
    end

    local selectedPetName = nil
    local petOptions = {}
    local PetDropdown = nil
    local autofarmEnabled = false
    local autofarmLoop = nil
    local autofarmThrottle = setmetatable({}, {__mode = "k"})

    local function resolveSelectedPet()
        if not selectedPetName then
            return nil
        end
        local pet = Pets.FindPetByName(selectedPetName)
        if pet and pet.Parent and pet:IsDescendantOf(workspace) then
            return pet
        end
        return nil
    end

    local ACTION_REMOTE = {
        food = {
            id = "f-32",
            partName = "UseBlock",
            cf = CFrame.new(-5979.0981445312, 4000.6198730469, -9018.005859375, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        },
        drink = {
            id = "f-7",
            partName = "UseBlock",
            cf = CFrame.new(-5979.0966796875, 4000.6198730469, -9021.0029296875, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        },
        shower = {
            id = "f-16",
            partName = "UseBlock",
            cf = CFrame.new(-5960.5434570312, 4000.7026367188, -9008.4345703125, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        },
        toilet = {
            id = "f-26",
            partName = "Seat1",
            cf = CFrame.new(-5961.6484375, 4003.1552734375, -9012.5, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        },
        bed = {
            id = "f-26",
            partName = "Seat1",
            cf = CFrame.new(-5987.7016601562, 4002.6306152344, -9029.9853515625, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        },
    }

    local function activateHardcodedAction(actionName, pet)
        pet = pet or resolveSelectedPet()
        if not pet or not pet:IsA("Model") then
            return false, "No pet selected"
        end
        local action = ACTION_REMOTE[actionName]
        if not action then
            return false, "Unknown action " .. tostring(actionName)
        end

        local ok, err = callRemoteSafe(ActivateFurniture, player, action.id, action.partName, {cframe = action.cf}, pet)
        if not ok then
            return false, err
        end
        return true
    end

    local function doWalk(pet)
        if not pet or not pet:IsA("Model") then
            return false, "No pet selected"
        end
        if not Toys or type(Toys.walkWithPet) ~= "function" then
            return false, "Walk helper missing"
        end
        if not HoldBaby then
            return false, "HoldBaby remote missing"
        end
        status.updateStatus("Walking pet")
        local ok, err = pcall(function()
            return Toys.walkWithPet(player, HoldBaby, pet, function()
                return PetStateApi.isWalk and PetStateApi.isWalk(pet)
            end)
        end)
        if not ok then
            return false, err
        end
        return true
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

        task.spawn(function()
            task.wait(5)
            if platform and platform.Parent then
                platform:Destroy()
            end
        end)

        return true
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
                and workspace.StaticMap.Park.SeatsSpinModel:FindFirstChild("Collisions")
                and workspace.StaticMap.Park.Roundabout.SeatsSpinModel.Collisions:FindFirstChild("Collider")
        end
        return nil
    end

    local function exitHouseToMainArea()
        if UnsubscribeFromHouse then
            local ok, err = callRemoteSafe(UnsubscribeFromHouse, true)
            if not ok then
                warn("UnsubscribeFromHouse failed:", err)
            end
        end
        task.wait(2)

        local char = player.Character
        if not char then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        local targetCF = CFrame.new(2978.0874, 6534.81934, 12039.1875, 0.999999702, 0, 0.000776898232, 0, 1, 0, -0.000776898232, 0, 0.999999702)
        char:PivotTo(targetCF)
        task.wait(6)
        return true
    end

    local function teleportToNamedTargetAsync(name)
        status.updateStatus("Loading " .. name .. " furniture")
        if not exitHouseToMainArea() then
            status.updateStatus("Failed to exit house")
            return
        end

        local target = getTeleportTarget(name)
        if not target then
            status.updateStatus("TP target not found: " .. name)
            return
        end

        local tpPart = resolveTeleportPart(target)
        if tpPart and tpPart.Name == "TouchToEnter" then
            local RunService = game:GetService("RunService")
            for attempt = 1, 3 do
                status.updateStatus("Flying to " .. name .. " door")
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
                    status.updateStatus("Arrived at " .. name .. " door")
                    return
                end
                task.wait(1)
                target = getTeleportTarget(name)
                tpPart = resolveTeleportPart(target)
            end
            status.updateStatus("Failed to reach " .. name .. " door")
            return
        end

        if teleportToSafePart(target) then
            task.wait(1)
            status.updateStatus("Teleported to " .. name)
        else
            status.updateStatus("Teleport failed: " .. name)
        end
    end

    local function refreshSelectedPetStatus()
        local pet = resolveSelectedPet()
        if status and type(status.refreshSelectedPetStatus) == "function" then
            pcall(function()
                status.refreshSelectedPetStatus(pet)
            end)
        end
        if ailmentsPanel and type(ailmentsPanel.refresh) == "function" then
            pcall(function()
                ailmentsPanel.refresh()
            end)
        end
    end

    local window = Rayfield:CreateWindow({
        Name = "Pet Controller",
        Icon = 0,
        LoadingTitle = "Pet Controller",
        LoadingSubtitle = "Adopt Me pet care",
        Theme = "Ocean",
        ToggleUIKeybind = Enum.KeyCode.F2,
        ConfigurationSaving = {Enabled = true, FolderName = "PetController", FileName = "config"},
    })
    local tab = window:CreateTab("Controls", "gamepad-2")
    local needsTab = window:CreateTab("Pet Needs", "heart-pulse")
    local StatusLabel = tab:CreateLabel("Status: Ready")
    local PetStatusLabel = tab:CreateLabel("Pet Status: unknown")
    status.setStatusLabels(StatusLabel, PetStatusLabel)
    tab:CreateSection("Pet Selection")
    tab:CreateSection("Actions")

    local ailmentsPanel = nil
    if AilmentsPanel and type(AilmentsPanel.Create) == "function" then
        ailmentsPanel = AilmentsPanel.Create(needsTab, PetStateApi, resolveSelectedPet)
    else
        ailmentsPanel = { refresh = function() end }
    end

    -- Requirements tab (minimal): show scan status and allow scanning
    local ReqTab = window:CreateTab("Requirements", 0)
    ReqTab:CreateSection("Autofarm Setup")
    local ReqSummaryLabel = ReqTab:CreateLabel("Status: not scanned")
    local function refreshRequirements()
        if type(Requirements) == "table" and type(Requirements.scan) == "function" then
            pcall(function() Requirements.scan(Care, Sleep, Toys, player) end)
            local summary, _ = Requirements.getSummaryText and Requirements.getSummaryText() or {"Status: scanned"}
            ReqSummaryLabel:Set(summary)
        else
            ReqSummaryLabel:Set("Status: no Requirements module")
        end
    end
    ReqTab:CreateButton({ Name = "Scan House", Callback = function() refreshRequirements() status.updateStatus("Requirements scanned") end })

    local runAutofarmOnce

    runAutofarmOnce = function()
        local pet = resolveSelectedPet()
        if not pet then
            return false, "No pet selected"
        end

        status.updateStatus("Checking pet needs...")
        PetStateApi.debugPetNeeds(pet, "autofarm")

        if PetStateApi.isHungry(pet) then
            status.updateStatus("Pet is hungry...")
            return activateHardcodedAction("food", pet)
        end
        if PetStateApi.isThirsty(pet) then
            status.updateStatus("Pet is thirsty...")
            return activateHardcodedAction("drink", pet)
        end
        if PetStateApi.isToilet(pet) then
            status.updateStatus("Pet needs toilet...")
            return activateHardcodedAction("toilet", pet)
        end
        if PetStateApi.isDirty(pet) then
            status.updateStatus("Pet is dirty...")
            return activateHardcodedAction("shower", pet)
        end
        if PetStateApi.isSleepy(pet) then
            status.updateStatus("Pet is sleepy...")
            return activateHardcodedAction("bed", pet)
        end

        status.updateStatus("Pet doesn't need anything")
        return true
    end

    local function setAutofarmEnabled(enabled)
        autofarmEnabled = enabled
        if autofarmEnabled then
            status.updateStatus("Autofarm enabled")
            if not autofarmLoop then
                autofarmLoop = task.spawn(function()
                    while autofarmEnabled do
                        if resolveSelectedPet() then
                            pcall(runAutofarmOnce)
                        else
                            status.updateStatus("Autofarm: no pet selected")
                        end
                        task.wait(4)
                    end
                    autofarmLoop = nil
                end)
            end
        else
            status.updateStatus("Autofarm disabled")
        end
        refreshSelectedPetStatus()
    end

    local function onAilmentsUpdated()
        local pet = resolveSelectedPet()
        if not pet then
            return
        end
        PetStateApi.debugPetNeeds(pet, "ailments_manager")
        refreshSelectedPetStatus()
        if autofarmEnabled then
            local last = autofarmThrottle[pet]
            if not last or (time() - last) > 2 then
                autofarmThrottle[pet] = time()
                task.spawn(function()
                    pcall(runAutofarmOnce)
                end)
            end
        end
    end

    PetStateApi.subscribe(onAilmentsUpdated)

    if DataChanged and DataChanged:IsA("RemoteEvent") then
        DataChanged.OnClientEvent:Connect(function(_, dataType, data)
            if dataType ~= "ailments_manager" then
                return
            end
            PetStateApi.parseAilmentsManager(data)
        end)
        print("Pet Controller: ailments_manager → PetState (keys + kind)")
    end

    local function refreshPets()
        petOptions = {}
        local pets = Pets.GetPets()
        for _, pet in ipairs(pets) do
            table.insert(petOptions, pet.Name)
        end
        if #petOptions > 0 then
            PetDropdown:Refresh(petOptions)
            if selectedPetName and Helpers.tableContains(petOptions, selectedPetName) then
                PetDropdown:Set({selectedPetName})
            else
                selectedPetName = petOptions[1]
                PetDropdown:Set({selectedPetName})
            end
            status.updateStatus("Found " .. #petOptions .. " pets")
        else
            selectedPetName = nil
            PetDropdown:Refresh({"No pets available"})
            PetDropdown:Set({"No pets available"})
            status.updateStatus("No pets found")
        end
        refreshSelectedPetStatus()
    end

    PetDropdown = tab:CreateDropdown({
        Name = "Select Pet",
        Options = {"No pets available"},
        CurrentOption = {"No pets available"},
        MultipleOptions = false,
        Flag = "PetDropdown",
        Callback = function(options)
            local name = options[1]
            if name == "No pets available" then
                selectedPetName = nil
                status.updateStatus("No pet selected")
                refreshSelectedPetStatus()
                return
            end
            selectedPetName = name
            local pet = resolveSelectedPet()
            if pet then
                status.updateStatus("Selected: " .. pet.Name)
                PetStateApi.debugPetNeeds(pet, "select")
            else
                status.updateStatus("Pet not found")
            end
            refreshSelectedPetStatus()
        end,
    })

    tab:CreateButton({Name = "🔍 Debug Pet Needs", Callback = function()
        local pet = resolveSelectedPet()
        if not pet then
            status.updateStatus("No pet selected")
            return
        end
        PetStateApi.debugPetNeeds(pet, "manual")
        refreshSelectedPetStatus()
        status.updateStatus("Printed needs to console (F9)")
    end})

    tab:CreateButton({Name = "🔄 Refresh Pets", Callback = function()
        refreshPets()
    end})

    tab:CreateButton({Name = "❌ Clear Selection", Callback = function()
        selectedPetName = nil
        PetDropdown:Set({"No pets available"})
        status.updateStatus("Selection cleared")
        refreshSelectedPetStatus()
    end})

    tab:CreateButton({Name = "🍼 Hold Pet", Callback = function()
        local pet = resolveSelectedPet()
        if not pet then status.updateStatus("No pet selected") return end
        pcall(function() HoldBaby:FireServer(pet) end)
        status.updateStatus("Holding " .. pet.Name)
    end})

    tab:CreateButton({Name = "⬇️ Drop Pet", Callback = function()
        local pet = resolveSelectedPet()
        if not pet then status.updateStatus("No pet selected") return end
        pcall(function() EjectBaby:FireServer(pet) end)
        status.updateStatus("Dropped " .. pet.Name)
    end})

    tab:CreateButton({Name = "🛏️ Put Pet To Sleep", Callback = function()
        local pet = resolveSelectedPet()
        if not pet then status.updateStatus("No pet selected") return end
        local ok, err = activateHardcodedAction("bed", pet)
        status.updateStatus(ok and (pet.Name .. " is sleeping") or ("Sleep failed: " .. tostring(err)))
    end})

    tab:CreateButton({Name = "🍎 Feed Pet", Callback = function()
        local pet = resolveSelectedPet()
        if not pet then status.updateStatus("No pet selected") return end
        local ok, err = activateHardcodedAction("food", pet)
        status.updateStatus(ok and (pet.Name .. " is eating") or ("Feed failed: " .. tostring(err)))
    end})

    tab:CreateButton({Name = "🥤 Give Pet Drink", Callback = function()
        local pet = resolveSelectedPet()
        if not pet then status.updateStatus("No pet selected") return end
        local ok, err = activateHardcodedAction("drink", pet)
        status.updateStatus(ok and (pet.Name .. " is drinking") or ("Drink failed: " .. tostring(err)))
    end})

    tab:CreateButton({Name = "🚿 Shower Pet", Callback = function()
        local pet = resolveSelectedPet()
        if not pet then status.updateStatus("No pet selected") return end
        local ok, err = activateHardcodedAction("shower", pet)
        status.updateStatus(ok and (pet.Name .. " is showering") or ("Shower failed: " .. tostring(err)))
    end})

    tab:CreateButton({Name = "🚽 Toilet", Callback = function()
        local pet = resolveSelectedPet()
        if not pet then status.updateStatus("No pet selected") return end
        local ok, err = activateHardcodedAction("toilet", pet)
        status.updateStatus(ok and (pet.Name .. " is using toilet") or ("Toilet failed: " .. tostring(err)))
    end})

    tab:CreateToggle({
        Name = "🤖 Autofarm Enabled",
        CurrentValue = false,
        Flag = "AutoFarmToggle",
        Callback = function(value)
            setAutofarmEnabled(value)
        end,
    })

    refreshPets()
    Rayfield:LoadConfiguration()
end

return UI
