---
name: editable-polygon-platforms
description: 创建、迁移或修复 city-warrior 中带高度的 Polygon2D 可站立地形平台，复用 editable_platform.gd 并验证投影、同高通路与分层后墙。用于平台高度、阻挡、落地或后缘问题；纯装饰多边形和独立世界边界不适用。
---

# 可编辑 Polygon2D 地形平台

本项目这类带高度、可站立面、实体侧面阻挡和后墙的平台，默认复用
`levels/platform_simple_test/editable_platform.gd`。它是已验证的基础，具体顶点、
高度、后墙配置和地形适配器仍须验证，不能假定挂上脚本后任何配置都正确。
本文路径均相对仓库根目录。保留用户已有编辑和脚本中的中文注释。

## 接通同一份平台定义

创建或迁移前，先读 `editable_platform.gd` 和目标场景使用的地形适配器：

- 简单场景：`levels/platform_simple_test/editor_terrain.gd`。
- 工业场景：`levels/industrial_yard/industrial_terrain.gd`。
- 共享查询、实体碰撞与角色移动：`features/level_objects/terrain/belt_terrain_map.gd`
  和 `features/level_objects/terrain/belt_terrain_motor.gd`。

顶面预览、支撑查询、实体侧面和后墙都从保存的 Polygon2D 顶点及导出属性生成。
用 `top_points_in()` 处理节点位置和 offset，用 `rear_wall_entry()` 生成指定边的后墙。
确认适配器确实读取新脚本的 `height`、`solid`、`fall_from_edges` 等字段；仅替换脚本
而保留旧字段读取不算完成迁移。迁移时显式保留每个面的高度和行为，地面设为 0，
避免继承平台脚本的默认高度。已有独立后墙与自动后墙只保留一个有效来源。

纯装饰 Polygon2D 保持装饰用途。独立世界边界继续独立配置；工业场景的这类节点仍用
`industrial_terrain_outline.gd`，不要批量变成可站立平台。

## 顶面、高度和投影

- 顶点描绘背景中可站立的**顶面**，前沿不能落到侧面或阴影上。
- `height` 是绝对楼层高度，不是图片 y 坐标，也不是节点的 y 位置。
- 工业图片坐标转换：`ground_y = picture_y + image_offset_y + height`；
  从地面位置画脚：`visible_foot_y = ground_y - elevation`。
  转为地形局部坐标的顶点只需再投影高度，避免重复叠加图片偏移。
- 分别核对可见顶面、角色脚部碰撞范围和地面投影。画面重叠不代表同层或同一纵深。
- 以背景顶面、侧面、接触位置和用户确认的路线校准高度；真实高差和空隙保留。
  不通过全局扩大碰撞、抬高跳跃或把所有平台设成同高来掩盖错误。
- 背景已经画出平台时，设置透明填充和 `draw_side_faces = false`，保留浅蓝轮廓与金色边。
  简单测试场景没有这类固定背景，可继续显示侧面预览。
- 高度变更后联动检查梯子、平台交接、箱子/传送带、出生点、出口和独立墙的高度范围。

## 同高通路与后墙

同高且相接的平台允许双向、斜向直接走过，共享边不生成后墙。按背景和预期连接修正
局部顶点缝隙，并逐帧检查支撑；不得扩大整个地图来桥接真实空隙。

`rear_wall` 开关与 `rear_edge` 决定金色边及其向外 12 px 的实体后墙。
重叠楼层使用 `rear_wall_on_level_only = true`：地形保存每面墙的 `base_height`，
移动器调用 `sync_rear_wall_collisions()`，通过**逐角色、逐墙碰撞例外**启用对应楼层的墙。
不能仅开一个共享碰撞层而同时激活所有层的后墙。

后墙判断使用支撑/起跳楼层；跳跃期间保留起跳层规则，落到另一层后切换。
站在高层的角色应能跨过低层后墙的画面投影，只受当前层自己的后缘限制。
迁移的工业平台不再依赖旧 `block_back_edge` 的“向后支撑变低就阻挡”规则；不要删除
其他场景仍在使用的兼容逻辑。区分实体侧面造成的合法“需要跳跃”和错误的后墙卡住。

## 行为验收

先按现有场景建立可重复的实际移动路径，再改配置。对本次工业四级结构使用以下例子，
数值不是所有新关卡的通用常量：

| 层级 | 平台 | 高度 |
| --- | --- | ---: |
| 一级 | GirderPile | 80 |
| 二级 | Step1 / Step2 / StepLanding，同高互通 | 104 |
| 三级 | TowerTop | 152 |
| 四级 | LoadingDeck | 192 |

验收必须覆盖：

1. 实际从一级 80 跳上二级 104，确认 GROUNDED，再持续 W：脚跨过一级金线的画面位置，
   只在二级自己的后缘停住。继续朝后跳也不能越过二级后墙；不能用直接放置到二级替代这条路径。
2. 二级三块铁板双向和斜向互通，全程保持支撑，无需跳跃。
3. 从二级前沿走下落到一级，再朝前接近并跳回二级；真实落差仍需要跳跃。
4. 104 → 152 → 192 的前方/侧方跳跃与落地，保留原有路线；相关高度改动后检查梯子和出口。
5. 简单平台场景无回归：侧面阻挡、跳上高层、后缘保护、前/侧边掉落及保存顶点后重新生成地形。

优先复用 `tools/smoke_test_industrial_rear_edges.gd`（真实跨层金线、同高接缝、分层墙）、
`smoke_test_industrial_platform_edges.gd`（走下及跳上）、`smoke_test_industrial_front_jump.gd`、
`smoke_test_industrial_tower_jump.gd` 和 `smoke_test_platform_simple.gd`。
高度联动改动再运行工业 terrain、deck_alignment、keyboard_jump 和 stage_two 等对应测试。
在仓库根目录用本机 Godot 可执行文件运行：

```sh
godot --headless --path . --script tools/smoke_test_industrial_rear_edges.gd
```

场景或 API 已变化时先核对测试夹具，不机械照搬旧高度；测试应断言行为而非只校验属性。
遵守当前运行权限：用户正在使用 Godot 或要求不要运行时，只做允许的静态检查并明确记录
哪些动态验证未重跑。浏览器/电脑操作需要用户明确授权，本技能不提供这项授权。

工业历史取证、局部顶点修正及完整测试入口见 `levels/industrial_yard/README.md`；
处理该关卡时读取。报告根因、实际验证路径、通过/未执行的检查和残余限制。
