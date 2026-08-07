import QtQuick

// Stops a hung Quickshell Process and emits timeout before cancellation.
Item {
    id: root

    property var process: null
    property int timeoutMs: 15000
    property bool timedOut: false

    signal timeout()

    function sync() {
        if (!root.process) return;
        if (root.process.running) {
            root.timedOut = false;
            watchdog.restart();
        } else {
            watchdog.stop();
        }
    }

    onProcessChanged: sync()
    onTimeoutMsChanged: if (root.process && root.process.running) watchdog.restart()

    Connections {
        target: root.process
        function onRunningChanged() { root.sync(); }
    }

    Timer {
        id: watchdog
        interval: Math.max(1, root.timeoutMs)
        repeat: false
        onTriggered: {
            if (!root.process || !root.process.running) return;
            root.timedOut = true;
            root.timeout();
            root.process.running = false;
        }
    }
}
