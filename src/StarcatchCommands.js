function executablePath(value) {
    var path = value === undefined || value === null ? "" : String(value).trim();
    return path || "starcatch";
}

function requireEntryType(type) {
    if (type !== "todo" && type !== "idea" && type !== "log")
        throw new Error("unsupported Starcatch entry type: " + type);
    return type;
}

function requireTodoAction(action) {
    if (action !== "done" && action !== "archive" && action !== "reopen")
        throw new Error("unsupported Starcatch todo action: " + action);
    return action;
}

function command(executable, args) {
    return [executablePath(executable)].concat(args);
}

function listCommand(executable, type, days) {
    var entryType = requireEntryType(type);
    if (entryType === "todo")
        return command(executable, ["--json", "todo", "list", "--all"]);
    if (entryType === "idea")
        return command(executable, ["--json", "idea", "list", "-d", String(days || 7)]);
    if (days === 0)
        return command(executable, ["--json", "log", "list", "--all"]);
    return command(executable, ["--json", "log", "list", "-d", String(days || 3)]);
}

function showCommand(executable, type, id) {
    return command(executable, ["--json", requireEntryType(type), "show", String(id)]);
}

function deleteCommand(executable, type, id) {
    return command(executable, [requireEntryType(type), "delete", String(id)]);
}

function todoActionCommand(executable, action, id) {
    return command(executable, ["todo", requireTodoAction(action), String(id)]);
}

function todoEditCommand(executable, id, fields) {
    return command(executable, [
        "todo", "edit", String(id),
        "--title", fields.title,
        "--desc", fields.description,
        "-p", fields.priority,
        "--due", fields.due,
        "-t", fields.tags,
        "-P", fields.project
    ]);
}

function ideaEditCommand(executable, id, fields) {
    return command(executable, [
        "idea", "edit", String(id),
        "--title", fields.title,
        "-c", fields.content,
        "-s", fields.source,
        "-t", fields.tags,
        "-P", fields.project
    ]);
}

function logEditCommand(executable, id, fields, imageArgs) {
    var args = [
        "log", "edit", String(id),
        "-c", fields.content,
        "-m", fields.mood,
        "-t", fields.tags,
        "-P", fields.project
    ];
    return command(executable, args.concat(imageArgs || []));
}

function logAddCommand(executable, content, mood, tags, project, images) {
    var args = ["log", "add"];
    images = images || [];
    if (mood) args.push("-m", mood);
    if (tags && tags.length > 0) args.push("-t", tags.join(","));
    if (project) args.push("-P", project);
    for (var i = 0; i < images.length; i++)
        args.push("--image", images[i]);
    args.push("--", content);
    return command(executable, args);
}

function pipeCommand(helperPath, executable, type, text) {
    return [String(helperPath), executablePath(executable), requireEntryType(type), String(text)];
}

if (typeof module !== "undefined") {
    module.exports = {
        executablePath: executablePath,
        listCommand: listCommand,
        showCommand: showCommand,
        deleteCommand: deleteCommand,
        todoActionCommand: todoActionCommand,
        todoEditCommand: todoEditCommand,
        ideaEditCommand: ideaEditCommand,
        logEditCommand: logEditCommand,
        logAddCommand: logAddCommand,
        pipeCommand: pipeCommand
    };
}
