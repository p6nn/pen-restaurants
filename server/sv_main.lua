local restaurantChannels = {}
local channelCounter = 100

---@param src number
---@param desired boolean
---@return boolean
local function setDuty(src, desired)
    if exports.qbx_core and exports.qbx_core.SetJobDuty then
        exports.qbx_core:SetJobDuty(src, desired)
        return true
    end
    return false
end

---@param cid string
---@param restaurant string
---@return any
local function clockInDatabase(cid, restaurant)
    return MySQL.insert.await(
        "INSERT INTO pen_restaurant_clockin (player_id, restaurant, status) VALUES (?, ?, 'clocked_in')",
        { cid, restaurant }
    )
end

---@param cid string
---@param restaurant string
---@return number|nil
local function getOpenClockinId(cid, restaurant)
    local row = MySQL.single.await(
        "SELECT id FROM pen_restaurant_clockin WHERE player_id = ? AND restaurant = ? AND status = 'clocked_in' ORDER BY id DESC LIMIT 1",
        { cid, restaurant }
    )
    return row and row.id or nil
end

---@param id number|nil
---@return number
local function clockOutDatabaseById(id)
    if not id then return 0 end
    return MySQL.update.await(
        [[
            UPDATE pen_restaurant_clockin
            SET clock_out_time = NOW(),
                hours_worked   = ROUND(TIMESTAMPDIFF(SECOND, clock_in_time, NOW())/3600, 2),
                status         = 'clocked_out'
            WHERE id = ?
        ]],
        { id }
    )
end

---@param cid string
---@return number
local function clockOutAllOpenRowsForCid(cid)
    if not cid then return 0 end
    return MySQL.update.await(
        [[
            UPDATE pen_restaurant_clockin
            SET clock_out_time = NOW(),
                hours_worked   = ROUND(TIMESTAMPDIFF(SECOND, clock_in_time, NOW())/3600, 2),
                status         = 'clocked_out'
            WHERE player_id = ? AND status = 'clocked_in'
        ]],
        { cid }
    )
end

---@param restaurant string
---@return integer
local function CountPlayersOnDuty(restaurant)
    if not restaurant then return 0 end
    local resCfg = Config.restaurant and Config.restaurant[restaurant]
    if not resCfg or not resCfg.requiredJob then return 0 end
    local jobName = resCfg.requiredJob
    local count = 0
    local players = GetPlayers() or {}
    for _, s in ipairs(players) do
        local p = exports.qbx_core:GetPlayer(s)
        if p and p.PlayerData and p.PlayerData.job then
            local j = p.PlayerData.job
            if j.name == jobName and j.onduty then
                count = count + 1
            end
        end
    end
    return count
end

---@param n any
---@param fallback any
---@return any
local function safeNumber(n, fallback)
    n = tonumber(n)
    if not n or n < 0 then return fallback or 0 end
    return n
end

---@param restaurant any
---@return string
local function getCompanyAccountName(restaurant)
    local r = Config.restaurant and Config.restaurant[restaurant]
    return r and r.companyAccount or nil
end

---@param key any
---@return string
---@return any
local function getItemFromConfigKey(key)
    local entry = Config.shopPrices[key]
    if type(entry) == "table" then
        return entry.item or key, safeNumber(entry.price, 0)
    end
    return key, safeNumber(entry, 0)
end

---@param src any
---@param item any
---@param qty any
---@return boolean
local function giveItem(src, item, qty)
    qty = safeNumber(qty, 1)
    if exports.ox_inventory then
        exports.ox_inventory:AddItem(src, item, qty)
        return true
    end
    print(("[pen-restaurant] Give %sx %s to %s (no ox_inventory export found)"):format(qty, item, src))
    return true
end

