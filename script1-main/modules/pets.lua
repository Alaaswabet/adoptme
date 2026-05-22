local Pets = {}

function Pets.GetPets()
    local folder = workspace:FindFirstChild("Pets")
    if not folder then return {} end

    local list = {}

    for _,v in pairs(folder:GetChildren()) do
        if v:IsA("Model") then
            table.insert(list, v)
        end
    end

    return list
end

function Pets.FindPetByName(name)
    local folder = workspace:FindFirstChild("Pets")
    if not folder then
        return nil
    end

    for _, pet in pairs(folder:GetChildren()) do
        if pet:IsA("Model") and pet.Name == name then
            return pet
        end
    end

    return nil
end

return Pets