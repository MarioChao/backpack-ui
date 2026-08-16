# Changelogs

## [v1.1.0] Custom preset screen gui | 2026/08/16

Readded preset `Backpack_ScreenGui` customization.
- Simply copy a `Backpack_ScreenGui` to `StarterGui`, then that screen gui will be used instead of the default one.

## [v1.0.6] Faster loading | 2026/05/22

Removed `playerGui:WaitForChild` for preset `Backpack_ScreenGui`.
- Greatly reduces the loading time.
- The "wait for 1 second" preset feature doesn't really work since `StarterGui` only parents to `PlayerGui` when the character is first loaded.

## [v1.0.5] Reorganization + Wally package | 2026/05/20

Reorganized the repository:
- Shortened `src/ReplicatedStorage/Scripts/BackpackUI` to `src/BackpackUI`.
- Ungrouped the `BackpackUI` subfolder under the main `BackpackUI`.

Added `wally.toml` and MIT license.

Slightly modified the repository description.

Added "credits" section to [README](README.md).

Some minor code changes.

## [v1.0.4] Small UI change | 2026/03/09

Made the tool name `TextLabel` smaller so selection box won't cover the text.

## [v1.0.3] Hiding hotbar slot fix | 2026/02/23

Fixed hotbar slot remaining visible when the corresponding item is removed.

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
