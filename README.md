# Crafters Ledger

Creator: Kronic | Version 3.3.0

A crafting planner and saved shopping list. Search your recipe book, see the required skill level and expected output, and choose how many times you want to craft. Add the ingredients to your shopping list, grouped under the item you are making so you always know what your supplies are for.

Click + beside an item to see its materials, or - to collapse them. The list compares what you are carrying with what you need and updates quantities automatically as you collect or use supplies. Filter by To get, All, or Ready, or search for a recipe or material.

Made a mistake? Type a new amount in a material's Needed box and press Enter or Set. Click X beside a recipe, then Sure?, to take the whole recipe and its materials off the list; materials another recipe also uses stay, with that recipe's amount.

Add individual materials or paste a custom list. You can also label existing supplies with a recipe without increasing their quantities. Your list and recipe labels are saved between sessions.

Show or hide Crafters Ledger with the book-and-quill icon or its key in the Add-Ons window. Open it with /ledger.

Find items searches every item your recipes make or use. Type part of a name, like garnet, and see how many you own and where. Click Where to see the exact bag, bank container or house chest.

Use the Inventory and Account checkboxes at the top to choose what Have counts: your bag, your account (bank, house chests, other characters, mail, vendor listings), or both. Account counts need a game client with Lua API 55 or later.

Turn on the on-screen tracker from the shopping list (Show / hide) or with /ledgertrack. It shows what you still need, grouped by recipe like the quest list, and its title bar only shows when you point at it. Stretch it from any edge, right-click it to fade it, or pick a background shade (None, Light, Medium, Dark). Click x on a recipe to take it off the tracker; it stays on your shopping list, and Track all brings it back. It remembers its place and size.

## Installation

Import or extract the complete crafters-ledger folder, including manifest.json and icon.png. Disable older copies before enabling this version. Keep CraftersLedger-data.tsv and ShoppingCart-data.tsv in the main Lua folder to preserve saved lists. Run /lua reload after updating.

## 3.2.13

The shopping list now stays inside the available window area. Scroll with the mouse wheel or drag the native scrollbar when expanded recipes extend below the list. Search, filters, totals, and page controls stay outside the scrolling area.
