-- UI wrapper module
-- Loads the organized refactored UI implementation.

local url = "https://raw.githubusercontent.com/Alaaswabet/adoptme/refs/heads/main/script1-main/modules/ui-refactored.lua"
local ok, src = pcall(function()
    return game:HttpGet(url)
end)
if not ok or type(src) ~= "string" or #src < 10 then
    error("Failed to load ui-refactored.lua from GitHub: " .. tostring(src))
end

local fn, err = loadstring(src, "@ui-refactored.lua")
if not fn then
    error("Failed to compile ui-refactored.lua: " .. tostring(err))
end

local ok2, result = pcall(fn)
if not ok2 then
    error("ui-refactored.lua runtime error: " .. tostring(result))
end

return result
