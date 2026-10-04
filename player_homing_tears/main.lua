local mod = RegisterMod("Player Homing Tears", 1)

local HOMING_FLAG = TearFlags.TEAR_HOMING
local PIERCING_FLAG = TearFlags.TEAR_PIERCING
local SPECTRAL_FLAG = TearFlags.TEAR_SPECTRAL
local HOMING_STRENGTH = 0.30
local MIN_VECTOR_LENGTH = 0.001
local STARTING_PICKUP_COUNT = 99

local function onPlayerInit(_, player)
    player:AddCoins(STARTING_PICKUP_COUNT - player:GetNumCoins())
    player:AddBombs(STARTING_PICKUP_COUNT - player:GetNumBombs())
    player:AddKeys(STARTING_PICKUP_COUNT - player:GetNumKeys())
end

local function getPlayerOwner(entity)
    if entity == nil then
        return nil
    end

    if entity.Type == EntityType.ENTITY_PLAYER then
        return entity:ToPlayer()
    end

    if entity.Type == EntityType.ENTITY_FAMILIAR then
        local familiar = entity:ToFamiliar()
        if familiar ~= nil then
            return familiar.Player
        end
    end

    return nil
end

local function isPlayerOwnedAttack(attack)
    if attack == nil then
        return false
    end

    if getPlayerOwner(attack.SpawnerEntity) ~= nil then
        return true
    end

    if getPlayerOwner(attack.Parent) ~= nil then
        return true
    end

    return false
end

local function addFlagIfMissing(attack, flag)
    if not attack:HasTearFlags(flag) then
        attack:AddTearFlags(flag)
    end
end

local function applyTearEnhancements(tear)
    addFlagIfMissing(tear, HOMING_FLAG)
    addFlagIfMissing(tear, PIERCING_FLAG)
    addFlagIfMissing(tear, SPECTRAL_FLAG)
end

local function applyLaserEnhancements(laser)
    addFlagIfMissing(laser, HOMING_FLAG)
    addFlagIfMissing(laser, PIERCING_FLAG)
    addFlagIfMissing(laser, SPECTRAL_FLAG)
    laser:SetMaxDistance(0)
end

local function isValidTarget(entity)
    return entity:IsActiveEnemy(false)
        and entity:IsVulnerableEnemy()
        and not entity:IsDead()
        and not entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
end

local function findNearestTarget(position)
    local nearestTarget = nil
    local nearestDistance = math.huge

    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if isValidTarget(entity) then
            local distance = position:DistanceSquared(entity.Position)
            if distance < nearestDistance then
                nearestTarget = entity
                nearestDistance = distance
            end
        end
    end

    return nearestTarget
end

local function steerVelocityTowardTarget(entity, target)
    local speed = entity.Velocity:Length()
    local targetOffset = target.Position - entity.Position

    if speed <= MIN_VECTOR_LENGTH or targetOffset:Length() <= MIN_VECTOR_LENGTH then
        return
    end

    local desiredVelocity = targetOffset:Resized(speed)
    local blendedVelocity = entity.Velocity * (1 - HOMING_STRENGTH)
        + desiredVelocity * HOMING_STRENGTH

    if blendedVelocity:Length() > MIN_VECTOR_LENGTH then
        entity.Velocity = blendedVelocity:Resized(speed)
    end
end

local function steerLinearLaserTowardTarget(laser, target)
    local targetOffset = target.Position - laser.Position
    if targetOffset:Length() <= MIN_VECTOR_LENGTH then
        return
    end

    local targetAngle = targetOffset:GetAngleDegrees()
    local angleDifference = (targetAngle - laser.AngleDegrees + 180) % 360 - 180
    laser.AngleDegrees = laser.AngleDegrees
        + angleDifference * HOMING_STRENGTH
end

local function steerLaserTowardTarget(laser)
    local target = findNearestTarget(laser.Position)
    if target == nil then
        return
    end

    if laser:IsCircleLaser() then
        steerVelocityTowardTarget(laser, target)
    else
        steerLinearLaserTowardTarget(laser, target)
    end
end

local function onTearUpdate(_, tear)
    if not isPlayerOwnedAttack(tear) then
        return
    end

    applyTearEnhancements(tear)

    local target = findNearestTarget(tear.Position)
    if target ~= nil then
        steerVelocityTowardTarget(tear, target)
    end
end

local function onLaserInit(_, laser)
    if not isPlayerOwnedAttack(laser) then
        return
    end

    steerLaserTowardTarget(laser)
end

local function onLaserUpdate(_, laser)
    if not isPlayerOwnedAttack(laser) then
        return
    end

    applyLaserEnhancements(laser)
    steerLaserTowardTarget(laser)
end

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, onPlayerInit)
mod:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, onTearUpdate)
mod:AddCallback(ModCallbacks.MC_POST_LASER_INIT, onLaserInit)
mod:AddCallback(ModCallbacks.MC_POST_LASER_UPDATE, onLaserUpdate)

include("quality_of_life")(mod)

Isaac.DebugString("[Player Homing Tears] loaded")
