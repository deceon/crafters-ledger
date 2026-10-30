# Crafters Ledger 3.3.0

Find items, account-wide counts and an on-screen tracker.

- New Find items page: type part of a name (like garnet) to find every item your recipes make or use, plus anything on your shopping list. Each item shows which recipes make it and use it, and has an Add button.
- Inventory and Account checkboxes at the top choose what Have counts: your bag, your account (bank, house chests, other characters, mail, vendor listings), or both. They apply to Find items, the shopping list and recipe details, and are saved.
- + and - on each item show where it is: your bag, bank and each house lot with its own total, and the containers inside each.
- Compass: stand next to a chest and click Mark on its line once; after that, Compass points the game's compass at it while you're in that scene. Clear compass stops pointing; Unmark forgets the chest.
- On-screen tracker: the shopping list on screen like the quest list, with recipes as headings and what you still need under them. Its title bar only shows when you point at it. Stretch it from any edge, right-click it to fade it, and click x on a recipe to take it off the tracker (it stays on your shopping list; Track all brings it back). Turn it on from the shopping list (Show / hide) or with /ledgertrack. Its place and size are saved.
- Counts are faster: more lookups at once, the list redraws as counts arrive, and the item list and counts start getting ready shortly after you log in.
- Refresh counts also asks the game again for bank and chest counts.

# Crafters Ledger 3.2.17

Republishes the 3.2.16 fixes. The store's 3.2.16 package was built from older files and still had the launcher error.

- The shopping list stays inside the window and scrolls when expanded recipes run past the bottom.
- Fixed the HUD launcher button failing to load ("cannot access field Show").

# Crafters Ledger 3.2.16

Shopping list scrolling fix and launcher fix.

- The shopping list now stays inside the window. When expanded recipes run past the bottom, scroll with the mouse wheel or drag the scrollbar.
- Search, filters, totals and page controls stay fixed outside the scrolling area.
- Fixed the HUD launcher button failing to load ("cannot access field Show").

# Crafters Ledger 3.2.12

Shopping list fixes for mistakes.

- Needed is now editable: type the amount and press Enter or Set.
- X next to a recipe in the shopping list removes the whole recipe and the materials it added (click X, then Sure? to confirm). Materials another recipe also uses stay, with that recipe's amount.

# Crafters Ledger 3.2.10

Initial GitHub release of the crafting planner and saved shopping list.

- Search known recipes and view required skill level, output, and materials.
- Scale ingredient requirements by crafting attempts.
- Group supplies by the item being crafted, with + / - expansion.
- Compare carried inventory with targets and filter To get, All, or Ready.
- Save shopping lists and recipe labels between sessions.
- Book-and-quill launcher and configurable show/hide key.
- Uses the supported standard window for search fields and dropdowns.

Bank and house storage support remains a feature request.
