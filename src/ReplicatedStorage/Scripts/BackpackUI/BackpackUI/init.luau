--!strict

-- Backpack UI Module


---------- Services ----------

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsClient() then
    warn("[Backpack UI]: Module should only be required from the client!")
end


---------- Types ----------

type ItemSlotInfo = {
    toolName: string,
    toolTip: string,
    mainButton: TextButton,
    multiplier_TextLabel: TextLabel,
    selectionBox_Frame: Frame,
    slotNumber_TextLabel: TextLabel,
    toolIcon_ImageLabel: ImageLabel,
    toolName_TextLabel: TextLabel,
}


---------- Constants ----------

local Constants = {}

Constants.localPlayer = Players.LocalPlayer :: Player
Constants.playerGui = Constants.localPlayer.PlayerGui

do
    local backpack_uis = {}
    backpack_uis.screenGui = (function()
        local child = Constants.playerGui:WaitForChild("Backpack_ScreenGui", 1)
        local result
        if child and child:IsA("ScreenGui") then
            result = child :: typeof(script:WaitForChild("Backpack_ScreenGui"))
        else
            result = script:WaitForChild("Backpack_ScreenGui"):Clone()
        end
        result.Enabled = false
        return result
    end)()

    backpack_uis.paddedFrame = backpack_uis.screenGui:WaitForChild("Padded_Frame")

    backpack_uis.inventoryFrame = backpack_uis.paddedFrame:WaitForChild("Inventory_Frame")
    backpack_uis.inventoryFrame.Visible = false
    backpack_uis.itemsScrollingFrame = backpack_uis.inventoryFrame:WaitForChild("Items_ScrollingFrame")
    backpack_uis.filterTextBox = backpack_uis.inventoryFrame:WaitForChild("Filter_TextBox")

    backpack_uis.hotbarFrame = backpack_uis.paddedFrame:WaitForChild("Hotbar_Frame")
    backpack_uis.defaultHotbarSlotFrame = backpack_uis.hotbarFrame:WaitForChild("HotbarSlot_Frame")
    backpack_uis.defaultHotbarSlotFrame.Visible = false

    backpack_uis.defaultItemSlotButton = backpack_uis.paddedFrame:WaitForChild("ItemSlot_Button")
    backpack_uis.defaultItemSlotButton.Visible = false

    backpack_uis.toolTipTextLabel  = backpack_uis.screenGui:WaitForChild("ToolTip_TextLabel")
    backpack_uis.toolTipTextLabel.Visible = false

    Constants.backpack_uis = backpack_uis
    table.freeze(backpack_uis)
end

table.freeze(Constants)


---------- Globals ----------

local Globals = {}

Globals.isConnected = false

Globals.highestLayoutOrder = 0
Globals.inventoryEnabled = false
Globals.toolName_count = {} :: {[string]: number}
Globals.toolName_itemSlotInfo = {} :: {[string]: ItemSlotInfo}
Globals.itemSlotButton_toolName = {} :: {[Instance]: string}

Globals.tool_isRegistered = {} :: {[Instance]: boolean}
Globals.tool_toolChangedConnection = {} :: {[Instance]: RBXScriptConnection}
Globals.tool_toolName = {} :: {[Instance]: string}

Globals.hotbarSlotFrames = {} :: {Frame}

Globals.currentlyEquippedToolName = nil :: string?
Globals.currentlyEquippedTool = nil :: Instance?
Globals.currentlyDraggedItemSlotInfo = nil :: ItemSlotInfo?


---------- Local functions ----------

local getIsHoveringOverGuiObject
local getHoveredGuis
local getHoveredGuisSet

local getAndIncrementHighestLayoutOrder

local setUpDefaultHotbarSlots
local getHoveredHotbarSlotFrame
local getHotbarSlotItemSlotInfo

local createNewItemSlot
local setUpItemSlotButton
local getHoveredItemSlotInfos
local normalizeItemSlotLayoutOrders
local refreshItemSlot
local refreshItemSlotByName
local toggleEquipItem
local unequipItem
local onItemEquipped
local queryEquipItem

local onItemAdded
local onItemRemoved: (Instance, string?) -> nil

local onCharacterAdded

local refreshInventoryVisible
local setUpInventorySearch

local setUpToolTip


----- Hover helper -----

