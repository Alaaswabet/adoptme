--// Pet Controller UI (modular) — PetStates is the only needs source

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Detection = require(script.Parent:FindFirstChild("Core"):FindFirstChild("Detection"))
local PetStates = require(script.Parent:FindFirstChild("Core"):FindFirstChild("PetStates"))
local Helpers = require(script.Parent:FindFirstChild("Utils"):FindFirstChild("Helpers"))
local Furniture = require(script.Parent:FindFirstChild("Utils"):FindFirstChild("Furniture"))
local UIWindow = require(script.Parent:FindFirstChild("UI"):FindFirstChild("Window"))
local UIStatus = require(script.Parent:FindFirstChild("UI"):FindFirstChild("Status"))
local AilmentsPanel = require(script.Parent:FindFirstChild("UI"):FindFirstChild("AilmentsPanel"))

local UI = {}

function UI.Init(Pets, Sleep, Care, Remotes, PetState)
    PetState = PetState or PetStates.Init()

    local player = game:GetService("Players").LocalPlayer
    local HoldBaby = Remotes.HoldBaby
    local EjectBaby = Remotes.EjectBaby
    local ActivateFurniture = Remotes.ActivateFurniture
    local DataChanged = Remotes.DataChanged

    local PetStateApi = Detection.Init(PetState)
    local furniture = Furniture.Init(player, ActivateFurniture, Helpers)
    local status = UIStatus.Init(PetStateApi)

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

    local function activateForPet(furnitureId, target, partName, label, pet)
        pet = pet or resolveSelectedPet()
        return furniture.performFurnitureActivation(furnitureId, target, partName, label, pet)
    end

    local function refreshSelectedPetStatus()
        status.refreshSelectedPetStatus(resolveSelectedPet())
        ailmentsPanel.refresh()
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
    local StatusLabel = UIWindow.createLabel(tab, "Status: Ready")
    local PetStatusLabel = UIWindow.createLabel(tab, "Pet Status: unknown")
    status.setStatusLabels(StatusLabel, PetStatusLabel)
    UIWindow.createSection(tab, "Pet Selection")
    UIWindow.createSection(tab, "Actions")

    local ailmentsPanel = AilmentsPanel.Create(needsTab, PetStateApi, resolveSelectedPet)

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
            local furnitureId, obj = Care.FindFood()
            return activateForPet(furnitureId, obj, "UseBlock", "food", pet)
        end
        if PetStateApi.isThirsty(pet) then
            status.updateStatus("Pet is thirsty...")
            local furnitureId, obj = Care.FindDrink()
            return activateForPet(furnitureId, obj, "UseBlock", "drink", pet)
        end
        if PetStateApi.isToilet(pet) then
            status.updateStatus("Pet needs toilet...")
            local furnitureId, seat = Care.FindToilet()
            return activateForPet(furnitureId, seat, "Seat1", "toilet", pet)
        end
        if PetStateApi.isDirty(pet) then
            status.updateStatus("Pet is dirty...")
            local furnitureId, obj = Care.FindShower()
            return activateForPet(furnitureId, obj, "UseBlock", "shower", pet)
        end
        if PetStateApi.isSleepy(pet) then
            status.updateStatus("Pet is sleepy...")
            local furnitureId, seat = Sleep.FindBed()
            return activateForPet(furnitureId, seat, "Seat1", "bed", pet)
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
        local furnitureId, seat = Sleep.FindBed()
        if not furnitureId or not seat then status.updateStatus("No bed found") return end
        local ok = activateForPet(furnitureId, seat, "Seat1", "bed", pet)
        status.updateStatus(ok and (pet.Name .. " is sleeping") or "Sleep failed")
    end})

    tab:CreateButton({Name = "🍎 Feed Pet", Callback = function()
        local pet = resolveSelectedPet()
        if not pet then status.updateStatus("No pet selected") return end
        local furnitureId, obj = Care.FindFood()
        if not furnitureId or not obj then status.updateStatus("No food found") return end
        local ok = activateForPet(furnitureId, obj, "UseBlock", "food", pet)
        status.updateStatus(ok and (pet.Name .. " is eating") or "Feed failed")
    end})

    tab:CreateButton({Name = "🥤 Give Pet Drink", Callback = function()
        local pet = resolveSelectedPet()
        if not pet then status.updateStatus("No pet selected") return end
        local furnitureId, obj = Care.FindDrink()
        if not furnitureId or not obj then status.updateStatus("No drink found") return end
        local ok = activateForPet(furnitureId, obj, "UseBlock", "drink", pet)
        status.updateStatus(ok and (pet.Name .. " is drinking") or "Drink failed")
    end})

    tab:CreateButton({Name = "🚿 Shower Pet", Callback = function()
        local pet = resolveSelectedPet()
        if not pet then status.updateStatus("No pet selected") return end
        local furnitureId, obj = Care.FindShower()
        if not furnitureId or not obj then status.updateStatus("No shower found") return end
        local ok = activateForPet(furnitureId, obj, "UseBlock", "shower", pet)
        status.updateStatus(ok and (pet.Name .. " is showering") or "Shower failed")
    end})

    tab:CreateButton({Name = "🚽 Toilet", Callback = function()
        local pet = resolveSelectedPet()
        if not pet then status.updateStatus("No pet selected") return end
        local furnitureId, seat = Care.FindToilet()
        if not furnitureId or not seat then status.updateStatus("No toilet found") return end
        local ok = activateForPet(furnitureId, seat, "Seat1", "toilet", pet)
        status.updateStatus(ok and (pet.Name .. " is using toilet") or "Toilet failed")
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
