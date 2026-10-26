--!strict

-- Backpack UI Main Server


---------- Constants ----------

local Constants = {}

Constants.backpack_remoteEvent = script.Parent:WaitForChild("Backpack_RemoteEvent")

table.freeze(Constants)


---------- Local functions ----------

local onEquipTool
local onUnequipTools


----- Tool -----

onEquipTool = function(player: Player, tool: Tool?)
    -- Validate parameter
    if not (tool and tool:IsA("Tool")) then
        return
    end

    -- Get humanoid
    local character = player.Character
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
    if not (character and humanoid) then
        return
    end

    -- Validate tool not equipped
    if tool:IsDescendantOf(character) then
        return
    end

    -- Equip tool
    humanoid:EquipTool(tool)
end

onUnequipTools = function(player: Player)
    -- Get humanoid
    local character = player.Character
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
    if not (character and humanoid) then
        return
    end

    -- Validate a tool equipped
    if not character:FindFirstChildWhichIsA("Tool") then
        return
    end

    -- Unequip tools
    humanoid:UnequipTools()
end

----- Main -----

local function main()
    Constants.backpack_remoteEvent.OnServerEvent:Connect(function(caller: Player, mode: string, ...)
        if mode == "EquipTool" then
            onEquipTool(caller, ...)
        elseif mode == "UnequipTools" then
            onUnequipTools(caller)
        end
    end)
end


---------- Calling function ----------

main()
