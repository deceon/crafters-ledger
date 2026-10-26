-- Crafters Ledger v3.2.16. Legacy ShoppingCart commands and save file remain compatible.
ShoppingCart = {items={},projects={},sources={},amounts={}}
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
    C.projects[title]=nil
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
local refreshCart,preview,findRecipes
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
        local n=have and (have[string.lower(name)] or 0)
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
    local summary=have and (ready..' of '..total..' materials ready | '..units..' units still to get')
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
        local n=have and (have[string.lower(cell.name)] or 0)
        local text=n and tostring(n) or '?'
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
preview=function()
    if not el.preview then return end
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
        children[#children+1]=label('Have '..(have[string.lower(tostring(field(item,'name') or ''))] or 0),80)
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
local function readRecipes()
    local ok,book=false,nil
    if type(ShroudGetKnownRecipes)=='function' then ok,book=pcall(ShroudGetKnownRecipes) end
    if not ok or type(book)~='table' or next(book)==nil then
        ok,book=pcall(ShroudGetRecipeBook)
    end
    if not ok or type(book)~='table' then msg('Could not read your recipe book.'); return end
    recipes={}; detailCache={}
    for _,r in pairs(book) do if type(field(r,'name'))=='string' then recipes[#recipes+1]=r end end
    table.sort(recipes,function(a,b) return field(a,'name')<field(b,'name') end)
    msg('Read '..#recipes..' recipes. Search by part of the name.')
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
        row{listSearch,viewPicker,UI.Button{text='Refresh counts',onClick=refreshCart}},
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
    local pages={['Shopping list']=shopPage,Recipes=recipesPage,['Add materials']=manualPage}
    local activePage='Recipes'
    local navLabel=label('Recipes')
    navigate=function(name)
        activePage=name
        for key,section in pairs(pages) do section:SetVisible(key==name) end
        navLabel:SetText(name)
        if name=='Shopping list' then refreshCart() end
    end
    win=UI.Window{id='crafters_ledger_v3',title="Crafters Ledger",width=1000,height=650,
        minWidth=900,minHeight=460,x=70,y=70,escCloses=true,
        style={paddingLeft=16,paddingRight=16,paddingTop=10,paddingBottom=10},children={
            row{UI.Button{text='Recipes',onClick=function() navigate('Recipes') end},
                UI.Button{text='Shopping list',onClick=function() navigate('Shopping list') end},
                UI.Button{text='Add materials',onClick=function() navigate('Add materials') end}},
            navLabel,shopPage,recipesPage,manualPage,
            el.message,
            label('Carried inventory only | Updates automatically | Saved between sessions'),
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
local elapsed=0
function ShroudOnUpdate()
    if toggleRequested then
        toggleRequested=false
        local ok,err=pcall(function()
            if win and win:IsShown() then win:Hide() else openWindow() end
        end)
        if not ok then say('Could not toggle window: '..tostring(err)) end
    end
    if openRequested then
        openRequested=false
        local ok,err=pcall(openWindow)
        if not ok then say('Interface could not open: '..tostring(err)) end
    end
    elapsed=elapsed+(tonumber(ShroudDeltaTime) or 0)
    if elapsed>=2 then
        elapsed=0
        if win then
            local ok,err=pcall(function() if win:IsShown() then refreshCart() end end)
            if not ok then say('Refresh failed: '..tostring(err)) end
        end
    end
end
function ShroudOnDisableScript()
    openRequested=false; toggleRequested=false
    if win then pcall(function() win:Destroy() end); win=nil end
    if launcher then pcall(function() launcher:Destroy() end); launcher=nil end
end

