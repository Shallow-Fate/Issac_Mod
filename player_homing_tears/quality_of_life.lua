-- Floor, payout, carrying capacity, and inventory-drop additions.
return function(mod)
    local game = Game()
    local SECRET_TYPES = {
        [RoomType.ROOM_SECRET] = true,
        [RoomType.ROOM_SUPERSECRET] = true,
        [RoomType.ROOM_ULTRASECRET] = true,
    }
    local GRID_WIDTH = 13
    local GRID_SIZE = GRID_WIDTH * GRID_WIDTH
    local DIRECTIONS = {
        { DoorSlot.LEFT0, -1 },
        { DoorSlot.UP0, -GRID_WIDTH },
        { DoorSlot.RIGHT0, 1 },
        { DoorSlot.DOWN0, GRID_WIDTH },
    }
    local PAYOUT_POOLS = {
        [4] = ItemPoolType.POOL_BEGGAR,
        [5] = ItemPoolType.POOL_DEMON_BEGGAR,
        [7] = ItemPoolType.POOL_KEY_MASTER,
        [9] = ItemPoolType.POOL_BOMB_BUM,
        [13] = ItemPoolType.POOL_BATTERY_BUM,
        [18] = ItemPoolType.POOL_ROTTEN_BEGGAR,
    }
    local TRADE_VARIANTS = {
        [2] = true, [3] = true, [4] = true, [5] = true,
        [7] = true, [9] = true, [13] = true, [17] = true, [18] = true,
    }
    local lastResources = {}
    local runStarted = false
    local dealLayouts = nil
    local dropMenu = { open = false, selected = 1, playerIndex = 0 }
    local dropFont = Font()
    local dropFontAttempted = false
    local DROP_PAGE_SIZE = 20

    local function ensureDropFont()
        if dropFont:IsLoaded() then return true end
        if dropFontAttempted then return false end
        dropFontAttempted = true
        if EID ~= nil and EID.modPath ~= nil then
            dropFont:Load(EID.modPath .. "resources/font/eid_cn_default.fnt")
            if dropFont:IsLoaded() then return true end
        end
        for _, path in ipairs({
            "font/cjk/lanapixel.fnt",
            "resources.zh/font/teammeatfontextended12.fnt",
        }) do
            dropFont:Load(path)
            if dropFont:IsLoaded() then return true end
        end
        return dropFont:IsLoaded()
    end

    local function drawDropText(message, x, y, selected)
        if ensureDropFont() then
            local color = selected and KColor(1, 0.9, 0.5, 1)
                or KColor(1, 1, 1, 1)
            dropFont:DrawStringUTF8(message, x, y, color, 0, false)
        end
    end

    local function collectibleName(id, info)
        local names = EID and EID.ItemNames and EID.ItemNames.zh_cn
        local translated = names and names["5.100." .. id]
        if translated ~= nil and translated ~= "" then return translated end
        local descriptions = EID and EID.descriptions
            and EID.descriptions.zh_cn and EID.descriptions.zh_cn.collectibles
        local entry = descriptions and descriptions[id]
        if entry ~= nil and entry[2] ~= nil and entry[2] ~= "" then
            return entry[2]
        end
        if Isaac.GetLocalizedString ~= nil and info ~= nil
            and info.Name ~= nil and info.Name:sub(1, 1) == "#" then
            local ok, localized = pcall(Isaac.GetLocalizedString,
                "Items", info.Name:sub(2), 13)
            if ok and localized ~= nil and localized ~= ""
                and localized ~= info.Name then
                return localized
            end
        end
        return "道具 #" .. id
    end

    local function isSecretType(roomType)
        return SECRET_TYPES[roomType] == true
    end

    local function getAdjacentIndex(index, slot)
        local x = index % GRID_WIDTH
        local y = math.floor(index / GRID_WIDTH)
        if slot == DoorSlot.LEFT0 and x > 0 then return index - 1 end
        if slot == DoorSlot.RIGHT0 and x < GRID_WIDTH - 1 then return index + 1 end
        if slot == DoorSlot.UP0 and y > 0 then return index - GRID_WIDTH end
        if slot == DoorSlot.DOWN0 and y < GRID_WIDTH - 1 then return index + GRID_WIDTH end
        return nil
    end

    local function revealSecretRooms()
        local level = game:GetLevel()
        local rooms = level:GetRooms()
        local changed = false
        for i = 0, rooms.Size - 1 do
            local descriptor = rooms:Get(i)
            if descriptor.Data ~= nil and isSecretType(descriptor.Data.Type) then
                local index = descriptor.SafeGridIndex or descriptor.GridIndex
                if index >= 0 then
                    -- GetRooms can return a descriptor copy. Write through the
                    -- current dimension's room index so the map keeps the change.
                    local writable = level:GetRoomByIdx(index)
                    if writable.Data ~= nil
                        and writable.ListIndex == descriptor.ListIndex then
                        local flags = writable.DisplayFlags | 5
                        if flags ~= writable.DisplayFlags then
                            writable.DisplayFlags = flags
                            changed = true
                        end
                    end
                end
            end
        end
        if changed then level:UpdateVisibility() end
    end

    local function uncoverAllSecretEntrances()
        local level = game:GetLevel()
        local rooms = level:GetRooms()
        for i = 0, rooms.Size - 1 do
            local hidden = rooms:Get(i)
            if hidden.GridIndex >= 0 and hidden.Data ~= nil
                and isSecretType(hidden.Data.Type)
                and hidden.Data.Shape == RoomShape.ROOMSHAPE_1x1 then
                for _, direction in ipairs(DIRECTIONS) do
                    local neighborIndex = getAdjacentIndex(hidden.GridIndex, direction[1])
                    if neighborIndex ~= nil then
                        local neighbor = level:GetRoomByIdx(neighborIndex)
                        if neighbor.Data ~= nil
                            and neighbor.Data.Shape == RoomShape.ROOMSHAPE_1x1 then
                            level:UncoverHiddenDoor(neighborIndex, (direction[1] + 2) % 4)
                        end
                    end
                end
            end
        end
    end

    local function openSecretDoors()
        local level = game:GetLevel()
        local room = game:GetRoom()
        local index = level:GetCurrentRoomIndex()
        local current = level:GetCurrentRoomDesc()
        for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
            local door = room:GetDoor(slot)
            local targetType = door and door.TargetRoomType or nil
            if not isSecretType(targetType) and index >= 0 and current.Data ~= nil
                and current.Data.Shape == RoomShape.ROOMSHAPE_1x1 then
                local targetIndex = getAdjacentIndex(index, slot)
                if targetIndex ~= nil then
                    local target = level:GetRoomByIdx(targetIndex)
                    if target.Data ~= nil then targetType = target.Data.Type end
                end
            end
            if isSecretType(targetType)
                or (current.Data ~= nil and isSecretType(current.Data.Type) and door ~= nil) then
                level:UncoverHiddenDoor(index, slot)
                door = room:GetDoor(slot)
                if door ~= nil then
                    if not door:IsOpen() then
                        door:TryBlowOpen(true, Isaac.GetPlayer(0))
                        door:Open()
                    end
                end
            end
        end
    end

    local function hasRoomType(level, roomType)
        local rooms = level:GetRooms()
        for i = 0, rooms.Size - 1 do
            local desc = rooms:Get(i)
            if desc.Data ~= nil and desc.Data.Type == roomType and desc.GridIndex >= 0 then
                return true
            end
        end
        return false
    end

    local function createRedDealRoom(level, roomData)
        if roomData == nil then return false end
        local rooms = level:GetRooms()
        local candidates = {}
        for i = 0, rooms.Size - 1 do
            local desc = rooms:Get(i)
            if desc.Data ~= nil and desc.GridIndex >= 0
                and desc.Data.Shape == RoomShape.ROOMSHAPE_1x1
                and desc.Data.Type ~= RoomType.ROOM_ANGEL
                and desc.Data.Type ~= RoomType.ROOM_DEVIL then
                table.insert(candidates, desc.GridIndex)
            end
        end
        -- Prefer the boss room just cleared, then other boss rooms and 1x1 rooms.
        local currentIndex = level:GetCurrentRoomIndex()
        table.sort(candidates, function(a, b)
            if (a == currentIndex) ~= (b == currentIndex) then
                return a == currentIndex
            end
            local aBoss = level:GetRoomByIdx(a).Data.Type == RoomType.ROOM_BOSS
            local bBoss = level:GetRoomByIdx(b).Data.Type == RoomType.ROOM_BOSS
            if aBoss ~= bBoss then return aBoss end
            return a < b
        end)
        for _, sourceIndex in ipairs(candidates) do
            for _, direction in ipairs(DIRECTIONS) do
                local slot = direction[1]
                local targetIndex = getAdjacentIndex(sourceIndex, slot)
                local entrance = (slot + 2) % 4
                if targetIndex ~= nil and targetIndex < GRID_SIZE
                    and roomData.Shape == RoomShape.ROOMSHAPE_1x1
                    and (roomData.Doors & (1 << entrance)) ~= 0
                    and level:GetRoomByIdx(targetIndex).Data == nil
                    and level:MakeRedRoomDoor(sourceIndex, slot) then
                    local added = level:GetRoomByIdx(targetIndex)
                    added.Data = roomData
                    added.DisplayFlags = added.DisplayFlags | 5
                    level:UpdateVisibility()
                    return true
                end
            end
        end
        return false
    end

    local function doorToward(fromIndex, toIndex)
        for _, direction in ipairs(DIRECTIONS) do
            if getAdjacentIndex(fromIndex, direction[1]) == toIndex then
                return direction[1]
            end
        end
        return nil
    end

    local function connectUltraSecretRoom(level, ultraIndex)
        -- Ultra secret rooms often sit one or two red rooms away from the map.
        -- Build the shortest corridor of red doors from a regular 1x1 room.
        local queue = { ultraIndex }
        local parent = { [ultraIndex] = false }
        local source
        local head = 1
        while head <= #queue and source == nil do
            local index = queue[head]
            head = head + 1
            for _, direction in ipairs(DIRECTIONS) do
                local nextIndex = getAdjacentIndex(index, direction[1])
                if nextIndex ~= nil and parent[nextIndex] == nil then
                    local desc = level:GetRoomByIdx(nextIndex)
                    if desc.Data == nil then
                        parent[nextIndex] = index
                        table.insert(queue, nextIndex)
                    elseif desc.Data.Shape == RoomShape.ROOMSHAPE_1x1
                        and desc.Data.Type ~= RoomType.ROOM_ULTRASECRET then
                        parent[nextIndex] = index
                        source = nextIndex
                        break
                    end
                end
            end
        end
        if source == nil then return end
        local current = source
        while current ~= ultraIndex do
            local nextIndex = parent[current]
            local slot = doorToward(current, nextIndex)
            if slot == nil or not level:MakeRedRoomDoor(current, slot) then return end
            local desc = level:GetRoomByIdx(nextIndex)
            desc.DisplayFlags = desc.DisplayFlags | 5
            current = nextIndex
        end
        level:UpdateVisibility()
    end

    local function connectAllUltraSecretRooms()
        local level = game:GetLevel()
        local rooms = level:GetRooms()
        local targets = {}
        for i = 0, rooms.Size - 1 do
            local desc = rooms:Get(i)
            if desc.Data ~= nil and desc.Data.Type == RoomType.ROOM_ULTRASECRET
                and desc.GridIndex >= 0 then
                table.insert(targets, desc.GridIndex)
            end
        end
        for _, index in ipairs(targets) do
            local desc = level:GetRoomByIdx(index)
            if desc.Data ~= nil and desc.Data.Type == RoomType.ROOM_ULTRASECRET then
                connectUltraSecretRoom(level, index)
            end
        end
    end

    local function setupDealRooms()
        local level = game:GetLevel()
        if hasRoomType(level, RoomType.ROOM_ANGEL)
            and hasRoomType(level, RoomType.ROOM_DEVIL) then return end
        local deal = level:GetRoomByIdx(GridRooms.ROOM_DEVIL_IDX)
        if deal.VisitedCount > 0 then return end
        if dealLayouts == nil then
            -- The vanilla deal index holds only one layout. Copy both layouts
            -- into persistent red rooms and leave that index as the devil room.
            deal.Data = nil
            level:InitializeDevilAngelRoom(true, false)
            local angelData = deal.Data
            deal.Data = nil
            level:InitializeDevilAngelRoom(false, true)
            dealLayouts = { angel = angelData, devil = deal.Data }
        end
        if not hasRoomType(level, RoomType.ROOM_ANGEL) then
            createRedDealRoom(level, dealLayouts.angel)
        end
        if not hasRoomType(level, RoomType.ROOM_DEVIL) then
            createRedDealRoom(level, dealLayouts.devil)
        end
    end

    local function bossWasDefeated()
        local room = game:GetRoom()
        return room:GetType() == RoomType.ROOM_BOSS and room:IsClear()
            and game:GetLevel():GetCurrentRoomDesc().Clear
    end

    local function keepDealDoorOpen()
        local level = game:GetLevel()
        local room = game:GetRoom()
        if bossWasDefeated() and not (
            hasRoomType(level, RoomType.ROOM_ANGEL)
            and hasRoomType(level, RoomType.ROOM_DEVIL)) then
            room:TrySpawnDevilRoomDoor(false, true)
        end
        for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
            local door = room:GetDoor(slot)
            if door ~= nil and (door.TargetRoomType == RoomType.ROOM_DEVIL
                or door.TargetRoomType == RoomType.ROOM_ANGEL) then
                if not door:IsOpen() then door:Open() end
            end
        end
    end

    local function grantExtraSlots(player)
        for _, item in ipairs({
            CollectibleType.COLLECTIBLE_SCHOOLBAG,
            CollectibleType.COLLECTIBLE_MOMS_PURSE,
            CollectibleType.COLLECTIBLE_POLYDACTYLY,
            CollectibleType.COLLECTIBLE_GUPPYS_EYE,
        }) do
            if not player:HasCollectible(item, true) then
                player:AddCollectible(item, 0, false)
            end
        end
    end

    local function resourceSnapshot(player)
        return {
            coins = player:GetNumCoins(), bombs = player:GetNumBombs(),
            keys = player:GetNumKeys(), hearts = player:GetHearts(),
            soul = player:GetSoulHearts(), bone = player:GetBoneHearts(),
        }
    end

    local function paidFor(slotVariant, before, after)
        if before == nil then return false end
        if slotVariant == 2 or slotVariant == 5 or slotVariant == 17 then
            return after.hearts < before.hearts or after.soul < before.soul
                or after.bone < before.bone
        elseif slotVariant == 7 then
            return after.keys < before.keys
        elseif slotVariant == 9 then
            return after.bombs < before.bombs
        end
        return after.coins < before.coins
    end

    local function giveFinalPayout(slot)
        local variant = slot.Variant
        local rng = slot:GetDropRNG()
        local item
        if variant == 2 then
            item = rng:RandomInt(2) == 0
                and CollectibleType.COLLECTIBLE_BLOOD_BAG
                or CollectibleType.COLLECTIBLE_IV_BAG
        elseif variant == 3 then
            item = CollectibleType.COLLECTIBLE_CRYSTAL_BALL
        elseif variant == 17 then
            item = game:GetDevilRoomDeals() > 0
                and CollectibleType.COLLECTIBLE_REDEMPTION
                or game:GetItemPool():GetCollectible(ItemPoolType.POOL_ANGEL, true, rng:Next())
        else
            local pool = PAYOUT_POOLS[variant]
            if pool == nil then return end
            item = game:GetItemPool():GetCollectible(pool, true, rng:Next())
            if variant == 4 then game:GetLevel():AddAngelRoomChance(0.35) end
            if variant == 18 then game:GetLevel():AddAngelRoomChance(0.10) end
        end
        if item == nil or item <= 0 then return end
        local position = game:GetRoom():FindFreePickupSpawnPosition(slot.Position, 40, true)
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE,
            item, position, Vector.Zero, nil)
        slot:Remove()
    end

    local function checkTrades()
        local players = {}
        for i = 0, game:GetNumPlayers() - 1 do
            local player = Isaac.GetPlayer(i)
            local key = GetPtrHash(player)
            local after = resourceSnapshot(player)
            table.insert(players, { player = player, before = lastResources[key], after = after })
            lastResources[key] = after
        end
        for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT, -1, -1, false, false)) do
            if TRADE_VARIANTS[entity.Variant] and entity:Exists() then
                for _, record in ipairs(players) do
                    local distance = record.player.Position:Distance(entity.Position)
                    if distance <= record.player.Size + entity.Size + 18
                        and paidFor(entity.Variant, record.before, record.after) then
                        giveFinalPayout(entity)
                        break
                    end
                end
            end
        end
    end

    local function onGameStarted(_, continued)
        runStarted = true
        lastResources = {}
        dealLayouts = nil
        if not continued then
            for i = 0, game:GetNumPlayers() - 1 do
                grantExtraSlots(Isaac.GetPlayer(i))
            end
        end
        connectAllUltraSecretRooms()
        revealSecretRooms()
        uncoverAllSecretEntrances()
        openSecretDoors()
    end

    local function onPlayerInit(_, player)
        if runStarted then grantExtraSlots(player) end
    end

    local function onNewLevel()
        lastResources = {}
        dealLayouts = nil
        if not runStarted then return end
        connectAllUltraSecretRooms()
        revealSecretRooms()
        uncoverAllSecretEntrances()
        openSecretDoors()
    end

    local function onNewRoom()
        lastResources = {}
        revealSecretRooms()
        openSecretDoors()
        if bossWasDefeated() then setupDealRooms() end
        keepDealDoorOpen()
    end

    local function onUpdate()
        checkTrades()
        if bossWasDefeated() then
            setupDealRooms()
            keepDealDoorOpen()
        end
    end

    local function inventoryFor(player)
        local result = {}
        local config = Isaac.GetItemConfig()
        for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET2 do
            local id = player:GetActiveItem(slot)
            if id ~= nil and id > 0 then
                local info = config:GetCollectible(id)
                table.insert(result, {
                    id = id, slot = slot,
                    name = collectibleName(id, info)
                        .. "（主动栏 " .. (slot + 1) .. "）",
                })
            end
        end
        local count = config:GetCollectibles().Size
        for id = 1, count - 1 do
            local info = config:GetCollectible(id)
            if info ~= nil and info.Type ~= ItemType.ITEM_ACTIVE then
                local owned = player:GetCollectibleNum(id, true)
                if owned > 0 then
                    table.insert(result, {
                        id = id, slot = ActiveSlot.SLOT_PRIMARY,
                        name = collectibleName(id, info)
                            .. (owned > 1 and (" ×" .. owned) or ""),
                    })
                end
            end
        end
        return result
    end

    local function dropSelected(player, entry)
        if entry == nil then return end
        local before = player:GetCollectibleNum(entry.id, true)
        if before <= 0 then return end
        local charge = 0
        if player:GetActiveItem(entry.slot) == entry.id then
            charge = player:GetActiveCharge(entry.slot)
        end
        player:RemoveCollectible(entry.id, true, entry.slot, true)
        if player:GetCollectibleNum(entry.id, true) >= before then return end
        local room = game:GetRoom()
        local position = room:FindFreePickupSpawnPosition(
            player.Position + Vector(0, 40), 20, true)
        local pickup = Isaac.Spawn(EntityType.ENTITY_PICKUP,
            PickupVariant.PICKUP_COLLECTIBLE, entry.id,
            position, Vector.Zero, player):ToPickup()
        pickup.Charge = charge
        pickup.Wait = 30
    end

    local function renderDropMenu(_, shaderName)
        if shaderName ~= "HomingTearsItemDrop" then return end
        if not game:IsPaused() then
            dropMenu.open = false
            return
        end
        if Input.IsButtonTriggered(Keyboard.KEY_F7, 0) then
            dropMenu.open = not dropMenu.open
            dropMenu.selected = 1
        end
        if not dropMenu.open then return end
        local numPlayers = game:GetNumPlayers()
        if numPlayers <= 0 then return end
        dropMenu.playerIndex = dropMenu.playerIndex % numPlayers
        if Input.IsButtonTriggered(Keyboard.KEY_Q, 0) then
            dropMenu.playerIndex = (dropMenu.playerIndex - 1) % numPlayers
            dropMenu.selected = 1
        elseif Input.IsButtonTriggered(Keyboard.KEY_E, 0) then
            dropMenu.playerIndex = (dropMenu.playerIndex + 1) % numPlayers
            dropMenu.selected = 1
        end
        local player = Isaac.GetPlayer(dropMenu.playerIndex)
        local items = inventoryFor(player)
        if #items > 0 then
            dropMenu.selected = math.min(dropMenu.selected, #items)
            if Input.IsButtonTriggered(Keyboard.KEY_W, 0) then
                dropMenu.selected = (dropMenu.selected - 3) % #items + 1
            elseif Input.IsButtonTriggered(Keyboard.KEY_S, 0) then
                dropMenu.selected = (dropMenu.selected + 1) % #items + 1
            elseif Input.IsButtonTriggered(Keyboard.KEY_A, 0) then
                dropMenu.selected = (dropMenu.selected - 2) % #items + 1
            elseif Input.IsButtonTriggered(Keyboard.KEY_D, 0) then
                dropMenu.selected = dropMenu.selected % #items + 1
            end
            if Input.IsButtonTriggered(Keyboard.KEY_ENTER, 0) then
                dropSelected(player, items[dropMenu.selected])
                dropMenu.selected = math.min(dropMenu.selected, math.max(1, #items - 1))
            end
        end
        drawDropText("F7 道具列表 | WASD 选择 | Enter 丢弃 | Q/E 切换角色", 48, 48, false)
        local page = math.floor((dropMenu.selected - 1) / DROP_PAGE_SIZE) + 1
        local totalPages = math.max(1, math.ceil(#items / DROP_PAGE_SIZE))
        drawDropText("角色 " .. (dropMenu.playerIndex + 1) .. " | 第 "
            .. page .. "/" .. totalPages .. " 页", 48, 62, false)
        local first = math.floor((dropMenu.selected - 1) / DROP_PAGE_SIZE)
            * DROP_PAGE_SIZE + 1
        for i = first, math.min(first + DROP_PAGE_SIZE - 1, #items) do
            local entry = items[i]
            local marker = i == dropMenu.selected and "> " or "  "
            local offset = i - first
            drawDropText(marker .. entry.name,
                48 + (offset % 2) * 260,
                80 + math.floor(offset / 2) * 16,
                i == dropMenu.selected)
        end
    end

    local function suppressNativeMenuInput(_, entity, hook, action)
        if not dropMenu.open or not game:IsPaused() then return end
        if action == ButtonAction.ACTION_MENUCONFIRM
            or action == ButtonAction.ACTION_UP
            or action == ButtonAction.ACTION_DOWN
            or action == ButtonAction.ACTION_LEFT
            or action == ButtonAction.ACTION_RIGHT then
            if hook == InputHook.GET_ACTION_VALUE then return 0 end
            return false
        end
    end

    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, onGameStarted)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, onPlayerInit)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, onNewLevel)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, onNewRoom)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, onUpdate)
    -- Shader callbacks draw after the built-in pause screen.
    mod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, renderDropMenu)
    mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, suppressNativeMenuInput)
end
