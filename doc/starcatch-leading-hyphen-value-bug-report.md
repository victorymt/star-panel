# [Bug] 编辑字段无法接收以 `- ` 开头的 Markdown 内容

> 状态：已由 Starcatch CLI 修复。当前报告保留为问题记录；star-panel 已切换回标准的分离参数调用。

## 摘要

Starcatch 的部分编辑选项无法接收以连字符开头的文本值。例如，将 Markdown 无序列表作为 `idea edit --content` 的值传入时，CLI 会把正文中的 `- ` 解析为新的命令行参数，并返回 `unexpected argument '- '`。

该问题会影响从 GUI、脚本或其他程序通过 argv 调用 Starcatch 的场景。调用方已经把整段正文作为单个参数传递，但 Starcatch 仍拒绝该值。

## 环境

- Starcatch：`0.1.0`
- 操作系统：Arch Linux
- 内核：`Linux 7.1.5-arch1-2 x86_64`
- Shell：Bash

## 最小复现

以下命令使用临时数据库，不会修改现有数据：

```bash
tmp_dir="$(mktemp -d)"
db="$tmp_dir/test.db"

starcatch -D "$db" idea add "Markdown list" --content seed
idea_id="$(starcatch --json -D "$db" idea list | jq -r '.[0].id')"

starcatch -D "$db" idea edit "$idea_id" \
  --content $'- first\n- second'
```

## 实际行为

命令退出码为 `2`，输出：

```text
error: unexpected argument '- ' found

  tip: to pass '- ' as a value, use '-- - '

Usage: starcatch idea edit [OPTIONS] <ID>

For more information, try '--help'.
```

## 预期行为

命令应成功更新灵感内容，并原样保存：

```markdown
- first
- second
```

`--content`、`--desc` 等自由文本字段应允许任意 UTF-8 文本，包括以 `-`、`--` 或 Markdown 列表标记开头的值。

## 已确认的临时规避方式

将选项和值绑定为同一个 argv 可以成功执行：

```bash
starcatch -D "$db" idea edit "$idea_id" \
  $'--content=- first\n- second'
```

这说明数据库和内容保存逻辑正常，问题位于命令行参数解析阶段。

对于 `log add` 的位置参数，可以在正文前使用选项终止符：

```bash
starcatch -D "$db" log add -- $'- first\n- second'
```

## 影响范围

已复现或确认受相同解析规则影响的字段：

- `idea edit --content`
- `log edit --content`
- `todo edit --desc`

建议同时检查所有接收自由文本的选项：

- `idea add --content`
- `todo add --desc`
- `--title`
- `--source`
- `--mood`
- `--tag`
- `--project`
- `--due`
- `--image`

位置参数如 `idea add <TITLE>`、`todo add <TITLE>` 和 `log add <CONTENT>` 仍可按常规 CLI 规则使用 `--` 终止选项解析。

## 可能原因

Starcatch 使用 clap 解析参数。相关字符串参数可能没有启用 `allow_hyphen_values`，导致 clap 将以 `-` 开头的选项值识别为新参数。

## 建议修复

对所有自由文本选项启用连字符值，例如：

```rust
#[arg(short = 'c', long, allow_hyphen_values = true)]
content: Option<String>,

#[arg(long, allow_hyphen_values = true)]
desc: Option<String>,
```

具体字段名和类型以 Starcatch 当前命令定义为准。对于标题、来源、标签、项目等其他用户输入字段，也建议统一启用该设置，避免相同问题再次出现。

## 建议测试

增加 CLI 集成测试，至少覆盖：

1. `idea edit --content` 接收 `- first\n- second`。
2. `log edit --content` 接收 `- first\n- second`。
3. `todo edit --desc` 接收 `- first\n- second`。
4. 使用 `--option value` 和 `--option=value` 两种形式时结果一致。
5. 更新后通过 `show` 命令读取并断言内容逐字节一致。

## 严重程度

建议标记为 **Medium**：不会破坏已有数据，但会阻止常见 Markdown 内容通过 CLI 集成正常保存，并影响所有基于 argv 调用 Starcatch 的前端。