getIsHoveringOverGuiObject = function(object: GuiObject)
    local mousePosition = UserInputService:GetMouseLocation()
    local positionInsetted = mousePosition - GuiService:GetGuiInset()
    local hoveredGuis = Constants.playerGui:GetGuiObjectsAtPosition(positionInsetted.X, positionInsetted.Y)
    return table.find(hoveredGuis, object) ~= nil
end

getHoveredGuis = function()
    local mousePosition = UserInputService:GetMouseLocation()
    local positionInsetted = mousePosition - GuiService:GetGuiInset()
    local hoveredGuis = Constants.playerGui:GetGuiObjectsAtPosition(positionInsetted.X, positionInsetted.Y)
    return hoveredGuis
end

getHoveredGuisSet = function()
    local mousePosition = UserInputService:GetMouseLocation()
    local positionInsetted = mousePosition - GuiService:GetGuiInset()
    local hoveredGuis = Constants.playerGui:GetGuiObjectsAtPosition(positionInsetted.X, positionInsetted.Y)
    local gui_hovered = {} :: {[GuiObject]: boolean}

    -- Get hovered guis
    for _, gui in hoveredGuis do
        gui_hovered[gui] = true
    end

    return gui_hovered
end


----- Layout order -----

getAndIncrementHighestLayoutOrder = function()
    Globals.highestLayoutOrder += 2
    return Globals.highestLayoutOrder
end


----- Hotbar -----

setUpDefaultHotbarSlots = function()
    table.clear(Globals.hotbarSlotFrames)
    for i = 1, 10 do
        local hotbarSlotFrame = Constants.backpack_uis.defaultHotbarSlotFrame:Clone()
        hotbarSlotFrame.LayoutOrder = i
        hotbarSlotFrame.Name = `HotbarSlot_Frame_{string.format("%2d", i)}`
        hotbarSlotFrame.Parent = Constants.backpack_uis.hotbarFrame
        table.insert(Globals.hotbarSlotFrames, hotbarSlotFrame)
    end
end

getHoveredHotbarSlotFrame = function(): Frame?
    local gui_hovered = getHoveredGuisSet()
    local result

    -- Check for hovered hotbar slots
    for _, hotbarSlotFrame in Globals.hotbarSlotFrames do
        if gui_hovered[hotbarSlotFrame] then
            result = hotbarSlotFrame
            break
        end
    end
    return result
end

getHotbarSlotItemSlotInfo = function(hotbarSlotFrame: GuiObject): ItemSlotInfo?
    local itemSlotButton = hotbarSlotFrame:QueryDescendants("> TextButton")[1]
    local toolName
    local itemSlotInfo
    local result
    if itemSlotButton then
        toolName = Globals.itemSlotButton_toolName[itemSlotButton]
        if toolName then
            itemSlotInfo = Globals.toolName_itemSlotInfo[toolName]
            if itemSlotInfo then
                result = itemSlotInfo
            end
        end
    end
    return result
end


----- Item slot -----

createNewItemSlot = function(tool: Tool)
    if Globals.toolName_itemSlotInfo[tool.Name] then
        return
    end
    local itemSlotButton = Constants.backpack_uis.defaultItemSlotButton:Clone()
    local itemSlotInfo = {
        toolName = tool.Name,
        mainButton = itemSlotButton,
        multiplier_TextLabel = itemSlotButton:WaitForChild("Multiplier_TextLabel") :: TextLabel,
        selectionBox_Frame = itemSlotButton:WaitForChild("SelectionBox_Frame") :: Frame,
        slotNumber_TextLabel = itemSlotButton:WaitForChild("SlotNumber_TextLabel") :: TextLabel,
        toolIcon_ImageLabel = itemSlotButton:WaitForChild("ToolIcon_ImageLabel") :: ImageLabel,
        toolName_TextLabel = itemSlotButton:WaitForChild("ToolName_TextLabel") :: TextLabel,
    } :: ItemSlotInfo
    Globals.toolName_itemSlotInfo[tool.Name] = itemSlotInfo
    Globals.itemSlotButton_toolName[itemSlotButton] = tool.Name

    -- Put in hotbar if possible, or else put in inventory
    local freeHotbarSlotFrame
    for _, hotbarSlotFrame in Globals.hotbarSlotFrames do
        if getHotbarSlotItemSlotInfo(hotbarSlotFrame) == nil then
            freeHotbarSlotFrame = hotbarSlotFrame
            break
        end
    end
    if freeHotbarSlotFrame then
        itemSlotButton.Visible = true
        itemSlotButton.Parent = freeHotbarSlotFrame
        refreshInventoryVisible()
    else
        itemSlotButton.Parent = Constants.backpack_uis.itemsScrollingFrame
    end

    -- Set up item slot
    setUpItemSlotButton(itemSlotInfo)
    refreshItemSlot(itemSlotInfo)
