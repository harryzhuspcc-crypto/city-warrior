# Repository instructions

Do not check browser or computer use unless I tell you to.

# Project memory

- Game asset folder (in-repo): `dd_assets/modern-tiles` (originals of the Double Dragon sheets: `dd_assets/double-dragon`)

# Polygon2D platform convention

- 创建、迁移或修复带高度的 Polygon2D 可站立地形平台时，先读 [editable-polygon-platforms](.agents/skills/editable-polygon-platforms/SKILL.md)，默认复用 `levels/platform_simple_test/editable_platform.gd`。纯装饰多边形和独立世界边界不适用；同时接通地形生成，验证同高通路与分层后墙。
