local target = exports.ox_target
local driveThruIntercomId = nil
local activeTrayZones = {}
local cookingZones = {}

local function createSubmix()
    driveThruIntercomId = CreateAudioSubmix('driveThruIntercom')
    SetAudioSubmixEffectRadioFx(driveThruIntercomId, 1)
    SetAudioSubmixEffectParamInt(driveThruIntercomId, 1, GetHashKey('default'), 1)
    SetAudioSubmixEffectParamFloat(driveThruIntercomId, 1, GetHashKey('freq_low'), 10.0)
    SetAudioSubmixEffectParamFloat(driveThruIntercomId, 1, GetHashKey('freq_hi'), 10000.0)
    SetAudioSubmixEffectParamFloat(driveThruIntercomId, 1, GetHashKey('rm_mod_freq'), 300.0)
    SetAudioSubmixEffectParamFloat(driveThruIntercomId, 1, GetHashKey('rm_mix'), 0.2)
    SetAudioSubmixEffectParamFloat(driveThruIntercomId, 1, GetHashKey('fudge'), 0.0)
    SetAudioSubmixEffectParamFloat(driveThruIntercomId, 1, GetHashKey('o_freq_lo'), 200.0)
    SetAudioSubmixEffectParamFloat(driveThruIntercomId, 1, GetHashKey('o_freq_hi'), 5000.0)
    AddAudioSubmixOutput(driveThruIntercomId, 1)
end

---@param entering boolean
---@param callChannel number
---@param restaurant string
local function applyDriveThruCall(entering, callChannel, restaurant)
    if entering then
        exports["pma-voice"]:setCallChannel(callChannel)
        MumbleSetAudioInputIntent(`music`)
        for i = 0, 255 do
            if NetworkIsPlayerActive(i) then
                local serverId = GetPlayerServerId(i)
                MumbleSetSubmixForServerId(serverId, driveThruIntercomId)
            end
        end
    else
        exports["pma-voice"]:removePlayerFromCall()
        MumbleSetAudioInputIntent(`speech`)
        for i = 0, 255 do
            if NetworkIsPlayerActive(i) then
                local serverId = GetPlayerServerId(i)
                MumbleSetSubmixForServerId(serverId, nil)
            end
        end
    end
end

---@param restaurant string
---@param entering boolean
local function startDriveThru(restaurant, entering)
    TriggerServerEvent("pen-restaurant:driveThru:server:zoneChange", restaurant, entering)
end

---@param restaurant string
---@return boolean
function isClockedIn(restaurant)
    if not restaurant then return false end
    local player = exports.qbx_core:GetPlayerData()
    if not player or not player.job then return false end
    local cfg = Config.restaurant[restaurant]
    if not cfg then return false end
    return player.job.name == cfg.requiredJob and player.job.onduty == true
end

---@param restaurant string
local function openStorage(restaurant)
    if isClockedIn(restaurant) then
        exports.ox_inventory:openInventory('stash', { id = Config.restaurant[restaurant].stashName })
    end
end

---@param restaurant string
---@return boolean
local function canAccessManagement(restaurant)
    if not restaurant then return false end
    local config = Config.restaurant[restaurant]
    if not config then return false end
    if Config.debug then return true end
    if not isClockedIn(restaurant) then return false end
    local player = exports.qbx_core:GetPlayerData()
    if not player or not player.job then return false end
    local playerGrade = player.job.grade and player.job.grade.level or 0
    local m = config.managementAccess
    if not m then return true end
    if m.allowedGrades then
        for _, grade in ipairs(m.allowedGrades) do
            if playerGrade == grade then return true end
        end
        return false
    end
    if m.minimumGrade then
        return playerGrade >= m.minimumGrade
    end
    return true
end

---@param restaurant string
function handleDriveThru(restaurant)
    startDriveThru(restaurant, true)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local zone
    zone = lib.zones.box({
        coords = playerCoords,
        size = vec3(1.0, 1.0, 4.0),
        onExit = function()
            startDriveThru(restaurant, false)
            if zone then zone:remove() end
        end,
        debug = Config.debug
    })
