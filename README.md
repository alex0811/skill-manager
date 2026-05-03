# skill-manager

一个用于管理 Claude Code skill 启用状态的本地 Shell CLI。

## 目录约定

- 启用中的 skill：`~/.claude/skills`
- 禁用中的 skill：`~/.claude/skills-disabled`

启用或禁用 skill 时，工具会在这两个目录之间移动对应的 skill 目录。列出 skill 时，普通目录和快捷方式都会显示。

## 使用方法

```bash
./skill-manager select
./skill-manager list
./skill-manager enable <skill-name>
./skill-manager disable <skill-name>
```

## 交互式选择

```bash
./skill-manager select
```

交互界面需要在真实终端中运行，并会列出所有 skill：

- 左侧显示光标和方形选择框
- 实心方块 `■` 表示选中，颜色为 RGB `233,118,88`
- 空心方块 `□` 表示未选中
- 右侧显示应用后的状态：`enabled` 或 `disabled`
- 选中表示应用后会启用
- 未选中表示应用后会禁用

如果同名 skill 同时存在于启用和禁用目录，工具会先报错，避免应用出有歧义的结果。

快捷键：

| 按键 | 作用 |
| --- | --- |
| 上/下方向键 | 移动光标 |
| `j` / `k` | 移动光标 |
| Space | 切换选中/反选 |
| Enter | 应用变更 |
| `q` | 放弃并退出 |

示意：

```text
Configure skill availability

Use ↑/↓ or j/k to move, Space to toggle, Enter to apply, q to cancel.

› ■ daily-review                           enabled
  □ xcode-build-fixer                      disabled
```

## 列出 skill

```bash
./skill-manager list
```

输出示例：

```text
enabled:
  my-active-skill
disabled:
  my-disabled-skill
```

## 启用 skill

```bash
./skill-manager enable daily-review
```

这会把：

```text
~/.claude/skills-disabled/daily-review
```

移动到：

```text
~/.claude/skills/daily-review
```

## 禁用 skill

```bash
./skill-manager disable daily-review
```

这会把：

```text
~/.claude/skills/daily-review
```

移动到：

```text
~/.claude/skills-disabled/daily-review
```

## 测试

```bash
bash test.sh
```
