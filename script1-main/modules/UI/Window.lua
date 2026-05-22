--// Window Module
--// Handles Rayfield UI window creation

local Window = {}

function Window.Init(Rayfield)
    local function createWindow()
        local UIWindow = Rayfield:CreateWindow({
            Name = "Pet Controller",
            Icon = 0,
            LoadingTitle = "Pet Controller",
            LoadingSubtitle = "Loading your pets...",
            Theme = "Default",
            ToggleUIKeybind = Enum.KeyCode.F2,
            DisableRayfieldPrompts = false,
            DisableBuildWarnings = false,
            ConfigurationSaving = {
                Enabled = true,
                FolderName = "PetController",
                FileName = "config"
            }
        })
        return UIWindow
    end

    local function createTab(window, name, icon)
        return window:CreateTab(name, icon)
    end

    local function createSection(tab, name)
        return tab:CreateSection(name)
    end

    local function createLabel(tab, text)
        return tab:CreateLabel(text)
    end

    local function createButton(tab, name, callback)
        return tab:CreateButton({
            Name = name,
            Callback = callback
        })
    end

    local function createToggle(tab, name, defaultValue, flag, callback)
        return tab:CreateToggle({
            Name = name,
            CurrentValue = defaultValue,
            Flag = flag,
            Callback = callback
        })
    end

    local function createDropdown(tab, name, options, flag, callback)
        return tab:CreateDropdown({
            Name = name,
            Options = options,
            CurrentOption = options[1] or "No options",
            MultipleOptions = false,
            Flag = flag,
            Callback = callback
        })
    end

    return {
        createWindow = createWindow,
        createTab = createTab,
        createSection = createSection,
        createLabel = createLabel,
        createButton = createButton,
        createToggle = createToggle,
        createDropdown = createDropdown,
    }
end

return Window