---@param src any
---@param total any
---@return boolean
local function chargePersonal(src, total)
    total = safeNumber(total, 0)
    if total <= 0 then return true end

    if exports.qbx_core then
        local success = exports.qbx_core:RemoveMoney(src, 'bank', total, 'restaurant-ingredient-purchase')
        return success ~= false
    end

    print(("[pen-restaurant] Charge personal %s skipped (no qbx_core)."):format(total))
    return true
end

---@param restaurant any
---@param total any
---@return boolean
local function chargeCompany(restaurant, total)
    total = safeNumber(total, 0)
    if total <= 0 then return true end

    local account = getCompanyAccountName(restaurant)
    if not account then
        print(("[pen-restaurant] No company account for %s; cannot charge company."):format(tostring(restaurant)))
        return false
    end

    -- TODO: banking shit
    print(("[pen-restaurant] (FAKE) Charged company account %s for %s"):format(account, total))
    return true
end

---@param src number
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    local ply = exports.qbx_core:GetPlayer(src)
    if not ply or not ply.PlayerData then return end
    local cid = ply.PlayerData.citizenid
    clockOutAllOpenRowsForCid(cid)
    for key, _ in pairs(Config.restaurant) do
        TriggerClientEvent('pen-restaurant:staff:client:updated', -1, key)
    end
end)

---@param res string
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    MySQL.update.await(
        [[
            UPDATE pen_restaurant_clockin
            SET clock_out_time = NOW(),
                hours_worked   = ROUND(TIMESTAMPDIFF(SECOND, clock_in_time, NOW())/3600, 2),
                status         = 'clocked_out'
            WHERE status = 'clocked_in'
        ]],
        {}
    )
    for key, _ in pairs(Config.restaurant) do
        TriggerClientEvent('pen-restaurant:staff:client:updated', -1, key)
    end
end)

---@param restaurant string
---@param entering boolean
RegisterNetEvent("pen-restaurant:driveThru:server:zoneChange", function(restaurant, entering)
    local src = source
    if not restaurantChannels[restaurant] then
        restaurantChannels[restaurant] = channelCounter
        channelCounter += 1
    end
    local callChannel = restaurantChannels[restaurant]
    TriggerClientEvent("pen-restaurant:driveThru:client:applyCallChannel", src, entering, callChannel, restaurant)
end)

---@param restaurant string
RegisterNetEvent("pen-restaurant:server:clockIn", function(restaurant)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local cfg = Config.restaurant[restaurant]
    if not cfg then return end
    local job = player.PlayerData.job
    local jobName = job and job.name
    if jobName ~= cfg.requiredJob then
        TriggerClientEvent("ox_lib:notify", src, { title="Access Denied", description="You don't have permission to clock in here.", type="error" })
        return
    end
    local cid = player.PlayerData.citizenid
    local desiredDuty = not (job and job.onduty == true)
    if not setDuty(src, desiredDuty) then
        TriggerClientEvent("ox_lib:notify", src, { title="Duty", description="Failed to toggle duty.", type="error" })
        return
    end
    if desiredDuty then
        clockInDatabase(cid, restaurant)
        TriggerClientEvent("ox_lib:notify", src, { title="Clocked In", description="You have clocked in at " .. cfg.label, type="success" })
    else
        local openId = getOpenClockinId(cid, restaurant)
        if openId then clockOutDatabaseById(openId) end
        TriggerClientEvent("ox_lib:notify", src, { title="Clocked Out", description="You have clocked out at " .. cfg.label, type="inform" })
    end
    TriggerClientEvent('pen-restaurant:staff:client:updated', -1, restaurant)
end)

