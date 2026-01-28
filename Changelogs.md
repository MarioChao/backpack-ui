# Changelogs

## [v1.0.2] Tool name with special characters fix | 2026/01/27

Fixed issues that occur when tool names contain special characters.
- Replaced `:QueryDescendants()` to find first child.

## [v1.0.1] Swap item layout order fix | 2026/01/25 (2)

Layout order is now swapped when swapping inventory item and a hotbar item.

## [v1.0.0] Customized backpack ui | 2026/01/25 (1)

Created a customized backpack ui with many functionalities:
- Tool tip that shows when hovering or dragging items.
- Drag to sort items in both hotbar and inventory.
- Search tool to filter items by tool name (uses pattern matching).
- Tools with the same name only take up one slot.
    - Multiple items will be shown as a multiplier text (e.g. x2, x5).
    - When icon or tool tip is changed, the displayed info is chosen from one random tool.
        - Prioritizes the currently equipped tool over the tools in backpack.
- Backpack is disabled for mobile & non-keyboard devices -> uses Roblox's default.
