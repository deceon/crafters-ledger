-- Crafters Ledger v3.3.0. Legacy ShoppingCart commands and save file remain compatible.
ShoppingCart = {items={},projects={},sources={},amounts={},countInv=true,countAcct=false,
    tracker={shown=false,shade=25,x=nil,y=nil,w=nil,h=nil},untracked={},
    spots={},                 -- where you marked a chest: key -> {raw,x,y,z}
    nicknames={}}             -- your own name for a container: key -> "Reagent Chest"
MarketBasket = ShoppingCart
CraftersLedger = ShoppingCart
local C=ShoppingCart
local filename = type(ShroudLuaPath)=='string' and
    (ShroudLuaPath..'/CraftersLedger-data.tsv') or nil
local function say(s) print('[Crafters Ledger] '..s) end
local function valid(name)
    return type(name)=='string' and #name>0 and not name:find('[\t\r\n]')
end
function C.save()
    if not filename or type(io)~='table' or type(io.open)~='function' then
        say('File saving unavailable. This cart lasts until Lua reloads.'); return false
    end
    local ok,err=pcall(function()
        local f,e=io.open(filename,'w'); if not f then error(e) end
        local names={}; for name in pairs(C.items) do names[#names+1]=name end
        table.sort(names)
        for _,name in ipairs(names) do f:write(name,'\t',tostring(C.items[name]),'\n') end
        for title,project in pairs(C.projects) do
            f:write('@project\t',title,'\t',tostring(project.crafts),'\t',project.output or '', '\n')
        end
        for name,sources in pairs(C.sources) do
            if C.items[name] then
                for title in pairs(sources) do f:write('@source\t',name,'\t',title,'\n') end
            end
        end
        -- per-recipe share of each material, so removing a recipe can take back its amount
        for name,shares in pairs(C.amounts) do
            if C.items[name] then
                for title,n in pairs(shares) do
                    if C.sources[name] and C.sources[name][title] then
                        f:write('@amount\t',name,'\t',title,'\t',tostring(n),'\n')
                    end
                end
            end
        end
        -- which places Have counts: the Inventory and Account checkboxes
        f:write('@counts\t',C.countInv and '1' or '0','\t',C.countAcct and '1' or '0','\n')
        local t=C.tracker
        f:write('@tracker\t',t.shown and '1' or '0','\t',tostring(t.shade),'\t',tostring(t.x or ''),'\t',tostring(t.y or ''),
            '\t',tostring(t.w or ''),'\t',tostring(t.h or ''),'\n')
        -- recipes taken off the tracker (still on the shopping list)
        for title in pairs(C.untracked) do f:write('@untrack\t',title,'\n') end
        for key,nick in pairs(C.nicknames) do f:write('@nickname\t',key,'\t',nick,'\n') end
        for key,sp in pairs(C.spots) do
            f:write('@spot\t',key,'\t',sp.raw,'\t',string.format('%.2f\t%.2f\t%.2f',sp.x,sp.y,sp.z),'\n')
        end
        f:close()
    end)
    if not ok then say('Save failed: '..tostring(err)); return false end
    return true
end
function C.add(name,quantity)
    quantity=tonumber(quantity)
    if not valid(name) or not quantity or quantity<1 or quantity~=math.floor(quantity) then
        say('Use ShoppingCart.add("Item Name", positive whole number)'); return
    end
    C.items[name]=(C.items[name] or 0)+quantity
    say(name..': target '..C.items[name])
    if C.save() then say('Saved.') end
end
function C.set(name,quantity)
    quantity=tonumber(quantity)
    if not valid(name) or not quantity or quantity<1 or quantity~=math.floor(quantity) then
        say('Use ShoppingCart.set("Item Name", positive whole number)'); return
    end
    C.items[name]=quantity
    -- one recipe using it: that recipe's share is the whole target now
    local only,count=nil,0
    for title in pairs(C.sources[name] or {}) do only=title; count=count+1 end
    if count==1 then C.amounts[name]={[only]=quantity} end
    if C.save() then say('Saved.') end
end
function C.remove(name)
    C.items[name]=nil; C.sources[name]=nil; C.amounts[name]=nil; C.save(); say('Removed: '..tostring(name))
end
-- Takes a whole recipe off the list: its label, its craft count and the
-- materials it added. Materials shared with other recipes keep the other
-- recipes' amounts.
function C.removeRecipe(title)
    if not valid(title) then return 0 end
    local removed,kept=0,0
    for name,sources in pairs(C.sources) do
        if sources[title] then
            sources[title]=nil
            local share=C.amounts[name] and C.amounts[name][title]
            if C.amounts[name] then C.amounts[name][title]=nil end
            if next(sources)==nil then
                C.items[name]=nil; C.sources[name]=nil; C.amounts[name]=nil; removed=removed+1
            else
                if share and C.items[name] then
                    local left=C.items[name]-share
                    if left>=1 then C.items[name]=left else C.items[name]=1 end
                end
                kept=kept+1
            end
        end
    end
    C.projects[title]=nil; C.untracked[title]=nil
    C.save()
    say('Removed recipe: '..title)
    return removed,kept
end
function C.show()
    local ok,inventory=pcall(ShroudGetInventoryItems)
    if not ok or type(inventory)~='table' then say('Inventory unavailable; try again in game.'); return end
    local counts={}
    for _,item in pairs(inventory) do
        if type(item)=='table' and type(item.name)=='string' then
            local key=string.lower(item.name)
            counts[key]=(counts[key] or 0)+(tonumber(item.quantity) or 0)
        end
    end
    local names={}; for name in pairs(C.items) do names[#names+1]=name end
    table.sort(names)
    if #names==0 then say('Cart empty. Add an item to get started.'); return end
    say('Item | Target | Carrying | Still need')
    for _,name in ipairs(names) do
        local target=C.items[name]
        local have=counts[string.lower(name)] or 0
        say(name..' | '..target..' | '..have..' | '..math.max(0,target-have))
    end
    say('Exact item names; carried inventory only. Run show() to refresh.')
end
function C.holly(crafts)
    crafts=tonumber(crafts) or 1
    if crafts<1 or crafts~=math.floor(crafts) then say('Enter a positive whole number of crafts.'); return end
    local list={{'Turkey Meat',1},{'Bacon',2},{'Potato',2},{'Pepper',1},
                {'Bottle of Milk',1},{'Bread Loaf',2},{'Chunk of Coal',1}}
    for _,r in ipairs(list) do C.items[r[1]]=(C.items[r[1]] or 0)+r[2]*crafts end
    say('Added supplies for '..crafts..' Holly crafts. Bread Loaf selected as bread type.')
    C.save(); C.show()
end
local function loadCart()
    if not filename or type(io)~='table' or type(io.open)~='function' then return end
    local f=io.open(filename,'r')
    if not f and type(ShroudLuaPath)=='string' then
        for _,old in ipairs({ShroudLuaPath..'/ShoppingCart-data.tsv',
            ShroudLuaPath..'/../shoppingcart/ShoppingCart-data.tsv'}) do
            f=io.open(old,'r')
            if f then say('Imported your previous shopping list.'); break end
        end
    end
    if not f then return end
    for line in f:lines() do
        if line:sub(1,9)=='@project\t' then
            local title,n,output=line:match('^@project\t([^\t]+)\t(%d+)\t(.*)$')
            if valid(title) and tonumber(n) then C.projects[title]={crafts=tonumber(n),output=output} end
        elseif line:sub(1,8)=='@source\t' then
            local name,title=line:match('^@source\t([^\t]+)\t([^\t]+)$')
            if valid(name) and valid(title) then C.sources[name]=C.sources[name] or {}; C.sources[name][title]=true end
        elseif line:sub(1,9)=='@tracker\t' then
            local shown,shade,x,y,rest=line:match('^@tracker\t([01])\t(%d+)\t(%-?%d*)\t(%-?%d*)(.*)$')
            if shown then
                local w,h=tostring(rest):match('^\t(%d*)\t(%d*)$')
                C.tracker={shown=shown=='1',shade=math.min(90,tonumber(shade) or 25),x=tonumber(x),y=tonumber(y),
                    w=tonumber(w),h=tonumber(h)}
            end
        elseif line:sub(1,10)=='@nickname\t' then
            local key,nick=line:match('^@nickname\t([^\t]+)\t([^\t]+)$')
            if key and valid(nick) then C.nicknames[key]=nick end
        elseif line:sub(1,6)=='@spot\t' then
            local key,raw,x,y,z=line:match('^@spot\t([^\t]+)\t([^\t]+)\t([%-%d%.]+)\t([%-%d%.]+)\t([%-%d%.]+)$')
            if key then C.spots[key]={raw=raw,x=tonumber(x),y=tonumber(y),z=tonumber(z)} end
        elseif line:sub(1,9)=='@untrack\t' then
            local title=line:match('^@untrack\t([^\t]+)$')
            if valid(title) then C.untracked[title]=true end
        elseif line:sub(1,8)=='@counts\t' then
            local inv,acct=line:match('^@counts\t([01])\t([01])$')
            if inv then
                C.countInv=inv=='1'; C.countAcct=acct=='1'
                if not C.countInv and not C.countAcct then C.countInv=true end
            end
        elseif line:sub(1,8)=='@amount\t' then
            local name,title,n=line:match('^@amount\t([^\t]+)\t([^\t]+)\t(%d+)$')
            n=tonumber(n)
            if valid(name) and valid(title) and n then C.amounts[name]=C.amounts[name] or {}; C.amounts[name][title]=n end
        else
            local name,n=line:match('^(.-)\t(%d+)$')
            n=tonumber(n)
            if valid(name) and n and n>0 then C.items[name]=n end
        end
    end
    f:close()
end
local ok,err=pcall(loadCart)
if not ok then say('Could not load saved cart: '..tostring(err)) end
if ok and next(C.items)~=nil then C.save() end
say('Loaded. Open with /ledger or the book icon.')

-- ShoppingCart v2: recipe browser and persistent material cart.
-- UI constructors follow the Shroud.UI interface used by installed add-ons.
local UI,win,el = nil,nil,{}
local recipes,selected,picks = {},nil,{}
local page,recipePage = 1,1
local matches={}
local PAGE=12
local RECIPE_PAGE=4
local detailCache={}
local renderMatches
local function field(o,k)
    local ok,v=pcall(function() return o[k] end)
    if ok then return v end
end
local function list(v) return type(v)=='table' and v or {} end
local function trim(s) return (tostring(s or ''):gsub('^%s+',''):gsub('%s+$','')) end
local function number(s)
    local n=tonumber(s)
    if n and n>=1 and n==math.floor(n) then return n end
end
local function msg(s)
    if el.message then el.message:SetText(s) end
    say(s)
end
local function label(text,width)
    return UI.Label{text=tostring(text),style={width=width,flexShrink=width and 0 or 1,
        flexGrow=0,whiteSpace='wrap',fontSize=13}}
end
local function flexLabel(text)
    return UI.Label{text=tostring(text),style={flexGrow=1,flexShrink=1,whiteSpace='wrap',fontSize=13}}
end
local function row(children)
    return UI.Row{style={alignItems='center',marginTop=4,flexShrink=0},children=children}
end
local function counts()
    local ok,items=pcall(ShroudGetInventoryItems)
    if not ok or type(items)~='table' then return nil end
    local result={}
    for _,item in pairs(items) do
        local name=field(item,'name')
        if type(name)=='string' then
            local k=string.lower(name)
            result[k]=(result[k] or 0)+(tonumber(field(item,'quantity')) or 0)
        end
    end
    return result
end

-- Account-wide counts (Lua API 55+). ShroudSearchOwnedItems takes an exact item name and answers a few
-- frames later through a function: total, totals by place (carried, bank, houseStorage, otherCharacters,
-- mail, crafting, vendorListings, ransom, unknown) and a row per place/container. A few lookups run at
-- once; answers are kept for a minute. The callback only stores data; the UI reads it on update.
local clockNow=0
local owned={}           -- lower name -> {at,name,total,carried,account,rows,missing,truncated}
local ownedWant,ownedQueued,inflight={},{},{}
local ownedVersion=0     -- goes up with every answer, so pages know to redraw
-- One search at a time: the game runs one "search everywhere" at a time, like its own Search All My
-- Stuff window, and a second one sent meanwhile may get no answer.
local OWNED_MAX,OWNED_TIMEOUT,OWNED_AGE,OWNED_RETRY=1,10,300,30
local PLACE_NAMES={carried='Bag',bank='Bank',houseStorage='House',otherCharacters='Other character',
    mail='Mail',crafting='Crafting',vendorListings='Vendor',ransom='Ransom',unknown='Other'}
local function canCountAccount() return type(ShroudSearchOwnedItems)=='function' end
local function wantOwned(name,front)
    if not canCountAccount() or not valid(name) then return end
    local k=string.lower(name)
    if inflight[k] then return end
    local o=owned[k]
    if o and clockNow-o.at<OWNED_AGE then return end
    if ownedQueued[k] then
        if not front then return end
        for i,n in ipairs(ownedWant) do if string.lower(n)==k then table.remove(ownedWant,i); break end end
    end
    ownedQueued[k]=true
    if front then table.insert(ownedWant,1,name) else ownedWant[#ownedWant+1]=name end
end
local function storeOwned(asked,res)
    local k=string.lower(asked)
    inflight[k]=nil
    ownedVersion=ownedVersion+1
    if type(res)~='table' then owned[k]={at=clockNow,name=asked,missing=true,total=0,carried=0,account=0,rows={}}; return end
    local totals=field(res,'totals')
    local carried=tonumber(type(totals)=='table' and field(totals,'carried')) or 0
    local total=tonumber(field(res,'total')) or 0
    local rows={}
    for _,r in ipairs(list(field(res,'rows'))) do
        if type(r)=='table' then
            rows[#rows+1]={place=tostring(field(r,'place') or 'unknown'),location=field(r,'location'),
                container=field(r,'container'),quantity=tonumber(field(r,'quantity')) or 0}
        end
    end
    if field(res,'ok')==false then
        -- the game said no: keep the old numbers if there are any, and ask again a bit later
        local why=tostring(field(res,'error') or field(res,'reason') or field(res,'message') or 'no reason given')
        local old=owned[k]
        if old and not old.failed then old.at=clockNow-OWNED_AGE+OWNED_RETRY; old.why=why; return end
        owned[k]={at=clockNow-OWNED_AGE+OWNED_RETRY,name=asked,failed=true,why=why,total=0,carried=0,account=0,rows={}}
        return
    end
    owned[k]={at=clockNow,name=field(res,'name') or asked,total=total,carried=carried,
        account=math.max(0,total-carried),rows=rows,truncated=field(res,'truncated')==true,
        missing=total==0 and #rows==0}
end
local function pumpOwned()
    if not canCountAccount() then return end
    local busy=0
    for k,t0 in pairs(inflight) do
        if clockNow-t0>OWNED_TIMEOUT then
            -- no answer: often not an exact item name, sometimes just a slow search. Keep any old
            -- numbers, show the quick bag-and-bank count meanwhile, and ask again a bit later.
            inflight[k]=nil; ownedVersion=ownedVersion+1
            local old=owned[k]
            if old and not old.failed then old.at=clockNow-OWNED_AGE+OWNED_RETRY
            else owned[k]={at=clockNow-OWNED_AGE+OWNED_RETRY,name=k,failed=true,why='no answer',total=0,carried=0,account=0,rows={}} end
        else busy=busy+1 end
    end
    while busy<OWNED_MAX and #ownedWant>0 do
        local name=table.remove(ownedWant,1)
        local k=string.lower(name)
        ownedQueued[k]=nil; inflight[k]=clockNow; busy=busy+1
        local ok=pcall(ShroudSearchOwnedItems,name,function(res) storeOwned(name,res) end)
        if not ok then storeOwned(name,nil) end
    end
end
local function forgetOwned()
    -- mark everything out of date but keep showing the old numbers until the new ones arrive
    for _,o in pairs(owned) do o.at=-math.huge end
end
-- Quick count (Lua API 55): ShroudGetOwnedCounts answers at once but only knows your bag and bank,
-- not house chests or other characters. Shown while the full search is on its way. A few per frame.
local quick={}               -- lower name -> {at,carried,account} (bag and bank only)
local quickLeft=0            -- quick lookups still allowed this frame
local QUICK_PER_FRAME=12
local function quickCount(name)
    local k=string.lower(name)
    local q=quick[k]
    if q and clockNow-q.at<30 then return q end
    if type(ShroudGetOwnedCounts)~='function' or quickLeft<=0 then return q end
    quickLeft=quickLeft-1
    local ok,r=pcall(ShroudGetOwnedCounts,name)
    if ok and type(r)=='table' then
        local carried=tonumber(field(r,'carried')) or 0
        local total=tonumber(field(r,'total')) or carried
        q={at=clockNow,carried=carried,account=math.max(0,total-carried)}
    else q={at=clockNow,carried=0,account=0} end
    quick[k]=q
    return q
end
-- Saved counts: the last full account counts are written to a file when you reload or log out, and
-- read back at login, so the numbers show straight away while fresh ones are fetched.
local countsFile=type(ShroudLuaPath)=='string' and (ShroudLuaPath..'/CraftersLedger-counts.tsv') or nil
local function saveCounts()
    if not countsFile or type(io)~='table' or type(io.open)~='function' then return end
    pcall(function()
        local f=io.open(countsFile,'w'); if not f then return end
        for k,o in pairs(owned) do
            if not o.missing and not o.failed and valid(o.name) then
                f:write('@item\t',o.name,'\t',tostring(o.total),'\t',tostring(o.carried),'\n')
                for _,r in ipairs(o.rows or {}) do
                    f:write('@row\t',o.name,'\t',tostring(r.place),'\t',(tostring(r.location or '')):gsub('[\t\r\n]',' '),'\t',
                        (tostring(r.container or '')):gsub('[\t\r\n]',' '),'\t',tostring(r.quantity),'\n')
                end
            end
        end
        f:close()
    end)
end
local function loadCounts()
    if not countsFile or type(io)~='table' or type(io.open)~='function' then return end
    pcall(function()
        local f=io.open(countsFile,'r'); if not f then return end
        for line in f:lines() do
            local name,total,carried=line:match('^@item\t([^\t]+)\t(%d+)\t(%d+)$')
            if name then
                -- out of date on purpose: shown now, fetched again soon
                owned[string.lower(name)]={at=-math.huge,name=name,total=tonumber(total),carried=tonumber(carried),
                    account=math.max(0,tonumber(total)-tonumber(carried)),rows={},saved=true}
            else
                local n,place,loc,box,q=line:match('^@row\t([^\t]+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(%d+)$')
                local o=n and owned[string.lower(n)]
                if o then o.rows[#o.rows+1]={place=place,location=loc~='' and loc or nil,container=box~='' and box or nil,quantity=tonumber(q)} end
            end
        end
        f:close()
    end)
end
loadCounts()
-- /lua code CraftersLedger.check('Black Pearl') prints exactly what the game answers for an item.
function C.check(name)
    name=tostring(name or '')
    if type(ShroudSearchOwnedItems)~='function' then say('This game client has no account search.'); return end
    local t0=clockNow
    say('Asking the game about "'..name..'"...')
    local function dump(v,pad,depth)
        if type(v)~='table' then say(pad..tostring(v)); return end
        local keys={}
        for key in pairs(v) do keys[#keys+1]=key end
        table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
        for _,key in ipairs(keys) do
            local x=v[key]
            if type(x)=='table' and depth<3 then say(pad..tostring(key)..':'); dump(x,pad..'   ',depth+1)
            else say(pad..tostring(key)..' = '..tostring(x)) end
        end
    end
    local ok,err=pcall(ShroudSearchOwnedItems,name,function(res,...)
        say(string.format('Answer after %.1f s:',clockNow-t0)); dump(res,'   ',1)
        if select('#',...)>0 then say('   (and '..select('#',...)..' more values)') end
    end)
    if not ok then say('The game refused: '..tostring(err)) end
    if type(ShroudGetOwnedCounts)=='function' then
        local ok2,q=pcall(ShroudGetOwnedCounts,name)
        say('Quick count:'); dump(ok2 and q or ('error '..tostring(q)),'   ',1)
    end
end
-- How many of an item the checked places hold. nil while an account count is still on its way.
-- inv is counts(): what this character carries, read straight from the bag.
local function haveOf(name,inv)
    local k=string.lower(name)
    local bag=inv and (inv[k] or 0)
    if not C.countAcct or not canCountAccount() then return bag end
    wantOwned(name)
    local o=owned[k]
    if o and o.failed then o=nil end
    local acct=o and o.account
    local carried=o and o.carried
    if not o then
        -- full search still on its way (or no answer): bag and bank for now
        local q=quickCount(name)
        if not q then return bag and (C.countInv and bag or nil) end
        acct=q.account; carried=q.carried
    end
    if not C.countInv then return acct end
    -- the game's count includes bags you carry; the plain bag list doesn't look inside them
    return math.max(bag or 0,carried or 0)+acct
end
local function countingText()
    if C.countAcct and canCountAccount() then
        return C.countInv and 'Counting your bag and account (bank, house, other characters)'
            or 'Counting your account only (bank, house, other characters), not your bag'
    end
    return 'Counting your bag only'
end
local refreshCart,preview,findRecipes
local trackerToggleRequested=false
local cartStructure=nil
local cartCells={}
local projectSignature=nil
local function sourceText(name)
    local names={}
    for title in pairs(C.sources[name] or {}) do names[#names+1]=title end
    table.sort(names)
    return #names>0 and ('Used for: '..table.concat(names,', ')) or 'Unassigned - label from Recipes'
end
local cartFilter='To get'
local cartQuery=''
local refreshSummary=nil
local expanded={}
refreshCart=function()
    if not el.cart then return end
    local have=counts()
    local groups={}
    local total,ready,units=0,0,0
    for name,target in pairs(C.items) do
        total=total+1
        local n=haveOf(name,have)
        local missing=n and math.max(0,target-n)
        if missing==0 then ready=ready+1 end
        units=units+(missing or 0)
        local included=cartFilter=='All' or (cartFilter=='Ready' and missing==0)
            or (cartFilter=='To get' and missing~=0)
        local titles={}
        for title in pairs(C.sources[name] or {}) do titles[#titles+1]=title end
        if #titles==0 then titles={'Other materials'} end
        for _,title in ipairs(titles) do
            if included and (string.find(string.lower(name),cartQuery,1,true)
                or string.find(string.lower(title),cartQuery,1,true)) then
                groups[title]=groups[title] or {}; groups[title][#groups[title]+1]=name
            end
        end
    end
    local summary=(have or C.countAcct) and (ready..' of '..total..' materials ready | '..units..' units still to get')
        or (total..' materials | Inventory unavailable')
    if el.summary and refreshSummary~=summary then el.summary:SetText(summary); refreshSummary=summary end
    local titles={}; for title in pairs(groups) do titles[#titles+1]=title end; table.sort(titles)
    local pages=math.max(1,math.ceil(#titles/PAGE)); page=math.min(page,pages)
    local parts={tostring(page),cartFilter}
    for _,title in ipairs(titles) do
        table.sort(groups[title])
        local project=C.projects[title]
        parts[#parts+1]=title..'|'..(project and (project.crafts..'|'..(project.output or '')) or '')
        parts[#parts+1]=table.concat(groups[title],'\t')
    end
    local signature=table.concat(parts,'\n')
    if signature~=cartStructure then
        cartStructure=signature; cartCells={}; el.cart:Clear()
        for i=(page-1)*PAGE+1,math.min(page*PAGE,#titles) do
            local title=titles[i]
            local project=C.projects[title]
            local content=UI.Column{visible=expanded[title]==true,style={paddingLeft=18,paddingBottom=8,flexShrink=0}}
            content:Add(row{flexLabel('Material'),label('To get',70),label('Have',65),label('Needed',115),label('',65)})
            for _,name in ipairs(groups[title]) do
                local amount=label('',65); local missing=label('',70)
                local target
                local function setNeeded()
                    local n=number(trim(target:GetText()))
                    if not n then
                        msg('Needed must be a whole number, 1 or more. Use Remove to take '..name..' off the list.')
                        target:SetText(tostring(C.items[name] or '')); return
                    end
                    if not C.items[name] then return end
                    C.set(name,n); refreshCart()
                    msg('Needed for '..name..' is now '..n..'.')
                end
                target=UI.TextField{text=tostring(C.items[name] or ''),maxLength=7,style={width=65},
                    tooltip='Type the amount you need, then press Enter or Set',onSubmit=setNeeded}
                local cell={name=name,target=target,amount=amount,status=missing,lastTarget=C.items[name]}
                cartCells[#cartCells+1]=cell
                local sourceCount=0; for _ in pairs(C.sources[name] or {}) do sourceCount=sourceCount+1 end
                local nameLabel=sourceCount>1 and (name..' (shared total)') or name
                content:Add(row{flexLabel(nameLabel),missing,amount,target,
                    UI.Button{text='Set',style={width=46},onClick=setNeeded},
                    UI.Button{text='Remove',style={width=65},onClick=function() C.remove(name); refreshCart() end}})
            end
            local toggle
            toggle=UI.Button{text=expanded[title] and '-' or '+',style={width=32},onClick=function()
                expanded[title]=not expanded[title]
                content:SetVisible(expanded[title]); toggle:SetText(expanded[title] and '-' or '+')
            end}
            local header={toggle,UI.Label{text=title,class='heading',style={flexGrow=1,flexShrink=1,whiteSpace='wrap',fontSize=16}}}
            if title~='Other materials' then
                -- X takes the whole recipe off the list; it asks once before removing
                local sure=false
                local drop
                drop=UI.Button{text='X',style={width=70},tooltip='Remove this recipe and its materials from the list',
                    onClick=function()
                        if not sure then
                            sure=true; drop:SetText('Sure?')
                            msg('Click Sure? to remove '..title..' and its materials. Materials other recipes use stay.')
                            return
                        end
                        local removed,kept=C.removeRecipe(title)
                        expanded[title]=nil; refreshCart()
                        msg('Removed '..title..': '..removed..' materials removed'..
                            (kept>0 and (', '..kept..' shared materials kept for other recipes.') or '.'))
                    end}
                header[#header+1]=drop
            end
            local children={row(header)}
            if project then children[#children+1]=label(project.crafts..' crafts'..
                ((project.output or '')~='' and (' | '..project.output) or '')) end
            children[#children+1]=content
            el.cart:Add(UI.Column{style={paddingTop=8,paddingBottom=8,marginBottom=6,flexShrink=0},children=children})
        end
        if #titles==0 then el.cart:Add(label(total==0 and 'Your list is empty. Add a recipe or materials to begin.'
            or 'No materials match this view. Choose All to see completed entries.')) end
        el.cartPage:SetText('Page '..page..' / '..pages..' - '..#titles..' entries')
    end
    for _,cell in ipairs(cartCells) do
        local target=C.items[cell.name]
        local n=haveOf(cell.name,have)
        local text=n and tostring(n) or (C.countAcct and '...' or '?')
        local missing=n and target and math.max(0,target-n)
        local status=missing and tostring(missing) or '?'
        local color=missing==0 and '@green' or '@red'
        if target and cell.lastTarget~=target then cell.target:SetText(tostring(target)); cell.lastTarget=target end
        if cell.lastText~=text then cell.amount:SetText(text); cell.lastText=text end
        if cell.lastStatus~=status then cell.status:SetText(status); cell.lastStatus=status end
        if cell.lastColor~=color then cell.status:SetStyle{color=color}; cell.lastColor=color end
    end
end
local function recipeRows()
    local rows={}
    local n=number(el.crafts:GetText())
    if not n then return nil,'Enter a positive whole number of crafts.' end
    if not selected then return nil,'Select a recipe first.' end
    for i,ing in ipairs(list(field(selected,'ingredients'))) do
        if field(ing,'optional')~=true then
            local item=ing
            if field(ing,'group')==true then
                local choices=list(field(ing,'choices'))
                item=choices[picks[i] or 1]
                if not item then return nil,'Choose a material for '..tostring(field(ing,'name')) end
            end
            local name=field(item,'name')
            local qty=tonumber(field(ing,'quantity'))
            if not valid(name) or not qty or qty<1 or qty~=math.floor(qty) then
                return nil,'Ingredient details unavailable. Use a manual material list for this recipe.'
            end
            rows[#rows+1]={name=name,quantity=qty*(field(ing,'tool')==true and 1 or n),
                tool=field(ing,'tool')==true}
        end
    end
    if #rows==0 then return nil,'No required ingredients returned for this recipe.' end
    return rows
end
local previewPending,previewVersion=false,0
preview=function()
    if not el.preview then return end
    previewPending=false; previewVersion=ownedVersion
    el.preview:Clear()
    if not selected then el.preview:Add(label('Search your recipes and select one to see its materials.')); return end
    local n=number(el.crafts:GetText()) or 1
    local skill=tostring(field(selected,'category') or 'Skill not supplied')
    local lvl=field(selected,'requiredLevel')
    el.preview:Add(label(tostring(field(selected,'name'))))
    el.preview:Add(label(skill..' - Required level: '..tostring(lvl or 'not supplied')..
        ' - '..tostring(field(selected,'station') or 'Station not supplied')))
    local results={}
    for _,r in ipairs(list(field(selected,'results'))) do
        local q=tonumber(field(r,'quantity'))
        results[#results+1]=tostring(q and q*n or '?')..' x '..tostring(field(r,'name') or '?')
    end
    el.preview:Add(label('Makes for '..n..' crafts: '..(#results>0 and table.concat(results,', ') or 'yield not supplied')))
    local have=counts() or {}
    for i,ing in ipairs(list(field(selected,'ingredients'))) do
        local qty=tonumber(field(ing,'quantity'))
        local tool=field(ing,'tool')==true
        local optional=field(ing,'optional')==true
        local suffix=tool and ' (tool, not consumed)' or (optional and ' (optional, not added)' or '')
        local item=ing
        local children={}
        if field(ing,'group')==true then
            local choices=list(field(ing,'choices'))
            local names={}; local byName={}
            for j,c in ipairs(choices) do
                local name=tostring(field(c,'name') or ('Choice '..j))
                names[#names+1]=name; byName[name]=j
            end
            local ix=i
            local picked=picks[ix] or 1
            item=choices[picked] or ing
            if #names>0 then
                children[#children+1]=UI.Dropdown{choices=names,value=names[picked],style={flexGrow=1},
                    onChange=function(_,v) picks[ix]=byName[v]; preview() end}
            else children[#children+1]=label(tostring(field(ing,'name'))..' (choices unavailable)') end
        else children[#children+1]=flexLabel(tostring(field(ing,'name') or 'Unnamed ingredient')..suffix) end
        local needed=qty and qty*(tool and 1 or n)
        children[#children+1]=label('Need '..tostring(needed or '?'),85)
        local itemName=tostring(field(item,'name') or '')
        local h=valid(itemName) and haveOf(itemName,have) or 0
        if h==nil then previewPending=true end
        children[#children+1]=label('Have '..(h or '...'),80)
        el.preview:Add(row(children))
    end
end
local function selectRecipe(r)
    if type(ShroudGetRecipe)=='function' and field(r,'id')~=nil then
        local ok,detail=pcall(ShroudGetRecipe,field(r,'id'))
        if ok and detail and field(detail,'name') then r=detail end
    end
    selected=r; picks={}; preview()
end
local function detail(r)
    local id=field(r,'id')
    if id and detailCache[id] then return detailCache[id] end
    if id and type(ShroudGetRecipe)=='function' then
        local ok,v=pcall(ShroudGetRecipe,id)
        if ok and v and field(v,'name') then r=v; detailCache[id]=v end
    end
    return r
end
local function amountLabel(have,need)
    local text=have..' / '..need
    if have<need then text=text..'  (buy '..(need-have)..')' end
    return UI.Label{text=text,style={width=165,flexShrink=0,fontSize=13,
        color=have>=need and '@green' or '@red'}}
end
renderMatches=function()
    if not el.matches then return end
    el.matches:Clear()
    local pages=math.max(1,math.ceil(#matches/RECIPE_PAGE))
    recipePage=math.min(recipePage,pages)
    local have=counts() or {}
    local n=number(el.crafts:GetText()) or 1
    for i=(recipePage-1)*RECIPE_PAGE+1,math.min(recipePage*RECIPE_PAGE,#matches) do
        local r=matches[i]
        el.matches:Add(UI.Button{text=tostring(field(r,'name')),onClick=function() selectRecipe(r) end})
    end
    if #matches==0 then el.matches:Add(label('No matching recipes. Search another name or use a material list.')) end
    el.matchPage:SetText(#matches..' recipes - page '..recipePage..' / '..pages)
end
local quietRead=false
local function readRecipes()
    local ok,book=false,nil
    if type(ShroudGetKnownRecipes)=='function' then ok,book=pcall(ShroudGetKnownRecipes) end
    if not ok or type(book)~='table' or next(book)==nil then
        ok,book=pcall(ShroudGetRecipeBook)
    end
    if not ok or type(book)~='table' then if not quietRead then msg('Could not read your recipe book.') end; return end
    recipes={}; detailCache={}; itemIndex=nil; indexJob=nil
    for _,r in pairs(book) do if type(field(r,'name'))=='string' then recipes[#recipes+1]=r end end
    table.sort(recipes,function(a,b) return field(a,'name')<field(b,'name') end)
    if not quietRead then msg('Read '..#recipes..' recipes. Search by part of the name.') end
end
findRecipes=function()
    if #recipes==0 then readRecipes() end
    local search=string.lower(trim(el.search:GetText()))
    matches={}; recipePage=1
    for _,r in ipairs(recipes) do
        if search=='' or string.find(string.lower(field(r,'name')),search,1,true) then matches[#matches+1]=r end
    end
    renderMatches()
end
local navigate=nil
local function addRecipe(linkOnly)
    local rows,err=recipeRows()
    if not rows then msg(err); return end
    local title=tostring(field(selected,'name'))
    if not valid(title) then msg('Recipe name is unavailable.'); return end
    local crafts=number(el.crafts:GetText())
    local linked=0
    for _,r in ipairs(rows) do
        if linkOnly~=true then
            C.items[r.name]=r.tool and math.max(C.items[r.name] or 0,r.quantity)
                or (C.items[r.name] or 0)+r.quantity
        end
        if C.items[r.name] then
            C.sources[r.name]=C.sources[r.name] or {}; C.sources[r.name][title]=true; linked=linked+1
            if linkOnly~=true and not r.tool then
                C.amounts[r.name]=C.amounts[r.name] or {}
                C.amounts[r.name][title]=(C.amounts[r.name][title] or 0)+r.quantity
            end
        end
    end
    if linked==0 then msg('No matching materials already in your list. Use Add ingredients instead.'); return end
    local old=C.projects[title]
    local total=(linkOnly~=true and old and old.crafts or 0)+crafts
    local results={}
    for _,r in ipairs(list(field(selected,'results'))) do
        local quantity=tonumber(field(r,'quantity'))
        if quantity then results[#results+1]=(quantity*total)..' x '..tostring(field(r,'name')) end
    end
    C.projects[title]={crafts=total,output=table.concat(results,', '):gsub('[\t\r\n]',' ')}
    C.untracked[title]=nil
    local saved=C.save(); refreshCart()
    if navigate then navigate('Shopping list') end
    msg((linkOnly==true and 'Labeled existing materials for ' or 'Added materials for ')..title..
        (saved and '. Saved.' or '. Saving failed; see chat.'))
end
local function addManual()
    local name=trim(el.item:GetText())
    local n=number(el.amount:GetText())
    if not valid(name) or not n then msg('Enter an item name and a positive whole quantity.'); return end
    C.add(name,n); refreshCart()
    msg('Added '..name..' to your shopping list.')
end
local function importList()
    local text=el.materials:GetText()
    local staged={}
    for entry in tostring(text):gmatch('[^;\r\n]+') do
        local name,n=entry:match('^%s*(.-)%s*=%s*(%d+)%s*$')
        name=trim(name); n=number(n)
        if not valid(name) or not n then msg('Use Item Name=quantity; Item Name=quantity. Nothing imported.'); return end
        staged[name]=(staged[name] or 0)+n
    end
    if next(staged)==nil then msg('Enter a material list first.'); return end
    for name,n in pairs(staged) do C.items[name]=(C.items[name] or 0)+n end
    local saved=C.save(); refreshCart()
    if navigate then navigate('Shopping list') end
    msg('Material list added.'..(saved and ' Cart saved.' or ' Saving failed; see chat.'))
end

-- Find items: every item your known recipes make or use, plus your shopping list, searchable by part
-- of its name. Built in small timed steps (the game stops an add-on that takes too long in one frame).
local itemIndex=nil          -- lower name -> {name,makes={recipe=true},uses={recipe=true}}
local indexJob=nil
local itemMatches,itemPage,itemCells={},1,{}
local itemQuery=''
local itemOpen={}            -- lower name -> its places are showing
local placeOpen={}           -- lower name..'|'..place key -> that place's containers are showing
local renderItems,refreshItems
local ITEM_PAGE=8
local STEP_SECONDS=0.004     -- time spent per frame building the item list
local function clock()
    if type(os)=='table' and type(os.clock)=='function' then
        local ok,v=pcall(os.clock); if ok and type(v)=='number' then return v end
    end
end
local function indexAdd(items,name,kind,title)
    if not valid(name) then return end
    local k=string.lower(name)
    local it=items[k]
    if not it then it={name=name,makes={},uses={}}; items[k]=it end
    if kind then it[kind][title]=true end
end
local function startIndex(quiet)
    if indexJob then return true end
    if #recipes==0 then quietRead=quiet==true; readRecipes(); quietRead=false end
    if #recipes==0 then return false end      -- recipe book not ready yet: try again later
    indexJob={list=recipes,i=1,items={}}
    if el.itemStatus then el.itemStatus:SetText('Building the item list from '..#recipes..' recipes...') end
    return true
end
local function indexStep()
    local j=indexJob
    local start,done=clock(),0
    while j.i<=#j.list do
        local r=j.list[j.i]; j.i=j.i+1; done=done+1
        local d=detail(r)
        local title=tostring(field(d,'name') or field(r,'name') or '?')
        for _,res in ipairs(list(field(d,'results'))) do indexAdd(j.items,field(res,'name'),'makes',title) end
        for _,ing in ipairs(list(field(d,'ingredients'))) do
            local choices=list(field(ing,'choices'))
            if field(ing,'group')~=true then indexAdd(j.items,field(ing,'name'),'uses',title) end
            for _,c in ipairs(choices) do indexAdd(j.items,field(c,'name'),'uses',title) end
        end
        local t=clock()
        if (start and t and t-start>=STEP_SECONDS) or (not (start and t) and done>=20) then return false end
    end
    itemIndex=j.items; indexJob=nil
    return true
end
local function titlesOf(set)
    local out={}; for title in pairs(set or {}) do out[#out+1]=title end
    table.sort(out); return out
end
local function shortList(names,max)
    if #names==0 then return 'none' end
    local shown={}
    for i=1,math.min(#names,max) do shown[i]=names[i] end
    return table.concat(shown,', ')..(#names>max and (' and '..(#names-max)..' more') or '')
end
local function findItems()
    if not el.itemResults then return end
    itemQuery=string.lower(trim(el.itemSearch:GetText()))
    itemPage=1
    if not itemIndex then startIndex(); itemMatches={}; renderItems(); return end
    local found={}
    local seen={}
    -- every word has to be in the name, in any order, like the game's Search All My Stuff
    local words={}
    for w in itemQuery:gmatch('%S+') do words[#words+1]=w end
    local function matches(k)
        for _,w in ipairs(words) do if not string.find(k,w,1,true) then return false end end
        return true
    end
    local function consider(name,entry)
        if not valid(name) then return end
        local k=string.lower(name)
        if seen[k] then return end
        if matches(k) then
            seen[k]=true
            found[#found+1]={name=entry and entry.name or name,entry=entry or itemIndex[k]}
        end
    end
    if itemQuery=='' then
        -- nothing typed: nothing listed
    else
        for _,entry in pairs(itemIndex) do consider(entry.name,entry) end
        for name in pairs(C.items) do consider(name,nil) end
        -- everything in your bag, even items no recipe uses
        local ok,bag=pcall(ShroudGetInventoryItems)
        if ok and type(bag)=='table' then
            for _,item in pairs(bag) do consider(field(item,'name'),nil) end
        end
        -- items the game has already counted for you
        for _,o in pairs(owned) do if not o.missing and not o.failed and type(o.name)=='string' then consider(o.name,nil) end end
    end
    if el.itemStatus then
        local n=0; for _ in pairs(itemIndex) do n=n+1 end
        el.itemStatus:SetText(itemQuery=='' and ('Type a name or words from it to search all '..n..' items.')
            or ('Searched '..n..' items, your bag and your shopping list. For anything else, type its full name.'))
    end
    -- exact name first, then names starting with the word, then the rest A-Z
    local function rank(f)
        local k=string.lower(f.name)
        if k==itemQuery then return 0 elseif k:sub(1,#itemQuery)==itemQuery then return 1 end
        return 2
    end
    table.sort(found,function(a,b)
        local ra,rb=rank(a),rank(b)
        if ra~=rb then return ra<rb end
        return a.name<b.name
    end)
    -- a typed exact name nobody's recipes mention can still be looked up
    if itemQuery~='' and #found==0 and valid(trim(el.itemSearch:GetText())) then
        found[1]={name=trim(el.itemSearch:GetText()),entry=nil,typed=true}
    end
    itemMatches=found
    renderItems()
end
-- Where an item is, grouped by place: your bag, a bank, each house lot, other characters, mail...
-- Each place has its own total and the containers in it. Only the ticked places count.
local function wherePlaces(o)
    local places,order={},{}
    for _,r in ipairs(o.rows or {}) do
        local isBag=r.place=='carried'
        if (isBag and C.countInv) or (not isBag and C.countAcct) then
            local loc=tostring(r.location or PLACE_NAMES[r.place] or r.place):gsub('%s*%(in a container%)','')
            local key=r.place..'|'..loc
            local p=places[key]
            if not p then
                p={key=key,label=loc,place=r.place,total=0,boxes={},boxOrder={}}
                places[key]=p; order[#order+1]=p
            end
            p.total=p.total+r.quantity
            local box=(r.container and r.container~='') and tostring(r.container) or 'Not in a container'
            if not p.boxes[box] then p.boxes[box]=0; p.boxOrder[#p.boxOrder+1]=box end
            p.boxes[box]=p.boxes[box]+r.quantity
        end
    end
    -- bag first, then bank, house and the rest; biggest first within each
    local rankOf={carried=1,bank=2,houseStorage=3,otherCharacters=4}
    table.sort(order,function(a,b)
        local ra,rb=rankOf[a.place] or 9,rankOf[b.place] or 9
        if ra~=rb then return ra<rb end
        return a.total>b.total
    end)
    return order
end
-- The compass: the game's search says which scene and container hold an item, not where the container
-- stands. Stand by a chest and click Mark to remember its spot; Compass then points the game's compass
-- (its beacon, the one /beacon sets) at it while you're in that scene.
-- The game's location can carry an internal scene name, like "Ivory Stronghold: BasementSceneDungeonTown_Arena
-- (Town Lot Basement)". Show it as "Ivory Stronghold (Town Lot Basement)"; saved marks still use the full text.
local function niceLocation(loc)
    local out=tostring(loc or '')
    out=out:gsub(':%s*[%w_]*Scene[%w_]*',''):gsub(':%s*%w+_[%w_]+','')
    out=out:gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','')
    return out
end
local function spotKey(loc,box) return string.lower(tostring(loc)..'|'..tostring(box)) end
local naming=nil            -- the container whose name box is open
local function shownBox(loc,box)
    return C.nicknames[spotKey(loc,box)] or box
end
local function hereRaw()
    if type(ShroudGetCurrentSceneNameRaw)~='function' then return nil end
    local ok,raw=pcall(ShroudGetCurrentSceneNameRaw)
    if ok and type(raw)=='string' and raw~='' then return raw end
end
local function markSpot(loc,box)
    local x,y,z=ShroudPlayerX,ShroudPlayerY,ShroudPlayerZ
    local raw=hereRaw()
    if type(x)~='number' or type(y)~='number' or type(z)~='number' or x~=x or not raw then
        msg('Your position is not available right now. Try again in a moment.'); return false
    end
    C.spots[spotKey(loc,box)]={raw=raw,x=x,y=y,z=z}; C.save()
    msg('Marked where you stand as '..shownBox(loc,box)..'. Compass will point here from anywhere in this scene.')
    return true
end
local beaconOn=nil          -- the chest the compass points at now (set by this add-on)
local function clearCompass()
    local ok=type(ShroudClearBeacon)=='function' and pcall(ShroudClearBeacon)
    if not ok then
        -- older clients: the game's own command clears it
        if Shroud and type(Shroud.RunCommand)=='function' then ok=pcall(Shroud.RunCommand,'/beacon clear') end
    end
    beaconOn=nil
    msg(ok and 'Compass cleared.' or 'Type /beacon clear to clear the compass.')
end
local function unmarkSpot(loc,box)
    local key=spotKey(loc,box)
    if beaconOn==key then clearCompass() end
    C.spots[key]=nil; C.save()
    msg('Forgot where '..shownBox(loc,box)..' is.')
end
local function pointAt(loc,box)
    local key=spotKey(loc,box)
    local sp=C.spots[key]
    if not sp then return end
    if hereRaw()~=sp.raw then
        msg(shownBox(loc,box)..' is in '..niceLocation(loc)..'. Go there, then click Compass again.'); return
    end
    if type(ShroudSetBeacon)~='function' then msg('This game client cannot set the compass.'); return end
    local ok,set=pcall(ShroudSetBeacon,sp.x,sp.y,sp.z,tostring(shownBox(loc,box)):gsub('[%[%]<>]',''):sub(1,40))
    if ok and set~=false then beaconOn=key; msg('Your compass points at '..shownBox(loc,box)..'. Click Clear compass to remove it.')
    else msg('The game did not set the compass right now. Try again in a moment.') end
end
local redrawWhere
local function fillWhere(cell)
    cell.where:Clear()
    local k=string.lower(cell.name)
    local o=owned[k]
    if C.countAcct and not o then cell.where:Add(label('Counting...')); return end
    if not C.countAcct then
        -- bag only: the bag's count is all there is to show
        local inv=counts()
        local b=inv and (inv[k] or 0)
        if o and not o.failed and b then b=math.max(b,o.carried or 0) end
        cell.where:Add(row{label('Bag',nil),UI.Label{text='',style={flexGrow=1}},label(tostring(b or '?'),70)})
        cell.where:Add(label('Tick Account at the top to see the bank, house chests and other characters.'))
        return
    end
    if o.failed then
        cell.where:Add(label('The game has not answered yet ('..tostring(o.why)..'). Showing bag and bank for now; trying again shortly.'))
        return
    end
    if o.missing then cell.where:Add(label('You have none of these anywhere the game can see.')); return end
    local places=wherePlaces(o)
    if #places==0 then cell.where:Add(label('None in the places you are counting.')) end
    for _,p in ipairs(places) do
        local pk=k..'|'..p.key
        local inside=UI.Column{visible=placeOpen[pk]==true,style={paddingLeft=40,flexShrink=0}}
        local findable=p.place=='houseStorage' or p.place=='bank' or p.place=='unknown'
        for _,box in ipairs(p.boxOrder) do
            local key=spotKey(p.label,box)
            local nick=C.nicknames[key]
            local parts={flexLabel(nick and (nick..'  ('..box..')') or box),label(tostring(p.boxes[box]),70)}
            if findable then
                local known=C.spots[key]~=nil
                if known then
                    local pointing=beaconOn==key
                    parts[#parts+1]=UI.Button{text=pointing and 'Clear compass' or 'Compass',style={width=pointing and 130 or 90},
                        tooltip=pointing and 'Stop pointing your compass at '..box or 'Point your compass at '..box..' (works in its scene)',
                        onClick=function()
                            if beaconOn==key then clearCompass() else pointAt(p.label,box) end
                            redrawWhere()
                        end}
                end
                parts[#parts+1]=UI.Button{text=known and 'Re-mark' or 'Mark',style={width=80},
                    tooltip='Stand next to '..box..' and click to remember where it is, for the compass',
                    onClick=function() if markSpot(p.label,box) then redrawWhere() end end}
                if known then
                    parts[#parts+1]=UI.Button{text='Unmark',style={width=80},
                        tooltip='Forget where '..box..' is',
                        onClick=function() unmarkSpot(p.label,box); redrawWhere() end}
                end
            end
            if box~='Not in a container' then
                parts[#parts+1]=UI.Button{text='Name',style={width=70},
                    tooltip='Give '..box..' a name of your own, like Reagent Chest',
                    onClick=function() naming=(naming~=key) and key or nil; redrawWhere() end}
            end
            inside:Add(row(parts))
            if naming==key then
                local field2
                local function saveName()
                    local nick2=trim(field2:GetText())
                    if nick2=='' then C.nicknames[key]=nil; msg(box..' shows its own name again.')
                    elseif not valid(nick2) then msg('That name can not be used.'); return
                    else C.nicknames[key]=nick2; msg(box..' is now called '..nick2..'.') end
                    naming=nil; C.save(); redrawWhere()
                end
                field2=UI.TextField{text=nick or '',placeholder='Your name for it, e.g. Reagent Chest',maxLength=40,
                    style={flexGrow=1},onSubmit=saveName}
                inside:Add(row{field2,UI.Button{text='Save',style={width=70},onClick=saveName},
                    UI.Button{text='Cancel',style={width=80},onClick=function() naming=nil; redrawWhere() end}})
                inside:Add(label('Leave it empty and Save to go back to the game\'s name.'))
            end
        end
        local header={}
        if #p.boxOrder>1 or p.boxOrder[1]~='Not in a container' or findable then
            local toggle
            toggle=UI.Button{text=placeOpen[pk] and '-' or '+',style={width=32},
                tooltip='Show the containers here',onClick=function()
                    placeOpen[pk]=not placeOpen[pk]
                    inside:SetVisible(placeOpen[pk]); toggle:SetText(placeOpen[pk] and '-' or '+')
                end}
            header[1]=toggle
        else
            header[1]=UI.Label{text='',style={width=32,flexShrink=0}}
        end
        -- the game's location already starts with "Inventory:" or "Bank:"; say it once
        local where=niceLocation(p.label:gsub('^Inventory:%s*',''):gsub('^Bank:%s*',''))
        header[#header+1]=flexLabel((PLACE_NAMES[p.place] or p.place)..': '..where)
        header[#header+1]=label(tostring(p.total),70)
        cell.where:Add(row(header))
        cell.where:Add(inside)
    end
    if #places>1 then
        cell.where:Add(row{UI.Label{text='',style={width=32,flexShrink=0}},flexLabel('Total'),label(tostring(haveOf(cell.name,counts()) or '...'),70)})
    end
    if o.truncated then cell.where:Add(label('The game cut this list short; totals are still complete.')) end
end
redrawWhere=function()
    for _,c in ipairs(itemCells) do
        if itemOpen[string.lower(c.name)] then fillWhere(c); c.version=ownedVersion end
    end
end
renderItems=function()
    if not el.itemResults then return end
    el.itemResults:Clear(); itemCells={}
    local pages=math.max(1,math.ceil(#itemMatches/ITEM_PAGE))
    itemPage=math.min(itemPage,pages)
    if indexJob then
        el.itemResults:Add(label('Building the item list ('..(indexJob.i-1)..' of '..#indexJob.list..
            ' recipes). Results show when it finishes.'))
    elseif #itemMatches==0 and not (itemIndex and itemQuery=='') then
        el.itemResults:Add(label(not itemIndex and 'Type part of an item name and press Enter or Find.'
            or 'No items match. Try part of the name, like garnet or potato.'))
    end
    for i=(itemPage-1)*ITEM_PAGE+1,math.min(itemPage*ITEM_PAGE,#itemMatches) do
        local m=itemMatches[i]
        local name=m.name
        local k=string.lower(name)
        wantOwned(name,true)
        local have=label('',260)
        local where=UI.Column{visible=itemOpen[k]==true,style={paddingLeft=34,paddingTop=4,flexShrink=0}}
        local cell={name=name,have=have,where=where,version=-1}
        itemCells[#itemCells+1]=cell
        local whereButton
        whereButton=UI.Button{text=itemOpen[k] and '-' or '+',style={width=32},
            tooltip='Show where it is: your bag, bank and house chests, each with its own total',onClick=function()
                itemOpen[k]=not itemOpen[k]
                where:SetVisible(itemOpen[k]); whereButton:SetText(itemOpen[k] and '-' or '+')
                fillWhere(cell); cell.version=ownedVersion
            end}
        local add=UI.Button{text='Add',style={width=55},tooltip='Add the amount above to what your shopping list needs',
            onClick=function()
                local n=number(el.itemAmount:GetText())
                if not n then msg('Amount must be a whole number, 1 or more.'); return end
                C.add(name,n); refreshCart(); refreshItems()
                local have=haveOf(name,counts())
                msg('Added '..n..' '..name..'. You need '..C.items[name]..(have and
                    (', have '..have..', so '..math.max(0,C.items[name]-have)..' still to get.') or '.'))
            end}
        local about
        if m.entry then
            local makes,uses=titlesOf(m.entry.makes),titlesOf(m.entry.uses)
            about='Made by: '..shortList(makes,2)..' | Used in '..#uses..(#uses==1 and ' recipe' or ' recipes')
                ..(#uses>0 and (': '..shortList(uses,3)) or '')
        elseif m.typed then about='Not in your recipes or bag. Looking it up by exact name.'
        elseif C.items[name] then about='On your shopping list'
        else about='Not used in your recipes' end
        el.itemResults:Add(UI.Column{style={paddingTop=6,paddingBottom=6,flexShrink=0},children={
            row{whereButton,UI.Label{text=name,class='heading',style={flexGrow=1,flexShrink=1,whiteSpace='wrap',fontSize=15}},
                have,add},
            label(about),
            where,
        }})
        if itemOpen[k] then fillWhere(cell); cell.version=ownedVersion end
    end
    el.itemPage:SetText(#itemMatches==0 and '' or ('Page '..itemPage..' / '..pages..' - '..#itemMatches..' items'))
    refreshItems()
end
refreshItems=function()
    if not el.itemResults then return end
    local inv=counts()
    for _,cell in ipairs(itemCells) do
        local n=haveOf(cell.name,inv)
        local need=C.items[cell.name]
        local text
        if n==nil then text='Have ...'
        else
            text='Have '..n
            local o=owned[string.lower(cell.name)]
            if C.countAcct and C.countInv and o and not o.failed and inv then
                text=text..' (bag '..math.max(inv[string.lower(cell.name)] or 0,o.carried or 0)..')'
            end
        end
        -- on the shopping list: what the list needs and what is still to get
        local color='@text'
        if need then
            local get=n and math.max(0,need-n)
            text=text..' | Need '..need..' | '..(get==nil and 'To get ...' or (get==0 and 'Ready' or ('To get '..get)))
            color=get==0 and '@green' or (get and '@red' or '@text')
        end
        if cell.lastText~=text then cell.have:SetText(text); cell.lastText=text end
        if cell.lastColor~=color then pcall(function() cell.have:SetStyle{color=color} end); cell.lastColor=color end
        if itemOpen[string.lower(cell.name)] and cell.version~=ownedVersion and not naming then
            fillWhere(cell); cell.version=ownedVersion
        end
    end
end

-- The tracker: the shopping list on screen like the game's quest list. A compact window (Lua API 19):
-- its title bar only shows while the pointer is over it, so it reads like a see-through list, but it
-- can be stretched from any edge and faded like any window (right-click it for opacity). Recipe names
-- are headings with what you still need under them; X takes a recipe off the tracker (it stays on the
-- shopping list), like untracking a quest. Built again only when the lines change; counts update in place.
local tracker=nil            -- {win,box,lines={name->label},signature,visible}
local TRACK_MAX_ROWS=60      -- headings + materials shown; past that a "more" line (element limits)
local SHADES={['None']=0,['Light']=25,['Medium']=45,['Dark']=65}
local SHADE_NAMES={'None','Light','Medium','Dark'}
local function shadeColor(pct)
    if pct<=0 then return '#00000000' end
    return string.format('#000000%02x',math.floor(math.min(pct,100)*255/100+0.5))
end
local function shadeName(pct)
    local best,gap='Light',999
    for name,v in pairs(SHADES) do if math.abs(v-pct)<gap then best,gap=name,math.abs(v-pct) end end
    return best
end
local function trackerGroups()
    local inv=counts()
    local groups,order={},{}
    local total,left,hidden=0,0,0
    for name,target in pairs(C.items) do
        total=total+1
        local n=haveOf(name,inv)
        local missing=n and math.max(0,target-n)
        if missing==nil or missing>0 then
            left=left+1
            local titles={}
            for title in pairs(C.sources[name] or {}) do titles[#titles+1]=title end
            if #titles==0 then titles={'Other materials'} end
            for _,title in ipairs(titles) do
                if C.untracked[title] then hidden=hidden+1
                else
                    if not groups[title] then groups[title]={}; order[#order+1]=title end
                    groups[title][#groups[title]+1]={name=name,have=n,need=target}
                end
            end
        end
    end
    table.sort(order,function(a,b)
        if a=='Other materials' then return false elseif b=='Other materials' then return true end
        return a<b
    end)
    for _,title in ipairs(order) do table.sort(groups[title],function(a,b) return a.name<b.name end) end
    return groups,order,total,left,hidden
end
local function trackerShown() return tracker~=nil and tracker.visible end
local function saveTrackerPlace()
    if not tracker then return end
    local changed=false
    local ok,x,y=pcall(function() return tracker.win:GetPosition() end)
    if ok and tonumber(x) and tonumber(y) and (math.floor(x)~=C.tracker.x or math.floor(y)~=C.tracker.y) then
        C.tracker.x,C.tracker.y=math.floor(x),math.floor(y); changed=true
    end
    local ok2,w,h=pcall(function() return tracker.win:GetSize() end)
    if ok2 and tonumber(w) and tonumber(h) and (math.floor(w)~=C.tracker.w or math.floor(h)~=C.tracker.h) then
        C.tracker.w,C.tracker.h=math.floor(w),math.floor(h); changed=true
    end
    if changed then C.save() end
end
local saveTrackerPosition=saveTrackerPlace
local untrackRecipe
local function itemText(m) return m.name..'  '..(m.have and tostring(m.have) or '...')..' / '..m.need end
local function fillTracker(groups,order,total,left,hidden)
    local box=tracker.box
    box:Clear(); tracker.lines={}
    local rows=0
    if total==0 then box:Add(UI.Label{text='Shopping list is empty',style={fontSize=13,whiteSpace='wrap'}})
    elseif left==0 then box:Add(UI.Label{text='Everything on the list is ready',style={fontSize=13,color='@green'}}) end
    for _,title in ipairs(order) do
        if rows>=TRACK_MAX_ROWS then break end
        local project=C.projects[title]
        box:Add(UI.Row{style={alignItems='center',marginTop=4,flexShrink=0},children={
            UI.Label{text=title..(project and (' x'..project.crafts) or ''),
                style={flexGrow=1,flexShrink=1,whiteSpace='wrap',fontSize=14,color='@gold'}},
            UI.Button{text='x',style={width=24,height=22,fontSize=12},
                tooltip='Take '..title..' off the tracker (it stays on your shopping list)',
                onClick=function() untrackRecipe(title) end}}})
        rows=rows+1
        for _,m in ipairs(groups[title]) do
            if rows>=TRACK_MAX_ROWS then break end
            local e=UI.Label{text=itemText(m),style={fontSize=13,whiteSpace='wrap',paddingLeft=14,flexShrink=0}}
            tracker.lines[#tracker.lines+1]={el=e,name=m.name,title=title,text=itemText(m)}
            box:Add(e); rows=rows+1
        end
    end
    local more=0
    for _,title in ipairs(order) do more=more+1+#groups[title] end
    if more>rows then box:Add(UI.Label{text='...and more. Open /ledger to see everything.',style={fontSize=12}}) end
    if hidden>0 then
        box:Add(UI.Label{text=hidden..' hidden from the tracker. Shopping list > Track all to bring them back.',
            style={fontSize=11,whiteSpace='wrap',marginTop=6}})
    end
end
local function refreshTracker()
    if not trackerShown() then return end
    local groups,order,total,left,hidden=trackerGroups()
    local parts={tostring(total==0),tostring(left==0),tostring(hidden)}
    for _,title in ipairs(order) do
        local project=C.projects[title]
        parts[#parts+1]=title..'|'..(project and project.crafts or '')
        for _,m in ipairs(groups[title]) do parts[#parts+1]=m.name end
    end
    local signature=table.concat(parts,'\n')
    if signature~=tracker.signature then
        tracker.signature=signature
        fillTracker(groups,order,total,left,hidden)
        return
    end
    -- same lines: only the counts change
    local byKey={}
    for _,title in ipairs(order) do for _,m in ipairs(groups[title]) do byKey[title..'\t'..m.name]=m end end
    for _,l in ipairs(tracker.lines) do
        local m=byKey[l.title..'\t'..l.name]
        if m then
            local text=itemText(m)
            if text~=l.text then l.el:SetText(text); l.text=text end
        end
    end
end
local function buildTracker()
    local t=C.tracker
    local box=UI.Column{style={paddingLeft=8,paddingRight=8,paddingTop=2,paddingBottom=6,flexShrink=0,
        backgroundColor=shadeColor(t.shade),borderRadius=3}}
    local win2=UI.Window{id='crafters_ledger_tracker_win',title='Shopping list',compact=true,
        width=t.w or 300,height=t.h or 320,minWidth=170,minHeight=80,
        x=t.x or 1480,y=t.y or 240,escCloses=false,
        onClose=function()
            if tracker then tracker.visible=false end
            C.tracker.shown=false; C.save()
        end,
        style={paddingTop=2,paddingBottom=2},
        children={UI.Scroll{id='ledger_tracker_scroll',style={flexGrow=1},children={box}}}}
    tracker={win=win2,box=box,lines={},signature=nil,visible=true}
end
local function setTracker(show)
    C.tracker.shown=show==true
    if show then
        if not tracker then
            local ok,err=pcall(buildTracker)
            if not ok then tracker=nil; C.tracker.shown=false; msg('Tracker unavailable: '..tostring(err)); C.save(); return end
        end
        pcall(function() tracker.win:Show() end); tracker.visible=true
        refreshTracker()
    elseif tracker then
        saveTrackerPlace()
        pcall(function() tracker.win:Hide() end); tracker.visible=false
    end
    C.save()
end
untrackRecipe=function(title)
    C.untracked[title]=true; C.save()
    if tracker then tracker.signature=nil end
    refreshTracker()
end
local function trackAll()
    C.untracked={}; C.save()
    if tracker then tracker.signature=nil end
    refreshTracker()
    msg('Every recipe on your shopping list is back on the tracker.')
end
function C.tracker_toggle() trackerToggleRequested=true end
local function setShade(pct)
    C.tracker.shade=pct; C.save()
    if tracker then pcall(function() tracker.box:SetStyle{backgroundColor=shadeColor(pct)} end) end
end
local function buildUI()
    UI=Shroud.UI
    cartStructure=nil; cartCells={}; refreshSummary=nil
    el.search=UI.TextField{text='',placeholder='Recipe name, e.g. Gingerbread',style={flexGrow=1},onSubmit=findRecipes}
    el.crafts=UI.TextField{text='1',maxLength=7,style={width=70},onChange=function() preview(); if renderMatches then renderMatches() end end}
    el.matches=UI.Column{}
    el.matchPage=label('Search your recipe book')
    el.preview=UI.Column{}
    -- Keep content at its natural height so the Scroll can measure overflow.
    el.cart=UI.Column{style={flexShrink=0,paddingRight=18}}
    el.cartPage=label('')
    el.message=label('Choose a recipe or add materials. Existing shopping targets are preserved.')
    el.item=UI.TextField{text='',placeholder='Exact item name',style={flexGrow=1}}
    el.amount=UI.TextField{text='1',maxLength=7,style={width=70}}
    el.materials=UI.TextField{text='',placeholder='Bottle of Milk=100; Potato=200',maxLength=4000,style={flexGrow=1}}
    projectSignature=nil
    el.projects=UI.Column{style={paddingTop=6,paddingBottom=8}}
    el.summary=UI.Label{text='',class='heading',style={fontSize=16,whiteSpace='wrap'}}
    local listSearch=UI.TextField{text='',placeholder='Find an item you are making or a material',style={flexGrow=1},
        onChange=function(_,value) cartQuery=string.lower(trim(value)); page=1; refreshCart() end}
    local viewPicker=UI.Dropdown{choices={'To get','All','Ready'},value='To get',style={width=140},
        onChange=function(_,value) cartFilter=value; page=1; refreshCart() end}
    -- A zero starting height makes this page fill the remaining window space,
    -- rather than growing the window layout to fit every expanded recipe.
    local shopPage=UI.Column{visible=false,style={height=0,flexGrow=1,flexShrink=1},children={
        el.summary,
        row{listSearch,viewPicker,UI.Button{text='Refresh counts',onClick=function() forgetOwned(); refreshCart() end}},
        row{label('On-screen tracker (like the quest list):',255),
            UI.Button{text='Show / hide',tooltip='See-through list of what you still need. Drag it by its grip.',
                onClick=function() setTracker(not trackerShown()) end},
            UI.Button{text='Track all',tooltip='Bring back recipes you took off the tracker with its x',
                onClick=function() trackAll() end},
            label('Background',85),
            UI.Dropdown{choices=SHADE_NAMES,value=shadeName(C.tracker.shade),style={width=120},
                onChange=function(_,v) setShade(SHADES[v] or 25) end}},
        label('Stretch the tracker from any edge. Right-click it to fade it. Its x takes a recipe off the tracker only.'),
        label('Click + to see materials, - to hide them. Shared materials show combined shopping-list totals.'),
        UI.Scroll{id='ledger_shopping_scroll',style={height=0,flexGrow=1,flexShrink=1},children={el.cart}},
        row{UI.Button{text='Previous',onClick=function() page=math.max(1,page-1); refreshCart() end},el.cartPage,
            UI.Button{text='Next',onClick=function() page=page+1; refreshCart() end}},
    }}
    local browse=UI.Column{style={width=310,flexShrink=0,paddingRight=14},children={
        label('Find a recipe'),row{el.search,UI.Button{text='Find',onClick=findRecipes}},
        UI.Scroll{style={flexGrow=1},children={el.matches}},
        row{UI.Button{text='<',onClick=function() recipePage=math.max(1,recipePage-1); renderMatches() end},
            el.matchPage,UI.Button{text='>',onClick=function()
                recipePage=math.min(math.max(1,math.ceil(#matches/RECIPE_PAGE)),recipePage+1); renderMatches()
            end}},
        UI.Button{text='Reload recipe book',onClick=function() readRecipes(); findRecipes() end},
    }}
    local plan=UI.Column{style={flexGrow=1,flexShrink=1,paddingLeft=14},children={
        label('Recipe details'),row{label('Crafting attempts',145),el.crafts},
        UI.Scroll{style={flexGrow=1},children={el.preview}},
        label('Quantities above are multiplied by crafting attempts, not finished item count.'),
        UI.Button{text='Add ingredients to shopping list',onClick=function() addRecipe(false) end},
        UI.Button{text='Label existing materials with this recipe',onClick=function() addRecipe(true) end},
    }}
    local recipesPage=UI.Row{visible=true,style={flexGrow=1,alignItems='stretch'},children={browse,plan}}
    local manualPage=UI.Column{visible=false,style={flexGrow=1},children={
        label('Add a material'),label('Use the exact in-game item name. Add increases your target; Set target replaces it.'),
        row{el.item,el.amount},
        row{UI.Button{text='Add to list',onClick=addManual},UI.Button{text='Set target',onClick=function()
            local name=trim(el.item:GetText()); local n=number(el.amount:GetText())
            if not valid(name) or not n then msg('Enter an item and a positive whole quantity.'); return end
            C.set(name,n); refreshCart(); msg('Updated target for '..name..'.')
        end}},
        label('Paste a material list'),label('Example: Bottle of Milk=100; Potato=200'),
        el.materials,UI.Button{text='Add pasted materials',onClick=importList},
        UI.Label{text='',style={flexGrow=1}},
    }}
    el.itemSearch=UI.TextField{text='',placeholder='Item name or words from it, e.g. black pearl',style={flexGrow=1},onSubmit=findItems}
    el.itemAmount=UI.TextField{text='1',maxLength=7,style={width=70}}
    el.itemResults=UI.Column{style={flexShrink=0,paddingRight=18}}
    el.itemPage=label('')
    el.itemStatus=label('Searches every item your recipes make or use, your bag and your shopping list. For anything else, type its full name.')
    itemCells={}
    local itemsPage=UI.Column{visible=false,style={height=0,flexGrow=1,flexShrink=1},children={
        row{el.itemSearch,UI.Button{text='Find',onClick=findItems},label('Amount to add',110),el.itemAmount},
        el.itemStatus,
        UI.Scroll{id='ledger_items_scroll',style={height=0,flexGrow=1,flexShrink=1},children={el.itemResults}},
        row{UI.Button{text='Previous',onClick=function() itemPage=math.max(1,itemPage-1); renderItems() end},el.itemPage,
            UI.Button{text='Next',onClick=function() itemPage=itemPage+1; renderItems() end}},
    }}
    local pages={['Shopping list']=shopPage,Recipes=recipesPage,['Add materials']=manualPage,['Find items']=itemsPage}
    local activePage='Recipes'
    local navLabel=label('Recipes')
    navigate=function(name)
        activePage=name
        for key,section in pairs(pages) do section:SetVisible(key==name) end
        navLabel:SetText(name)
        if name=='Shopping list' then refreshCart() end
        if name=='Find items' and not itemIndex then startIndex(); renderItems() end
    end
    el.counting=label(countingText()..' | Updates automatically | Saved between sessions')
    local invToggle,acctToggle
    local function countsChanged(which,value)
        if which=='inv' then C.countInv=value==true else C.countAcct=value==true end
        if C.countAcct and not canCountAccount() then
            C.countAcct=false; pcall(function() acctToggle:SetValue(false) end)
            msg('This game client cannot count your bank or chests yet (it needs Lua API 55).')
        end
        if not C.countInv and not C.countAcct then
            -- one of them has to count something: put back the one just unticked
            if which=='inv' then C.countInv=true; pcall(function() invToggle:SetValue(true) end)
            else C.countAcct=true; pcall(function() acctToggle:SetValue(true) end) end
            msg('Keep at least one of Inventory or Account ticked.')
        end
        C.save()
        el.counting:SetText(countingText()..' | Updates automatically | Saved between sessions')
        refreshCart(); renderItems(); if selected then preview() end
    end
    invToggle=UI.Toggle{text='Inventory',value=C.countInv,tooltip='Count what this character carries',
        onChange=function(_,v) countsChanged('inv',v) end}
    acctToggle=UI.Toggle{text='Account',value=C.countAcct,
        tooltip='Count your bank, house chests, other characters, mail and vendor listings',
        onChange=function(_,v) countsChanged('acct',v) end}
    win=UI.Window{id='crafters_ledger_v3',title="Crafters Ledger",width=1000,height=650,
        minWidth=900,minHeight=460,x=70,y=70,escCloses=true,
        style={paddingLeft=16,paddingRight=16,paddingTop=10,paddingBottom=10},children={
            row{UI.Button{text='Recipes',onClick=function() navigate('Recipes') end},
                UI.Button{text='Shopping list',onClick=function() navigate('Shopping list') end},
                UI.Button{text='Add materials',onClick=function() navigate('Add materials') end},
                UI.Button{text='Find items',onClick=function() navigate('Find items') end},
                UI.Label{text='',style={flexGrow=1}},label('Count:',55),invToggle,acctToggle},
            navLabel,shopPage,recipesPage,manualPage,itemsPage,
            el.message,
            el.counting,
        }}
    preview(); refreshCart(); win:Show()
end
-- Chat commands queue work; only the add-on's callbacks touch Shroud.UI.
local openRequested=false
local toggleRequested=false
local launcher=nil
function C.open()
    openRequested=true
end
function C.toggle()
    toggleRequested=true
end
local function openWindow()
    if not win then buildUI() else win:Show(); refreshCart() end
end
function ShroudOnStart()
    openRequested=true
    if Shroud and Shroud.Command then
        local ok,err=pcall(Shroud.Command,'shopping',function() C.open() end)
        if not ok then say('Use /lua code ShoppingCart.open() to open the cart.') end
    end
    if Shroud and Shroud.Command then pcall(Shroud.Command,'basket',function() C.open() end) end
    if Shroud and Shroud.Command then pcall(Shroud.Command,'ledger',function() C.open() end) end
    if Shroud and Shroud.Command then pcall(Shroud.Command,'ledgertrack',function() C.tracker_toggle() end) end
    if C.tracker.shown then trackerToggleRequested=true; C.tracker.shown=false end
    if Shroud and Shroud.Keybind then
        local bound,reason=pcall(Shroud.Keybind,{id='toggle',label="Show/hide Crafters Ledger",
            onPress=function() C.toggle() end})
        if not bound then say('Key setting unavailable: '..tostring(reason)) end
    end
    local ok,err=pcall(function()
        UI=Shroud.UI
        if UI.HudFrame then
            local texture=-1
            if type(ShroudLoadTexture)=='function' then
                for _,path in ipairs({'crafters-ledger/icon.png','icon.png'}) do
                    local loaded,id=pcall(ShroudLoadTexture,path)
                    if loaded and type(id)=='number' and id>=0 then texture=id; break end
                end
            end
            local button
            if texture>=0 and UI.IconButton then
                button=UI.IconButton{texture=texture,tooltip="Crafters Ledger - open your shopping list",
                    style={width=46,height=46},onClick=function() C.toggle() end}
            else
                button=UI.Button{text="Ledger",tooltip="Crafters Ledger - copy icon.png into the add-on folder",
                    style={width=46,height=46},onClick=function() C.toggle() end}
            end
            launcher=UI.HudFrame{id='crafters_ledger_launcher',x=20,y=300,width=50,height=50,children={button}}
        end
    end)
    if not ok then say('Cart button unavailable: '..tostring(err)) end
end
local elapsed,fastElapsed=0,0
local saveTimer=0
local cartVersion,trackVersion=0,0
local warmAt=3              -- seconds after login: start the item list and account counts in the background
function ShroudOnUpdate()
    if toggleRequested then
        toggleRequested=false
        local ok,err=pcall(function()
            if win and win:IsShown() then win:Hide() else openWindow() end
        end)
        if not ok then say('Could not toggle window: '..tostring(err)) end
    end
    if trackerToggleRequested then
        trackerToggleRequested=false
        if UI==nil and Shroud then UI=Shroud.UI end
        local ok,err=pcall(function() setTracker(not trackerShown()) end)
        if not ok then say('Tracker failed: '..tostring(err)) end
    end
    if openRequested then
        openRequested=false
        local ok,err=pcall(openWindow)
        if not ok then say('Interface could not open: '..tostring(err)) end
    end
    local dt=tonumber(ShroudDeltaTime) or 0
    clockNow=clockNow+dt
    quickLeft=QUICK_PER_FRAME
    saveTimer=saveTimer+dt
    if saveTimer>=120 then saveTimer=0; saveCounts() end
    local ok2,err2=pcall(function()
        pumpOwned()
        if indexJob and indexStep() then
            findItems()
        end
    end)
    if not ok2 then say('Item search stopped: '..tostring(err2)); indexJob=nil end
    fastElapsed=fastElapsed+dt
    if fastElapsed>=0.5 then
        fastElapsed=0
        if win then
            local ok3,err3=pcall(function()
                if not win:IsShown() then return end
                refreshItems()
                if cartVersion~=ownedVersion then cartVersion=ownedVersion; refreshCart() end
                if indexJob and el.itemResults and #itemCells==0 then renderItems() end
                if previewPending and previewVersion~=ownedVersion then preview() end
            end)
            if not ok3 then say('Refresh failed: '..tostring(err3)) end
        end
        if trackerShown() and trackVersion~=ownedVersion then
            trackVersion=ownedVersion
            pcall(refreshTracker)
        end
    end
    -- warm up shortly after login so counts and Find items are ready when the window opens
    if warmAt then
        warmAt=warmAt-dt
        if warmAt<=0 then
            warmAt=nil
            pcall(function()
                if C.countAcct then for name in pairs(C.items) do wantOwned(name) end end
                if not itemIndex and not startIndex(true) then warmAt=10 end
            end)
        end
    end
    elapsed=elapsed+dt
    if elapsed>=2 then
        elapsed=0
        if win then
            local ok,err=pcall(function() if win:IsShown() then refreshCart() end end)
            if not ok then say('Refresh failed: '..tostring(err)) end
        end
        if trackerShown() then
            local ok,err=pcall(function() refreshTracker(); saveTrackerPosition() end)
            if not ok then say('Tracker refresh failed: '..tostring(err)) end
        end
    end
end
-- Your bag changed (picked up, crafted, moved to a chest...): count your list's items again soon.
function ShroudOnInventoryChanged()
    for name in pairs(C.items) do
        local o=owned[string.lower(name)]
        if o and clockNow-o.at>5 then o.at=-math.huge end
    end
    for _,cell in ipairs(itemCells) do
        local o=owned[string.lower(cell.name)]
        if o and clockNow-o.at>5 then o.at=-math.huge end
    end
end
function ShroudOnDisableScript()
    saveCounts()
    openRequested=false; toggleRequested=false
    if win then pcall(function() win:Destroy() end); win=nil end
    if launcher then pcall(function() launcher:Destroy() end); launcher=nil end
    if tracker then saveTrackerPlace(); pcall(function() tracker.win:Destroy() end); tracker=nil end
end