end

setUpItemSlotButton = function(itemSlotInfo: ItemSlotInfo)
    local itemSlotButton = itemSlotInfo.mainButton
    itemSlotButton.LayoutOrder = getAndIncrementHighestLayoutOrder()
    itemSlotButton.MouseButton1Down:Connect(function()
        local initialPosition = itemSlotButton.Position
        local initialContainer = itemSlotButton.Parent
        local initialLayoutOrder = itemSlotButton.LayoutOrder
        local willToggleEquip = false

        -- Check inventory enabled
        if Globals.inventoryEnabled then
            -- Drag item
            Globals.currentlyDraggedItemSlotInfo = itemSlotInfo
            itemSlotButton.Parent = Constants.backpack_uis.screenGui
            while UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local desiredPosition = UserInputService:GetMouseLocation()
                itemSlotButton.Position = UDim2.fromOffset(desiredPosition.X, desiredPosition.Y)
                task.wait()
            end
            Globals.currentlyDraggedItemSlotInfo = nil

            -- Check if mouse is hovering over hotbar slot
            local hotbarSlotFrame = getHoveredHotbarSlotFrame()
            if hotbarSlotFrame then
                -- Swap item if needed
                local swappedItemSlotInfo = getHotbarSlotItemSlotInfo(hotbarSlotFrame)
                if swappedItemSlotInfo then
                    swappedItemSlotInfo.mainButton.Parent = initialContainer

                    -- Swap layout order
                    itemSlotButton.LayoutOrder = swappedItemSlotInfo.mainButton.LayoutOrder
                    swappedItemSlotInfo.mainButton.LayoutOrder = initialLayoutOrder

                    refreshItemSlot(swappedItemSlotInfo)
                end
                itemSlotButton.Parent = hotbarSlotFrame
            else
                -- Check if mouse is hovering over another item slot
                local hoveredItemSlotInfos = getHoveredItemSlotInfos()
                local selectedItemSlotInfo
                for _, hoveredItemSlotInfo: ItemSlotInfo in hoveredItemSlotInfos do
                    if hoveredItemSlotInfo ~= itemSlotInfo then
                        selectedItemSlotInfo = hoveredItemSlotInfo
                        break
                    end
                end

                -- Insert layout order if hovering, else put at end
                if selectedItemSlotInfo then
                    local selectedLayoutOrder = selectedItemSlotInfo.mainButton.LayoutOrder
                    itemSlotButton.LayoutOrder = selectedLayoutOrder - 1
                    normalizeItemSlotLayoutOrders()
                else
                    itemSlotButton.LayoutOrder = getAndIncrementHighestLayoutOrder()
                    normalizeItemSlotLayoutOrders()
                end

                itemSlotButton.Parent = Constants.backpack_uis.itemsScrollingFrame
            end
            itemSlotButton.Position = initialPosition

            -- Toggle equip if layout order remains the same & within same container
            if initialContainer == itemSlotButton.Parent then
                if itemSlotButton.LayoutOrder == initialLayoutOrder then
                    willToggleEquip = true
                end
            end
        else
            -- Wait until mouse released
            while UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                task.wait()
            end

            -- If hovering over slot, equip/unequip tool
            if getIsHoveringOverGuiObject(itemSlotButton) then
                willToggleEquip = true
            end
        end

        if willToggleEquip then
            toggleEquipItem(itemSlotInfo)
        end
        refreshItemSlot(itemSlotInfo)
    end)
end

getHoveredItemSlotInfos = function()
    local hoveredGuis = getHoveredGuis()
    local result = {}
    for _, gui in hoveredGuis do
        local toolName = Globals.itemSlotButton_toolName[gui]
        if toolName then
            local itemSlotInfo = Globals.toolName_itemSlotInfo[toolName]
            if itemSlotInfo then
                table.insert(result, itemSlotInfo)
            end
        end
    end
    return result
