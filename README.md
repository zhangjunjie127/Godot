# 我要上天

2D 像素风生存防守游戏的 Godot 项目。

当前 Demo 验证最小闭环：

- 6144 x 6144 的连续世界坐标与分层场景结构
- 约 35°–45°的 3/4 俯视镜头与纵深表现
- 玩家移动和镜头跟随
- 可交互草丛；本人半透明，远端玩家不可见
- 清爽明亮的占位地图，后续替换为正式分层大图

## 运行

- 引擎：Godot 4.7.2 Standard
- 脚本：GDScript
- 渲染：Compatibility
- 入口场景：`main.tscn`

用 Godot 打开项目后运行：方向键或 WASD 移动，`Shift` 跑，`Space` 跳，`C` 蹲伏，`Z` 爬行。

详细范围见 `docs/DEMO_BASELINE.md`。
