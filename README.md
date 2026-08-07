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
│   ├── ReloadCoordinator.qml ←── 数据刷新、超时与结果映射
│   ├── EntryInput.js      ←── 日志输入解析与图片路径规范化
│   ├── SettingsPanel.qml  ←── 设置面板（主题 / 面板宽度 / 界面缩放）
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
| 📓 日志列表 | 多行内容与图片缩略图，支持今天 / 近 3 天 / 近 7 天 / 近 30 天筛选 |
| 👆 条目操作 | 单击查看详情；悬停可直接编辑或复制，键盘操作保持不变 |
| 📖 长内容 | 详情与编辑表单独立滚动，标题和底部操作始终可见 |
| 📝 Markdown | 待办描述、灵感内容和日志正文在详情页统一渲染 Markdown |
| 🚿 快速输入 | 类型切换（📋 待办 / 💭 灵感 / 📓 日志）与主面板双向同步，日志可附加本地图片路径 |
| 🔄 稳定加载 | 待办 / 灵感 / 日志按类型独立加载，刷新时保留旧列表；失败后可直接重试 |
| 🛡️ 安全操作 | 删除当前项需要二次确认，关闭编辑弹窗时保护未保存修改 |
| 🎨 主题切换 | 5 种主题可选：Auto（Matugen 壁纸取色）/ Mocha / Frappé / Macchiato / Latte |
| ⚙ 设置面板 | ComboBox 主题选择、面板宽度调节、统一界面缩放 |
| 💾 配置持久化 | 所有设置保存到 `~/.config/star-panel/settings.json`，重启保留 |
| 🖥️ IPC 控制 | `qs -c star-panel ipc call panel toggle/show/hide` |

## ⌨ 键盘体验

star-panel 面向 Vim / Emacs 用户做了完整键盘路径：

| 场景 | 快捷键 |
|------|--------|
| 全局 | `Esc` / `Ctrl+Q` 关闭弹窗或面板，`Ctrl+1/2/3` 切 tab，`/` 聚焦搜索，`Ctrl+R` 刷新 |
| 列表 normal mode | `j/k` 上下，`h/l` 切 tab，`gg/G` 顶部/底部，`Ctrl+U/D` 半页，`Ctrl+B/F` 整页 |
| 列表操作 | `Enter` 查看，`Space` 完成/恢复 Todo，`a` 归档 Todo，`e` 编辑，`y` 复制，`dd` 删除，`r/R` 刷新当前/全部，`o` 进入快速输入，`:` 进入命令模式 |
| 命令模式 | `:open`、`:e/:edit`、`:d/:delete`（对同一项再次执行以确认）、`:y/:copy/:yank`、`:done/:archive/:reopen`、`:r/:reload`、`:help` |
| Emacs 编辑 | 搜索、快速输入、编辑弹窗支持 `Ctrl+A/E/B/F/K/U` |
| 快速输入退出 | 按 `Esc` 返回列表并保留未提交草稿，再次聚焦可继续输入 |
| Esc 切英文 | 从快速输入 / 搜索 / 编辑弹窗按 `Esc` 退出时，自动把 fcitx5+rime 切到英文（`ascii_mode`） |

完整快捷键说明见 [doc/README.md#43-快捷键](./doc/README.md#43-快捷键)。

## 📝 Markdown 内容

待办描述、灵感内容和日志正文都会在条目详情中使用 Qt 内置 Markdown 渲染；编辑框保留原始 Markdown 文本，便于继续修改。无序列表可以直接按行输入：

```markdown
- 第一项
- 第二项
```

快速输入日志时，面板会在正文前自动加入 `--`，因此正文以 `-` 或 `--` 开头也能正常提交。编辑待办或灵感时，需要使用已修复连字符选项值解析的 Starcatch CLI；旧版可能提示 `unexpected argument '-'`，请升级 Starcatch。问题记录见 [`doc/starcatch-leading-hyphen-value-bug-report.md`](./doc/starcatch-leading-hyphen-value-bug-report.md)。

## 📎 日志图片

切到 📓 日志输入时，底部会出现图片路径输入栏；多个路径用逗号分隔。在日志正文或图片路径栏按 `Ctrl+V` / `Shift+Insert` 可直接粘贴剪贴板图片，图片会先暂存到 star-panel cache，提交后由 Starcatch 复制到自己的 image-cache。普通文本剪贴板仍按原行为粘贴。

带图片提交会调用 `starcatch log add --image <path>`。日志列表的每个条目右侧会直接显示最多 3 张与条目等高的缩略图，更多图片以 `+N` 标记；点击条目打开详情，点击缩略图则只打开对应大图。编辑日志时同样支持粘贴或修改图片路径列表；清空后保存会移除该日志的图片。

需要 `wl-clipboard`（提供 `wl-paste`），以及支持 `log add/edit --image` 与 `--clear-images` 的 Starcatch CLI。

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
- **界面缩放** — 统一调整文字与控件密度（80% ~ 160%），保持标题、正文和元信息的层级关系
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

> 🎯 需要 [Starcatch](https://github.com/your/starcatch) CLI + [Quickshell](https://github.com/Quickshell/Quickshell) ≥ 0.3.0 + `wl-clipboard`
>
> 🌟 溯星逆流追寻星渺

如 `starcatch` 不在 `PATH` 中，可在启动面板前设置 `STARCATCH_BIN=/path/to/starcatch`。
