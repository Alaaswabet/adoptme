local Sleep = {}

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

function Sleep.FindBed()
    local beds = {}

    for _,obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "Seat1" then
            local furnitureId = getFurnitureId(obj)
            local text = getAncestorText(obj)
            print("DEBUG: Seat1 candidate", obj:GetFullName(), furnitureId, text)
            if furnitureId then
                if text:find("bed") or text:find("sleep") then
                    if not text:find("toilet") and not text:find("bath") and not text:find("shower") then
                        print("DEBUG: matched sleep bed", obj:GetFullName(), furnitureId)
                        return furnitureId, obj
                    end
                end
                table.insert(beds, {id = furnitureId, obj = obj, text = text})
            end
        end
    end

    if #beds > 0 then
        -- Only accept explicit sleep-related matches; no generic fallback to arbitrary Seat1 objects
        for _, entry in ipairs(beds) do
            if entry.text:find("bed") or entry.text:find("sleep") then
                print("DEBUG: matched sleep bed", entry.obj:GetFullName(), entry.id)
                return entry.id, entry.obj
            end
        end
    end

    print("DEBUG: no bed found")
    return nil, nil
end

return Sleep