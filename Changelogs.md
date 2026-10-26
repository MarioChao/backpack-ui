# Changelogs

## [v1.2.1] Visual fixes | 2026/10/25 (2)

Swapped items are no longer hidden when swapping hotbar slots while inventory is closed.

Fixed hover button tint retaining when swapping items.

Small fix on tool tip showing up when swapping items.
- No longer shows above the other item being swapped.
- Still a minor issue when dropping slots to the back of inventory.

Some optimizations made for retrieving hovered GUIs.

## [v1.2.0] Server-side equip + Mobile ui + Drag placeholder | 2026/10/25 (1)

Added server-side tool equip if the client-side call didn't work:
- Allows the backpack ui to work in experiences with server authority enabled.

Added mobile support.
- Changed Backpack_ScreenGui's display order from 0 to 100 (prevents thumbstick interferring with item dragging).
- Design inspired by that in [Frozen Soul](https://www.roblox.com/games/5475056496/Frozen-Soul).

Added an extra button to toggle inventory:
- Located at `Backpack_ScreenGui` > `Padded_Frame` > `ToggleBag_Button`.

Added a placeholder slot so that other item slots don't shift when dragging.

## [v1.1.1] Clearing existing screen gui | 2026/08/16 (2)

In situations where `BackpackUI` is required after a `Backpack_ScreenGui` has been parented to `PlayerGui`, that parented screen gui will now be cleared.

## [v1.1.0] Custom preset screen gui | 2026/08/16 (1)

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