end

normalizeItemSlotLayoutOrders = function()
    local itemSlotInfos = {}

    -- Get item slots sorted by layout order
    for _, itemSlotInfo in Globals.toolName_itemSlotInfo do
        table.insert(itemSlotInfos, itemSlotInfo)
    end
    table.sort(itemSlotInfos, function(a, b) return a.mainButton.LayoutOrder < b.mainButton.LayoutOrder end)
    
    -- Remap indices to positive integers
    for i = 1, #itemSlotInfos do
        itemSlotInfos[i].mainButton.LayoutOrder = i * 2
    end
    Globals.highestLayoutOrder = #itemSlotInfos * 2
end

refreshItemSlot = function(itemSlotInfo: ItemSlotInfo)
    local toolName = itemSlotInfo.toolName

    -- Tool multiplier
    itemSlotInfo.multiplier_TextLabel.Text = `x{Globals.toolName_count[toolName]}`
    itemSlotInfo.multiplier_TextLabel.Visible = Globals.toolName_count[toolName] > 1

    -- Tool slot
    local buttonParent = itemSlotInfo.mainButton.Parent
    local isHotbarAncestryMet = buttonParent and buttonParent:IsDescendantOf(Constants.backpack_uis.hotbarFrame)
    if buttonParent and buttonParent:IsA("GuiObject") and isHotbarAncestryMet then
        itemSlotInfo.slotNumber_TextLabel.Text = `{buttonParent.LayoutOrder}`
        itemSlotInfo.slotNumber_TextLabel.Visible = true
    else
        itemSlotInfo.slotNumber_TextLabel.Visible = false
    end

    local exampleTool
    local character = Constants.localPlayer.Character
    exampleTool = character and character:QueryDescendants(`> Tool#{toolName}`)[1]
    exampleTool = exampleTool or Constants.localPlayer.Backpack:FindFirstChild(toolName)
    if exampleTool and exampleTool:IsA("Tool") then
        -- Tool icon / tool name
        itemSlotInfo.toolIcon_ImageLabel.Image = exampleTool.TextureId
        itemSlotInfo.toolName_TextLabel.Text = exampleTool.Name
        if exampleTool.TextureId ~= "" then
            itemSlotInfo.toolIcon_ImageLabel.Visible = true
            itemSlotInfo.toolName_TextLabel.Visible = false
        else
            itemSlotInfo.toolIcon_ImageLabel.Visible = false
            itemSlotInfo.toolName_TextLabel.Visible = true
        end

        -- Tool tip
        itemSlotInfo.toolTip = exampleTool.ToolTip
    end
end

refreshItemSlotByName = function(toolName: string)
    local itemSlotInfo = Globals.toolName_itemSlotInfo[toolName]
    if itemSlotInfo then
        refreshItemSlot(itemSlotInfo)
    end
end

toggleEquipItem = function(itemSlotInfo: ItemSlotInfo)
    if Globals.currentlyEquippedToolName ~= itemSlotInfo.toolName then
        queryEquipItem(itemSlotInfo)
    else
        unequipItem()
    end
end

unequipItem = function()
    local character = Constants.localPlayer.Character
    local humanoid
    if character then
        humanoid = character:FindFirstChildWhichIsA("Humanoid")
        if humanoid then
            if Globals.currentlyEquippedToolName then
                local equippedItemSlotInfo = Globals.toolName_itemSlotInfo[Globals.currentlyEquippedToolName]
                equippedItemSlotInfo.selectionBox_Frame.Visible = false
                humanoid:UnequipTools()
                Globals.currentlyEquippedToolName = nil
                Globals.currentlyEquippedTool = nil
                refreshItemSlot(equippedItemSlotInfo)
            end
        end
    end
end

onItemEquipped = function(tool: Tool)
    if Globals.currentlyEquippedToolName then
        local previousItemSlotInfo = Globals.toolName_itemSlotInfo[Globals.currentlyEquippedToolName]
        if previousItemSlotInfo then
            previousItemSlotInfo.selectionBox_Frame.Visible = false
        end
    end
    local itemSlotInfo = Globals.toolName_itemSlotInfo[tool.Name]
    itemSlotInfo.selectionBox_Frame.Visible = true
    Globals.currentlyEquippedToolName = itemSlotInfo.toolName
    Globals.currentlyEquippedTool = tool
    refreshItemSlot(itemSlotInfo)
