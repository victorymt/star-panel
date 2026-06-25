# star-panel ⭐

> _Starcatch 的 Quickshell 负一屏组件 — 在 Hyprland 上优雅地捕获星光 ✨_

轻按 **Super + I**，右侧滑出你的待办、灵感和日志 ♪

## 🚀 快速开始

```bash
# 后台启动
quickshell -c star-panel --daemonize

# 切换显隐
qs -c star-panel ipc call panel toggle

# Hyprland 快捷键（已在 hyprland.lua 中配置）
# Super + I → qs -c star-panel ipc call panel toggle
```

## 📂 项目结构

```
├── shell.qml              ←── QS 入口
├── src/
│   ├── Panel.qml          ←── 主面板（右侧滑出）
│   ├── SettingsPanel.qml  ←── 设置面板（主题 / 面板宽度 / 字体大小）
│   ├── TodoList.qml       ←── 待办
│   ├── IdeaList.qml       ←── 灵感
│   ├── LogList.qml        ←── 日志
│   ├── QuickInput.qml     ←── 快速输入
│   ├── Colors.qml         ←── 主题色（Matugen / Catppuccin 预设）
│   └── Config.qml         ←── 配置 + 持久化
├── doc/README.md          ←── 📖 完整文档
└── README.md              ←── 本文件
```

## ✨ 功能一览

| 功能 | 说明 |
|------|------|
| 🪟 右侧滑出 | 动画 slide-in/out，点击外部 / Escape 关闭 |
| 📋 待办列表 | 优先级颜色指示（🔴🟡🟢⚪）、到期日高亮、标签显示 |
| 💭 灵感列表 | 标题 + 内容摘要 |
| 📓 日志列表 | 多行内容展示 |
| 🚿 快速输入 | 类型切换（📋 待办 / 💭 灵感 / 📓 日志），Enter 提交 |
| 🎨 主题切换 | 5 种主题可选：Auto（Matugen 壁纸取色）/ Mocha / Frappé / Macchiato / Latte |
| ⚙ 设置面板 | ComboBox 主题选择、面板宽度调节、6 级字体大小独立调整 |
| 💾 配置持久化 | 所有设置保存到 `~/.config/star-panel/settings.json`，重启保留 |
| 🖥️ IPC 控制 | `qs -c star-panel ipc call panel toggle/show/hide` |

## 🎨 主题系统

star-panel 支持两套主题方案：

### Auto（Matugen 动态取色）

由 Matugen 根据壁纸自动生成主题色，输出到 `~/.config/star-panel/theme.json`。配置方式：

1. 在 `~/.config/matugen/config.toml` 中添加模板：

```toml
[templates.star-panel]
input_path = "./templates/star-panel.json.template"
output_path = "~/.config/star-panel/theme.json"
```

2. 运行 `matugen` 生成主题，面板每 3s 自动检测更新。

### Catppuccin 预设

在设置面板（⚙）中通过 ComboBox 下拉菜单切换 4 种预设主题：

| 预设 | 风格 |
|------|------|
| ☕ Mocha | 深色暖调（默认） |
| 🍵 Frappé | 深色冷调 |
| 🌸 Macchiato | 中深色 |
| 🥛 Latte | 浅色 |

## ⚙ 设置面板

点击面板头部的 ⚙ 按钮打开设置弹窗，支持：

- **主题选择** — ComboBox 下拉切换 Auto / Catppuccin 预设
- **面板宽度** — 280px ~ 900px，步进 20px
- **字体大小** — 6 级独立调节（标签 / 副标题 / 正文 / 图标 / 按钮 / 标题）
- **恢复默认** — 一键重置所有参数

所有修改即时生效，自动保存。

## 📖 完整文档

见 [doc/README.md](./doc/README.md) 包含：
- 架构设计 & 数据流图
- 安装配置指南
- 组件详细说明
- Hyprland 集成
- 开发指南 & 故障排查

---

> 🎯 需要 [Starcatch](https://github.com/your/starcatch) CLI + [Quickshell](https://github.com/Quickshell/Quickshell) ≥ 0.3.0
>
> 🌟 溯星逆流追寻星渺
