--!strict

-- Backpack UI Module


---------- Services ----------

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
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

Constants.timeFn = time
Constants.epsilonTime = 1e-5

Constants.backpack_remoteEvent = script:WaitForChild("Backpack_RemoteEvent")

Constants.bagButtonPadding = 6
Constants.black = Color3.new(0, 0, 0)
Constants.white = Color3.new(1, 1, 1)
Constants.clickedLightenLerp = 0.2
Constants.hoveredDarkenLerp = 0.2

Constants.screenGuiName = "Backpack_ScreenGui"
Constants.screenGuiTagName = "BackpackUI"

do
    local backpack_uis = {}
    backpack_uis.screenGui = (function()
        local result

        -- Retrieve custom screen gui, or default if none found
        local starterGuiBackpack = StarterGui:FindFirstChild(Constants.screenGuiName)
        if starterGuiBackpack then
            -- Clone preset screen gui
            result = starterGuiBackpack:Clone() :: typeof(script.Backpack_ScreenGui)
            if result.ResetOnSpawn then
                warn(`[Backpack UI]: Custom '{result.Name}' should have ResetOnSpawn set to false!`)
            end

            -- Clear future screen guis
            Constants.playerGui.ChildAdded:Connect(function(child: Instance)
                if child:IsA("ScreenGui") and child.Name == Constants.screenGuiName then
                    if child ~= result then
                        child:Destroy()
                    end
                end
            end)

            -- Clear current extra screen guis
            task.defer(function()
                for _, child in Constants.playerGui:GetChildren() do
                    if child:IsA("ScreenGui") and child.Name == Constants.screenGuiName then
                        if child ~= result then
                            child:Destroy()
                        end
                    end
                end
            end)
        else
            result = script:WaitForChild(Constants.screenGuiName):Clone()
            result.ResetOnSpawn = false
        end
        result:AddTag(Constants.screenGuiTagName)
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
    backpack_uis.hotbarUIListLayout = backpack_uis.hotbarFrame:WaitForChild("UIListLayout")

    backpack_uis.toggleBagButton = backpack_uis.paddedFrame:WaitForChild("ToggleBag_Button")
    backpack_uis.toggleBagButton.Visible = false

    backpack_uis.itemDragPlaceholderFrame = backpack_uis.paddedFrame:WaitForChild("ItemDragPlaceholder_Frame")
    backpack_uis.itemDragPlaceholderFrame.Visible = false

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
Globals.hotbarSlotFrame_exist = {} :: {[Frame]: boolean}

Globals.hoveredGuisCache = {} :: {GuiObject}
Globals.hoveredGuisSetCache = {} :: {[GuiObject]: true?}
Globals.lastHoveredGuisUpdateTime = Constants.timeFn() - 1
Globals.lastHoveredGuisSetUpdateTime = Constants.timeFn() - 1

Globals.currentlyEquippedToolName = nil :: string?
Globals.currentlyEquippedTool = nil :: Instance?
Globals.currentlyClickedItemSlotInfo = nil :: ItemSlotInfo?
Globals.currentlyDraggedItemSlotInfo = nil :: ItemSlotInfo?


---------- Local functions ----------

local getFirstChildrenAdvanced

local getHoveredGuis
local getHoveredGuisSet
local getIsHoveringOverGuiObject

local getAndIncrementHighestLayoutOrder

local setUpDefaultHotbarSlots
local getHoveredHotbarSlotFrame
local getHotbarSlotItemSlotInfo
local getParentHotbarSlotFrame
local refreshHotbarSlotFrameVisible

local createNewItemSlot
local onItemSlotMouseDown
local setUpItemSlotButton
local getHoveredItemSlotInfos
local normalizeItemSlotLayoutOrders
local refreshItemSlot
local refreshItemSlotByName
local toggleEquipItem
local unequipItem
local onItemEquipped
local queryEquipItem
local updateItemSlotButtonColors

local onItemAdded
local onItemRemoved: (Instance, string?) -> nil

local onCharacterAdded

local toggleInventory
local refreshInventoryVisible
local setUpInventoryButton
local updateInventoryByFilter

local updateToolTip


----- Get children -----

getFirstChildrenAdvanced = function(parent: Instance, name: string, isA_className: string): Instance?
    local result
    for _, object in parent:GetChildren() do
        if object.Name == name and object:IsA(isA_className) then
            result = object
            break
        end
    end
    return result
end


----- Hover helper -----

getHoveredGuis = function()
    -- Check cache
    local nowTime = Constants.timeFn()
    if nowTime < Globals.lastHoveredGuisUpdateTime + Constants.epsilonTime then
        return Globals.hoveredGuisCache
    end

    -- Get from playerGui
    local mousePosition = UserInputService:GetMouseLocation()
    local positionInsetted = mousePosition - GuiService:GetGuiInset()
    local hoveredGuis = Constants.playerGui:GetGuiObjectsAtPosition(positionInsetted.X, positionInsetted.Y)

    -- Set cache
    Globals.hoveredGuisCache = hoveredGuis
    Globals.lastHoveredGuisUpdateTime = nowTime
    table.freeze(hoveredGuis)

    -- Return
    return hoveredGuis
end

getHoveredGuisSet = function()
    -- Check cache
    local nowTime = Constants.timeFn()
    if nowTime < Globals.lastHoveredGuisSetUpdateTime + Constants.epsilonTime then
        return Globals.hoveredGuisSetCache
    end

    -- Get hovered guis
    local hoveredGuis = getHoveredGuis()
    local gui_hovered = {} :: {[GuiObject]: true?}

    -- Convert to set
    for _, gui in hoveredGuis do
        gui_hovered[gui] = true
    end

    -- Set cache
    Globals.hoveredGuisSetCache = gui_hovered
    Globals.lastHoveredGuisSetUpdateTime = nowTime
    table.freeze(gui_hovered)

    -- Return
    return gui_hovered
end

getIsHoveringOverGuiObject = function(object: GuiObject)
    local hoveredGuisSet = getHoveredGuisSet()
    return hoveredGuisSet[object] ~= nil
end


----- Layout order -----

getAndIncrementHighestLayoutOrder = function()
    Globals.highestLayoutOrder += 2
    return Globals.highestLayoutOrder
end


----- Hotbar -----

setUpDefaultHotbarSlots = function(hotbarSlotsCount: number)
    table.clear(Globals.hotbarSlotFrames)

    -- Create hotbar slots
    for i = 1, hotbarSlotsCount do
        local hotbarSlotFrame = Constants.backpack_uis.defaultHotbarSlotFrame:Clone()
        hotbarSlotFrame.LayoutOrder = i
        hotbarSlotFrame.Name = `HotbarSlot_Frame_{string.format("%2d", i)}`
        hotbarSlotFrame.Parent = Constants.backpack_uis.hotbarFrame
        table.insert(Globals.hotbarSlotFrames, hotbarSlotFrame)
    end

    -- Store existence info
    table.clear(Globals.hotbarSlotFrame_exist)
    for _, frame in Globals.hotbarSlotFrames do
        Globals.hotbarSlotFrame_exist[frame] = true
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

getHotbarSlotItemSlotInfo = function(hotbarSlotFrame: Frame): ItemSlotInfo?
    local itemSlotButton = hotbarSlotFrame:FindFirstChildWhichIsA("TextButton")
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

getParentHotbarSlotFrame = function(itemSlotInfo: ItemSlotInfo): Frame?
    local buttonParent = itemSlotInfo.mainButton.Parent
    local result
    if buttonParent and buttonParent:IsA("Frame") and Globals.hotbarSlotFrame_exist[buttonParent] then
        result = buttonParent
    end
    return result
end

refreshHotbarSlotFrameVisible = function(hotbarSlotFrame: Frame)
    if Globals.inventoryEnabled then
        hotbarSlotFrame.Visible = true
    else
        local hasTool = getHotbarSlotItemSlotInfo(hotbarSlotFrame) ~= nil
        hotbarSlotFrame.Visible = hasTool
    end
end


----- Item slot -----

createNewItemSlot = function(tool: Tool)
    if Globals.toolName_itemSlotInfo[tool.Name] then
        return
    end
    local itemSlotButton = Constants.backpack_uis.defaultItemSlotButton:Clone()
    local itemSlotInfo = {
        toolName = tool.Name,
        toolTip = tool.ToolTip,
        mainButton = itemSlotButton,
        multiplier_TextLabel = itemSlotButton:WaitForChild("Multiplier_TextLabel") :: TextLabel,
        selectionBox_Frame = itemSlotButton:WaitForChild("SelectionBox_Frame") :: Frame,
        slotNumber_TextLabel = itemSlotButton:WaitForChild("SlotNumber_TextLabel") :: TextLabel,
        toolIcon_ImageLabel = itemSlotButton:WaitForChild("ToolIcon_ImageLabel") :: ImageLabel,
        toolName_TextLabel = itemSlotButton:WaitForChild("ToolName_TextLabel") :: TextLabel,
    } :: ItemSlotInfo
    Globals.toolName_itemSlotInfo[tool.Name] = itemSlotInfo
    Globals.itemSlotButton_toolName[itemSlotButton] = tool.Name

    -- Set initial properties
    itemSlotButton.SelectionBox_Frame.Visible = false

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

onItemSlotMouseDown = function(itemSlotInfo: ItemSlotInfo)
    -- Initial info
    local itemSlotButton = itemSlotInfo.mainButton
    local initialPosition = itemSlotButton.Position
    local initialAnchorPoint = itemSlotButton.AnchorPoint
    local initialContainer = itemSlotButton.Parent
    local initialLayoutOrder = itemSlotButton.LayoutOrder
    local willToggleEquip = false

    -- Initial container info
    local initialContainerIsHotbar = initialContainer and initialContainer:IsA("Frame") and Globals.hotbarSlotFrame_exist[initialContainer]
    local initialContainerIsInventory = initialContainer == Constants.backpack_uis.itemsScrollingFrame

    -- Drag if inventory enabled, else listen for click
    if Globals.inventoryEnabled then
        -- Drag item
        Globals.currentlyDraggedItemSlotInfo = itemSlotInfo
        itemSlotButton.Parent = Constants.backpack_uis.screenGui

        -- Show placeholder if dragging inventory item
        if initialContainerIsInventory then
            Constants.backpack_uis.itemDragPlaceholderFrame.Parent = initialContainer
            Constants.backpack_uis.itemDragPlaceholderFrame.LayoutOrder = initialLayoutOrder
            Constants.backpack_uis.itemDragPlaceholderFrame.Visible = true
        end

        -- Loop until release
        while UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
            -- Move item slot to the mouse position
            local desiredPosition = UserInputService:GetMouseLocation()
            itemSlotButton.Position = UDim2.fromOffset(desiredPosition.X, desiredPosition.Y)
            task.wait()
        end

        -- No longer dragging
        Globals.currentlyDraggedItemSlotInfo = nil

        -- Resolve release
        (function()
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

                -- Toggle equip if layout order remains the same & within same container
                if initialContainer == itemSlotButton.Parent then
                    if itemSlotButton.LayoutOrder == initialLayoutOrder then
                        willToggleEquip = true
                    end
                end

                return
            end

            -- Check if mouse is hovering over the drag placeholder
            if Constants.backpack_uis.itemDragPlaceholderFrame.Visible and getIsHoveringOverGuiObject(Constants.backpack_uis.itemDragPlaceholderFrame) then
                -- Toggle equip
                willToggleEquip = true

                -- Parent to inventory
                itemSlotButton.Parent = Constants.backpack_uis.itemsScrollingFrame

                return
            end

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
                -- Insert before if dragged from hotbar or a later item slot
                -- else insert after
                local selectedLayoutOrder = selectedItemSlotInfo.mainButton.LayoutOrder
                if initialContainerIsHotbar or selectedLayoutOrder < initialLayoutOrder then
                    itemSlotButton.LayoutOrder = selectedLayoutOrder - 1
                else
                    itemSlotButton.LayoutOrder = selectedLayoutOrder + 1
                end
                normalizeItemSlotLayoutOrders()
            else
                itemSlotButton.LayoutOrder = getAndIncrementHighestLayoutOrder()
                normalizeItemSlotLayoutOrders()
            end

            -- Parent to inventory
            itemSlotButton.Parent = Constants.backpack_uis.itemsScrollingFrame
        end)()

        -- Reset position properties
        itemSlotButton.Position = initialPosition
        itemSlotButton.AnchorPoint = initialAnchorPoint

        -- Hide placeholder
        Constants.backpack_uis.itemDragPlaceholderFrame.Visible = false
    else
        -- Click item
        Globals.currentlyClickedItemSlotInfo = itemSlotInfo

        -- Wait until mouse released
        while UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
            task.wait()
        end

        -- No longer clicking
        Globals.currentlyClickedItemSlotInfo = nil

        -- If hovering over same slot, equip/unequip tool
        if getIsHoveringOverGuiObject(itemSlotButton) then
            willToggleEquip = true
        end
    end

    -- Toggle equip & refresh inventory
    if willToggleEquip then
        toggleEquipItem(itemSlotInfo)
    end
    refreshItemSlot(itemSlotInfo)
    refreshInventoryVisible()
end

setUpItemSlotButton = function(itemSlotInfo: ItemSlotInfo)
    local itemSlotButton = itemSlotInfo.mainButton
    itemSlotButton.LayoutOrder = getAndIncrementHighestLayoutOrder()
    itemSlotButton.MouseButton1Down:Connect(function()
        onItemSlotMouseDown(itemSlotInfo)
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

    -- Tool slot number
    local buttonParent = itemSlotInfo.mainButton.Parent
    local isHotbarAncestryMet = buttonParent and buttonParent:IsDescendantOf(Constants.backpack_uis.hotbarFrame)
    if buttonParent and buttonParent:IsA("GuiObject") and isHotbarAncestryMet then
        itemSlotInfo.slotNumber_TextLabel.Text = `{buttonParent.LayoutOrder}`
        itemSlotInfo.slotNumber_TextLabel.Visible = true
    else
        itemSlotInfo.slotNumber_TextLabel.Visible = false
    end

    -- Tool info
    local exampleTool
    local character = Constants.localPlayer.Character
    exampleTool = character and getFirstChildrenAdvanced(character, toolName, "Tool")
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
                task.defer(function()
                    Constants.backpack_remoteEvent:FireServer("UnequipTools")
                end)
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
                task.defer(function()
                    Constants.backpack_remoteEvent:FireServer("EquipTool", tool)
                end)
                onItemEquipped(tool)
            end
        end
    end
end

updateItemSlotButtonColors = function()
    -- Get base color
    local baseBackgroundColor = Constants.backpack_uis.defaultItemSlotButton.BackgroundColor3

    -- Currently clicked or dragged
    local itemSlotButton_state = {} :: {[TextButton]: string}
    local clickedItemSlotInfo = Globals.currentlyClickedItemSlotInfo or Globals.currentlyDraggedItemSlotInfo
    if clickedItemSlotInfo then
        itemSlotButton_state[clickedItemSlotInfo.mainButton] = "Clicked"
    end

    -- Hovered item slots
    for _, itemSlotInfo in getHoveredItemSlotInfos() do
        if itemSlotInfo ~= clickedItemSlotInfo then
            itemSlotButton_state[itemSlotInfo.mainButton] = "Hovered"
        end
    end

    -- Update colors
    for _, itemSlotInfo in Globals.toolName_itemSlotInfo do
        local itemSlotButton = itemSlotInfo.mainButton
        local buttonState = itemSlotButton_state[itemSlotButton]
        if buttonState == "Clicked" then
            itemSlotButton.BackgroundColor3 = baseBackgroundColor:Lerp(Constants.white, Constants.clickedLightenLerp)
        elseif buttonState == "Hovered" then
            itemSlotButton.BackgroundColor3 = baseBackgroundColor:Lerp(Constants.black, Constants.hoveredDarkenLerp)
        else
            itemSlotButton.BackgroundColor3 = baseBackgroundColor
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
            -- Retrieve gui info
            local itemSlotInfo = Globals.toolName_itemSlotInfo[toolName]
            local hotbarSlotFrame = getParentHotbarSlotFrame(itemSlotInfo)

            -- Remove count & item slot
            itemSlotInfo.mainButton:Destroy()
            Globals.toolName_count[toolName] = nil
            Globals.toolName_itemSlotInfo[toolName] = nil
            Globals.itemSlotButton_toolName[itemSlotInfo.mainButton] = nil

            -- Hide hotbar slot if needed
            if hotbarSlotFrame then
                refreshHotbarSlotFrameVisible(hotbarSlotFrame)
            end
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
        onItemRemoved(tool, nil)
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

toggleInventory = function()
    if Constants.backpack_uis.screenGui.Enabled then
        Globals.inventoryEnabled = not Globals.inventoryEnabled
        refreshInventoryVisible()
    end
end

refreshInventoryVisible = function()
    Constants.backpack_uis.inventoryFrame.Visible = Globals.inventoryEnabled

    -- Set visibility of each slots
    for _, hotbarSlotFrame in Globals.hotbarSlotFrames do
        refreshHotbarSlotFrameVisible(hotbarSlotFrame)
    end
end

setUpInventoryButton = function()
    -- Calculate bag button position
    do
        local oneHotbarSlotWidth = Constants.backpack_uis.defaultHotbarSlotFrame.AbsoluteSize.Y
        local hotbarSlotsCount = #Globals.hotbarSlotFrames
        local listPaddingX = Constants.backpack_uis.hotbarUIListLayout.Padding.Offset
        local hotbarWidth = (oneHotbarSlotWidth + listPaddingX) * hotbarSlotsCount
        local offsetX = -hotbarWidth // 2 - Constants.bagButtonPadding
        Constants.backpack_uis.toggleBagButton.Position = UDim2.new(
            UDim.new(0.5, offsetX),
            Constants.backpack_uis.toggleBagButton.Position.Y
        )
    end

    -- Set up button clicked
    Constants.backpack_uis.toggleBagButton.Visible = true
    Constants.backpack_uis.toggleBagButton.Activated:Connect(function()
        toggleInventory()
    end)
end

updateInventoryByFilter = function()
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
end


----- Tool tip -----

updateToolTip = function()
    local selectedItemSlotInfo

    -- Get item slot that will show tool tip
    if Globals.currentlyDraggedItemSlotInfo then
        selectedItemSlotInfo = Globals.currentlyDraggedItemSlotInfo
    else
        local hoveredItemSlotInfos = getHoveredItemSlotInfos()
        if next(hoveredItemSlotInfos) then
            selectedItemSlotInfo = hoveredItemSlotInfos[1]
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
end


---------- Module ----------

local Module = {}


----- Module fields -----

Module.connect = function(hotbarSlotsCount: number)
    -- Validate not connected
    if Globals.isConnected then
        return
    end
    Globals.isConnected = true

    -- Parent screen gui
    Constants.backpack_uis.screenGui.Parent = Constants.playerGui

    -- Call functions
    local initialCharacter = Constants.localPlayer.Character
    if initialCharacter then
        task.defer(onCharacterAdded, initialCharacter)
    end
    Constants.localPlayer.CharacterAdded:Connect(onCharacterAdded)
    setUpDefaultHotbarSlots(hotbarSlotsCount)
    setUpInventoryButton()

    RunService.Heartbeat:Connect(function()
        updateInventoryByFilter()
        updateToolTip()
        updateItemSlotButtonColors()
    end)
end

Module.toggleInventory = function()
    toggleInventory()
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
