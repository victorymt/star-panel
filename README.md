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
├── shell.qml           ←── QS 入口
├── src/
│   ├── Panel.qml       ←── 主面板（右侧滑出）
│   ├── TodoList.qml    ←── 待办
│   ├── IdeaList.qml    ←── 灵感
│   ├── LogList.qml     ←── 日志
│   ├── QuickInput.qml  ←── 快速输入
│   ├── Colors.qml      ←── Matugen 主题
│   └── Config.qml      ←── 配置
├── doc/README.md       ←── 📖 完整文档
└── README.md           ←── 本文件
```

## ✨ 功能一览

| 功能 | 说明 |
|------|------|
| 🪟 右侧滑出 | 动画 slide-in/out，点击外部 / Escape 关闭 |
| 📋 待办列表 | 优先级颜色指示、到期日高亮、标签显示 |
| 💭 灵感列表 | 标题 + 内容摘要 |
| 📓 日志列表 | 多行内容展示 |
| 🚿 快速输入 | 类型切换（todo/idea/log），Enter Pipe 提交 |
| 🎨 Matugen 主题 | 自动读取 `qs_colors.json`，3s 轮询刷新 |
| 🖥️ IPC 控制 | `qs -c star-panel ipc call panel toggle` |

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
