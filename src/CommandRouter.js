var COMMAND_DEFINITIONS = [
    { cmd: ":q",       desc: "关闭面板",             action: { type: "close" } },
    { cmd: ":r",       desc: "刷新数据",             action: { type: "reload" } },
    { cmd: ":reload",  desc: "刷新数据",             action: { type: "reload" } },
    { cmd: ":s",       desc: "设置面板",             action: { type: "settings" } },
    { cmd: ":todo",    desc: "切换为待办输入",       action: { type: "setType", index: 0 } },
    { cmd: ":idea",    desc: "切换为灵感输入",       action: { type: "setType", index: 1 } },
    { cmd: ":log",     desc: "切换为日志输入",       action: { type: "setType", index: 2 } },
    { cmd: ":open",    desc: "查看当前项",           action: { type: "open" } },
    { cmd: ":e",       desc: "编辑当前项",           action: { type: "edit" } },
    { cmd: ":edit",    desc: "编辑当前项",           action: { type: "edit" } },
    { cmd: ":d",       desc: "删除当前项",           action: { type: "delete" } },
    { cmd: ":delete",  desc: "删除当前项",           action: { type: "delete" } },
    { cmd: ":y",       desc: "复制当前项到剪切板",   action: { type: "copy" } },
    { cmd: ":copy",    desc: "复制当前项到剪切板",   action: { type: "copy" } },
    { cmd: ":yank",    desc: "复制当前项到剪切板",   action: { type: "copy" } },
    { cmd: ":done",    desc: "标记当前待办完成",     action: { type: "todoAction", action: "done" } },
    { cmd: ":archive", desc: "归档当前待办",         action: { type: "todoAction", action: "archive" } },
    { cmd: ":reopen",  desc: "恢复当前待办",         action: { type: "todoAction", action: "reopen" } },
    { cmd: ":help",    desc: "显示帮助",             action: { type: "help" } }
];

function copyAction(action) {
    var copy = {};
    for (var key in action) copy[key] = action[key];
    return copy;
}

function allCommands() {
    return COMMAND_DEFINITIONS.map(function(definition) {
        return { cmd: definition.cmd, desc: definition.desc };
    });
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
    for (var i = 0; i < COMMAND_DEFINITIONS.length; i++) {
        if (COMMAND_DEFINITIONS[i].cmd === name)
            return copyAction(COMMAND_DEFINITIONS[i].action);
    }
    return { type: "unknown", name: name };
}

if (typeof module !== "undefined") {
    module.exports = {
        allCommands: allCommands,
        commandName: commandName,
        filterCommands: filterCommands,
        resolve: resolve
    };
}