end

queryEquipItem = function(itemSlotInfo: ItemSlotInfo)
    local character = Constants.localPlayer.Character
    local humanoid
    if character then
        humanoid = character:FindFirstChildWhichIsA("Humanoid")
        if humanoid then
            unequipItem()
            local tool = Constants.localPlayer.Backpack:FindFirstChild(itemSlotInfo.toolName)
            if tool and tool:IsA("Tool") then
                humanoid:EquipTool(tool)
                onItemEquipped(tool)
            end
        end
    end
end


----- New item -----

onItemAdded = function(tool: Tool)
    if not Globals.tool_isRegistered[tool] then
        Globals.tool_isRegistered[tool] = true
        Globals.tool_toolName[tool] = tool.Name
        local toolCount = Globals.toolName_count[tool.Name] or 0
        if toolCount > 0 then
            -- Duplicate
            Globals.toolName_count[tool.Name] += 1
            refreshItemSlotByName(tool.Name)
        else
            -- Unique
            Globals.toolName_count[tool.Name] = 1
            createNewItemSlot(tool)
        end

        -- Set up tool changed
        if not Globals.tool_toolChangedConnection[tool] then
            Globals.tool_toolChangedConnection[tool] = tool.Changed:Connect(function(property: string)
                if property == "Name" then
                    local previousToolName = Globals.tool_toolName[tool]
                    onItemRemoved(tool, previousToolName)
                    onItemAdded(tool)
                    if tool.Parent == Constants.localPlayer.Character then
                        onItemEquipped(tool)
                    end
                    if Globals.toolName_itemSlotInfo[previousToolName] then
                        refreshItemSlotByName(previousToolName)
                    end
                elseif property ~= "Parent" then
                    refreshItemSlotByName(tool.Name)
                end
            end)
        end
    end
end

onItemRemoved = function(tool: Instance, _toolName: string?)
    local toolName = _toolName or tool.Name
    if Globals.tool_isRegistered[tool] and Globals.toolName_count[toolName] then
        -- Clean up tool
        Globals.tool_isRegistered[tool] = nil
        Globals.tool_toolName[tool] = nil
        if Globals.tool_toolChangedConnection[tool] then
            Globals.tool_toolChangedConnection[tool]:Disconnect()
            Globals.tool_toolChangedConnection[tool] = nil
        end

        -- Clean up backpack
        Globals.toolName_count[toolName] -= 1
        if Globals.currentlyEquippedTool == tool then
            unequipItem()
        end
        if Globals.toolName_count[toolName] == 0 then
            -- Remove count & item slot
            local itemSlotInfo = Globals.toolName_itemSlotInfo[toolName]
            itemSlotInfo.mainButton:Destroy()
            Globals.toolName_count[toolName] = nil
            Globals.toolName_itemSlotInfo[toolName] = nil
            Globals.itemSlotButton_toolName[itemSlotInfo.mainButton] = nil
        else
            refreshItemSlotByName(tool.Name)
        end
    end
end


----- Character -----

onCharacterAdded = function(character: Model)
    -- Clear existing backpack
    local existingTools = {}
    for tool, _ in Globals.tool_isRegistered do
        table.insert(existingTools, tool)
    end
    for _, tool in existingTools do
        onItemRemoved(tool)
    end

    -- Populate the backpack
    local backpack = Constants.localPlayer.Backpack
    local initialBackpackChild = backpack:GetChildren()
    task.defer(function()
        for _, object in initialBackpackChild do
            if object:IsA("Tool") then
                task.defer(onItemAdded, object)
            end
        end
    end)

    local function onChildInstanceAdded(child: Instance)
        if child:IsA("Tool") then
            onItemAdded(child)
        end
    end
    local function onChildInstanceRemoved(child: Instance)
        local isValidParent = false
        isValidParent = isValidParent or child.Parent == backpack
        isValidParent = isValidParent or child.Parent == character
        if child:IsA("Tool") and not isValidParent then
            onItemRemoved(child, nil)
        end
    end
    backpack.ChildAdded:Connect(onChildInstanceAdded)
    backpack.ChildRemoved:Connect(onChildInstanceRemoved)
    character.ChildAdded:Connect(function(child: Instance)
        if child:IsA("Tool") and not Globals.tool_isRegistered[child] then
            onItemAdded(child)
            onItemEquipped(child)
        end
    end)
    character.ChildRemoved:Connect(onChildInstanceRemoved)
    Constants.backpack_uis.screenGui.Enabled = true
