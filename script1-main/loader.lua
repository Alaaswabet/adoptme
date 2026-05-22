--[[
  Pet Controller loader — run via:
  loadstring(game:HttpGet("YOUR_RAW_URL/loader.lua"))()

  PUSH ALL files under modules/ to GitHub (including PetStates.lua and ui.lua).
  NO require() — every file must work with loadstring alone.
]]

-- ▼▼▼ YOUR GITHUB RAW MODULES FOLDER ▼▼▼
local BASE = "https://raw.githubusercontent.com/Asarja2/script1/main/modules/"
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

local UI = loadModule({"ui", "UI/ui"})
if not UI then
    warn("FAILED to load ui.lua — push modules/ui.lua to GitHub (no require() in file!)")
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
        UI.Init(Pets, Sleep, Care, Remotes, PetState, Toys, Requirements)
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
