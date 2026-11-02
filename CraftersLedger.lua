-- Crafters Ledger v3.4.1. Legacy ShoppingCart commands and save file remain compatible.
ShoppingCart = {items={},projects={},sources={},amounts={},wanted={},wishes={},trackFilter='Still needed',trackView='By item',countInv=true,countAcct=false,
    tracker={shown=false,shade=90,x=nil,y=nil,w=nil,h=nil},untracked={},
    spots={},                 -- where you marked a chest: key -> {raw,x,y,z}
    nicknames={}}             -- your own name for a container: key -> "Reagent Chest"
MarketBasket = ShoppingCart
CraftersLedger = ShoppingCart
local C=ShoppingCart
local filename = type(ShroudLuaPath)=='string' and
    (ShroudLuaPath..'/CraftersLedger-data.tsv') or nil
local activityHistory,activityDirty,activityPage={},true,1
local refreshActivity=nil
local buildStage='loading'
local function say(s,details)
    local text=tostring(s)
    local lower=string.lower(text)
    local color='66CCFF' -- information, updates, and cancelled actions
    if lower:find('cancel',1,true) then
        color='66CCFF'
    elseif lower:find('error:',1,true) or lower:find('invalid',1,true) or lower:find('no ungrouped',1,true) or lower:find('not found',1,true) or lower:find('failed',1,true) or lower:find('unavailable',1,true) or
        lower:find('could not',1,true) or lower:find('nothing added',1,true) or
        lower:find('nothing imported',1,true) or lower:find('nothing changed',1,true) then
        color='FF6666'
    elseif lower:find('confirm',1,true) or lower:find('click sure?',1,true) then
        color='66CCFF'
    elseif lower:find('cleared',1,true) or lower:find('removed',1,true) or lower:find('forgot',1,true) then
        color='FF6666'
    elseif lower:find('added',1,true) or lower:find('saved',1,true) or
        lower:find('grouped',1,true) or lower:find('labeled',1,true) then
        color='66FF66'
    end
    local stamp=''
    if type(os)=='table' and type(os.date)=='function' then
        local ok,value=pcall(os.date,'%H:%M:%S')
        if ok then stamp=value..'  ' end
    end
    table.insert(activityHistory,1,{text=stamp..text,details=details,color=color})
    if #activityHistory>100 then table.remove(activityHistory) end
    activityPage=1; activityDirty=true
    local brief=text:gsub('[\r\n]+',' ')
    if details then brief=(text:match('^[^%.]+') or text)..'. Details: Activity tab.' end
    local problem=lower:find('failed',1,true) or lower:find('unavailable',1,true) or
        lower:find('could not',1,true) or lower:find('error:',1,true)
    if problem then
        if type(ShroudLuaPath)=='string' and type(io)=='table' and type(io.open)=='function' then
            pcall(function()
                local log=io.open(ShroudLuaPath..'/CraftersLedger-errors.log','a')
                if log then log:write('v3.4.1 [',buildStage,'] ',text,'\n'); log:close() end
            end)
        end
        local reason=text:match('%.lua:%b():%s*(.*)')
        brief='Error ['..buildStage..']: '..(reason or text:gsub('[A-Za-z]:[\\/][^\n]-%.lua','script'))
    elseif #brief>140 then brief=brief:sub(1,137)..'...' end
    if type(ShroudConsoleLog)=='function' then ShroudConsoleLog('['..color..']'..brief..'[-]')
    else print(brief) end
end
local function lifecycle(status,color)
    local text='Crafters Ledger v3.4.1: '
    if type(ShroudConsoleLog)=='function' then
        ShroudConsoleLog(text..'['..color..']'..status..'[-]')
    else
        print(text..status)
    end