end


----- Inventory -----

refreshInventoryVisible = function()
    Constants.backpack_uis.inventoryFrame.Visible = Globals.inventoryEnabled
    for _, hotbarSlotFrame in Globals.hotbarSlotFrames do
        if Globals.inventoryEnabled then
            hotbarSlotFrame.Visible = true
        else
            local hasTool = getHotbarSlotItemSlotInfo(hotbarSlotFrame) ~= nil
            hotbarSlotFrame.Visible = hasTool
        end
    end
end

setUpInventorySearch = function()
    RunService.Heartbeat:Connect(function()
        local filterText = string.lower(Constants.backpack_uis.filterTextBox.Text)
        for toolName, itemSlotInfo in Globals.toolName_itemSlotInfo do
            -- Make sure to only filter tool in inventory and not in hotbar
            if itemSlotInfo.mainButton:IsDescendantOf(Constants.backpack_uis.itemsScrollingFrame) then
                local filterSuccessful = false
                filterSuccessful = filterSuccessful or filterText == ""
                if not filterSuccessful then
                    local _, pcallResult = pcall(function()
                        return string.match(string.lower(toolName), filterText) ~= nil
                    end)
                    filterSuccessful = filterSuccessful or pcallResult == true
                end
                itemSlotInfo.mainButton.Visible = filterSuccessful
            end
        end
    end)
end


----- Tool tip -----

setUpToolTip = function()
    RunService.Heartbeat:Connect(function()
        local gui_hovered = getHoveredGuisSet()
        local selectedItemSlotInfo

        -- Get item slot that will show tool tip
        if Globals.currentlyDraggedItemSlotInfo then
            selectedItemSlotInfo = Globals.currentlyDraggedItemSlotInfo
        else
            for _, itemSlotInfo in Globals.toolName_itemSlotInfo do
                if gui_hovered[itemSlotInfo.mainButton] then
                    selectedItemSlotInfo = itemSlotInfo
                    break
                end
            end
        end

        -- Configure tool tip
        if selectedItemSlotInfo and selectedItemSlotInfo.toolTip ~= "" then
            local button = selectedItemSlotInfo.mainButton
            local buttonAbsolutePosition = button.AbsolutePosition + GuiService:GetGuiInset()
            Constants.backpack_uis.toolTipTextLabel.Text = selectedItemSlotInfo.toolTip
            Constants.backpack_uis.toolTipTextLabel.Position = UDim2.fromOffset(
                buttonAbsolutePosition.X + button.AbsoluteSize.X / 2,
                buttonAbsolutePosition.Y - 5
            )
            Constants.backpack_uis.toolTipTextLabel.Visible = true
        else
            Constants.backpack_uis.toolTipTextLabel.Visible = false
        end
    end)
end


---------- Module ----------

local Module = {}


----- Module fields -----

Module.connect = function()
    if Globals.isConnected then
        return
    end
    Globals.isConnected = true
    Constants.backpack_uis.screenGui.Parent = Constants.playerGui
    local initialCharacter = Constants.localPlayer.Character
    if initialCharacter then
        task.defer(onCharacterAdded, initialCharacter)
    end
    Constants.localPlayer.CharacterAdded:Connect(onCharacterAdded)
    setUpDefaultHotbarSlots()
    setUpInventorySearch()
    setUpToolTip()
end

Module.toggleInventory = function()
    if Constants.backpack_uis.screenGui.Enabled then
        Globals.inventoryEnabled = not Globals.inventoryEnabled
        refreshInventoryVisible()
    end
end

Module.toggleEquipHotbarSlot = function(slotNumber: number)
    local hotbarSlotFrame = Globals.hotbarSlotFrames[slotNumber]
    if hotbarSlotFrame then
        local itemSlotInfo = getHotbarSlotItemSlotInfo(hotbarSlotFrame)
        if itemSlotInfo then
            toggleEquipItem(itemSlotInfo)
        end
    end
end


---------- Return module ----------

table.freeze(Module)
return Module
