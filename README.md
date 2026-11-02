# Crafters Ledger

Creator: Kronic | Version 3.4.0

Open with /ledger, the ledger icon, or a shortcut configured in Add-Ons. Toggle the on-screen Shopping list with /ledgertrack.

## Add items
Choose Craft something, search learned recipes, select an item, enter the finished quantity and Add to cart. Material alternatives appear in the preview. Paste a list accepts 2 x Iron Lantern or Iron Lantern: 2, separated by newlines or semicolons. Enter queues each row. Valid items add; unresolved ones remain in the draft with an Activity error. Calculations use prepared components, not recursively expanded raw materials.

Choose Find/add resources to search what you own and where it is stored, or add resource quantities directly. Paste resource quantities opens the advanced importer. Existing Item=quantity lists and item/material groups remain supported.

## Cart and Wishlist
Switch between By crafted item and Cart (combined resources). Required is the total for the plan; Owned counts selected Inventory/Account sources; Still to get is the remaining shortage. Note identifies the crafted items. Calculated quantities are read-only. Remove a crafted-item group and add the desired plan again to replace it. Clear cart requires confirmation.

The star Wishlist button opens a separate window. Add any item name and quantity, then Add to cart when needed. Repeated clicks do not increase the target repeatedly. Clearing the cart preserves your wishlist.

## Recipes
Learned and Missing share one search box; blank searches show no results. Missing compares your known recipes with MasterRecipes.lua and cannot discover entries absent from that file. Wishlist saves the recipe for later; Add to cart adds its Recipe: scroll. This does not purchase it or guarantee it is sold by NPCs. Refresh after learning recipes.

## Shopping list tracker and Activity
Show/hide the tracker from Cart. Its filter (Still needed / All resources / Ready), layout (By item / Resource list) and background are saved. Rows show only the remaining quantity by default. Resize or use the window's text/opacity controls. The information symbol toggles a separate Source popup without needing the main window open.

Activity keeps the last 100 messages for the current Lua session: green additions, red problems/removals, blue information. Clear history does not clear the cart. Full errors append to CraftersLedger-errors.log.

## Sources
Sources.lua contains a small verified offline reference set: Recipe: Iron Lantern, Wax, Maple Binding and three crafting-chest patterns. Other entries show Unknown. Reference URLs are selectable for copying. Vendor data is not live.

## Installation and updates
Install from Community Addons, or extract the complete crafters-ledger folder into your Lua add-on folder. Keep manifest.json, MasterRecipes.lua, Sources.lua, CraftersLedger.lua and icon.png together. Enable Crafters Ledger and run /lua reload. Disable the separate test add-on before checking production.

Production uses CraftersLedger-data.tsv and CraftersLedger-counts.tsv in the main Lua folder. Preserve these files when updating. Test data remains separate and is not copied automatically. API 37+ is required; account-wide counts require API 55+.

Your existing inventory-location search, container labels and compass marks remain supported. Stand beside a chest to mark its location before using its compass action.
