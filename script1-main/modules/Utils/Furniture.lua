--// Furniture Module
--// Handles furniture activation and pet actions

local Furniture = {}

function Furniture.Init(player, ActivateFurniture, Helpers)
    local function teleportToTarget(cframe)
        if not cframe then
            return
        end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = cframe * CFrame.new(0, 0, -5)
        end
    end

    local function performFurnitureActivation(furnitureId, target, partName, actionLabel, pet)
        if not furnitureId or not target then
            return false, "No furniture found"
        end
        if not pet or not pet:IsA("Model") then
            return false, "No pet selected"
        end

        local targetCFrame = Helpers.resolveCFrame(target, partName)
        if not targetCFrame then
            return false, "Invalid furniture position"
        end

        print("DEBUG ACTION", actionLabel, "furnitureId=", furnitureId, "pet=", pet.Name)
        teleportToTarget(targetCFrame)

        local ok, err = pcall(function()
            ActivateFurniture:InvokeServer(
                player,
                furnitureId,
                partName,
                {cframe = targetCFrame},
                pet
            )
        end)

        if not ok then
            return false, err
        end

        return true
    end

    return {
        teleportToTarget = teleportToTarget,
        performFurnitureActivation = performFurnitureActivation,
    }
end

return Furniture
