function allCommands() {
    return [
        { cmd: ":q",       desc: "关闭面板" },
        { cmd: ":r",       desc: "刷新数据" },
        { cmd: ":reload",  desc: "刷新数据" },
        { cmd: ":s",       desc: "设置面板" },
        { cmd: ":todo",    desc: "切换为待办输入" },
        { cmd: ":idea",    desc: "切换为灵感输入" },
        { cmd: ":log",     desc: "切换为日志输入" },
        { cmd: ":open",    desc: "查看当前项" },
        { cmd: ":e",       desc: "编辑当前项" },
        { cmd: ":edit",    desc: "编辑当前项" },
        { cmd: ":d",       desc: "删除当前项" },
        { cmd: ":delete",  desc: "删除当前项" },
        { cmd: ":y",       desc: "复制当前项到剪切板" },
        { cmd: ":copy",    desc: "复制当前项到剪切板" },
        { cmd: ":yank",    desc: "复制当前项到剪切板" },
        { cmd: ":done",    desc: "标记当前待办完成" },
        { cmd: ":archive", desc: "归档当前待办" },
        { cmd: ":reopen",  desc: "恢复当前待办" },
        { cmd: ":help",    desc: "显示帮助" }
    ];
}

function commandName(command) {
    var text = (command || "").toString().trim();
    return text ? text.split(/\s+/)[0].toLowerCase() : "";
}

function filterCommands(text, commands) {
    var input = (text || "").toString();
    var list = commands || allCommands();
    var raw = input.slice(1).split(/\s+/)[0].toLowerCase();
    if (!raw) return list;
    return list.filter(function(item) {
        return item.cmd.indexOf(raw, 1) >= 1;
    });
}

function resolve(command) {
    var name = commandName(command);
    switch (name) {
        case ":q":       return { type: "close" };
        case ":r":
        case ":reload":  return { type: "reload" };
        case ":s":       return { type: "settings" };
        case ":todo":    return { type: "setType", index: 0 };
        case ":idea":    return { type: "setType", index: 1 };
        case ":log":     return { type: "setType", index: 2 };
        case ":open":    return { type: "open" };
        case ":e":
        case ":edit":    return { type: "edit" };
        case ":d":
        case ":delete":  return { type: "delete" };
        case ":y":
        case ":copy":
        case ":yank":    return { type: "copy" };
        case ":done":    return { type: "todoAction", action: "done" };
        case ":archive": return { type: "todoAction", action: "archive" };
        case ":reopen":  return { type: "todoAction", action: "reopen" };
        case ":help":    return { type: "help" };
        default:         return { type: "unknown", name: name };
    }
}

if (typeof module !== "undefined") {
    module.exports = {
        allCommands: allCommands,
        commandName: commandName,
        filterCommands: filterCommands,
        resolve: resolve
    };
}
