import QtQuick
import Quickshell
import Quickshell.Io
import "EntryMapper.js" as EntryMapper
import "StarcatchCommands.js" as StarcatchCommands

/// ReloadCoordinator — Starcatch 三类数据的并行刷新、超时和结果映射。
// ── 数据获取器 ──
Item {
    id: root

    property string starcatchPath: "starcatch"
    property int logFilterDays: 3
    property int activeTabIndex: 0
    property bool panelVisible: false

    property var todos: []
    property var ideas: []
    property var logs: []
    property bool loading: false
    property bool todoLoading: false
    property bool ideaLoading: false
    property bool logLoading: false
    property int pendingCount: 0
    property string queuedReloadType: ""
    property string timeoutReloadType: ""
    property bool abortingFetch: false
    // 三个独立 error 属性，避免并行 Process 互相覆盖；
    // 聚合 error 只读属性供 UI 显示（优先 todo → idea → log）。
    property string todoError: ""
    property string ideaError: ""
    property string logError: ""
    property string timeoutError: ""
    readonly property string error: todoError || ideaError || logError || timeoutError
    readonly property string activeError: timeoutError || (root.activeTabIndex === 0 ? todoError
        : root.activeTabIndex === 1 ? ideaError : logError)
    readonly property string activeReloadType: timeoutError !== "" && timeoutReloadType !== ""
        ? timeoutReloadType
        : root.activeTabIndex === 0 ? "todo"
            : root.activeTabIndex === 1 ? "idea" : "log"

    function normalizeLogFilterDays(value) {
        var days = Number(value);
        return days === 1 || days === 3 || days === 7 || days === 30 ? days : 3;
    }

    function reload(type) {
        var normalized = normalizeReloadType(type);
        if (pendingCount > 0) {
            queueReload(normalized);
            return;
        }
        startReload(normalized);
    }

    function startReload(type) {
        loading = true;
        timeoutError = "";
        timeoutReloadType = type;
        abortingFetch = false;
        pendingCount = 0;
        todoLoading = false;
        ideaLoading = false;
        logLoading = false;

        if (type === "todo") {
            todoError = "";
            fetchTodos();
        } else if (type === "idea") {
            ideaError = "";
            fetchIdeas();
        } else if (type === "log") {
            logError = "";
            fetchLogs();
        } else {
            todoError = "";
            ideaError = "";
            logError = "";
            fetchTodos();
            fetchIdeas();
            fetchLogs();
        }

        if (pendingCount > 0) {
            fetchTimeout.restart();
        } else {
            loading = false;
            fetchTimeout.stop();
        }
    }

    function normalizeReloadType(type) {
        if (type === "todo" || type === "idea" || type === "log") return type;
        return "all";
    }

    function queueReload(type) {
        var next = normalizeReloadType(type);
        if (queuedReloadType === "") {
            queuedReloadType = next;
        } else if (queuedReloadType !== next) {
            queuedReloadType = "all";
        }
    }

    function drainQueuedReload() {
        if (queuedReloadType === "") return;
        var next = queuedReloadType;
        queuedReloadType = "";
        startReload(next);
    }

    function fetchTodos() {
        pendingCount++;
        todoLoading = true;
        todoProcess.running = true;
    }

    function fetchIdeas() {
        pendingCount++;
        ideaLoading = true;
        ideaProcess.running = true;
    }

    function fetchLogs() {
        pendingCount++;
        logLoading = true;
        logProcess.running = true;
    }

    function firstLine(text) {
        var trimmed = (text || "").trim();
        return trimmed ? trimmed.split("\n")[0] : "";
    }

    function emptyMessage(type) {
        if (type === "todo") return "待办数据为空，请确认 Starcatch 可用";
        if (type === "idea") return "灵感数据为空，请确认 Starcatch 可用";
        return "日志数据为空，请确认 Starcatch 可用";
    }

    function failureMessage(type, exitCode, stderrText) {
        var detail = firstLine(stderrText);
        var prefix = type === "todo" ? "待办获取失败"
            : type === "idea" ? "灵感获取失败"
            : "日志获取失败";
        return prefix + (detail ? "：" + detail : "（退出码 " + exitCode + "）");
    }

    function parseFailureMessage(type, err) {
        var prefix = type === "todo" ? "待办解析失败"
            : type === "idea" ? "灵感解析失败"
            : "日志解析失败";
        return prefix + "：" + err.message;
    }

    function setFetchError(type, msg) {
        if (type === "todo") todoError = msg;
        else if (type === "idea") ideaError = msg;
        else logError = msg;
    }

    function setFetchItems(type, value) {
        if (type === "todo") todos = value;
        else if (type === "idea") ideas = value;
        else logs = value;
    }

    function setTypeLoading(type, value) {
        if (type === "todo") todoLoading = value;
        else if (type === "idea") ideaLoading = value;
        else if (type === "log") logLoading = value;
    }

    function handleFetchDone(type, exitCode, stdoutText, stderrText) {
        setTypeLoading(type, false);

        if (abortingFetch) {
            // Ignore output from the timed-out batch; only settle its counters.
            checkDone();
            return;
        }

        var out = (stdoutText || "").trim();

        if (exitCode !== 0) {
            setFetchError(type, failureMessage(type, exitCode, stderrText));
            checkDone();
            return;
        }

        if (!out) {
            setFetchError(type, emptyMessage(type));
            setFetchItems(type, []);
            checkDone();
            return;
        }

        try {
            var raw = EntryMapper.parseListJson(out);
            if (type === "todo") setFetchItems(type, EntryMapper.mapTodos(raw));
            else if (type === "idea") setFetchItems(type, EntryMapper.mapIdeas(raw));
            else setFetchItems(type, EntryMapper.mapLogs(raw));
            setFetchError(type, "");
        } catch (e) {
            setFetchError(type, parseFailureMessage(type, e));
        }

        checkDone();
    }

    Process {
        id: todoProcess
        command: StarcatchCommands.listCommand(root.starcatchPath, "todo")
        running: false
        stdout: StdioCollector { id: todoStdout }
        stderr: StdioCollector { id: todoStderr }
        onExited: function(exitCode, exitStatus) {
            root.handleFetchDone("todo", exitCode, todoStdout.text, todoStderr.text);
        }
    }

    Process {
        id: ideaProcess
        command: StarcatchCommands.listCommand(root.starcatchPath, "idea", 7)
        running: false
        stdout: StdioCollector { id: ideaStdout }
        stderr: StdioCollector { id: ideaStderr }
        onExited: function(exitCode, exitStatus) {
            root.handleFetchDone("idea", exitCode, ideaStdout.text, ideaStderr.text);
        }
    }

    Process {
        id: logProcess
        command: StarcatchCommands.listCommand(
            root.starcatchPath,
            "log",
            root.normalizeLogFilterDays(root.logFilterDays)
        )
        running: false
        stdout: StdioCollector { id: logStdout }
        stderr: StdioCollector { id: logStderr }
        onExited: function(exitCode, exitStatus) {
            root.handleFetchDone("log", exitCode, logStdout.text, logStderr.text);
        }
    }

    function checkDone() {
        pendingCount--;
        if (pendingCount <= 0) {
            pendingCount = 0;
            loading = false;
            fetchTimeout.stop();
            abortingFetch = false;
            drainQueuedReload();
        }
    }

    Timer {
        id: fetchTimeout
        interval: 15000
        repeat: false
        onTriggered: {
            if (root.loading) {
                // Snapshot the old batch before stopping it. An exit callback may
                // synchronously drain a queued reload and start a new process.
                var stopTodo = todoProcess.running;
                var stopIdea = ideaProcess.running;
                var stopLog = logProcess.running;
                root.loading = false;
                root.abortingFetch = true;
                root.todoLoading = false;
                root.ideaLoading = false;
                root.logLoading = false;
                root.timeoutError = "数据获取超时，请检查 Starcatch 是否运行";
                if (stopTodo) todoProcess.running = false;
                if (stopIdea) ideaProcess.running = false;
                if (stopLog) logProcess.running = false;
            }
        }
    }

    // 自动刷新（面板可见期间 30s 循环）
    Timer {
        id: autoRefreshTimer
        running: root.panelVisible
        interval: 30000
        repeat: true
        onTriggered: {
            if (root.panelVisible) root.reload();
        }
    }

}
