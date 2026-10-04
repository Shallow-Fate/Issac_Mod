from pathlib import Path


WORKSPACE_MOD_DIR = Path(r"D:\Code\isaac\player_homing_tears")
INSTALLED_MOD_DIR = Path(
    r"E:\SteamLibrary\steamapps\common\The Binding of Isaac Rebirth\mods\player_homing_tears"
)


def read_workspace_lua():
    return (WORKSPACE_MOD_DIR / "main.lua").read_text(encoding="utf-8")


def test_every_player_starts_with_99_pickups():
    lua = read_workspace_lua()

    assert "local STARTING_PICKUP_COUNT = 99" in lua
    assert "ModCallbacks.MC_POST_PLAYER_INIT" in lua
    assert "STARTING_PICKUP_COUNT - player:GetNumCoins()" in lua
    assert "STARTING_PICKUP_COUNT - player:GetNumBombs()" in lua
    assert "STARTING_PICKUP_COUNT - player:GetNumKeys()" in lua


def test_player_tears_keep_native_range_and_receive_other_enhancements():
    lua = read_workspace_lua()

    assert "TearFlags.TEAR_HOMING" in lua
    assert "TearFlags.TEAR_PIERCING" in lua
    assert "TearFlags.TEAR_SPECTRAL" in lua
    assert "FLIGHT_HEIGHT" not in lua
    assert "tear.Height" not in lua
    assert "tear.FallingSpeed" not in lua
    assert "tear.FallingAcceleration" not in lua


def test_strong_homing_uses_only_valid_hostile_targets():
    lua = read_workspace_lua()

    assert "local HOMING_STRENGTH = 0.30" in lua
    assert "Isaac.GetRoomEntities()" in lua
    assert "entity:IsActiveEnemy(false)" in lua
    assert "entity:IsVulnerableEnemy()" in lua
    assert "not entity:IsDead()" in lua
    assert "EntityFlag.FLAG_FRIENDLY" in lua
    assert "target.Position - entity.Position" in lua
    assert "blendedVelocity:Resized(speed)" in lua


def test_enemy_projectiles_remain_unchanged():
    lua = read_workspace_lua()

    assert "EntityType.ENTITY_PLAYER" in lua
    assert "EntityType.ENTITY_FAMILIAR" in lua
    assert "ModCallbacks.MC_POST_TEAR_UPDATE" in lua
    assert "MC_POST_PROJECTILE_UPDATE" not in lua


def test_player_lasers_receive_all_enhancements():
    lua = read_workspace_lua()

    assert "ModCallbacks.MC_POST_LASER_INIT" in lua
    assert "ModCallbacks.MC_POST_LASER_UPDATE" in lua
    assert "applyLaserEnhancements(laser)" in lua
    assert "addFlagIfMissing(laser, HOMING_FLAG)" in lua
    assert "addFlagIfMissing(laser, PIERCING_FLAG)" in lua
    assert "addFlagIfMissing(laser, SPECTRAL_FLAG)" in lua
    assert "laser:SetMaxDistance(0)" in lua
    assert "laser.Timeout" not in lua


def test_lasers_use_type_specific_strong_homing():
    lua = read_workspace_lua()

    assert "laser:IsCircleLaser()" in lua
    assert "steerVelocityTowardTarget(laser, target)" in lua
    assert "targetOffset:GetAngleDegrees()" in lua
    assert "(targetAngle - laser.AngleDegrees + 180) % 360 - 180" in lua
    assert "angleDifference * HOMING_STRENGTH" in lua


def test_enemy_lasers_remain_unchanged():
    lua = read_workspace_lua()

    assert "local function isPlayerOwnedAttack(attack)" in lua
    assert "if not isPlayerOwnedAttack(laser) then" in lua
    assert "MC_POST_PROJECTILE_UPDATE" not in lua


def test_workspace_and_installed_mod_are_synchronized():
    for filename in ("main.lua", "quality_of_life.lua", "metadata.xml", "content/shaders.xml"):
        workspace_content = (WORKSPACE_MOD_DIR / filename).read_bytes()
        installed_content = (INSTALLED_MOD_DIR / filename).read_bytes()
        assert installed_content == workspace_content


def test_metadata_describes_starting_pickups_native_range_tears_and_unlimited_lasers():
    xml = (WORKSPACE_MOD_DIR / "metadata.xml").read_text(encoding="utf-8")

    assert "<name>Player Homing Tears</name>" in xml
    assert "<id>0</id>" in xml
    assert "<version>1.7</version>" in xml
    assert "extra carrying slots" in xml
    assert "Guppy's Eye at run start" in xml
    assert "revealed secret rooms" in xml
    assert "instant trading payouts" in xml
