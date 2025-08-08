local isUIOpen = false
local currentRestaurant = nil
local currentMenu = {}
local lastRestaurant

---@param restaurant string
function openManagementUI(restaurant)
    if isUIOpen then return end
    if not Config.restaurant[restaurant] then return end
    currentRestaurant = restaurant
    local restaurantData = Config.restaurant[restaurant]
    lib.callback('pen-restaurant:getStats', false, function(stats)
        lib.callback('pen-restaurant:management:getFullMenu', false, function(fullMenu)
            currentMenu = fullMenu
            SendNUIMessage({
                type="openManagementUI",
                restaurant={ id=restaurant, name=restaurantData.label, menu=fullMenu, revenue=stats.totalRevenue, staffCount=stats.staffOnline },
                shopPrices=Config.shopPrices,
                tabAccess={ shop=true, menu=true, recipes=true, staff=true }
            })
            SetNuiFocus(true, true)
            isUIOpen = true
        end, restaurant)
    end, restaurant)
end

function closeManagementUI()
    if not isUIOpen then return end
    SendNUIMessage({ type="closeManagementUI" })
    SetNuiFocus(false, false)
    isUIOpen = false
    currentRestaurant = nil
    currentMenu = {}
end

---@param data table
---@param cb fun(result:string)
RegisterNUICallback("closeUI", function(_, cb)
    closeManagementUI()
    cb("ok")
end)

---@param data table
---@param cb fun(result:string)
RegisterNUICallback("createRecipe", function(data, cb)
    TriggerServerEvent('pen-restaurant:management:server:createRecipe', {
        restaurant=currentRestaurant, name=data.name, type=data.type, ingredients=data.ingredients, cookTime=data.cookTime, description=data.description
    })
    cb("ok")
end)

---@param data table
---@param cb fun(result:string)
RegisterNUICallback("updateRecipe", function(data, cb)
    data.restaurant = currentRestaurant or data.restaurant
    TriggerServerEvent('pen-restaurant:management:server:updateRecipe', data)
    cb("ok")
end)

---@param data table
---@param cb fun(result:string)
RegisterNUICallback("deleteRecipe", function(data, cb)
    TriggerServerEvent('pen-restaurant:management:server:deleteRecipe', data.recipeId)
    cb("ok")
end)

---@param data table
---@param cb fun(result:string)
RegisterNUICallback("getRecipes", function(data, cb)
    local restaurant = data.restaurant or currentRestaurant
    TriggerServerEvent('pen-restaurant:management:server:getRecipes', restaurant)
    cb("ok")
end)

---@param data table
---@param cb fun(result:string)
RegisterNUICallback('requestFullMenu', function(data, cb)
    local restaurant = data.restaurant or currentRestaurant
    lib.callback('pen-restaurant:management:getFullMenu', false, function(menu)
        SendNUIMessage({ type='refreshMenu', menu=menu or {} })
        cb('ok')
    end, restaurant)
end)

---@param data table
---@param cb fun(result:string)
RegisterNUICallback('checkoutBasket', function(data, cb)
    TriggerServerEvent('pen-restaurant:shop:server:checkoutBasket', data)
    cb('ok')
end)

---@param data {restaurant:string}
---@param cb fun(result:string)
RegisterNUICallback('getClockins', function(data, cb)
    local restaurant = data and data.restaurant or nil
    if not restaurant then cb('ok'); return end
    lib.callback('pen-restaurant:getClockinHistory', false, function(rows)
        SendNUIMessage({ type = 'clockinData', rows = rows or {} })
        cb('ok')
    end, restaurant)
end)


---@param payload table
RegisterNetEvent('pen-restaurant:nui:message', function(payload)
    if type(payload) ~= 'table' then return end
    SendNUIMessage(payload)
end)

---@param recipes table[]
RegisterNetEvent('pen-restaurant:management:client:recipesData', function(recipes)
    SendNUIMessage({ type="recipesData", recipes=recipes or {} })
end)

---@param restaurant string
RegisterNetEvent('pen-restaurant:management:client:refreshMenu', function(restaurant)
    if currentRestaurant == restaurant and isUIOpen then
        lib.callback('pen-restaurant:management:getFullMenu', false, function(fullMenu)
            currentMenu = fullMenu
            SendNUIMessage({ type="refreshMenu", menu=fullMenu })
        end, restaurant)
    end
end)

---@param restaurant string
RegisterNetEvent('pen-restaurant:management:client:recipesUpdated', function(restaurant)
    lib.callback('pen-restaurant:cooking:getRecipes', false, function(recipes)
        SendNUIMessage({ type='recipesData', recipes=recipes or {} })
    end, restaurant)
    lib.callback('pen-restaurant:management:getFullMenu', false, function(menu)
        SendNUIMessage({ type='refreshMenu', menu=menu or {} })
    end, restaurant)
end)

