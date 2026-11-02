-- Small, verified source reference set. Unknown entries are never guessed.
-- Checked 2026-11-02 against the linked SotAwiki pages; not live vendor inventory.
CraftersLedgerSources={
    ['Recipe: Iron Lantern']={source='NPC vendor',vendor='Housing Decorations Merchant',trade='Blacksmithing',
        location='Goti: second floor of the bank, northwest of Town Square.',
        reference='https://sotawiki.org/sota/Housing_Decorations_Merchant_%28Goti%29'},
    ['Wax']={source='NPC vendor',vendor='Crafting Supplies Merchant / Tailor / Textile Merchant',trade='Multiple crafting trades',
        location='Examples: Chaoxiang, Castle Atos; Chip Leland, Ardoris; Isabel Spalding, Aerie.',
        reference='https://sotawiki.org/sota/Wax'},
    ['Maple Binding']={source='Crafted component',vendor='No verified NPC vendor in this reference set',trade='Milling',
        location='Make at a Milling Station. Maple Timber x2 + Wax x1 (tool required).',
        reference='https://sotawiki.org/sota/Wax'},
}
for _,trade in ipairs({'Tailoring','Tanning','Textiles'}) do
    CraftersLedgerSources['Pattern: '..trade..' Crafting Chest']={source='NPC vendor',vendor='Decorations Merchant',
        trade='Carpentry (apply chest pattern)',location='Castle Atos: Market Square. Listed price: 200 gold.',
        reference='https://sotawiki.org/sota/Decorations_Merchant%28Castle_Atos%29'}
end
