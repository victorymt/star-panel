import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var toastTarget: null
    property var fallbackTarget: null
    property bool acceptImageForRequest: false
    property bool captureStarted: false
    property var ownedPaths: []
    readonly property bool busy: captureProc.running
    readonly property string helperPath: Quickshell.shellDir + "/src/clipboard-image.sh"
    readonly property string stagingDir: Quickshell.cacheDir + "/star-panel/clipboard"

    signal imageCaptured(string path)

    visible: false
    width: 0
    height: 0

    Component.onCompleted: Quickshell.execDetached([root.helperPath, "prune", root.stagingDir])

    function isPasteShortcut(event) {
        var ctrlV = (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V;
        var shiftInsert = (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_Insert;
        return ctrlV || shiftInsert;
    }

    function appendPath(currentText, path) {
        var raw = (currentText || "").split(/[\n,]/);
        var paths = [];
        for (var i = 0; i < raw.length; i++) {
            var current = raw[i].trim();
            if (current && paths.indexOf(current) < 0) paths.push(current);
        }
        if (path && paths.indexOf(path) < 0) paths.push(path);
        return paths.join("\n");
    }

    function showToast(message) {
        if (root.toastTarget && root.toastTarget.showToast)
            root.toastTarget.showToast(message);
    }

    function fallbackToTextPaste() {
        var target = root.fallbackTarget;
        root.fallbackTarget = null;
        if (target && target.paste) target.paste();
    }

    function requestPaste(target, acceptImage) {
        if (captureProc.running) {
            showToast("⏳ 正在读取剪贴板...");
            return;
        }
        root.fallbackTarget = target;
        root.acceptImageForRequest = acceptImage;
        root.captureStarted = false;
        captureProc.command = [root.helperPath, "capture", root.stagingDir];
        startGuard.restart();
        captureProc.running = true;
    }

    function cleanupPath(path) {
        if (!path) return;
        var kept = [];
        for (var i = 0; i < root.ownedPaths.length; i++) {
            if (root.ownedPaths[i] !== path) kept.push(root.ownedPaths[i]);
        }
        root.ownedPaths = kept;
        Quickshell.execDetached([root.helperPath, "cleanup", root.stagingDir, path]);
    }

    function cleanupAll() {
        if (root.ownedPaths.length === 0) return;
        var command = [root.helperPath, "cleanup", root.stagingDir];
        for (var i = 0; i < root.ownedPaths.length; i++)
            command.push(root.ownedPaths[i]);
        root.ownedPaths = [];
        Quickshell.execDetached(command);
    }

    Timer {
        id: startGuard
        interval: 250
        repeat: false
        onTriggered: {
            if (captureProc.running || root.captureStarted) return;
            if (Quickshell.clipboardText !== "") {
                root.fallbackToTextPaste();
            } else {
                root.fallbackTarget = null;
                root.showToast("❌ 无法启动剪贴板图片助手");
            }
        }
    }

    Process {
        id: captureProc
        running: false
        stdout: StdioCollector { id: captureStdout }
        stderr: StdioCollector { id: captureStderr }

        onStarted: {
            root.captureStarted = true;
            startGuard.stop();
        }

        onExited: function(exitCode, exitStatus) {
            startGuard.stop();
            if (exitCode === 0) {
                var path = captureStdout.text.trim();
                root.fallbackTarget = null;
                if (!path) {
                    root.showToast("❌ 未取得剪贴板图片路径");
                    return;
                }
                if (!root.acceptImageForRequest) {
                    Quickshell.execDetached([root.helperPath, "cleanup", root.stagingDir, path]);
                    root.showToast("⚠️ 图片附件仅支持日志");
                    return;
                }

                var paths = root.ownedPaths.slice();
                paths.push(path);
                root.ownedPaths = paths;
                root.imageCaptured(path);
                root.showToast("📎 已粘贴图片");
                return;
            }

            if (exitCode === 3) {
                root.fallbackToTextPaste();
                return;
            }

            if (exitCode === 127 && Quickshell.clipboardText !== "") {
                root.fallbackToTextPaste();
                return;
            }

            root.fallbackTarget = null;
            var detail = captureStderr.text.trim();
            root.showToast("❌ " + (detail ? detail.split("\n")[0] : "读取剪贴板图片失败"));
        }
    }
}