---@param staff table[]
local function sendStaffToNui(staff)
    SendNUIMessage({ type='staffData', staff=staff or {} })
end

---@param restaurant string
local function requestStaff(restaurant)
    if not restaurant then return end
    lastRestaurant = restaurant
    lib.callback('pen-restaurant:staff:getStaff', false, function(result)
        sendStaffToNui(result or {})
    end, restaurant)
end

---@param data table
---@param cb fun(result:string)
RegisterNUICallback('getStaff', function(data, cb)
    requestStaff(data and data.restaurant)
    cb('ok')
end)

---@param data table
---@param cb fun(result:string)
RegisterNUICallback('staffAction', function(data, cb)
    local restaurant = data and data.restaurant
    local action = data and data.action
    local cid = data and data.cid
    if not restaurant or not action or not cid then cb('ok'); return end
    TriggerServerEvent('pen-restaurant:staff:server:action', { restaurant=restaurant, action=action, cid=cid })
    cb('ok')
end)

---@param restaurant string
RegisterNetEvent('pen-restaurant:staff:client:updated', function(restaurant)
    SendNUIMessage({ type='staffUpdated', restaurant=restaurant })
    requestStaff(restaurant)
end)

---@param _onDuty boolean
RegisterNetEvent('QBCore:Client:SetDuty', function(_onDuty)
    if lastRestaurant then requestStaff(lastRestaurant) end
end)

---@param restaurant string
---@param stationType string
---@param recipeIndex number
---@param recipe table
function startCooking(restaurant, stationType, recipeIndex, recipe)
    lib.callback('pen-restaurant:cooking:hasIngredients', false, function(hasItems)
        if hasItems then
            local animDict = "amb@prop_human_bbq@male@base"
            local animName = "base"
            if recipe.name:lower():find("coffee") or recipe.name:lower():find("tea") or recipe.name:lower():find("drink") then
                animDict = "mp_ped_interaction"
                animName = "handshake_guy_a"
            end
            if lib.progressCircle({
                duration=recipe.cookTime, label="Preparing " .. recipe.name .. "...",
                useWhileDead=false, canCancel=true,
                disable={ move=true, car=true, mouse=false, combat=true },
                anim={ dict=animDict, clip=animName, flag=49 },
            }) then
                for _, ingredient in ipairs(recipe.ingredients) do
                    TriggerServerEvent('pen-restaurant:cooking:removeItem', ingredient, 1)
                end
                local itemName = recipe.name:lower():gsub(" ", "_")
                TriggerServerEvent('pen-restaurant:cooking:addItem', itemName, 1)
                exports.qbx_core:Notify('Successfully prepared ' .. recipe.name .. '!', 'success')
            else
                exports.qbx_core:Notify('Cooking cancelled!', 'error')
            end
        else
            local ingredientsList = table.concat(recipe.ingredients, ", "):gsub("_", " ")
            exports.qbx_core:Notify('Missing ingredients: ' .. ingredientsList, 'error')
        end
    end, recipe.ingredients)
end

---@param restaurant string
---@param stationType string
local function showCookingMenu(restaurant, stationType)
    lib.callback('pen-restaurant:cooking:getRecipes', false, function(recipes)
        if not recipes or #recipes == 0 then
            exports.qbx_core:Notify('No recipes available for ' .. stationType, 'error')
            return
        end
        local menuOptions = {}
        for i, recipe in ipairs(recipes) do
            local ingredients = {}
            if recipe.ingredients then
                local ok, decoded = pcall(json.decode, recipe.ingredients)
                if ok then ingredients = decoded end
            end
            local ingredientsList = table.concat(ingredients, ", "):gsub("_", " ")
            menuOptions[#menuOptions+1] = {
                title=recipe.name,
                description=(recipe.description or "Custom recipe") .. "\nIngredients: " .. ingredientsList,
                icon= stationType == "drinks" and "coffee" or "utensils",
                onSelect=function()
                    startCooking(restaurant, stationType, i, {
                        name=recipe.name, ingredients=ingredients, cookTime=recipe.cook_time or 10000, description=recipe.description
                    })
                end
            }
        end
        lib.registerContext({
            id='cooking_menu_'..restaurant..'_'..stationType,
            title=Config.restaurant[restaurant].label .. ' - ' .. stationType:gsub("^%l", string.upper) .. ' Menu',
            options=menuOptions
        })
        lib.showContext('cooking_menu_'..restaurant..'_'..stationType)
    end, restaurant, stationType)
end

exports('openCookingUI', openManagementUI)
exports('openManagementUI', openManagementUI)
