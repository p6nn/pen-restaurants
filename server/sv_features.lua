---@param playerId number
---@param restaurant string
function refreshRecipes(playerId, restaurant)
    MySQL.query('SELECT * FROM pen_restaurant_recipes WHERE restaurant = ? ORDER BY created_at DESC', {restaurant}, function(result)
        TriggerClientEvent('pen-restaurant:management:client:recipesData', playerId, result or {})
    end)
end

---@param restaurant string
---@param name string
---@param recipeType string
---@param ingredients table|string[]
---@param cookTime number
---@param description string
RegisterNetEvent('pen-restaurant:management:server:createRecipe', function(recipeData)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local restaurant = recipeData.restaurant
    local name = recipeData.name
    local recipeType = recipeData.type
    local ingredients = recipeData.ingredients
    local cookTime = recipeData.cookTime
    local description = recipeData.description
    if not restaurant or not name or not ingredients or #ingredients == 0 then
        TriggerClientEvent("ox_lib:notify", src, { title="Error", description="Invalid recipe data provided", type="error" })
        return
    end
    MySQL.insert('INSERT INTO pen_restaurant_recipes (restaurant, name, type, ingredients, cook_time, description, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { restaurant, name, recipeType, json.encode(ingredients), cookTime, description, src }, function(result)
        if result then
            TriggerClientEvent("ox_lib:notify", src, { title="Recipe Created", description="Successfully created recipe: " .. name, type="success" })
            refreshRecipes(src, restaurant)
        else
            TriggerClientEvent("ox_lib:notify", src, { title="Error", description="Failed to create recipe", type="error" })
        end
    end)
end)

---@param source number
---@param restaurant string
---@return table
lib.callback.register('pen-restaurant:management:getFullMenu', function(source, restaurant)
    local recipes = MySQL.query.await('SELECT * FROM pen_restaurant_recipes WHERE restaurant = ? ORDER BY type, name', {restaurant})
    local fullMenu = {}
    if recipes then
        for _, recipe in ipairs(recipes) do
            local basePrice = 8
            if recipe.published ~= nil and recipe.published ~= 1 then goto continue end
            local ingredients = {}
            if recipe.ingredients then
                local ok, decoded = pcall(json.decode, recipe.ingredients)
                if ok then
                    ingredients = decoded
                    for _, ing in ipairs(ingredients) do
                        local shopData = Config.shopPrices[ing]
                        local price = shopData and shopData.price or 2
                        basePrice = basePrice + (price * 0.3)
                    end
                end
            end
            fullMenu[#fullMenu+1] = {
                name = recipe.name,
                price = math.floor(basePrice),
                description = recipe.description or "Chef's special recipe",
                type = 'custom',
                recipeType = recipe.type
            }
            ::continue::
        end
    end
    return fullMenu
end)

---@param source number
---@param restaurant string
---@param recipeType string
---@return table
lib.callback.register('pen-restaurant:cooking:getRecipes', function(source, restaurant, recipeType)
    local result = MySQL.query.await('SELECT * FROM pen_restaurant_recipes WHERE restaurant = ? AND type = ? ORDER BY created_at DESC', {restaurant, recipeType})
    return result or {}
end)

---@param restaurant string
RegisterNetEvent('pen-restaurant:management:server:getRecipes', function(restaurant)
    local src = source
    MySQL.query('SELECT * FROM pen_restaurant_recipes WHERE restaurant = ? ORDER BY created_at DESC', {restaurant}, function(result)
        TriggerClientEvent('pen-restaurant:management:client:recipesData', src, result or {})
    end)
end)

---@param recipeId number
RegisterNetEvent('pen-restaurant:management:server:deleteRecipe', function(recipeId)
    local src = source
    local affected = MySQL.update.await('DELETE FROM pen_restaurant_recipes WHERE id = ?', { recipeId }) or 0
    if affected > 0 then
        TriggerClientEvent("ox_lib:notify", src, { title="Recipe Deleted", description="Recipe has been removed", type="success" })
    else
        TriggerClientEvent("ox_lib:notify", src, { title="Error", description="Failed to delete recipe", type="error" })
    end
end)

---@param saleData table
RegisterNetEvent('pen-restaurant:register:server:processSale', function(saleData)
    local src = source
    local cashier = exports.qbx_core:GetPlayer(src)
    local customer = exports.qbx_core:GetPlayer(saleData.customerId)
    if not cashier or not customer then
        TriggerClientEvent("ox_lib:notify", src, { title="Error", description="Invalid cashier or customer ID", type="error" })
        return
    end
    local restaurant = saleData.restaurant
    local config = Config.restaurant[restaurant]
    if not config then return end
    local amount = saleData.totalAmount
    local tax = amount * (config.taxRate or 0.1)
    local employeeTip = amount * (config.employeePayPercentage or 0.15)
    local paymentMethod = saleData.paymentMethod or 'cash'
    if customer.Functions.GetMoney(paymentMethod) >= amount then
        customer.Functions.RemoveMoney(paymentMethod, amount, 'restaurant-purchase')
        cashier.Functions.AddMoney('cash', employeeTip, 'restaurant-tip')
        MySQL.insert('INSERT INTO pen_restaurant_transactions (restaurant, cashier_id, customer_id, items, subtotal, tax, total, tip, payment_method) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { restaurant, src, saleData.customerId, json.encode({ { name = saleData.itemName, quantity = saleData.quantity, price = saleData.totalAmount / saleData.quantity } }),
              amount - tax, tax, amount, employeeTip, paymentMethod })
        MySQL.query('INSERT INTO pen_restaurant_stats (restaurant, date, total_revenue, total_transactions, total_tips) VALUES (?, CURDATE(), ?, 1, ?) ON DUPLICATE KEY UPDATE total_revenue = total_revenue + VALUES(total_revenue), total_transactions = total_transactions + VALUES(total_transactions), total_tips = total_tips + VALUES(total_tips)',
            { restaurant, amount, employeeTip })
        TriggerClientEvent("ox_lib:notify", src, { title="Sale Completed", description=string.format("Total: $%.2f | Your Tip: $%.2f", amount, employeeTip), type="success" })
        TriggerClientEvent("ox_lib:notify", saleData.customerId, { title="Purchase Complete", description=string.format("Paid $%.2f via %s", amount, paymentMethod), type="success" })
    else
        local deficit = amount - customer.Functions.GetMoney(paymentMethod)
        TriggerClientEvent("ox_lib:notify", src, { title="Payment Failed", description=string.format("Customer needs $%.2f more", deficit), type="error" })
        TriggerClientEvent("ox_lib:notify", saleData.customerId, { title="Insufficient Funds", description=string.format("You need $%.2f to complete this purchase", deficit), type="error" })
    end
