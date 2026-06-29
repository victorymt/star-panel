# star-panel ⭐ 完整文档

> _Starcatch 的 Quickshell 负一屏组件 — 在 Hyprland 上优雅地捕获星光 ✨_

---

## 目录

1. [项目概览](#1-项目概览)
2. [架构设计](#2-架构设计)
3. [安装与配置](#3-安装与配置)
4. [使用指南](#4-使用指南)
5. [组件说明](#5-组件说明)
6. [Hyprland 集成](#6-hyprland-集成)
7. [开发指南](#7-开发指南)
8. [故障排查](#8-故障排查)

---

## 1. 项目概览

**star-panel** 是一个基于 [Quickshell](https://github.com/Quickshell/Quickshell) (QML/ Qt6) 的浮动面板组件，
与 [Starcatch](https://github.com/your/starcatch) 数据引擎配合，在 Hyprland 上实现「负一屏」体验。

| 属性 | 值 |
|------|-----|
| 项目名 | `star-panel`（星面板） |
| 路径 | `/data/project/star-panel` |
| QS 配置名 | `star-panel` |
| 技术栈 | QML + Qt6 + Quickshell + WlrLayershell |
| 后端 | Starcatch CLI (Rust) |
| 窗口类型 | `PanelWindow` + `WlrLayer.Top` |
| 定位 | 右侧全高浮动（`Top \| Bottom \| Right` anchored） |

### 设计理念

```
轻按 Super+I → 右侧滑出 → 一目了然 → 快速捕获 → 滑走关闭
     ↑                              ↓
    Starcatch DB ←─── CLI Pipe ─────┘
```

---

## 2. 架构设计

```
ShellRoot (shell.qml)
 └── PanelWindow (Panel.qml)  ←── WlrLayer.Top 覆盖层
      ├── Colors (Colors.qml)  ←── Matugen 主题色
      ├── IpcHandler           ←── IPC 控制 (toggle/show/hide)
      ├── Rectangle (背景面板)  ←── 半透明浮动卡片
      │    ├── Header        ⭐ 星捕 + ↻ 刷新 + ✕ 关闭
      │    ├── TabBar        📋待办 │ 💭灵感 │ 📓日志
      │    ├── StackLayout   ─── 内容区 ───
      │    │    ├── TodoList   📋 待办列表
      │    │    ├── IdeaList   💭 灵感列表
      │    │    └── LogList    📓 日志列表
      │    └── QuickInput    🚿 底部快速输入栏
      ├── MouseArea           ←── 点击外部关闭
      └── Shortcut (Escape)   ←── 快捷键关闭
```

### 数据流

```
STARCATCH CLI                         PANEL (QML)
┌─────────────────┐     JSON (--json)  ┌──────────────────────┐
│ starcatch --json│──── Process ────→ │ parseTodos()         │
│ todo list --all │                   │ → todos: [...]       │
├─────────────────┤                   ├──────────────────────┤
│ starcatch --json│──── Process ────→ │ parseIdeas()         │
│ idea list -d 7  │                   │ → ideas: [...]       │
├─────────────────┤                   ├──────────────────────┤
│ starcatch --json│──── Process ────→ │ parseLogs()          │
│ log list -d 3   │                   │ → logs: [...]        │
├─────────────────┤                   ├──────────────────────┤
│ starcatch pipe  │←─── bash -c ──── │ QuickInput           │
│ todo/idea/log   │   "printf ... |"  │ Enter 提交            │
└─────────────────┘                   └──────────────────────┘
```

---

## 3. 安装与配置

### 3.1 前置依赖

```bash
# Arch Linux
sudo pacman -S quickshell qt6-declarative qt6-shadertools

# 需要 starcatch CLI 已安装
which starcatch  # 确认可用
```

### 3.2 项目结构

```
~/.config/quickshell/star-panel/  (软链接 → /data/project/star-panel/)
├── shell.qml          ←── Quickshell 入口（ShellRoot）
└── src/               ←── 组件目录
    ├── Panel.qml          主面板窗口
    ├── TodoList.qml       待办列表
    ├── IdeaList.qml       灵感列表
    ├── LogList.qml        日志列表
    ├── QuickInput.qml     快速输入
    ├── DetailPopup.qml    详情弹窗（todo 完成/归档等操作）
    ├── TagList.qml        标签显示组件
    ├── SettingsPanel.qml  设置面板（主题/宽度/字体）
    ├── Colors.qml         主题色（Matugen / Catppuccin 预设）
    └── Config.qml         配置 + 持久化
```

所有组件通过软链接部署到 `~/.config/quickshell/star-panel/`，
使得 `quickshell -c star-panel` 可直接找到入口。

### 3.3 主题色配置

star-panel 自动读取 `~/.config/hypr/scripts/quickshell/qs_colors.json`，
实现 Matugen 动态主题。Colors.qml 每 3 秒轮询一次文件变化。

文件格式 (Catppuccin Mocha 风格):
```json
{
  "base": "#1e1e2e",
  "mantle": "#181825",
  "crust": "#11111b",
  "text": "#cdd6f4",
  "surface0": "#313244",
  "surface1": "#45475a",
  "blue": "#89b4fa",
  "red": "#f38ba8",
  "green": "#a6e3a1",
  ...
}
```

---

## 4. 使用指南

### 4.1 启动

```bash
# 前台启动（调试用）
quickshell -c star-panel -v

# 后台守护进程（生产用）
quickshell -c star-panel --daemonize
```

### 4.2 IPC 控制

```bash
# 切换显隐
qs -c star-panel ipc call panel toggle

# 显示
qs -c star-panel ipc call panel show

# 隐藏
qs -c star-panel ipc call panel hide
```

### 4.3 快捷键

| 操作 | 触发 |
|------|------|
| `Escape` | 关闭面板 |
| `Enter` (输入框聚焦时) | 提交快速捕获 |
| IPC `toggle` | 切换显隐 |

### 4.4 交互说明

- **刷新按钮** (↻)：重新拉取 Starcatch 数据
- **关闭按钮** (✕)：关闭面板
- **点击外部**：点击面板右侧空白区域关闭
- **Tab 切换**：在待办/灵感/日志之间切换
- **快速输入**：在底部输入框输入内容，Enter 提交到 Starcatch
  - 点击类型按钮可在 `📋待办 → 💭灵感 → 📓日志` 之间循环

---

## 5. 组件说明

### Panel.qml

主窗口组件，`PanelWindow` 类型。

| 属性 | 值 |
|------|-----|
| 宽度 | 420px + 16px margin |
| 高度 | 全屏 |
| 定位 | 右侧（WlrLayer anchored） |
| 动画 | slide-in/out 280ms OutQuint |
| 背景 | 半透明（92% opacity）+ 圆角 16px |

**关键实现细节:**
- 使用 `WlrLayershell.namespace: "qs-star-panel"` 标识（layer 为 `WrlLayer.Top`）
- 动画通过 `Behavior on slideOffset` 实现
- `visible` 条件控制: `panelVisible || slideOffset > -(panelWidth + panelMargin * 2)`
- 面板通过 `ColumnLayout` 垂直布局: 头部 → 选项卡 → 分隔线 → 内容区 → 快速输入

### TodoList.qml

待办列表，直接从 `starcatch todo list --all` 输出解析。

| 可视化 | 含义 |
|--------|------|
| 🔴 红色指示条 | P0 高优先级 |
| 🟡 橙色指示条 | P1 中优先级 |
| 🟢 绿色指示条 | P2/P3 低优先级 |
| `⬜` → `○` | 待办 |
| `✅` → `✓` | 已完成（删除线样式） |
| `📦` → `📦` | 已归档 |
| 红色日期 | 已过期 |
| 橙色日期 | 2 天内到期 |

CLI 输出通过 `--json` 选项返回 JSON，面板用 `JSON.parse()` 解析:

```
starcatch --json todo list --all  →  [{ id, title, priority, status, due_date, tags, ... }, ...]
starcatch --json idea list -d 7   →  [{ id, title, content, source, tags, ... }, ...]
starcatch --json log list -d 3    →  [{ id, content, mood, tags, ... }, ...]
```

对应解析函数: `parseTodos()` / `parseIdeas()` / `parseLogs()`（`Panel.qml`）。

### IdeaList.qml

灵感列表，从 `starcatch idea list -d 7` 输出解析。
显示标题（粗体）+ 内容摘要（单行省略）。

### LogList.qml

日志列表，从 `starcatch log list -d 3` 输出解析。
显示标题 + 内容（最多 2 行，自动换行）。

### QuickInput.qml

快速输入组件。将文本通过 pipe 模式提交到 Starcatch。

```bash
# 内部执行的命令示例
echo "买个奶茶" | starcatch pipe todo
echo "写个新项目" | starcatch pipe idea
echo "今天好累" | starcatch pipe log
```

三种类型循环切换: `📋待办 → 💭灵感 → 📓日志`

### Colors.qml

主题色单例（普通 Item 单实例，非 `pragma Singleton`）。从 `theme.json` 加载 Matugen 色，fallback 到 Catppuccin Mocha。
启动时由 `Config.settingsLoader` 完成后调用 `theme.initFromSettings()` 统一驱动，避免 matugen 闪现。
Matugen 模式下通过 `Timer { interval: 3000 }` 轮询文件变化，实现热更新。

### Config.qml

配置单例（普通 Item 单实例，非 `pragma Singleton`），集中管理参数:
- `panelWidth`: 420
- `panelMargin`: 8
- `panelRadius`: 16
- `animationDuration`: 280
- `defaultTab`: 0
- 字体大小 6 级: `fontTiny/fontSmall/fontBase/fontMedium/fontLarge/fontXl`
- `themeName`: "" (Matugen 自动) / "mocha" / "latte" / "frappe" / "macchiato"
- `todoFilter`: "Pending" / "Done" / "Archived"

> 注：`refreshInterval`（30000ms）硬编码在 `Panel.qml` 的 `autoRefreshTimer`；
> `starcatch` 二进制路径硬编码在各 `Process.command` 数组中，非 Config 属性。

---

## 6. Hyprland 集成

### 6.1 快捷键绑定（已配置 ✅）

添加到 `~/.config/hypr/hyprland.lua`:

```lua
-- StarPanel 负一屏 (Quickshell)
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("qs -c star-panel ipc call panel toggle"))
```

已配置在 `hyprland.lua` 中，快捷键 **Super + I**~

### 6.2 开机启动（已配置 ✅）

```lua
-- 在 hyprland.start 事件中
hl.exec_cmd("qs -c star-panel --daemonize")
```

已添加到 `hyprland.lua` 的 `hyprland.start` 回调中~

### 6.3 Layer Rule（已配置 ✅）

star-panel 使用 `WrlLayer.Top` 的 `PanelWindow`，
不适用普通 Hyprland `windowrulev2`，需用 `layer_rule`：

```lua
hl.layer_rule({
  match = { namespace = "qs-star-panel" },
  name = "star-panel-blur",
  blur = true,
  ignore_alpha = 0,
})
```

已配置 blur 效果。

### 6.4 集成拓扑

```
Hyprland
 ├── bind Super+I ──→ qs ipc call panel toggle
 ├── hyprland.start ──→ qs --daemonize (开机启动)
 │
  └── star-panel (WrlLayer.Top)
      ├── layer_rule: blur enabled
      └── Process ──→ starcatch CLI ──→ SQLite DB
```

---

## 7. 开发指南

### 7.1 本地调试

```bash
cd /data/project/star-panel

# 前台启动查看日志
quickshell -c star-panel -v

# 修改后无需重启 QS（Quickshell 支持热重载）
killall quickshell && quickshell -c star-panel --daemonize
```

### 7.2 常见开发问题

**Q: QML 文件修改后需要重启吗？**
A: 是的，Quickshell 支持 `Quickshell.reload(true)` 热重载，但目前 star-panel 未实现自动监听。
可手动 `qs -c star-panel kill && quickshell -c star-panel --daemonize`。

**Q: 如何添加新的数据源？**
A: 在 Panel.qml 的 `dataFetcher` Item 下添加新的 `Process` 组件，
在 `onStreamFinished` 中调用 `JSON.parse()` 解析（CLI 需加 `--json` 选项），
然后将结果赋值给对应属性。

**Q: 为什么用了 `theme` 而不是 `colors`？**
A: QML 的作用域链查找规则：
`Colors { id: theme }` 声明在 PanelWindow 根元素中，
所有子组件（包括通过 `StackLayout` 加载的 QML 文件）都可以直接通过 `theme` 访问到。
这是 QML 的 ID 作用域机制。

### 7.3 QML 注意事项

- `PanelWindow` 不支持 `x/y` 属性（由 WlrLayershell 协议管理位置）
- 使用 `implicitWidth` / `implicitHeight` 代替 `width/height`（避免 deprecation warning）
- `Behavior` 不能绑定到 `readonly property` 上
- `Qt.callLater(fn)` 的参数必须是函数，不能是 `obj.method`（需要用 `function() { obj.method(); }`）

---

## 8. 故障排查

### 8.1 启动失败

```bash
# 查看详细日志
quickshell -c star-panel -v 2>&1

# 检查 QS 版本
quickshell --version  # 需要 ≥ 0.3.0
```

**常见错误:**

| 错误 | 原因 | 解决 |
|------|------|------|
| `Type Panel unavailable` | QML 语法错误 | 检查 `src/Panel.qml` 最后几行 |
| `Cannot assign to non-existent property` | 属性名错误或类型不匹配 | 检查 QML 属性声明 |
| `TypeError: ... is not a function` | 方法调用方式错误 | 用 `function() { obj.method(); }` |
| `MultiEffect is not a type` | 缺少 Qt 图形效果模块 | 移除 MultiEffect 或用简单半透明替代 |
| `Property value set multiple times` | 重复的 `Component.onCompleted` | 确保只有一个 |

### 8.2 数据显示异常

```bash
# 先确认 CLI 本身能正常工作
starcatch todo list --all
starcatch idea list -d 7
starcatch log list -d 3
```

如果 CLI 正常但面板无数据，检查 `parseTodos()`/`parseIdeas()`/`parseLogs()` 的 JSON 字段映射是否与 CLI `--json` 输出一致。

### 8.3 IPC 不响应

```bash
# 确认实例在运行
qs -c star-panel list

# 手动测试 IPC
qs -c star-panel ipc call panel toggle

# 如果实例是 dead 状态，重新启动
quickshell -c star-panel --daemonize
```

---

## 附录: Quickshell 参考

### 常用 WlrLayershell 属性

| 属性 | 说明 |
|------|------|
| `WlrLayershell.namespace` | 窗口标识 |
| `WlrLayershell.layer` | 层: `WrlLayer.Background / Bottom / Top / Overlay`（本项目用 `Top`） |
| `exclusionMode` | 是否排除出布局: `Ignore / Normal` |
| `focusable` | 是否可获取焦点 |
| `anchors.top/bottom/left/right` | 锚定方向 |

### IPC 通信

```qml
// 服务端（Panel.qml 内）
IpcHandler {
    target: "panel"
    function toggle() { ... }
}

// 客户端（命令行）
qs -c star-panel ipc call panel toggle
```

---

> 🌟 星光不问赶路人 — 溯星逆流追寻星渺
>
> _Built with ♥ for Hyprland + Quickshell + Starcatch_