---@param data any
RegisterNetEvent('pen-restaurant:shop:server:checkoutBasket', function(data)
    local src = source
    local restaurant = data and data.restaurant
    local items = (data and data.items) or {}
    local payment = (data and data.payment) or 'company'

    if type(items) ~= 'table' or #items == 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Basket is empty.' })
        TriggerClientEvent('pen-restaurant:nui:message', src, { type='basketResult', ok=false, error='empty' })
        return
    end

    local total = 0
    local normalized = {}

    for _, it in ipairs(items) do
        local key = it.itemName
        local qty = safeNumber(it.qty, 1)
        local itemDbName, unitPrice = getItemFromConfigKey(key)
        if unitPrice <= 0 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = ('Invalid price for %s'):format(key) })
            TriggerClientEvent('pen-restaurant:nui:message', src, { type='basketResult', ok=false, error='invalid_price' })
            return
        end
        total = total + unitPrice * qty
        normalized[#normalized+1] = { item = itemDbName, key = key, qty = qty, unit = unitPrice }
    end

    local ok = false
    if payment == 'personal' then
        ok = chargePersonal(src, total)
    else
        ok = chargeCompany(restaurant, total)
    end
    if not ok then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Payment failed.' })
        TriggerClientEvent('pen-restaurant:nui:message', src, { type='basketResult', ok=false, error='payment_failed' })
        return
    end

    for _, row in ipairs(normalized) do
        giveItem(src, row.item, row.qty)
    end

    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Purchased %d items ($%s)'):format(#normalized, total) })
    TriggerClientEvent('pen-restaurant:nui:message', src, { type='basketResult', ok=true })
end)


---@param source number
---@param restaurant string
---@return table
lib.callback.register('pen-restaurant:getStats', function(source, restaurant)
    local result = MySQL.query.await('SELECT total_revenue, total_transactions, total_tips FROM pen_restaurant_stats WHERE restaurant = ? AND date = CURDATE()', {restaurant})
    if result and result[1] then
        return {
            totalRevenue = result[1].total_revenue or 0,
            dailyTransactions = result[1].total_transactions or 0,
            totalTips = result[1].total_tips or 0,
            staffOnline = CountPlayersOnDuty(restaurant)
        }
    end
    return { totalRevenue = 0, dailyTransactions = 0, totalTips = 0 }
end)

---@param source number
---@param restaurant string
---@param limit number
---@return table
lib.callback.register('pen-restaurant:getTransactionHistory', function(source, restaurant, limit)
    local result = MySQL.query.await('SELECT * FROM pen_restaurant_transactions WHERE restaurant = ? ORDER BY created_at DESC LIMIT ?', {restaurant, limit or 50})
    return result or {}
end)

---@param source number
---@param restaurant string
---@return table
lib.callback.register('pen-restaurant:getClockinHistory', function(source, restaurant)
    local result = MySQL.query.await(
        'SELECT player_id, restaurant, clock_in_time, clock_out_time, hours_worked FROM pen_restaurant_clockin WHERE restaurant = ? ORDER BY clock_in_time DESC LIMIT 50',
        { restaurant }
    )

    for _, row in ipairs(result) do
        local player = exports.qbx_core:GetPlayerByCitizenId(row.player_id)
        if player then
            row.player_name = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')
        else
            row.player_name = nil
        end
    end

    return result
end)

---@param source number
---@param restaurant string
---@return table
lib.callback.register('pen-restaurant:getRegisterStats', function(source, restaurant)
    local dailyStats = MySQL.query.await('SELECT total_revenue, total_transactions FROM pen_restaurant_stats WHERE restaurant = ? AND date = CURDATE()', {restaurant})
    local recentTransactions = MySQL.query.await('SELECT * FROM pen_restaurant_transactions WHERE restaurant = ? ORDER BY created_at DESC LIMIT 10', {restaurant})
    return {
        dailyTotal = dailyStats[1] and dailyStats[1].total_revenue or 0,
        dailyTransactions = dailyStats[1] and dailyStats[1].total_transactions or 0,
        recentTransactions = recentTransactions or {},
        totalTransactions = #(recentTransactions or {})
    }
end)

CreateThread(function()
    for restaurantName, data in pairs(Config.restaurant) do
        if data.stashName then
            exports.ox_inventory:RegisterStash(data.stashName, data.label .. " Storage", 50, 50000, true)
        end
    end
end)
