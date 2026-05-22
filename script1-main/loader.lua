--[[
  Pet Controller loader — run via:
  loadstring(game:HttpGet("YOUR_RAW_URL/loader.lua"))()

  PUSH ALL files under modules/ to GitHub (including PetStates.lua and ui.lua).
  NO require() — every file must work with loadstring alone.
]]

-- ▼▼▼ YOUR GITHUB RAW MODULES FOLDER ▼▼▼
local BASE = "https://raw.githubusercontent.com/Alaaswabet/adoptme/refs/heads/main/script1-main/modules/"
-- If 404 errors, try: .../script1-main/modules/  (depends on repo folder name)

local function loadModule(paths)
    for _, name in ipairs(paths) do
        local url = BASE .. name .. ".lua"
        print("loading", name)
        local okGet, src = pcall(function()
            return game:HttpGet(url)
        end)
        if not okGet or type(src) ~= "string" or #src < 10 then
            warn("  skip (download failed):", url, src)
        else
            -- If we're loading the UI module, rewrite require(script.Parent:...) calls
            -- to use the already-loaded modules in `_INJECTED`, avoiding runtime errors
            if name:match("ui%-refactored") or name:match("^ui$") or name:match("UI/ui") then
                local replacements = {
                    ['require(script.Parent:FindFirstChild("Core"):FindFirstChild("Detection"))'] = "_INJECTED.Detection",
                    ['require(script.Parent:FindFirstChild("Core"):FindFirstChild("PetStates"))'] = "_INJECTED.PetStates",
                    ['require(script.Parent:FindFirstChild("Utils"):FindFirstChild("Helpers"))'] = "_INJECTED.Helpers",
                    ['require(script.Parent:FindFirstChild("Utils"):FindFirstChild("Furniture"))'] = "_INJECTED.Furniture",
                    ['require(script.Parent:FindFirstChild("UI"):FindFirstChild("Window"))'] = "_INJECTED.UIWindow",
                    ['require(script.Parent:FindFirstChild("UI"):FindFirstChild("Status"))'] = "_INJECTED.UIStatus",
                    ['require(script.Parent:FindFirstChild("UI"):FindFirstChild("AilmentsPanel"))'] = "_INJECTED.AilmentsPanel",
                }
                for k, v in pairs(replacements) do
                    src = src:gsub(k, v)
                end
                -- Also prepend convenient locals for older variants
                local injected_header = "local Detection = _INJECTED and _INJECTED.Detection or nil\n"
                injected_header = injected_header .. "local PetStates = _INJECTED and _INJECTED.PetStates or nil\n"
                injected_header = injected_header .. "local Helpers = _INJECTED and _INJECTED.Helpers or nil\n"
                injected_header = injected_header .. "local UIWindow = _INJECTED and _INJECTED.UIWindow or nil\n"
                injected_header = injected_header .. "local UIStatus = _INJECTED and _INJECTED.UIStatus or nil\n"
                injected_header = injected_header .. "local AilmentsPanel = _INJECTED and _INJECTED.AilmentsPanel or nil\n"
                injected_header = injected_header .. "local Furniture = _INJECTED and _INJECTED.Furniture or nil\n"
                src = injected_header .. src
            end

            local fn, errCompile = loadstring(src, "@" .. name)
            if not fn then
                warn("  skip (compile):", name, errCompile)
            else
                local okRun, result = pcall(fn)
                if okRun then
                    return result
                else
                    warn("  skip (runtime):", name, result)
                end
            end
        end
    end
    return nil
end

print("INIT UI — loader v10")

local Remotes = loadModule({"remote"})
local Pets = loadModule({"pets"})
local Sleep = loadModule({"sleep"})
local Care = loadModule({"care"})
local Toys = loadModule({"toys"})
local Requirements = loadModule({"requirements"})

-- Try flat path first, then Core/ subfolder
local PetStatesModule = loadModule({"PetStates", "Core/PetStates"})

-- load auxiliary UI and utils modules to inject into ui-refactored
local Detection = loadModule({"Core/Detection", "Core/Detection"})
local Helpers = loadModule({"Utils/Helpers", "Utils/Helpers"})
local Furniture = loadModule({"Utils/Furniture", "Utils/Furniture"})
local UIWindow = loadModule({"UI/Window", "UI/Window"})
local UIStatus = loadModule({"UI/Status", "UI/Status"})
local AilmentsPanel = loadModule({"UI/AilmentsPanel", "UI/AilmentsPanel"})

-- expose injected modules for UI code that assumes `require(script.Parent:...)`
_INJECTED = {
    Detection = Detection,
    PetStates = PetStatesModule,
    Helpers = Helpers,
    Furniture = Furniture,
    UIWindow = UIWindow,
    UIStatus = UIStatus,
    AilmentsPanel = AilmentsPanel,
}

local UI = loadModule({"ui-refactored", "ui", "UI/ui"})
if not UI then
    warn("FAILED to load ui-refactored.lua / ui.lua — push modules/ui-refactored.lua or modules/ui.lua to GitHub (no require() in file!)")
end

local PetState = nil
if PetStatesModule and PetStatesModule.Init then
    local ok, st = pcall(PetStatesModule.Init)
    if ok then
        PetState = st
        print("PetStates OK")
    else
        warn("PetStates.Init error:", st)
    end
else
    warn("PetStates missing — push modules/PetStates.lua to GitHub")
end

if type(UI) == "table" and type(UI.Init) == "function" then
    local ok, err = pcall(function()
        UI.Init(Pets, Sleep, Care, Remotes, PetState, Toys, Requirements, Detection, PetStatesModule, Helpers, UIWindow, UIStatus, AilmentsPanel)
    end)
    if ok then
        print("UI.Init OK")
    else
        warn("UI.Init crashed:", err)
    end
else
    warn("UI missing Init")
    warn("type(UI)=", type(UI))
    if type(UI) == "table" then
        for k in pairs(UI) do
            print("  UI key:", k)
        end
    end
end
