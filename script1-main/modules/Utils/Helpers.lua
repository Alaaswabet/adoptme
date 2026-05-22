--// Helpers Module
--// General utility functions

local Helpers = {}

function Helpers.tableContains(tbl, value)
    if type(tbl) ~= "table" then
        return false
    end
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function Helpers.resolveCFrame(target, expectedName)
    if not target then
        return nil
    end

    if target:IsA("BasePart") then
        return target.CFrame
    end

    if target:IsA("Model") and target.PrimaryPart then
        return target.PrimaryPart.CFrame
    end

    local childPart = target:FindFirstChild(expectedName)
    if childPart and childPart:IsA("BasePart") then
        return childPart.CFrame
    end

    local anyPart = target:FindFirstChildOfClass("BasePart")
    if anyPart then
        return anyPart.CFrame
    end

    return nil
end

function Helpers.childStateEnabled(pet, name)
    local targetName = name:lower()
    local child = pet:FindFirstChild(name)

    if not child then
        for _, v in ipairs(pet:GetChildren()) do
            if v.Name:lower() == targetName then
                child = v
                break
            end
        end
    end

    if not child then
        return false
    end

    if child:IsA("BoolValue") then
        return child.Value == true
    end

    if child:IsA("IntValue") or child:IsA("NumberValue") then
        return child.Value ~= 0
    end

    if child:IsA("StringValue") then
        local lowerValue = tostring(child.Value):lower()
        return lowerValue ~= "" and lowerValue == targetName
    end

    if child:IsA("ObjectValue") then
        local lowerValue = tostring(child.Value):lower()
        return lowerValue == targetName
    end

    return true
end

function Helpers.descendantStateEnabled(pet, name)
    local targetName = name:lower()
    for _, descendant in ipairs(pet:GetDescendants()) do
        if descendant.Name:lower() == targetName then
            if descendant:IsA("BoolValue") then
                return descendant.Value == true
            end
            if descendant:IsA("IntValue") or descendant:IsA("NumberValue") then
                return descendant.Value ~= 0
            end
            if descendant:IsA("StringValue") then
                local lowerValue = tostring(descendant.Value):lower()
                return lowerValue ~= "" and lowerValue == targetName
            end
            if descendant:IsA("ObjectValue") then
                local lowerValue = tostring(descendant.Value):lower()
                return lowerValue == targetName
            end
            return true
        end
    end
    return false
end

function Helpers.activePerformanceEnabled(pet, name)
    local active = pet:FindFirstChild("ActivePerformances")
    if not active then
        return false
    end

    local lowerName = name:lower()
    for _, perf in ipairs(active:GetChildren()) do
        local perfName = perf.Name:lower()
        local value
        if perf:IsA("BoolValue") or perf:IsA("IntValue") or perf:IsA("NumberValue") then
            value = perf.Value
        elseif perf:IsA("StringValue") then
            value = perf.Value
        elseif perf:IsA("ObjectValue") then
            value = perf.Value and perf.Value.Name or nil
        end

        if perfName == lowerName or perfName:find(lowerName, 1, true) then
            if value == nil or value == true or tostring(value):lower() == lowerName then
                return true
            end
            if type(value) == "string" and value:lower() ~= "false" and value:lower() ~= "" then
                return true
            end
        end
    end

    return false
end

function Helpers.hasEffect(pet, name)
    local lowerName = name:lower()
    local effects = pet:FindFirstChild("effects") or pet:FindFirstChild("Effects")

    if effects then
        for _, child in ipairs(effects:GetChildren()) do
            local childName = child.Name and child.Name:lower() or ""
            if childName == lowerName then
                return true
            end

            if child:IsA("StringValue") or child:IsA("ObjectValue") or child:IsA("BoolValue") or child:IsA("IntValue") or child:IsA("NumberValue") then
                local valueString = tostring(child.Value):lower()
                if valueString == lowerName then
                    return true
                end
            end
        end
    end

    local attr = pet:GetAttribute("effects") or pet:GetAttribute("Effects")
    if attr then
        if type(attr) == "string" then
            if attr:lower() == lowerName then
                return true
            end
        elseif type(attr) == "table" then
            for _, item in ipairs(attr) do
                if tostring(item):lower() == lowerName then
                    return true
                end
            end
        end
    end

    return false
end

function Helpers.petHasState(pet, name)
    if not pet then
        return false
    end

    local attr = pet:GetAttribute(name)
    if attr == true or attr == 1 or tostring(attr):lower() == "true" then
        return true
    end
    if type(attr) == "string" and attr:lower() == name:lower() then
        return true
    end
    if type(attr) == "table" then
        for _, item in ipairs(attr) do
            if tostring(item):lower() == name:lower() then
                return true
            end
        end
    end

    if Helpers.childStateEnabled(pet, name) then
        return true
    end

    if Helpers.descendantStateEnabled(pet, name) then
        return true
    end

    if Helpers.activePerformanceEnabled(pet, name) then
        return true
    end

    if Helpers.hasEffect(pet, name) then
        return true
    end

    return false
end

function Helpers.petHasAnyState(pet, names)
    for _, name in ipairs(names) do
        if Helpers.petHasState(pet, name) then
            return true
        end
    end
    return false
end

return Helpers