end

---@param restaurant string
---@param registerId number
local function handleRegister(restaurant, registerId)
    if not isClockedIn(restaurant) then
        exports.qbx_core:Notify('You must be clocked in to use the register', 'error')
        return
    end
    lib.callback('pen-restaurant:management:getFullMenu', false, function(fullMenu)
        if not fullMenu or #fullMenu == 0 then
            exports.qbx_core:Notify('No menu available', 'error')
            return
        end
        local menuOptions = {}
        for i, item in ipairs(fullMenu) do
            menuOptions[#menuOptions+1] = { value = i, label = item.name .. ' - $' .. item.price }
        end
        local input = lib.inputDialog('Point of Sale', {
            {type='number', label='Customer ID', description='Server ID of customer', required=true, min=1, max=1000},
            {type='select', label='Menu Item', options=menuOptions, required=true},
            {type='number', label='Quantity', default=1, min=1, max=50, required=true},
            {type='select', label='Payment Method', options={{value='cash',label='Cash'},{value='bank',label='Bank Card'}}, default='cash', required=true}
        })
        if input then
            local customerId, itemIndex, quantity, paymentMethod = input[1], input[2], input[3], input[4]
            local menuItem = fullMenu[itemIndex]
            if menuItem then
                local total = menuItem.price * quantity
                local confirm = lib.alertDialog({
                    header='Confirm Order',
                    content=string.format('Customer: %d\nItem: %s x%d\nTotal: $%.2f\nPayment: %s\n\nProcess this order?',
                        customerId, menuItem.name, quantity, total, paymentMethod:upper()),
                    centered=true, cancel=true
                })
                if confirm == 'confirm' then
                    TriggerServerEvent('pen-restaurant:register:server:processSale', {
                        restaurant=restaurant, customerId=customerId, itemIndex=itemIndex, itemName=menuItem.name,
                        quantity=quantity, totalAmount=total, paymentMethod=paymentMethod, registerId=registerId
                    })
                end
            end
        end
    end, restaurant)
end

---@param zoneData table
local function addZone(zoneData)
    if not zoneData.coords then return end
    target:addSphereZone({
        coords = zoneData.coords,
        radius = zoneData.radius or 1.5,
        debug = Config.debug,
        options = {{
            name = zoneData.option,
            label = zoneData.label,
            icon = zoneData.icon or "fa-solid fa-user-check",
            onSelect = zoneData.action
        }}
    })
end

---@param restaurant string
local function showCustomerMenu(restaurant)
    lib.callback('pen-restaurant:management:getFullMenu', false, function(fullMenu)
        if not fullMenu or #fullMenu == 0 then
            exports.qbx_core:Notify('No menu available', 'error')
            return
        end
        local menuOptions = {}
        for _, menuItem in ipairs(fullMenu) do
            local typeIcon = ""
            if menuItem.type == 'custom' then
                typeIcon = menuItem.recipeType == 'drinks' and "☕ " or "🍽️ "
            end
            menuOptions[#menuOptions+1] = {
                title = typeIcon .. menuItem.name,
                description = (menuItem.description or "Delicious " .. menuItem.name:lower()) .. " - $" .. (menuItem.price or 15),
                icon = 'utensils'
            }
        end
        lib.registerContext({
            id = 'customer_menu_' .. restaurant,
            title = Config.restaurant[restaurant].label .. ' - Menu',
            options = menuOptions
        })
        lib.showContext('customer_menu_' .. restaurant)
    end, restaurant)
end

RegisterNetEvent("pen-restaurant:driveThru:client:applyCallChannel", function(entering, callChannel, restaurant)
    applyDriveThruCall(entering, callChannel, restaurant)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if isUIOpen then closeManagementUI() end
    for _, zone in pairs(activeTrayZones) do if zone and zone.remove then zone:remove() end end
    for _, zone in pairs(cookingZones) do if zone and zone.remove then zone:remove() end end
    activeTrayZones = {}
    cookingZones = {}
end)

CreateThread(function()
    createSubmix()
    Wait(1000)
    for name, v in pairs(Config.restaurant) do
        local restaurantName = name
        local zones = {
            { coords=v.stashCoords, icon="fa-solid fa-box", radius=1.5, option="stash_"..restaurantName, label="Open Storage", action=function() openStorage(restaurantName) end },
            { coords=v.managementCoords, icon="fa-solid fa-chart-line", radius=1.5, option="management_"..restaurantName, label="Restaurant Management", action=function()
                if canAccessManagement(restaurantName) then
                    openManagementUI(restaurantName)
                else
                    exports.qbx_core:Notify('You need a higher job grade to access management', 'error')
                end
            end },
            { coords=v.clockInCoords, icon="fa-solid fa-clock", radius=1.5, option="clockin_"..restaurantName, label="Clock In/Out", action=function() TriggerServerEvent("pen-restaurant:server:clockIn", restaurantName) end }
        }
        for i = 1, #zones do addZone(zones[i]) end
        if v.registers then
            for regId, register in pairs(v.registers) do
                target:addSphereZone({
                    coords=register.coords, radius=1.5, debug=Config.debug,
                    options = {
                        {
                            name="register_"..restaurantName.."_"..regId,
                            label="Use "..register.label,
                            icon="fa-solid fa-cash-register",
                            onSelect=function() handleRegister(restaurantName, regId) end
                        },
                        {
                            name="register_mgmt_"..restaurantName.."_"..regId,
                            label="Management Interface",
                            icon="fa-solid fa-chart-line",
                            canInteract=function() return canAccessManagement(restaurantName) end,
                            onSelect=function()
                                openManagementUI(restaurantName)
                                Wait(100)
                                SendNUIMessage({ type="switchToTab", tab="register" })
                            end
                        }
                    }
                })
            end
        end
        if v.driveThruEnabled then
            local driveThruAction = function() handleDriveThru(restaurantName) end
            local driveThruLabel = "Connect to Drive-Thru"
            addZone({ coords=v.driveThruCoords, radius=1.5, option="drivethru_"..restaurantName, label=driveThruLabel, action=driveThruAction })
            addZone({ coords=v.driveThruWorkerCoords, radius=1.5, option="drivethruworker_"..restaurantName, label=driveThruLabel, action=driveThruAction })
        end
        if v.trays then
            for trayId, trayConfig in pairs(v.trays) do
                local zoneId = restaurantName .. "_" .. trayId
                if activeTrayZones[zoneId] then activeTrayZones[zoneId]:remove() end
                local stashId = "tray_" .. zoneId
                activeTrayZones[zoneId] = target:addSphereZone({
                    coords=trayConfig.coords, radius=1.0, debug=Config.debug,
                    options={{ name="open_tray_"..zoneId, label="Open "..trayConfig.label, icon="fa-solid fa-utensils",
                        onSelect=function() exports.ox_inventory:openInventory('stash', { id=stashId }) end }}
                })
            end
        end
        if v.cookingStations then
            for stationType, stations in pairs(v.cookingStations) do
                for i, coords in ipairs(stations) do
                    local zoneId = restaurantName .. "_" .. stationType .. "_" .. i
                    cookingZones[zoneId] = target:addSphereZone({
                        coords=coords, radius=1.5, debug=Config.debug,
                        options={{ name="cook_"..zoneId, label="Cook "..stationType:gsub("^%l", string.upper),
                            icon= stationType == "drinks" and "fa-solid fa-coffee" or "fa-solid fa-utensils",
                            canInteract=function() return isClockedIn(restaurantName) end,
                            onSelect=function() showCustomerMenu(restaurantName) end}}
                    })
                end
            end
        end
        if v.coords then
            addZone({
                coords=vector3(v.coords.x + 2.0, v.coords.y + 2.0, v.coords.z),
                icon="fa-solid fa-book-open", radius=2.0, option="menu_"..restaurantName, label="View Menu",
                action=function() showCustomerMenu(restaurantName) end
            })
        end
    end
end)