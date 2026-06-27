---
name: restart-panel
description: 重启 star-panel 面板（停止当前进程，重新启动）
user_invocable: true
---
# restart-panel

重启 star-panel。执行 `restart.sh` 停止并重新启动面板进程。

## 用法

```
/restart-panel
```

## 效果

1. 停止所有 `quickshell.*star-panel` 进程
2. 以 daemonize 模式重新启动
3. 验证进程是否启动成功
