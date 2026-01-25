--!strict

-- Backpack UI Main


---------- Services ----------

local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")


---------- Imports ----------

local BackpackUI = require(script.Parent:WaitForChild("BackpackUI"))


---------- Constants ----------

local Constants = {}

Constants.action_name = {
    toggleInventory = "[Backpack UI]: Toggle Inventory",
    hotbar_prefix = "[Backpack UI]: Hotbar",
    hotbar_1 = "[Backpack UI]: Hotbar 1",
    hotbar_2 = "[Backpack UI]: Hotbar 2",
    hotbar_3 = "[Backpack UI]: Hotbar 3",
    hotbar_4 = "[Backpack UI]: Hotbar 4",
    hotbar_5 = "[Backpack UI]: Hotbar 5",
    hotbar_6 = "[Backpack UI]: Hotbar 6",
    hotbar_7 = "[Backpack UI]: Hotbar 7",
    hotbar_8 = "[Backpack UI]: Hotbar 8",
    hotbar_9 = "[Backpack UI]: Hotbar 9",
    hotbar_10 = "[Backpack UI]: Hotbar 10",
}
table.freeze(Constants.action_name)

table.freeze(Constants)


---------- Local functions ----------

local handleAction
local setUpBackpack


----- Backpack -----

handleAction = function(actionName: string, inputState: Enum.UserInputState, inputObject: InputObject)
    if actionName == Constants.action_name.toggleInventory then
        if inputState == Enum.UserInputState.Begin then
            BackpackUI.toggleInventory()
        end
    else
        if inputState == Enum.UserInputState.Begin then
            for i = 1, 10 do
                if actionName == Constants.action_name.hotbar_prefix .. ` {i}` then
                    BackpackUI.toggleEquipHotbarSlot(i)
                    return
                end
            end
        end
    end
end

setUpBackpack = function()
    ContextActionService:BindAction(Constants.action_name.toggleInventory, handleAction, false, Enum.KeyCode.Backquote)
    ContextActionService:BindAction(Constants.action_name.hotbar_1, handleAction, false, Enum.KeyCode.One)
    ContextActionService:BindAction(Constants.action_name.hotbar_2, handleAction, false, Enum.KeyCode.Two)
    ContextActionService:BindAction(Constants.action_name.hotbar_3, handleAction, false, Enum.KeyCode.Three)
    ContextActionService:BindAction(Constants.action_name.hotbar_4, handleAction, false, Enum.KeyCode.Four)
    ContextActionService:BindAction(Constants.action_name.hotbar_5, handleAction, false, Enum.KeyCode.Five)
    ContextActionService:BindAction(Constants.action_name.hotbar_6, handleAction, false, Enum.KeyCode.Six)
    ContextActionService:BindAction(Constants.action_name.hotbar_7, handleAction, false, Enum.KeyCode.Seven)
    ContextActionService:BindAction(Constants.action_name.hotbar_8, handleAction, false, Enum.KeyCode.Eight)
    ContextActionService:BindAction(Constants.action_name.hotbar_9, handleAction, false, Enum.KeyCode.Nine)
    ContextActionService:BindAction(Constants.action_name.hotbar_10, handleAction, false, Enum.KeyCode.Zero)
    BackpackUI.connect()
end


----- Main -----

local function main()
    if UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse then
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
        setUpBackpack()
    end
end


---------- Calling function ----------

main()