end)

---@param src number
---@param restaurant string
---@return table
lib.callback.register('pen-restaurant:staff:getStaff', function(src, restaurant)
    local function hasManagementPerm(s, r, minGrade)
        local ply = exports.qbx_core:GetPlayer(s)
        if not ply or not ply.PlayerData or not ply.PlayerData.job then return false end

        local job = ply.PlayerData.job
        local cfg = Config.restaurant[r]
        if not cfg or not cfg.requiredJob then return false end

        -- Debug mode: treat current job as if it's the right one and at highest grade
        if Config.debug then
            return job.name == job.name -- always true
        end

        local grade = (job.grade and job.grade.level) or 0
        return job.name == cfg.requiredJob and grade >= (minGrade or 2)
    end

    if not hasManagementPerm(src, restaurant) then return {} end

    local list = {}
    for _, s in pairs(GetPlayers()) do
        local ply = exports.qbx_core:GetPlayer(s)
        if ply then
            local job = ply.PlayerData.job
            local cfg = Config.restaurant[restaurant]
            if job and cfg and job.name == cfg.requiredJob then
                local ci = ply.PlayerData.charinfo
                list[#list+1] = {
                    id    = tonumber(s),
                    cid   = ply.PlayerData.citizenid,
                    name  = (ci.firstname .. ' ' .. ci.lastname),
                    grade = job.grade.level,
                    role  = job.grade.name,
                    duty  = job.onduty  -- << was onDuty; JS expects "duty"
                }
            end
        end
    end
    return list
end)


---@param data table
RegisterNetEvent('pen-restaurant:staff:server:action', function(data)
    local src = source
    local function hasManagementPerm(s, r, minGrade)
        local ply = exports.qbx_core:GetPlayer(s)
        if not ply then return false end
        local job = ply.PlayerData.job
        local cfg = Config.restaurant[r]
        return job.name == cfg.requiredJob and job.grade.level >= (minGrade or 2)
    end
    if not hasManagementPerm(src, data.restaurant) then
        return TriggerClientEvent('ox_lib:notify', src, { type='error', description='Insufficient permissions.' })
    end
    local ok = false
    if data.action == 'toggleDuty' then
        for _, s in pairs(GetPlayers()) do
            local ply = exports.qbx_core:GetPlayer(s)
            if ply.PlayerData.citizenid == data.cid then
                ply:SetJobDuty(not ply.PlayerData.job.onduty)
                ok = true
                break
            end
        end
    elseif data.action == 'promote' or data.action == 'demote' then
        local delta = data.action == 'promote' and 1 or -1
        for _, s in pairs(GetPlayers()) do
            local ply = exports.qbx_core:GetPlayer(s)
            if ply.PlayerData.citizenid == data.cid then
                local job = ply.PlayerData.job
                ply:SetJob(job.name, math.max(0, job.grade.level + delta))
                ok = true
                break
            end
        end
    elseif data.action == 'remove' then
        for _, s in pairs(GetPlayers()) do
            local ply = exports.qbx_core:GetPlayer(s)
            if ply.PlayerData.citizenid == data.cid then
                ply:SetJob('unemployed', 0)
                ok = true
                break
            end
        end
    end
    if ok then
        TriggerClientEvent('pen-restaurant:staff:client:updated', -1, data.restaurant)
    else
        TriggerClientEvent('ox_lib:notify', src, { type='error', description='Action failed.' })
    end
end)

CreateThread(function()
    for restaurantName, config in pairs(Config.restaurant) do
        if config.trays then
            for trayId, trayConfig in pairs(config.trays) do
                local stashId = "tray_" .. restaurantName .. "_" .. trayId
                exports.ox_inventory:RegisterStash(stashId, trayConfig.label, 20, 25000, true)
            end
        end
    end
end)

---@param itemName string
---@param amount number
RegisterNetEvent('pen-restaurant:cooking:removeItem', function(itemName, amount)
    local src = source
    exports.ox_inventory:RemoveItem(src, itemName, amount)
end)

---@param itemName string
---@param amount number
RegisterNetEvent('pen-restaurant:cooking:addItem', function(itemName, amount)
    local src = source
    exports.ox_inventory:AddItem(src, itemName, amount)
end)

---@param source number
---@param ingredients string[]
---@return boolean
lib.callback.register('pen-restaurant:cooking:hasIngredients', function(source, ingredients)
    for _, ingredient in ipairs(ingredients) do
        local count = exports.ox_inventory:Search(source, 'count', ingredient)
        if count < 1 then
            return false
        end
    end
    return true
end)