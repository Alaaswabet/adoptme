local Care = {}

local function getFurnitureId(instance)
    local current = instance
    while current do
        for _,v in pairs(current:GetAttributes()) do
            local str = tostring(v)
            if str:match("^f%-") then
                return str
            end
        end
        current = current.Parent
    end
    return nil
end

local function getAncestorText(instance)
    local parts = {}
    local current = instance
    while current do
        table.insert(parts, current.Name:lower())
        current = current.Parent
    end
    return table.concat(parts, " ")
end

local function resolveTarget(obj)
    if not obj then
        return nil
    end
    if obj:IsA("BasePart") then
        return obj
    end
    if obj:IsA("Model") then
        local direct = obj:FindFirstChild("UseBlock")
        if direct and direct:IsA("BasePart") then
            return direct
        end
        return obj:FindFirstChildOfClass("BasePart")
    end
    return obj:FindFirstChildOfClass("BasePart")
end

local function findUseBlockByKeyword(keywords)
    for _,obj in pairs(workspace:GetDescendants()) do
        local furnitureId = getFurnitureId(obj)
        if furnitureId then
            local text = getAncestorText(obj)
            print("DEBUG: furniture candidate", obj:GetFullName(), furnitureId, text)
            for _,keyword in ipairs(keywords) do
                if text:find(keyword, 1, true) then
                    local target = resolveTarget(obj)
                    if target then
                        print("DEBUG: matched keyword", keyword, "for", obj:GetFullName())
                        return furnitureId, target
                    end
                end
            end
        end
    end
    print("DEBUG: no matching furniture found")
    return nil, nil
end

function Care.FindFood()
    return findUseBlockByKeyword({"food", "PetFoodBowl", "kitchen", "meal", "dish", "snack", "feeder", "hungry"})
end

function Care.FindDrink()
    return findUseBlockByKeyword({"PetWaterBowl", "water", "fountain", "tap", "bottle", "hydration", "thirst"})
end

function Care.FindShower()
    return findUseBlockByKeyword({"shower", "bath", "wash", "shower", "ModernShower", "CheapPetBathtub"})
end

function Care.FindToilet()
    return findUseBlockByKeyword({"toilet", "restroom", "bathroom", "wc"})
end

return Care