end
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
        for name,n in pairs(C.wishes) do f:write('@wish\t',name,'\t',tostring(n),'\n') end
        for name,r in pairs(C.wanted) do
            f:write('@wanted\t',r.key,'\t',name,'\t',tostring(r.level or ''),'\n')
        end
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
        f:write('@minimaltracker\t1\n')
        f:write('@trackoptions\t',C.trackFilter,'\t',C.trackView,'\n')
        f:write('@counts\t',C.countInv and '1' or '0','\t',C.countAcct and '1' or '0','\n')
        local t=C.tracker
        f:write('@tracker\t',t.shown and '1' or '0','\t',tostring(t.shade),'\t',tostring(t.x or ''),'\t',tostring(t.y or ''),
            '\t',tostring(t.w or ''),'\t',tostring(t.h or ''),'\n')
        -- recipes taken off the tracker (still on the cart)
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
    if not f then return end
    for line in f:lines() do
        if line:sub(1,6)=='@wish\t' then
            local name,n=line:match('^@wish\t([^\t]+)\t(%d+)$')
            if valid(name) and tonumber(n) and tonumber(n)>0 then C.wishes[name]=tonumber(n) end
        elseif line:sub(1,8)=='@wanted\t' then
            local key,name,level=line:match('^@wanted\t([^\t]+)\t([^\t]+)\t(.*)$')
            if valid(key) and valid(name) then C.wanted[name]={key=key,name=name,level=tonumber(level)} end
        elseif line:sub(1,9)=='@project\t' then
            local title,n,output=line:match('^@project\t([^\t]+)\t(%d+)\t(.*)$')
            if valid(title) and tonumber(n) then C.projects[title]={crafts=tonumber(n),output=output} end
        elseif line:sub(1,8)=='@source\t' then
            local name,title=line:match('^@source\t([^\t]+)\t([^\t]+)$')
            if valid(name) and valid(title) then C.sources[name]=C.sources[name] or {}; C.sources[name][title]=true end
        elseif line=='@minimaltracker\t1' then C.minimalTracker=true
        elseif line:match('^@trackoptions\t') then
            local filter,view=line:match('^@trackoptions\t([^\t]+)\t([^\t]+)$')
            if filter=='Still needed' or filter=='All resources' or filter=='Ready' then C.trackFilter=filter end
            if view=='By item' or view=='Resource list' then C.trackView=view end
        elseif line:sub(1,9)=='@tracker\t' then
            local shown,shade,x,y,rest=line:match('^@tracker\t([01])\t(%d+)\t(%-?%d*)\t(%-?%d*)(.*)$')
            if shown then
                local w,h=tostring(rest):match('^\t(%d*)\t(%d*)$')
                C.tracker={shown=shown=='1',shade=math.min(100,tonumber(shade) or 90),x=tonumber(x),y=tonumber(y),
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
lifecycle('Ready','00FF00')

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
local function msg(s,details)
    if el.message then el.message:SetText(s) end
    say(s,details)
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
local function resourcePurpose(name)
    local purposes={}
    for title in pairs(C.sources[name] or {}) do
        local p=C.projects[title]
        purposes[#purposes+1]=p and (p.output or '')~='' and p.output or
            (title..(p and (' x'..p.crafts) or ''))
    end
    table.sort(purposes)
    return #purposes>0 and ('For: '..table.concat(purposes,'; ')) or nil
end
local sourceWindow=nil
local sourceWindowItem=nil
local sourceWindowOpen=false
local function lookupItemName(name)
    local clean=tostring(name or ''):match('^%s*(.-)%s*$')
    clean=clean:gsub('^%d+%s*[xX×]%s*','')
    -- A labelled ingredient row: use its crafted item, not the whole row.
    if not clean:match('^Recipe:') and not clean:match('^Pattern:') then
        clean=clean:match('^(.-):') or clean
    end
    clean=clean:gsub('%s*:%s*%d+%s*$',''):match('^%s*(.-)%s*$')
    return clean
end
local function lookupEncode(text)
    return (text:gsub('[^%w_%-%.~]',function(c) return string.format('%%%02X',string.byte(c)) end))
end
local function showItemSource(name)
    name=lookupItemName(name)
    if sourceWindow and sourceWindowItem==name and sourceWindowOpen then
        sourceWindow:Hide(); sourceWindowOpen=false; return
    end
    local data=(CraftersLedgerSources or {})[name]
    local trade=data and data.trade or 'Unknown'
    local recipe=name:match('^Recipe:%s*(.+)$')
    if not data and recipe then
        for key,group in pairs(CraftersLedgerMasterRecipes or {}) do
            for _,r in ipairs(type(group)=='table' and group or {}) do
                if string.lower(tostring(field(r,'name')))==string.lower(recipe) then trade=key:gsub('^Crafting_','') end
            end
        end
    end
    if sourceWindow then pcall(function() sourceWindow:Destroy() end); sourceWindow=nil end
    local wikiName=recipe or name
    local ref='https://sotawiki.org/sota/'..lookupEncode(wikiName:gsub(' ','_'))
    local lookupURL=UI.TextField{text=ref,tooltip='Select and copy the link into your browser'}
    local function lookupButton(title,url)
        return UI.Button{text=title,onClick=function() lookupURL:SetText(url) end}
    end
    sourceWindow=UI.Window{id='crafters_ledger_item_source',title='SotAWiki lookup',width=620,height=380,onClose=function() sourceWindowOpen=false end,
        minWidth=540,minHeight=350,escCloses=true,children={
            UI.Label{text=name,class='heading',style={fontSize=17,whiteSpace='wrap'}},
            label('Vendor: '..(data and data.vendor or 'Not verified')),
            label('Trade: '..trade),
            UI.Label{text=data and data.location or 'Look up this item on SotAWiki.',style={whiteSpace='wrap'}},
            lookupButton('SotAWiki — item page',ref),
            label('Copy this link. In your browser press Ctrl+L, then paste and Enter.'),
            label('Search name: '..(recipe or name)),
            lookupURL,
        }}
    sourceWindowItem=name; sourceWindowOpen=true
    sourceWindow:Show()
end
local cartView='By crafted item'
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
        if cartView=='Cart' then
            local matches=string.find(string.lower(name),cartQuery,1,true)~=nil
            for _,title in ipairs(titles) do
                if string.find(string.lower(title),cartQuery,1,true) then matches=true end
            end
            if included and matches then
                groups['Cart']=groups['Cart'] or {}
                groups['Cart'][#groups['Cart']+1]=name
            end
        else
            for _,title in ipairs(titles) do
                if included and (string.find(string.lower(name),cartQuery,1,true)
                    or string.find(string.lower(title),cartQuery,1,true)) then
                    groups[title]=groups[title] or {}; groups[title][#groups[title]+1]=name
                end
            end
        end
    end
    local summary=(have or C.countAcct) and (ready..' of '..total..' resources ready | '..units..' still to collect')
        or (total..' materials | Inventory unavailable')
    if el.summary and refreshSummary~=summary then el.summary:SetText(summary); refreshSummary=summary end
    local titles={}; for title in pairs(groups) do titles[#titles+1]=title end; table.sort(titles)
    local pages=math.max(1,math.ceil(#titles/PAGE)); page=math.min(page,pages)
    local parts={tostring(page),cartFilter,cartView}
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
            local flat=cartView=='Cart'
            local project=not flat and C.projects[title] or nil
            if expanded[title]==nil then expanded[title]=true end
            local content=UI.Column{visible=flat or expanded[title]==true,style={paddingLeft=18,paddingBottom=8,flexShrink=0}}
            content:Add(row{flexLabel('Resource'),label('Note',210),label('Required',85),label('Owned',75),label('Still to get',100),label('',130)})
            for _,name in ipairs(groups[title]) do
                local amount=label('',75); local missing=label('',100)
                local calculated=next(C.sources[name] or {})~=nil
                local target
                local function setNeeded()
                    local n=number(trim(target:GetText()))
                    if not n then
                        msg('Error: Required must be a whole number of 1 or more. Use Remove to delete a manual resource.')
                        target:SetText(tostring(C.items[name] or '')); return
                    end
                    if not C.items[name] then return end
                    C.set(name,n); refreshCart()
                    msg('Updated required quantity: '..name..' x'..n..'.')
                end
                if calculated then
                    target=label(tostring(C.items[name] or ''),85)
                else
                    target=UI.TextField{text=tostring(C.items[name] or ''),maxLength=7,style={width=85},
                        tooltip='Total resource quantity required. Owned resources are counted automatically.',onSubmit=setNeeded}
                end
                local cell={name=name,target=target,amount=amount,status=missing,lastTarget=C.items[name]}
                cartCells[#cartCells+1]=cell
                local sourceCount=0; for _ in pairs(C.sources[name] or {}) do sourceCount=sourceCount+1 end
                local nameLabel=not flat and sourceCount>1 and (name..' (shared total)') or name
                local purpose=resourcePurpose(name)
                local nameCell=flexLabel(nameLabel)
                local purposeCell=UI.Label{text=purpose and purpose:gsub('^For:%s*','') or 'Manual resource',
                    style={width=210,fontSize=13,color='#99BBDD',whiteSpace='wrap',flexShrink=0}}
                local actions
                if calculated then
                    actions=UI.Button{text='ⓘ',tooltip='Source information: click to open or close',style={width=26,height=24},onClick=function() showItemSource(name) end}
                else
                    actions=row{UI.Button{text='ⓘ',tooltip='Source information: click to open or close',style={width=26,height=24},onClick=function() showItemSource(name) end},UI.Button{text='Set',style={width=46},onClick=setNeeded},
                        UI.Button{text='Remove',style={width=76},onClick=function() C.remove(name); refreshCart() end}}
                end
                content:Add(row{nameCell,purposeCell,target,amount,missing,actions})
            end
            if flat then
                el.cart:Add(content)
            else
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
        end
        if #titles==0 then el.cart:Add(label(total==0 and 'Your list is empty. Add a recipe or materials to begin.'
            or 'No materials match this view. Choose All to see completed entries.')) end
        el.cartPage:SetText(cartView=='Cart' and
            ((groups['Cart'] and #groups['Cart'] or 0)..' materials') or
            ('Page '..page..' / '..pages..' - '..#titles..' entries'))
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
    if not ok or type(book)~='table' then if not quietRead then msg('Could not read your recipe book.') end; return end
    recipes={}; detailCache={}; itemIndex=nil; indexJob=nil
    for _,r in pairs(book) do if type(field(r,'name'))=='string' then recipes[#recipes+1]=r end end
    table.sort(recipes,function(a,b) return field(a,'name')<field(b,'name') end)
    -- Routine recipe refreshes do not clutter Activity or chat.
end
findRecipes=function()
    if #recipes==0 then readRecipes() end
    local search=string.lower(trim(el.search:GetText()))
    matches={}; recipePage=1
    if search=='' then
        selected=nil; picks={}
        if el.matches then el.matches:Clear() end
        if el.matchPage then el.matchPage:SetText('Search to see recipes') end
        if el.preview then el.preview:Clear() end
        return
    end
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
    if navigate then navigate('Cart') end
    msg((linkOnly==true and 'Labeled existing materials for ' or 'Added materials for ')..title..
        (saved and '. Saved.' or '. Saving failed; see chat.'))
end
-- Crafting plans use desired finished quantities; recipe details are read one per frame.
local bulkPlan,bulkJob,bulkReplace=nil,nil,nil
local bulkFailures={}
local addBulkPlan
local requestWantedRecipe
local previewBulkPlan
local simplePicked=nil
local enteredPlanItems={}
local function splitPlanText(text)
    text=tostring(text):gsub('(:%s*%d+)%s+','%1;')
    text=text:gsub('(%d+)%s+[xX]%s+',';%1 x ')
    return text:gsub('(%d+)%s+×%s+',';%1 x ')
end
local function planEntries(text)
    local entries={}
    for raw in splitPlanText(text):gmatch('[^;\r\n]+') do
        raw=trim(raw)
        if raw~='' then entries[#entries+1]=raw end
    end
    return entries
end
local function planItem(raw)
    raw=trim(raw):gsub('^%-%s+','')
    local name,n=raw:match('^(.-):%s*(%d+)%s*$')
    if not name then n,name=raw:match('^(%d+)%s+[xX]%s+(.+)$') end
    name=trim(name); n=number(n)
    if not valid(name) or not n or name:find(':%s*%d') then return nil end
    return name,n
end
local function planKey(s)
    return string.lower(trim(s)):gsub('^recipe:%s*','')
end
local function resetBulkPlan()
    bulkPlan=nil; bulkJob=nil; bulkReplace=nil; bulkFailures={}
    if el.bulkPreview then el.bulkPreview:Clear() end
    if el.bulkStatus then el.bulkStatus:SetText('Preview the plan before adding it.') end
end
local function showEnteredPlanItems()
    if el.bulkEntered then
        el.bulkEntered:SetText(#enteredPlanItems>0 and table.concat(enteredPlanItems,'\n') or 'No items entered yet.')
    end
end
local function enterPlanItems()
    local staged={}
    for _,raw in ipairs(planEntries(el.bulkInput:GetText())) do
        local name,n=planItem(raw)
        if not name then el.bulkStatus:SetText('Invalid entry: '..raw); msg('Error: Invalid plan entry: '..raw..'. Use 2 x Iron Lantern.'); return end
        staged[#staged+1]=n..' x '..name
    end
    if #staged==0 then return end
    if #enteredPlanItems+#staged>100 then el.bulkStatus:SetText('Enter up to 100 item rows per plan.'); return end
    resetBulkPlan()
    for _,line in ipairs(staged) do enteredPlanItems[#enteredPlanItems+1]=line end
    el.bulkInput:SetText(''); showEnteredPlanItems()
    el.bulkStatus:SetText('Checking recipes for your entered items...')
    previewBulkPlan()
end
previewBulkPlan=function()
    resetBulkPlan()
    local wanted,order={},{}
    local text=table.concat(enteredPlanItems,'; ')..'; '..tostring(el.bulkInput:GetText())
    for _,raw in ipairs(planEntries(text)) do
        local name,n=planItem(raw)
        if not name then
            el.bulkStatus:SetText('Invalid entry: '..raw); msg('Error: Invalid plan entry: '..raw..'. Use 2 x Iron Lantern.'); return
        end
        local key=planKey(name)
        if not wanted[key] then wanted[key]={name=name,quantity=0}; order[#order+1]=key end
        wanted[key].quantity=wanted[key].quantity+n
    end
    if #order==0 then el.bulkStatus:SetText('Enter at least one item.'); return end
    quietRead=true; readRecipes(); quietRead=false
    local byName={}
    for _,r in ipairs(recipes) do
        local key=planKey(field(r,'name'))
        byName[key]=byName[key] or {}; byName[key][#byName[key]+1]=r
    end
    bulkJob={wanted=wanted,order=order,byName=byName,index=1,entries={},errors=0,unresolved={}}
    el.bulkStatus:SetText('Checking '..#order..' items...')
end
local function bulkPlanStep()
    local job=bulkJob
    if not job then return end
    local key=job.order[job.index]
    if not key then
        bulkPlan=#job.entries>0 and job.entries or nil
        bulkFailures=job.unresolved
        bulkJob=nil
        if #job.entries>0 and job.autoAdd then addBulkPlan(); return end
        el.bulkStatus:SetText(job.errors==0 and
            'Materials are ready. Choose alternatives if needed, then click Add to cart.' or
            (#job.entries..' items ready to add; '..job.errors..' need attention. See the red messages below and Activity.'))
        return
    end
    local want=job.wanted[key]
    job.index=job.index+1
    local function fail(reason,missing)
        job.errors=job.errors+1
        job.unresolved[#job.unresolved+1]=want.quantity..' x '..want.name
        msg('Error: Check '..want.name..' x'..want.quantity..' — '..reason)
        el.bulkPreview:Add(UI.Label{text=want.name..': '..reason,style={color='#FF6666',whiteSpace='wrap',fontSize=14}})
        if missing then
            el.bulkPreview:Add(row{
                UI.Button{text='Wishlist',onClick=function() requestWantedRecipe(want.name,false) end},
                UI.Button{text='Add to cart',onClick=function() requestWantedRecipe(want.name,true) end},
            })
        end
    end
    local candidates=job.byName[key] or {}
    if #candidates~=1 then
        if #candidates==0 then
            local found=false
            for _,group in pairs(CraftersLedgerMasterRecipes or {}) do
                for _,r in ipairs(list(group)) do
                    if planKey(field(r,'name'))==key then found=true; break end
                end
                if found then break end
            end
            fail(found and 'Recipe not learned. Learn it or add the recipe to your cart.' or
                'Recipe not found. Check the name or learn the recipe.',found)
        else fail('More than one recipe matches. Choose it from the recipe search.') end
        return
    end
    local r=detail(candidates[1])
    local results=list(field(r,'results'))
    local output=nil
    for _,result in ipairs(results) do
        if planKey(field(result,'name'))==key then
            if output then fail('Output is ambiguous. Use Recipes.'); return end
            output=result
        end
    end
    if not output and #results==1 then output=results[1] end
    local yield=output and number(field(output,'quantity'))
    if not yield then fail('Finished-item yield unavailable. Use Recipes.'); return end
    local crafts=math.ceil(want.quantity/yield)
    local entry={title=tostring(field(r,'name')),sourceName=want.name,requested=want.quantity,crafts=crafts,output={},rows={}}
    local children={label(want.name..' — requested '..want.quantity..', makes '..(crafts*yield)..' ('..crafts..' crafts)')}
    for _,result in ipairs(results) do
        local q=number(field(result,'quantity'))
        if q then entry.output[#entry.output+1]=(q*crafts)..' x '..tostring(field(result,'name')) end
    end
    for _,ing in ipairs(list(field(r,'ingredients'))) do
        if field(ing,'optional')~=true then
            local q=number(field(ing,'quantity'))
            local tool=field(ing,'tool')==true
            if not q then fail('Ingredient quantities unavailable.'); return end
            local options={}
            if field(ing,'group')==true then
                for _,choice in ipairs(list(field(ing,'choices'))) do
                    local name=field(choice,'name')
                    if valid(name) then options[#options+1]=name end
                end
            elseif valid(field(ing,'name')) then options[1]=field(ing,'name') end
            if #options==0 then fail('Ingredient names or choices unavailable.'); return end
            local material={name=options[1],quantity=q*(tool and 1 or crafts),tool=tool}
            entry.rows[#entry.rows+1]=material
            if #options>1 then
                children[#children+1]=row{label('Need '..material.quantity..(tool and ' (tool)' or ''),145),
                    UI.Dropdown{choices=options,value=options[1],style={flexGrow=1},
                        onChange=function(_,name) material.name=name end}}
            else
                children[#children+1]=label('  '..material.name..': '..material.quantity..(tool and ' (tool, reused)' or ''))
            end
        end
    end
    if #entry.rows==0 then fail('Required ingredients unavailable.'); return end
    job.entries[#job.entries+1]=entry
    el.bulkPreview:Add(UI.Column{style={paddingBottom=10,flexShrink=0},children=children})
end
local function convertExistingItems()
    readRecipes()
    local known={}
    for _,r in ipairs(recipes) do known[planKey(field(r,'name'))]=true end
    local lines,snapshot={},{}
    for name,n in pairs(C.items) do
        if not next(C.sources[name] or {}) and known[planKey(name)] then
            lines[#lines+1]=name..': '..n; snapshot[name]=n
        end
    end
    table.sort(lines)
    if #lines==0 then msg('No ungrouped items match learned recipe names. Use Crafting plan to enter your items.'); return end
    enteredPlanItems={}; showEnteredPlanItems()
    el.bulkInput:SetText(table.concat(lines,'; '))
    previewBulkPlan()
    if bulkJob then bulkReplace=snapshot end
    if navigate then navigate('Crafting plan') end
    msg('Review this conversion. Add crafting plan will replace these finished-item entries with their resources.')
end
addBulkPlan=function()
    if bulkJob or not bulkPlan then msg('Preview a valid crafting plan first. Nothing added.'); return end
    if bulkReplace then
        for name,n in pairs(bulkReplace) do
            if C.items[name]~=n or next(C.sources[name] or {}) then
                msg('The list changed. Preview the conversion again. Nothing added.'); return
            end
        end
        for _,entry in ipairs(bulkPlan) do
            local name=entry.sourceName
            if bulkReplace[name] then C.items[name]=nil; C.sources[name]=nil; C.amounts[name]=nil end
        end
    end
    for _,entry in ipairs(bulkPlan) do
        for _,r in ipairs(entry.rows) do
            C.items[r.name]=r.tool and math.max(C.items[r.name] or 0,r.quantity) or
                (C.items[r.name] or 0)+r.quantity
            C.sources[r.name]=C.sources[r.name] or {}; C.sources[r.name][entry.title]=true
            if not r.tool then
                C.amounts[r.name]=C.amounts[r.name] or {}
                C.amounts[r.name][entry.title]=(C.amounts[r.name][entry.title] or 0)+r.quantity
            end
        end
        local old=C.projects[entry.title]
        C.projects[entry.title]={crafts=(old and old.crafts or 0)+entry.crafts,
            output=table.concat(entry.output,', '):gsub('[\t\r\n]',' ')}
        -- Existing recipe groups can include earlier batches: avoid showing a last-batch-only output.
        if old then C.projects[entry.title].output='' end
        C.untracked[entry.title]=nil
    end
    local activityDetails={}
    for _,entry in ipairs(bulkPlan) do
        activityDetails[#activityDetails+1]='- '..(#entry.output>0 and table.concat(entry.output,', ') or entry.title)
    end
    local remaining=bulkFailures
    local addedCount=#bulkPlan
    local saved=C.save()
    resetBulkPlan()
    el.bulkInput:SetText('')
    enteredPlanItems=remaining
    showEnteredPlanItems(); refreshCart()
    msg(saved and ('Added '..addedCount..' crafted items to the cart.') or
        'Plan added. Saving failed; see chat.',activityDetails)
    if #remaining>0 then
        el.bulkStatus:SetText('Added '..addedCount..' items. '..#remaining..' still need attention and remain in your draft. See Activity.')
        msg('Error: '..#remaining..' items were not added. Check recipes; these remain in your draft.',remaining)
    elseif navigate then navigate('Cart') end
end

local function searchSimpleRecipes()
    if not el.simpleMatches then return end
    quietRead=true; readRecipes(); quietRead=false
    el.simpleMatches:Clear()
    local query=planKey(el.simpleSearch:GetText())
    local shown,total=0,0
    for _,r in ipairs(recipes) do
        local name=tostring(field(r,'name'))
        if query~='' and string.find(planKey(name),query,1,true) then
            total=total+1
            if shown<8 then
                shown=shown+1
                local chosen=name
                el.simpleMatches:Add(UI.Button{text=name,style={height=28,flexGrow=0,flexShrink=0},onClick=function()
                    simplePicked=chosen
                    el.simpleSelected:SetText('Making: '..chosen)
                    enteredPlanItems={}; el.bulkInput:SetText((number(el.simpleQuantity:GetText()) or 1)..' x '..chosen)
                    previewBulkPlan()
                end})
            end
        end
    end
    if query=='' then el.simpleMatches:Add(label('Search for an item, then choose it below.'))
    elseif total==0 then el.simpleMatches:Add(label('No learned recipe matches. Learn the recipe first, or check its name in Recipes.'))
    elseif total>8 then el.simpleMatches:Add(label('Type more of the name to narrow the results.')) end
    if el.simpleResultsScroll then
        el.simpleResultsScroll:SetStyle{height=math.min(180,math.max(28,shown*30+(total>8 and 24 or 0))),flexGrow=0,flexShrink=0}
    end
end
local function addSimpleItem()
    if bulkPlan then addBulkPlan(); return end
    if bulkJob then bulkJob.autoAdd=true; return end
    if not simplePicked then msg('Choose an item from the search results first.'); return end
    local n=number(el.simpleQuantity:GetText())
    if not n then msg('Enter a quantity of 1 or more.'); return end
    enteredPlanItems={}; el.bulkInput:SetText(n..' x '..simplePicked)
    previewBulkPlan()
    if bulkJob then bulkJob.autoAdd=true end
end
local function addPastedPlan()
    previewBulkPlan()
    if bulkJob then bulkJob.autoAdd=true end
end
local function addManual()
    local name=trim(el.item:GetText())
    local n=number(el.amount:GetText())
    if not valid(name) or not n then msg('Enter an item name and a positive whole quantity.'); return end
    C.add(name,n); refreshCart()
    msg('Added '..name..' to your cart.')
end
-- Parse everything before changing the cart: a bad line never imports a partial list.
local function parseMaterialImport(text)
    local totals,groups={},{}
    local current=nil
    local function fail(line) return nil,nil,'Check this import line: '..line end
    -- The game's single-line field can replace pasted newlines with spaces.
    -- Recover our readable headings and bullet rows before parsing entries.
    text=tostring(text)
    text=text:gsub('(%s+—%s*[Mm]ake%s+%d+)%s*','%1;')
    text=text:gsub('(%s+–%s*[Mm]ake%s+%d+)%s*','%1;')
    text=text:gsub('(%s+%-%s*[Mm]ake%s+%d+)%s*','%1;')
    text=text:gsub('%s+%-%s+([^;\r\n]-:%s*%d+)',';%1')
    text=text:gsub('(:%s*%d+)%s+','%1;')
    for raw in tostring(text):gmatch('[^;\r\n]+') do
        local line=trim(raw)
        if line~='' then
            local title,count=line:match('^(.-)%s+—%s*[Mm]ake%s+(%d+)%s*$')
            if not title then title,count=line:match('^(.-)%s+–%s*[Mm]ake%s+(%d+)%s*$') end
            if not title then title,count=line:match('^(.-)%s+%-%s*[Mm]ake%s+(%d+)%s*$') end
            if title then
                title=trim(title); count=number(count)
                if not valid(title) or not count then return fail(line) end
                if groups[title] then return nil,nil,'Use one heading per item: '..title end
                current={crafts=count,materials={}}
                groups[title]=current
            else
                line=line:gsub('^%-%s+','')
                local name,n=line:match('^%s*(.-)%s*=%s*(%d+)%s*$')
                if not name then name,n=line:match('^%s*(.-)%s*:%s*(%d+)%s*$') end
                name=trim(name); n=number(n)
                if not valid(name) or not n then return fail(raw) end
                if name:find('=') or name:find(':%s*%d') or name:find('%s[Mm]ake%s+%d') then return fail(raw) end
                totals[name]=(totals[name] or 0)+n
                if current then current.materials[name]=(current.materials[name] or 0)+n end
            end
        end
    end
    if not next(totals) then return nil,nil,'Enter a material list first.' end
    for title,group in pairs(groups) do
        if not next(group.materials) then return nil,nil,'No materials listed for '..title end
    end
    return totals,groups
end
local function importList(groupExisting)
    local totals,groups,err=parseMaterialImport(el.materials:GetText())
    if not totals then msg(err..' Nothing imported.'); return end
    if groupExisting==true then
        if not next(groups) then msg('Include item headings to group existing materials.'); return end
        -- Only allocate quantities that are not already assigned to another recipe.
        for title in pairs(groups) do
            if C.projects[title] then msg('Already grouped: '..title..'. Nothing changed.'); return end
        end
        for name,n in pairs(totals) do
            local grouped=0
            for _,group in pairs(groups) do grouped=grouped+(group.materials[name] or 0) end
            if grouped~=n then msg('Put every material under an item heading. Nothing changed.'); return end
            local allocated=0
            for title in pairs(C.sources[name] or {}) do
                local share=C.amounts[name] and C.amounts[name][title]
                if not share then msg('Existing recipe allocation is unknown for '..name..'. Nothing changed.'); return end
                allocated=allocated+share
            end
            if (C.items[name] or 0)-allocated~=n then
                msg('Ungrouped '..name..' must match the pasted total ('..n..'). Nothing changed.'); return
            end
        end
    else
        for name,n in pairs(totals) do C.items[name]=(C.items[name] or 0)+n end
    end
    for title,group in pairs(groups) do
        for name,n in pairs(group.materials) do
            C.sources[name]=C.sources[name] or {}; C.sources[name][title]=true
            C.amounts[name]=C.amounts[name] or {}
            C.amounts[name][title]=(C.amounts[name][title] or 0)+n
        end
        local old=C.projects[title]
        local crafts=(old and old.crafts or 0)+group.crafts
        C.projects[title]={crafts=crafts,output=crafts..' x '..title}
        C.untracked[title]=nil
    end
    local saved=C.save(); refreshCart()
    if navigate then navigate('Cart') end
    local activityDetails={}
    for title,group in pairs(groups) do activityDetails[#activityDetails+1]='- '..title..' x'..group.crafts end
    if #activityDetails==0 then
        for name,n in pairs(totals) do activityDetails[#activityDetails+1]='- '..name..': '..n end
    end
    table.sort(activityDetails)
    msg((groupExisting==true and 'Existing materials grouped.' or 'Material list added.')..
        (saved and ' Cart saved.' or ' Saving failed; see chat.'),activityDetails)
end

-- Find items: every item your known recipes make or use, plus your cart, searchable by part
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

-- Missing recipes use names and categories only; no slow recipe-detail calls.
local missingJob,missingRows,missingCounts,missingError=nil,{},{},nil
local missingPage,missingTotal,missingKronic=1,0,false
local missingQuery,missingView='', 'Missing recipes'
local missingKnown={}
local MISSING_PAGE=12
local wishlistWin,wishlistRows,wishlistSearch=nil,nil,''
local refreshWishlist=nil
local function wantRecipe(r)
    C.wanted[r.name]={name=r.name,key=r.key,level=r.level}
    C.wishes['Recipe: '..r.name]=C.wishes['Recipe: '..r.name] or 1
    local saved=C.save()
    msg(saved and ('Added recipe to wanted list: '..r.name) or 'Recipe marked wanted. Saving failed; see chat.')
end
local function shopForRecipe(r)
    C.wanted[r.name]={name=r.name,key=r.key,level=r.level}
    local name='Recipe: '..r.name
    C.wishes[name]=C.wishes[name] or 1
    C.items[name]=math.max(1,C.items[name] or 0)
    C.sources[name]=C.sources[name] or {}; C.sources[name]['Recipes wanted']=true
    C.amounts[name]=C.amounts[name] or {}; C.amounts[name]['Recipes wanted']=C.items[name]
    C.untracked['Recipes wanted']=nil
    local saved=C.save(); refreshCart()
    msg(saved and ('Added to cart: '..name) or 'Recipe added. Saving failed; see chat.')
end
requestWantedRecipe=function(name,shop)
    for key,group in pairs(CraftersLedgerMasterRecipes or {}) do
        for _,r in ipairs(list(group)) do
            if planKey(field(r,'name'))==planKey(name) then
                local recipe={name=field(r,'name'),key=key,level=tonumber(field(r,'level'))}
                if shop then shopForRecipe(recipe) else wantRecipe(recipe) end
                return
            end
        end
    end
    msg('Recipe name not found in the reference list. Check Missing Recipes before adding it.')
end
local function skillName(key) return (key:gsub('^Crafting_','')) end
local function renderMissing()
    if not el.missingRows then return end
    el.missingRows:Clear()
    if missingQuery=='' and missingView=='Missing recipes' then
        el.missingStatus:SetText('Search to see missing recipes.')
        el.missingPage:SetText('')
        return
    end
    if missingJob then return end
    if missingError and missingView=='Missing recipes' then el.missingStatus:SetText(missingError); return end
    local rows={}
    local source=missingView=='Recipes wanted' and C.wanted or missingRows
    for _,r in pairs(source) do
        if string.find(string.lower(r.name),missingQuery,1,true) then rows[#rows+1]=r end
    end
    table.sort(rows,function(a,b)
        if a.key~=b.key then return a.key<b.key end
        return string.lower(a.name)<string.lower(b.name)
    end)
    local pages=math.max(1,math.ceil(#rows/MISSING_PAGE))
    missingPage=math.max(1,math.min(missingPage,pages))
    el.missingPage:SetText('Page '..missingPage..' / '..pages)
    el.missingStatus:SetText(#rows..' matching '..string.lower(missingView)..
        (missingView=='Missing recipes' and (' ('..missingTotal..' total missing)') or ''))
    local lastKey
    for i=(missingPage-1)*MISSING_PAGE+1,math.min(missingPage*MISSING_PAGE,#rows) do
        local r=rows[i]
        if r.key~=lastKey then
            el.missingRows:Add(UI.Label{text=skillName(r.key),class='heading',style={fontSize=16,marginTop=6}})
            lastKey=r.key
        end
        local learned=(missingKnown[r.key] or {})[string.lower(trim(r.name))]==true
        local actions={label(r.level and ('Level '..r.level) or 'Level unknown',115),
            flexLabel(r.name..(learned and ' (learned)' or ''))}
        if missingView=='Recipes wanted' then
            actions[#actions+1]=UI.Button{text='Remove wanted',onClick=function()
                C.wanted[r.name]=nil; C.save(); renderMissing(); msg('Removed from recipes wanted: '..r.name)
            end}
        elseif not C.wanted[r.name] then
            actions[#actions+1]=UI.Button{text='Wishlist',onClick=function() wantRecipe(r); renderMissing() end}
        else actions[#actions+1]=label('Wanted',80) end
        actions[#actions+1]=UI.Button{text='Add to cart',onClick=function() shopForRecipe(r); renderMissing() end}
        el.missingRows:Add(row(actions))
    end
    if #rows==0 then el.missingRows:Add(label(missingView=='Recipes wanted' and
        'No wanted recipes match. Find a missing recipe and click Want recipe.' or
        'No missing recipes match. This checks only the bundled recipe list.')) end
end
local function startMissing()
    missingPage=1; missingRows={}; missingCounts={}; missingTotal=0; missingError=nil
    local onlyKronic=missingKronic
    missingJob=coroutine.create(function()
        if type(CraftersLedgerMasterRecipes)~='table' then error('Master recipe list is unavailable.') end
        if type(ShroudGetKnownRecipes)~='function' then error('Known recipes API is unavailable.') end
        local ok,book=pcall(ShroudGetKnownRecipes)
        if not ok or type(book)~='table' then error('Could not read known recipes. Try Refresh recipes after login.') end
        local known,work={},0
        local function pause()
            work=work+1
            if work>=40 then work=0; coroutine.yield() end
        end
        for _,r in pairs(book) do
            local key,name=field(r,'categoryKey'),field(r,'name')
            if type(key)=='string' and type(name)=='string' and trim(name)~='' then
                known[key]=known[key] or {}; known[key][string.lower(trim(name))]=true
            end
            pause()
        end
        local keys,rows,counts,total={},{},{},0
        for key in pairs(CraftersLedgerMasterRecipes) do
            if type(key)=='string' then keys[#keys+1]=key end
            pause()
        end
        table.sort(keys)
        for _,key in ipairs(keys) do
            local group,seen={},{}
            for _,r in pairs(list(CraftersLedgerMasterRecipes[key])) do
                local name=field(r,'name')
                if type(name)=='string' then
                    name=trim(name)
                    local normalized=string.lower(name)
                    if name~='' and not seen[normalized] and not (known[key] or {})[normalized]
                        and (not onlyKronic or field(r,'kronic')==true) then
                        seen[normalized]=true
                        group[#group+1]={key=key,name=name,level=tonumber(field(r,'level'))}
                    end
                end
                pause()
            end
            table.sort(group,function(a,b)
                local al,bl=a.level or math.huge,b.level or math.huge
                if al~=bl then return al<bl end
                return string.lower(a.name)<string.lower(b.name)
            end)
            counts[#counts+1]={key=key,count=#group}; total=total+#group
            for _,r in ipairs(group) do r.count=#group; rows[#rows+1]=r; pause() end
            coroutine.yield()
        end
        missingRows=rows; missingCounts=counts; missingTotal=total; missingKnown=known
    end)
    if el.missingStatus then el.missingStatus:SetText('Checking known recipes against the master list...') end
    renderMissing()
end
local function missingStep()
    if not missingJob then return end
    local start=clock()
    for _=1,5 do
        local ok,err=coroutine.resume(missingJob)
        if not ok then
            missingJob=nil
            missingError='Missing recipes: '..tostring(err); renderMissing()
            return
        end
        if coroutine.status(missingJob)=='dead' then missingJob=nil; renderMissing(); return end
        local now=clock()
        if start and now and now-start>=STEP_SECONDS then return end
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
            or ('Searched '..n..' items, your bag and your cart. For anything else, type its full name.'))
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
        local add=UI.Button{text='Add',style={width=55},tooltip='Add the amount above to what your cart needs',
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
        elseif C.items[name] then about='On your cart'
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
        -- on the cart: what the list needs and what is still to get
        local color='@text'
        if need then
            local get=n and math.max(0,need-n)
            text=text..' | Need '..need..' | '..(get==nil and 'To get ...' or (get==0 and 'Ready' or ('To get '..get)))
            color=get==0 and '@green' or (get and '@red' or '#C9D5DF')
        end
        if cell.lastText~=text then cell.have:SetText(text); cell.lastText=text end
        if cell.lastColor~=color then pcall(function() cell.have:SetStyle{color=color} end); cell.lastColor=color end
        if itemOpen[string.lower(cell.name)] and cell.version~=ownedVersion and not naming then
            fillWhere(cell); cell.version=ownedVersion
        end
    end
end

-- The tracker: the cart on screen like the game's quest list. A compact window (Lua API 19):
-- its title bar only shows while the pointer is over it, so it reads like a see-through list, but it
-- can be stretched from any edge and faded like any window (right-click it for opacity). Recipe names
-- are headings with what you still need under them; X takes a recipe off the tracker (it stays on the
-- cart), like untracking a quest. Built again only when the lines change; counts update in place.
local tracker=nil            -- {win,box,lines={name->label},signature,visible}
local TRACK_MAX_ROWS=60      -- headings + materials shown; past that a "more" line (element limits)
-- Upgrade the old Dark setting and default to a nearly opaque panel.
if C.tracker.shade==65 then C.tracker.shade=90 end
if not C.minimalTracker then
    C.trackFilter='Still needed'; C.trackView='Resource list'; C.minimalTracker=true; C.save()
end
local SHADES={['None']=0,['Light']=25,['Medium']=60,['Dark']=90,['Solid']=100}
local SHADE_NAMES={'None','Light','Medium','Dark','Solid'}
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
        if missing==nil or missing>0 then left=left+1 end
        local include=C.trackFilter=='All resources' or (C.trackFilter=='Ready' and missing==0) or
            (C.trackFilter=='Still needed' and (missing==nil or missing>0))
        if include then
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
    if C.trackView=='Resource list' then
        local all,seen={},{}
        for _,title in ipairs(order) do
            for _,m in ipairs(groups[title]) do
                if not seen[m.name] then all[#all+1]=m; seen[m.name]=true end
            end
        end
        groups={}; order={}
        if #all>0 then groups.Resources=all; order={'Resources'} end
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
local function itemText(m)
    local left=m.have and math.max(0,m.need-m.have)
    if left==nil then return m.name..' ...' end
    if left==0 then return m.name..' - ready' end
    return m.name..' x'..left
end
local function fillTracker(groups,order,total,left,hidden)
    local box=tracker.box
    box:Clear(); tracker.lines={}
    local rows=0
    if total==0 then box:Add(UI.Label{text='Cart is empty',style={whiteSpace='wrap'}})
    elseif #order==0 then box:Add(UI.Label{text=C.trackFilter=='Ready' and 'No resources are ready yet.' or
        (hidden>0 and 'Tracked items are hidden. Use Track all.' or 'Nothing left to collect.'),style={color='@green',whiteSpace='wrap'}}) end
    for _,title in ipairs(order) do
        if rows>=TRACK_MAX_ROWS then break end
        local project=C.projects[title]
        local header={
            UI.Label{text=project and ((project.output or '')~='' and project.output or (title..' x'..project.crafts)) or (title=='Resources' and 'Shopping list' or title),
                style={flexGrow=1,flexShrink=1,whiteSpace='wrap',color='@gold'}},
            UI.Button{text='x',style={width=24,height=22,},
                tooltip='Take '..title..' off the tracker (it stays on your cart)',
                onClick=function() untrackRecipe(title) end}}
        if C.trackView=='Resource list' then table.remove(header) end
        box:Add(UI.Row{style={alignItems='center',marginTop=4,flexShrink=0},children=header})
        rows=rows+1
        for _,m in ipairs(groups[title]) do
            if rows>=TRACK_MAX_ROWS then break end
            local e=UI.Label{text=itemText(m),style={whiteSpace='wrap',paddingLeft=14,flexShrink=0}}
            tracker.lines[#tracker.lines+1]={el=e,name=m.name,title=title,text=itemText(m)}
            local itemName=m.name
            box:Add(UI.Row{style={alignItems='center',flexShrink=0},children={
                UI.Column{style={flexGrow=1,flexShrink=1},children={e}},
                UI.Button{text='ⓘ',tooltip='Source information: click to open or close',style={width=26,height=24},
                    onClick=function() showItemSource(itemName) end},
            }})
            rows=rows+1
        end
    end
    local more=0
    for _,title in ipairs(order) do more=more+1+#groups[title] end
    if more>rows then box:Add(UI.Label{text='...and more. Open /ledger to see everything.',style={}}) end
    if hidden>0 then
        box:Add(UI.Label{text=hidden..' hidden from the tracker. Cart > Track all to bring them back.',
            style={whiteSpace='wrap',marginTop=6}})
    end
end
local function refreshTracker()
    if not trackerShown() then return end
    local groups,order,total,left,hidden=trackerGroups()
    local parts={tostring(total==0),tostring(left==0),tostring(hidden),C.trackFilter,C.trackView}
    for _,title in ipairs(order) do
        local project=C.projects[title]
        parts[#parts+1]=title..'|'..(project and (project.crafts..'|'..(project.output or '')) or '')
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
local function setTrackerOption(key,value)
    C[key]=value; C.save()
    if tracker then tracker.signature=nil; refreshTracker() end
end
local function buildTracker()
    local t=C.tracker
    local box=UI.Column{style={paddingLeft=8,paddingRight=8,paddingTop=2,paddingBottom=6,flexShrink=0,
        borderRadius=3}}
    local scroll=UI.Scroll{id='ledger_tracker_scroll',style={flexGrow=1},children={box}}
    local win2=UI.Window{id='crafters_ledger_tracker_win',title='Shopping list',compact=true,
        width=math.max(t.w or 300,300),height=t.h or 320,minWidth=300,minHeight=120,
        x=t.x or 1480,y=t.y or 240,escCloses=false,
        onClose=function()
            if tracker then tracker.visible=false end
            C.tracker.shown=false; C.save()
        end,
        style={paddingTop=2,paddingBottom=2,backgroundColor=shadeColor(t.shade)},
        children={scroll}}
    tracker={win=win2,box=box,scroll=scroll,lines={},signature=nil,visible=true}
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
    msg('Every recipe on your cart is back on the tracker.')
end
function C.tracker_toggle() trackerToggleRequested=true end
local function setShade(pct)
    C.tracker.shade=pct; C.save()
    if tracker then
        pcall(function() tracker.win:SetStyle{backgroundColor=shadeColor(pct)} end)
    end
end
local function openWishlist()
    if wishlistWin then refreshWishlist(); wishlistWin:Show(); return end
    for name in pairs(C.wanted) do C.wishes['Recipe: '..name]=C.wishes['Recipe: '..name] or 1 end
    wishlistRows=UI.Column{style={flexShrink=0}}
    local itemInput=UI.TextField{text='',placeholder='Item name, recipe, pattern...',style={flexGrow=1},maxLength=160}
    local quantityInput=UI.TextField{text='1',style={width=65},maxLength=5}
    refreshWishlist=function()
        wishlistRows:Clear()
        local names={}
        for name in pairs(C.wishes) do
            if string.find(string.lower(name),wishlistSearch,1,true) then names[#names+1]=name end
        end
        table.sort(names)
        local shown=0
        for _,name in ipairs(names) do
            if shown>=30 then break end
            shown=shown+1
            local item=name
            wishlistRows:Add(row{flexLabel(item),label('x'..C.wishes[item],50),
                UI.Button{text='ⓘ',tooltip='Source information: click to open or close',style={width=26,height=24},onClick=function() showItemSource(item) end},
                UI.Button{text='Add to cart',onClick=function()
                    C.items[item]=math.max(C.items[item] or 0,C.wishes[item])
                    local saved=C.save(); refreshCart()
                    msg(saved and ('Added to cart: '..item..' x'..C.wishes[item]) or 'Item added. Saving failed; see chat.')
                end},
                UI.Button{text='Remove',onClick=function()
                    C.wishes[item]=nil
                    local recipeName=item:match('^Recipe:%s*(.+)$')
                    if recipeName then C.wanted[recipeName]=nil end
                    C.save(); refreshWishlist(); msg('Removed from wishlist: '..item)
                end}})
        end
        if #names==0 then wishlistRows:Add(label('Your wishlist is empty. Add anything you want to get.'))
        elseif #names>30 then wishlistRows:Add(label('Showing 30 of '..#names..'. Search to narrow the list.')) end
    end
    local function addWish()
        local name=trim(itemInput:GetText()); local n=number(quantityInput:GetText())
        if not valid(name) or not n then msg('Error: Enter an item name and quantity of 1 or more.'); return end
        C.wishes[name]=n; local saved=C.save()
        itemInput:SetText(''); refreshWishlist()
        msg(saved and ('Added to wishlist: '..name..' x'..n) or 'Wishlist updated. Saving failed; see chat.')
    end
    wishlistWin=UI.Window{id='crafters_ledger_wishlist',title='Wishlist',width=650,height=450,
        minWidth=560,minHeight=250,escCloses=true,children={
            row{itemInput,label('Qty',35),quantityInput,UI.Button{text='Add wish',onClick=addWish}},
            UI.TextField{text='',placeholder='Search wishlist',onChange=function(_,value)
                wishlistSearch=string.lower(trim(value)); refreshWishlist()
            end},
            UI.Scroll{style={height=0,flexGrow=1},children={wishlistRows}},
        }}
    refreshWishlist(); wishlistWin:Show()
end
local function buildUI()
    buildStage='start'
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
    el.materials=UI.TextField{text='',placeholder='Iron Lantern — make 2; Iron Ingot: 6; Glass Sheet: 2; Chunk of Coal: 6',maxLength=4000,style={flexGrow=1}}
    projectSignature=nil
    el.projects=UI.Column{style={paddingTop=6,paddingBottom=8}}
    el.summary=UI.Label{text='',class='heading',style={fontSize=16,whiteSpace='wrap'}}
    local listSearch=UI.TextField{text='',placeholder='Find an item you are making or a material',style={flexGrow=1},
        onChange=function(_,value) cartQuery=string.lower(trim(value)); page=1; refreshCart() end}
    local viewPicker=UI.Dropdown{choices={'To get','All','Ready'},value='To get',style={width=140},
        onChange=function(_,value) cartFilter=value; page=1; refreshCart() end}
    local clearArmed=false
    local clearCartButton,cancelClearButton
    local function cancelClearCart()
        clearArmed=false
        clearCartButton:SetText('Clear cart')
        cancelClearButton:SetVisible(false)
    end
    clearCartButton=UI.Button{text='Clear cart',
        tooltip='Remove all shopping materials and recipe groups, including hidden and filtered entries',
        onClick=function()
            if not clearArmed then
                clearArmed=true
                clearCartButton:SetText('Confirm clear ALL')
                cancelClearButton:SetVisible(true)
                msg('Clear ALL materials and recipe groups, including entries hidden by filters? Click Confirm clear ALL or Cancel.')
                return
            end
            C.items={}; C.projects={}; C.sources={}; C.amounts={}; C.untracked={}
            expanded={}; page=1; cartStructure=nil; projectSignature=nil
            local saved=C.save()
            cancelClearCart(); refreshCart()
            msg(saved and 'Cart cleared and saved.' or
                'Cart cleared in memory. Saving failed; see chat.')
        end}
    cancelClearButton=UI.Button{text='Cancel',visible=false,onClick=function()
        cancelClearCart(); msg('Clear cancelled. Your cart is unchanged.')
    end}
    -- A zero starting height makes this page fill the remaining window space,
    -- rather than growing the window layout to fit every expanded recipe.
    buildStage='cart'
    local shopPage=UI.Column{visible=false,style={height=0,flexGrow=1,flexShrink=1},children={
        el.summary,
        row{label('View',45),UI.Dropdown{choices={'By crafted item','Cart'},value=cartView,style={width=210},
            onChange=function(_,value) cartView=value; page=1; refreshCart(); if tracker then tracker.signature=nil; refreshTracker() end end}},
        row{listSearch,viewPicker,UI.Button{text='Refresh counts',onClick=function() forgetOwned(); refreshCart() end}},
        row{UI.Button{text='★ Wishlist',tooltip='Open your wishlist in a separate window',onClick=openWishlist},clearCartButton,cancelClearButton},
        row{label('On-screen tracker (like the quest list):',255),
            UI.Button{text='Show / hide',tooltip='See-through list of what you still need. Drag it by its grip.',
                onClick=function() setTracker(not trackerShown()) end},
            UI.Button{text='Track all',tooltip='Bring back recipes you took off the tracker with its x',
                onClick=function() trackAll() end},
            label('Background',85),
            UI.Dropdown{choices=SHADE_NAMES,value=shadeName(C.tracker.shade),style={width=120},
                onChange=function(_,v) setShade(SHADES[v] or 25) end}},
        row{label('Tracker shows',110),
            UI.Dropdown{choices={'Still needed','All resources','Ready'},value=C.trackFilter,style={width=155},
                onChange=function(_,value) setTrackerOption('trackFilter',value) end},
            label('Layout',65),UI.Dropdown{choices={'By item','Resource list'},value=C.trackView,style={width=145},
                onChange=function(_,value) setTrackerOption('trackView',value) end}},
        label('Required = total for your plan. Owned = what you have. Still to get = what is missing.'),
        label('Plan quantities are calculated. To replace a plan, remove its crafted-item group and add the new quantity.'),
        UI.Scroll{id='ledger_shopping_scroll',style={height=0,flexGrow=1,flexShrink=1},children={el.cart}},
        row{UI.Button{text='Previous',onClick=function() page=math.max(1,page-1); refreshCart() end},el.cartPage,
            UI.Button{text='Next',onClick=function() page=page+1; refreshCart() end}},
    }}
    buildStage='recipes'
    local browse=UI.Column{style={width=310,flexShrink=0,paddingRight=14},children={
        label('Learned recipes'),
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
        UI.Button{text='Add ingredients to cart',onClick=function() addRecipe(false) end},
        UI.Button{text='Label existing materials with this recipe',onClick=function() addRecipe(true) end},
    }}
    local recipesPage=UI.Row{visible=true,style={flexGrow=1,alignItems='stretch'},children={browse,plan}}
    el.bulkInput=UI.TextField{text='',placeholder='2 x Iron Lantern — press Enter to add a row',maxLength=12000,
        style={flexGrow=1},onSubmit=enterPlanItems,onChange=function() resetBulkPlan() end}
    el.bulkEntered=UI.Label{text='No items entered yet.',style={whiteSpace='wrap',fontSize=14}}
    el.bulkStatus=label('Search for an item, choose it, then add its materials.')
    el.bulkPreview=UI.Column{style={flexShrink=0,paddingRight=18}}
    el.simpleSearch=UI.TextField{text='',placeholder='Search learned recipes, e.g. lantern',style={flexGrow=1},
        onChange=function() simplePicked=nil; resetBulkPlan(); el.simpleSelected:SetText('Choose an item below.'); searchSimpleRecipes() end}
    el.simpleQuantity=UI.TextField{text='1',maxLength=5,style={width=70},onChange=function() resetBulkPlan() end}
    el.simpleMatches=UI.Column{style={flexShrink=0}}
    el.simpleSelected=label('Choose an item below.')
    local pasteSection=UI.Column{visible=false,style={flexShrink=0},children={
        label('Paste a list, or press Enter after each item. Example: 2 x Iron Lantern'),
        el.bulkInput,
        UI.Scroll{style={height=60,flexGrow=0,flexShrink=0},children={el.bulkEntered}},
        row{UI.Button{text='Add list to cart',onClick=addPastedPlan},
            UI.Button{text='Clear draft',onClick=function()
                resetBulkPlan(); enteredPlanItems={}; el.bulkInput:SetText(''); showEnteredPlanItems()
            end}},
    }}
    local pasteVisible=false
    el.simpleResultsScroll=UI.Scroll{style={height=28,flexGrow=0,flexShrink=0},children={el.simpleMatches}}
    buildStage='crafting'
    local bulkPage=UI.Column{visible=false,style={height=0,flexGrow=1,flexShrink=1,justifyContent='start'},children={
        row{el.simpleSearch,label('Quantity',75),el.simpleQuantity},
        el.simpleResultsScroll,
        el.simpleSelected,
        row{UI.Button{text='Add to cart',style={width=190,height=30,flexGrow=0},onClick=addSimpleItem},
        UI.Button{text='Paste a list...',style={width=140,height=30,flexGrow=0},onClick=function()
            pasteVisible=not pasteVisible; pasteSection:SetVisible(pasteVisible)
            resetBulkPlan(); enteredPlanItems={}; el.bulkInput:SetText(''); showEnteredPlanItems()
        end}},
        pasteSection,
        el.bulkStatus,
        UI.Scroll{id='ledger_bulk_scroll',style={height=0,flexGrow=1},children={el.bulkPreview}},
    }}
    buildStage='materials'
    local manualPage=UI.Column{visible=false,style={flexGrow=1},children={
        label('Add a material'),label('Use the exact in-game item name. Add increases your target; Set target replaces it.'),
        row{el.item,el.amount},
        row{UI.Button{text='Add to list',onClick=addManual},UI.Button{text='Set target',onClick=function()
            local name=trim(el.item:GetText()); local n=number(el.amount:GetText())
            if not valid(name) or not n then msg('Enter an item and a positive whole quantity.'); return end
            C.set(name,n); refreshCart(); msg('Updated target for '..name..'.')
        end}},
        label('For item names and quantities only, use Crafting plan to calculate resources.'),
        label('Paste materials or item headings with their materials'),
        label('Heading: Iron Lantern — make 2. Under it: Iron Ingot: 6. Amounts are totals for the batch.'),
        label('Separate lines with Enter or semicolons. Plain Item=quantity lists still work.'),
        el.materials,
        UI.Button{text='Add pasted items and materials',onClick=function() importList(false) end},
        UI.Button{text='Group existing materials (keep quantities)',onClick=function() importList(true) end},
        UI.Label{text='',style={flexGrow=1}},
    }}
    el.itemSearch=UI.TextField{text='',placeholder='Item name or words from it, e.g. black pearl',style={flexGrow=1},onSubmit=findItems}
    el.itemAmount=UI.TextField{text='1',maxLength=7,style={width=70}}
    el.itemResults=UI.Column{style={flexShrink=0,paddingRight=18}}
    el.itemPage=label('')
    el.itemStatus=label('Searches every item your recipes make or use, your bag and your cart. For anything else, type its full name.')
    itemCells={}
    buildStage='item search'
    local itemsPage=UI.Column{visible=false,style={height=0,flexGrow=1,flexShrink=1},children={
        row{el.itemSearch,UI.Button{text='Find',onClick=findItems},label('Amount to add',110),el.itemAmount},
        el.itemStatus,
        UI.Scroll{id='ledger_items_scroll',style={height=0,flexGrow=1,flexShrink=1},children={el.itemResults}},
        row{UI.Button{text='Previous',onClick=function() itemPage=math.max(1,itemPage-1); renderItems() end},el.itemPage,
            UI.Button{text='Next',onClick=function() itemPage=itemPage+1; renderItems() end}},
    }}
    el.missingStatus=label('')
    el.missingRows=UI.Column{style={flexShrink=0,paddingRight=18}}
    el.missingPage=label('')
    buildStage='missing recipes'
    local missingSection=UI.Column{visible=false,style={height=0,flexGrow=1,flexShrink=1},children={

        label('Want recipe saves it here. Shop recipe adds one Recipe: scroll to your cart.'),
        row{UI.Button{text='Refresh recipes',onClick=startMissing},
            UI.Toggle{text='Kronic recipes only',value=missingKronic,onChange=function(_,v)
                missingKronic=v==true; startMissing()
            end}},
        label('Compared with the bundled master list. Unknown levels appear last. Refresh after learning a recipe.'),
        el.missingStatus,
        UI.Scroll{id='ledger_missing_scroll',style={height=0,flexGrow=1,flexShrink=1},children={el.missingRows}},
        row{UI.Button{text='Previous',onClick=function() missingPage=math.max(1,missingPage-1); renderMissing() end},
            el.missingPage,UI.Button{text='Next',onClick=function() missingPage=missingPage+1; renderMissing() end}},
    }}
    el.activityRows=UI.Column{style={flexShrink=0,paddingRight=18}}
    el.activityPage=label('')
    refreshActivity=function()
        if not el.activityRows then return end
        activityDirty=false; el.activityRows:Clear()
        local pages=math.max(1,math.ceil(#activityHistory/10))
        activityPage=math.max(1,math.min(activityPage,pages))
        for i=(activityPage-1)*10+1,math.min(activityPage*10,#activityHistory) do
            local entry=activityHistory[i]
            local children={UI.Label{text=entry.text,style={color='#'..entry.color,whiteSpace='wrap',fontSize=15}}}
            if entry.details then
                children[#children+1]=UI.Label{text=table.concat(entry.details,'\n'),
                    style={paddingLeft=18,whiteSpace='wrap',fontSize=14}}
            end
            el.activityRows:Add(UI.Column{style={paddingBottom=14,flexShrink=0},children=children})
        end
        if #activityHistory==0 then el.activityRows:Add(label('No activity yet. Add items or use your cart.')) end
        el.activityPage:SetText('Page '..activityPage..' / '..pages..' — '..#activityHistory..' actions')
    end
    buildStage='activity'
    local activitySection=UI.Column{visible=false,style={height=0,flexGrow=1,flexShrink=1},children={
        label('Activity — newest first. Keeps the last 100 messages during this session.'),
        UI.Button{text='Clear history',tooltip='Clear only the activity history, not your cart',onClick=function()
            activityHistory={}; activityPage=1; activityDirty=true; refreshActivity()
        end},
        UI.Scroll{id='ledger_activity_scroll',style={height=0,flexGrow=1},children={el.activityRows}},
        row{UI.Button{text='Previous',onClick=function() activityPage=math.max(1,activityPage-1); refreshActivity() end},
            el.activityPage,UI.Button{text='Next',onClick=function() activityPage=activityPage+1; refreshActivity() end}},
    }}
    local addMode='Craft something'
    local resourceAdvanced=false
    local recipeMode='Learned'
    local recipeQuery=''
    local function selectAddMode(value)
        addMode=value
        bulkPage:SetVisible(value=='Craft something')
        itemsPage:SetVisible(value=='Find/add resources' and not resourceAdvanced)
        manualPage:SetVisible(value=='Find/add resources' and resourceAdvanced)
        if value=='Craft something' then searchSimpleRecipes()
        elseif not itemIndex then startIndex(); renderItems() end
    end
    local advancedButton
    advancedButton=UI.Button{text='Paste resource quantities...',onClick=function()
        resourceAdvanced=not resourceAdvanced
        advancedButton:SetText(resourceAdvanced and 'Back to resource search' or 'Paste resource quantities...')
        selectAddMode('Find/add resources')
    end}
    local resourceTools=UI.Column{visible=false,style={flexShrink=0},children={advancedButton}}
    local addPicker=UI.Dropdown{choices={'Craft something','Find/add resources'},value=addMode,style={width=220},
        onChange=function(_,value)
            resourceTools:SetVisible(value=='Find/add resources'); selectAddMode(value)
        end}
    local addSection=UI.Column{visible=false,style={height=0,flexGrow=1,flexShrink=1},children={
        row{label('I want to',85),addPicker},resourceTools,bulkPage,itemsPage,manualPage,
    }}
    local function selectRecipeMode(value)
        recipeMode=value
        recipesPage:SetVisible(value=='Learned')
        missingSection:SetVisible(value~='Learned')
        if value=='Learned' then el.search:SetText(recipeQuery); findRecipes()
        else
            missingView=value=='Wishlist' and 'Recipes wanted' or 'Missing recipes'
            missingQuery=string.lower(trim(recipeQuery)); missingPage=1
            if value=='Missing' then startMissing() else renderMissing() end
        end
    end
    local recipesSearch=UI.TextField{text='',placeholder='Search recipes, e.g. lantern',style={flexGrow=1},
        onChange=function(_,value)
            recipeQuery=value; el.search:SetText(value)
            missingQuery=string.lower(trim(value)); missingPage=1
            if recipeMode=='Learned' then findRecipes() else renderMissing() end
        end}
    local recipePicker=UI.Dropdown{choices={'Learned','Missing'},value=recipeMode,style={width=160},
        onChange=function(_,value) selectRecipeMode(value) end}
    local recipesSection=UI.Column{visible=false,style={height=0,flexGrow=1,flexShrink=1},children={
        row{recipesSearch,recipePicker},recipesPage,missingSection,
    }}
    local pages={['Add items']=addSection,['Cart']=shopPage,Recipes=recipesSection,Activity=activitySection}
    local navLabel=UI.Label{text='Add items',class='heading',style={fontSize=16,flexGrow=1}}
    local navButtons={}
    navigate=function(name)
        if name=='Crafting plan' then
            name='Add items'; addPicker:SetValue('Craft something'); resourceTools:SetVisible(false); selectAddMode('Craft something')
        elseif name=='Find items' or name=='Add materials' then
            resourceAdvanced=name=='Add materials'; name='Add items'
            addPicker:SetValue('Find/add resources'); resourceTools:SetVisible(true)
            advancedButton:SetText(resourceAdvanced and 'Back to resource search' or 'Paste resource quantities...')
            selectAddMode('Find/add resources')
        elseif name=='Missing Recipes' then
            name='Recipes'; recipePicker:SetValue('Missing'); selectRecipeMode('Missing')
        end
        for key,section in pairs(pages) do section:SetVisible(key==name) end
        navLabel:SetText(name)
        for key,button in pairs(navButtons) do
            button:SetStyle{color=key==name and '@gold' or '#C9D5DF',backgroundColor=key==name and '#151B23DD' or '#00000033'}
        end
        if name=='Activity' then refreshActivity() end
        if name=='Add items' then selectAddMode(addMode) end
        if name=='Cart' then refreshCart() end
        if name=='Recipes' then selectRecipeMode(recipeMode) end
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
    for _,entry in ipairs({
        {'Add items','Add items',130},{'Cart','Cart',140},
        {'Recipes','Recipes',120},{'Activity','Activity',120},
    }) do
        local key=entry[1]
        navButtons[key]=UI.Button{text=entry[2],style={width=entry[3],height=32,fontSize=14,flexShrink=0},
            onClick=function() navigate(key) end}
    end
    buildStage='main window'
    win=UI.Window{id='crafters_ledger_v3',title="Crafters Ledger",width=1000,height=650,
        minWidth=900,minHeight=460,x=70,y=70,escCloses=true,
        style={paddingLeft=16,paddingRight=16,paddingTop=10,paddingBottom=10},children={
            UI.Row{style={alignItems='center',flexShrink=0,marginBottom=8},children={
                navButtons['Add items'],navButtons['Cart'],navButtons.Recipes,navButtons.Activity,
            }},
            row{navLabel,label('Count resources in:',140),invToggle,acctToggle},
            addSection,shopPage,recipesSection,activitySection,
            el.message,
            el.counting,
        }}
    buildStage='initial refresh'
    preview(); refreshCart(); navigate('Crafting plan'); win:Show()
    buildStage='running'
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
local function registerChatCommand(name,help,run)
    if not Shroud or not Shroud.Command then return false,'Commands unavailable' end
    local ok,registered,reason=pcall(function()
        return Shroud.Command{name=name,help=help,run=run}
    end)
    if not ok then return false,tostring(registered) end
    if not registered then return false,tostring(reason or 'Registration rejected') end
    return true
end
function ShroudOnStart()
    lifecycle('Enabled','00FF00')
    openRequested=true
    local registered,reason=registerChatCommand('ledger','Open Crafters Ledger.',function() C.open() end)
    if registered then
        if type(ShroudConsoleLog)=='function' then ShroudConsoleLog('[FFFF00]/ledger[-]')
        else print('/ledger') end
    else
        say('Could not register /ledger: '..tostring(reason)..'. Use the book icon.')
    end
    registerChatCommand('shopping','Open Crafters Ledger.',function() C.open() end)
    registerChatCommand('basket','Open Crafters Ledger.',function() C.open() end)
    registerChatCommand('ledgertrack','Show or hide the shopping tracker.',function() C.tracker_toggle() end)
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
                button=UI.IconButton{texture=texture,tooltip="Crafters Ledger - open your cart",
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
    if activityDirty and refreshActivity and el.activityRows then
        local ok,err=pcall(refreshActivity)
        if not ok then activityDirty=false; print('Activity display unavailable: '..tostring(err)) end
    end
    if bulkJob then
        local ok,err=pcall(bulkPlanStep)
        if not ok then
            bulkJob=nil; bulkPlan=nil
            if el.bulkStatus then el.bulkStatus:SetText('Could not preview the plan. Nothing added: '..tostring(err)); msg('Error: Could not calculate crafting plan: '..tostring(err)) end
        end
    end
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
        missingStep()
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
    if sourceWindow then pcall(function() sourceWindow:Destroy() end); sourceWindow=nil end
    if wishlistWin then pcall(function() wishlistWin:Destroy() end); wishlistWin=nil end
    lifecycle('Disabled','FF0000')
    saveCounts()
    openRequested=false; toggleRequested=false
    if win then pcall(function() win:Destroy() end); win=nil end
    if launcher then pcall(function() launcher:Destroy() end); launcher=nil end
    if tracker then saveTrackerPlace(); pcall(function() tracker.win:Destroy() end); tracker=nil end
end

