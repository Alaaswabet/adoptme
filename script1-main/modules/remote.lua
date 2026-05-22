local ReplicatedStorage = game:GetService("ReplicatedStorage")
local API = ReplicatedStorage:WaitForChild("API")

local Remotes = {}

Remotes.HoldBaby = API:WaitForChild("AdoptAPI/HoldBaby")
Remotes.EjectBaby = API:WaitForChild("AdoptAPI/EjectBaby")
Remotes.ActivateFurniture = API:WaitForChild("HousingAPI/ActivateFurniture")
Remotes.UnsubscribeFromHouse = API:WaitForChild("HousingAPI/UnsubscribeFromHouse")
Remotes.ReplicatePerformanceModifiers = API:WaitForChild("PetAPI/ReplicatePerformanceModifiers")
Remotes.ReplicateActivePerformances = API:FindFirstChild("PetAPI/ReplicateActivePerformances")
Remotes.ReplicateActiveReactions = API:FindFirstChild("PetAPI/ReplicateActiveReactions")
Remotes.DataChanged = API:WaitForChild("DataAPI/DataChanged")

return Remotes