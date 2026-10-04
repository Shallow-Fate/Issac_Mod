# Player Homing Tears

适用于支持 Lua Mod API 的《以撒的结合》游戏版本。当前 Mod 版本为 **1.7**，代码对应 2026 年 10 月 3 日 18:59 的版本。

## 功能

- 每个角色开始时拥有 99 金钱、99 炸弹和 99 钥匙。
- 玩家及友方跟班发射的泪弹会主动追踪最近的有效敌人。
- 玩家泪弹获得穿透和灵体效果，可以穿过敌人与障碍物。
- 泪弹保留角色当前的原生射程，不会被强制改为无限射程。
- 玩家及友方跟班发射的激光获得强追踪、穿透、灵体和无限距离效果。
- 敌人的泪弹、投射物和激光不会被修改。
- 击败每层 Boss 后生成恶魔房和天使房入口，进出后仍可再次进入；特殊楼层或没有可用房间位置时可能无法生成。
- 显示普通、超级和红色隐藏房，并自动打开相邻的入口；红色隐藏房会尝试用红房间走廊连到地图。
- 乞丐、献血机、许愿机和忏悔室在第一次实际支付后立即给出最终奖励。
- 新角色获得 Schoolbag、Mom's Purse、Polydactyly 的栏位效果和嗝屁猫的眼睛，可携带两个主动道具、两个饰品和两个卡牌／药丸。

## 丢弃道具

游戏中按 Esc 暂停，再按 **F7** 打开本 Mod 的道具列表。用 **W/A/S/D** 在两列道具中移动，按 **Enter** 将选中道具放在地上；多人游戏可用 **Q/E** 切换角色。列表读取已启用的 External Item Descriptions 模组的简体中文道具名；未提供中文翻译的道具显示为“道具 #编号”。原生“道具表”的选中项没有公开给 Lua Mod，因而该操作使用独立的 F7 列表。

## 下载与安装

1. 从 [v1.7 Release](https://github.com/Shallow-Fate/Issac_Mod/releases/tag/v1.7) 下载 `player_homing_tears-v1.7.zip`。
2. 解压后，将其中的 `player_homing_tears` 文件夹复制到游戏安装目录的 `mods` 文件夹。
3. 确认最终文件路径类似：

   ```text
   ...\The Binding of Isaac Rebirth\mods\player_homing_tears\main.lua
   ```

4. 启动游戏，在 Mods 菜单中启用 **Player Homing Tears**。

> 需要支持 Lua Mod API 的游戏版本。

## 项目结构

```text
player_homing_tears/
  main.lua                 弹道强化与 Mod 入口
  quality_of_life.lua      房间、交易、栏位及丢弃功能
  content/shaders.xml      暂停界面列表绘制
  metadata.xml             Mod 名称、版本及说明
tests/           自动化检查
```

## 开发与测试

在仓库根目录运行：

```powershell
python -m pytest -q
```
