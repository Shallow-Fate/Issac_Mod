from pathlib import Path

import pytest


lupa = pytest.importorskip("lupa")
LuaRuntime = lupa.LuaRuntime
MOD_LUA = Path(__file__).resolve().parents[1] / "player_homing_tears" / "quality_of_life.lua"


def test_deal_rooms_appear_only_after_boss_clear_and_stay_open():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        """
        callbacks = {}
        RoomType = { ROOM_DEFAULT = 0, ROOM_SECRET = 1, ROOM_SUPERSECRET = 2,
            ROOM_ULTRASECRET = 3, ROOM_ANGEL = 4, ROOM_DEVIL = 5, ROOM_BOSS = 6 }
        RoomShape = { ROOMSHAPE_1x1 = 1 }
        DoorSlot = { LEFT0 = 0, UP0 = 1, RIGHT0 = 2, DOWN0 = 3, NUM_DOOR_SLOTS = 4 }
        GridRooms = { ROOM_DEVIL_IDX = -1 }
        ItemPoolType = {}
        EntityType = { ENTITY_SLOT = 1 }
        CollectibleType = { COLLECTIBLE_SCHOOLBAG = 1, COLLECTIBLE_MOMS_PURSE = 2,
            COLLECTIBLE_POLYDACTYLY = 3, COLLECTIBLE_GUPPYS_EYE = 665 }
        ModCallbacks = { MC_POST_GAME_STARTED = 1, MC_POST_PLAYER_INIT = 2,
            MC_POST_NEW_LEVEL = 3, MC_POST_NEW_ROOM = 4, MC_POST_UPDATE = 5,
            MC_GET_SHADER_PARAMS = 6, MC_INPUT_ACTION = 7 }
        function Font() return { IsLoaded = function() return false end } end
        function GetPtrHash(player) return player end

        local function descriptor(index, kind)
            return { GridIndex = index, SafeGridIndex = index, ListIndex = index,
                Data = kind and
                { Type = kind, Shape = 1, Doors = 15 } or nil,
                DisplayFlags = 0, VisitedCount = 0, Clear = false }
        end
        boss = descriptor(84, RoomType.ROOM_BOSS)
        local start = descriptor(80, RoomType.ROOM_DEFAULT)
        secret = descriptor(30, RoomType.ROOM_SECRET)
        supersecret = descriptor(31, RoomType.ROOM_SUPERSECRET)
        local offgrid = descriptor(-1, nil)
        local rooms = { boss, start, secret, supersecret }
        local byIndex = { [84] = boss, [80] = start, [30] = secret,
            [31] = supersecret, [-1] = offgrid }
        doors = {}
        level = { initCalls = 0, makeCalls = 0 }
        function level:GetRooms()
            return { Size = #rooms, Get = function(_, i)
                local original = rooms[i + 1]
                -- The list exposes room data for discovery, but its descriptors
                -- need not be the writable ones returned by GetRoomByIdx.
                return { GridIndex = original.GridIndex,
                    SafeGridIndex = original.SafeGridIndex,
                    ListIndex = original.ListIndex, Data = original.Data,
                    DisplayFlags = original.DisplayFlags,
                    VisitedCount = original.VisitedCount, Clear = original.Clear }
            end }
        end
        function level:GetRoomByIdx(index)
            if not byIndex[index] then byIndex[index] = descriptor(index, nil) end
            return byIndex[index]
        end
        function level:GetCurrentRoomDesc() return boss end
        function level:GetCurrentRoomIndex() return 84 end
        function level:InitializeDevilAngelRoom(angel)
            self.initCalls = self.initCalls + 1
            offgrid.Data = { Type = angel and RoomType.ROOM_ANGEL
                or RoomType.ROOM_DEVIL, Shape = 1, Doors = 15 }
        end
        function level:MakeRedRoomDoor(source, slot)
            local offsets = { [0] = -1, [1] = -13, [2] = 1, [3] = 13 }
            local target = source + offsets[slot]
            if self:GetRoomByIdx(target).Data then return false end
            local added = self:GetRoomByIdx(target)
            added.Data = { Type = RoomType.ROOM_DEFAULT, Shape = 1, Doors = 15 }
            table.insert(rooms, added)
            if source == 84 then
                doors[slot] = { target = target, open = false,
                    IsOpen = function(self) return self.open end,
                    Open = function(self) self.open = true end }
            end
            self.makeCalls = self.makeCalls + 1
            return true
        end
        function level:UpdateVisibility() end
        function level:UncoverHiddenDoor() end

        room = { clear = false, nativeDoorCalls = 0 }
        function room:GetType() return RoomType.ROOM_BOSS end
        function room:IsClear() return self.clear end
        function room:GetDoor(slot)
            local door = doors[slot]
            if door then door.TargetRoomType = level:GetRoomByIdx(door.target).Data.Type end
            return door
        end
        function room:TrySpawnDevilRoomDoor()
            self.nativeDoorCalls = self.nativeDoorCalls + 1
        end

        player = { items = {} }
        function player:HasCollectible(id) return self.items[id] == true end
        function player:AddCollectible(id) self.items[id] = true end
        function player:GetNumCoins() return 0 end
        function player:GetNumBombs() return 0 end
        function player:GetNumKeys() return 0 end
        function player:GetHearts() return 0 end
        function player:GetSoulHearts() return 0 end
        function player:GetBoneHearts() return 0 end

        game = {}
        function game:GetLevel() return level end
        function game:GetRoom() return room end
        function game:GetNumPlayers() return 1 end
        function Game() return game end
        Isaac = { GetPlayer = function() return player end,
            FindByType = function() return {} end }
        mod = { AddCallback = function(_, kind, callback) callbacks[kind] = callback end }
        """
    )
    lua.execute(MOD_LUA.read_text(encoding="utf-8"))(lua.globals().mod)

    lua.execute("callbacks[ModCallbacks.MC_POST_GAME_STARTED](nil, false)")
    assert lua.eval("player.items[CollectibleType.COLLECTIBLE_GUPPYS_EYE]") is True
    assert lua.eval("secret.DisplayFlags & 5") == 5
    assert lua.eval("supersecret.DisplayFlags & 5") == 5
    assert lua.eval("level.initCalls") == 0
    assert lua.eval("level.makeCalls") == 0

    lua.execute("callbacks[ModCallbacks.MC_POST_NEW_ROOM]()")
    lua.execute("callbacks[ModCallbacks.MC_POST_UPDATE]()")
    assert lua.eval("level.makeCalls") == 0

    lua.execute("room.clear = true; callbacks[ModCallbacks.MC_POST_UPDATE]()")
    assert lua.eval("level.makeCalls") == 0

    lua.execute("boss.Clear = true; callbacks[ModCallbacks.MC_POST_UPDATE]()")
    assert lua.eval("level.makeCalls") == 2
    assert lua.eval("level.initCalls") == 2
    assert lua.eval("(function() local a,d = 0,0; for _, door in pairs(doors) do "
                    "if door.TargetRoomType == RoomType.ROOM_ANGEL then a=a+1 end; "
                    "if door.TargetRoomType == RoomType.ROOM_DEVIL then d=d+1 end; "
                    "assert(door.open) end; return a==1 and d==1 end)()") is True

    lua.execute("for _, door in pairs(doors) do door.open = false end")
    lua.execute("callbacks[ModCallbacks.MC_POST_NEW_ROOM]()")
    assert lua.eval("level.makeCalls") == 2
    assert lua.eval("(function() for _, door in pairs(doors) do "
                    "if not door.open then return false end end; return true end)()") is True
