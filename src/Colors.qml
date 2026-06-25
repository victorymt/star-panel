import QtQuick
import Quickshell
import Quickshell.Io

/// Colors — 主题色单例
/// Matugen 自动 / Catppuccin 预设（Mocha / Latte / Frappé / Macchiato）
Item {
    id: root

    // ── 22 色属性（默认 Catppuccin Mocha） ──
    property color base: "#1e1e2e"
    property color mantle: "#181825"
    property color crust: "#11111b"
    property color text: "#cdd6f4"
    property color subtext0: "#a6adc8"
    property color subtext1: "#bac2de"
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color surface2: "#585b70"
    property color overlay0: "#6c7086"
    property color overlay1: "#7f849c"
    property color overlay2: "#9399b2"
    property color blue: "#89b4fa"
    property color sapphire: "#74c7ec"
    property color peach: "#fab387"
    property color green: "#a6e3a1"
    property color red: "#f38ba8"
    property color mauve: "#cba6f7"
    property color pink: "#f5c2e7"
    property color yellow: "#f9e2af"
    property color maroon: "#eba0ac"
    property color teal: "#94e2d5"

    // ── Catppuccin 预设调色板 ──
    readonly property var palettes: ({
        "mocha": {
            base: "#1e1e2e", mantle: "#181825", crust: "#11111b",
            text: "#cdd6f4", subtext0: "#a6adc8", subtext1: "#bac2de",
            surface0: "#313244", surface1: "#45475a", surface2: "#585b70",
            overlay0: "#6c7086", overlay1: "#7f849c", overlay2: "#9399b2",
            blue: "#89b4fa", sapphire: "#74c7ec", peach: "#fab387",
            green: "#a6e3a1", red: "#f38ba8", mauve: "#cba6f7",
            pink: "#f5c2e7", yellow: "#f9e2af", maroon: "#eba0ac", teal: "#94e2d5"
        },
        "latte": {
            base: "#eff1f5", mantle: "#e6e9ef", crust: "#dce0e8",
            text: "#4c4f69", subtext0: "#6c6f85", subtext1: "#5c5f77",
            surface0: "#ccd0da", surface1: "#bcc0cc", surface2: "#acb0be",
            overlay0: "#9ca0b0", overlay1: "#8c8fa1", overlay2: "#7c7f93",
            blue: "#1e66f5", sapphire: "#209fb5", peach: "#fe640b",
            green: "#40a02b", red: "#d20f39", mauve: "#8839ef",
            pink: "#ea76cb", yellow: "#df8e1d", maroon: "#e64553", teal: "#179299"
        },
        "frappe": {
            base: "#303446", mantle: "#292c3c", crust: "#232634",
            text: "#c6d0f5", subtext0: "#a5adce", subtext1: "#b5bfe2",
            surface0: "#414559", surface1: "#51576d", surface2: "#626880",
            overlay0: "#737994", overlay1: "#838ba7", overlay2: "#949cbb",
            blue: "#8caaee", sapphire: "#85c1dc", peach: "#ef9f76",
            green: "#a6d189", red: "#e78284", mauve: "#ca9ee6",
            pink: "#f4b8e4", yellow: "#e5c890", maroon: "#ea999c", teal: "#81c8be"
        },
        "macchiato": {
            base: "#24273a", mantle: "#1e2030", crust: "#181926",
            text: "#cad3f5", subtext0: "#a5adcb", subtext1: "#b8c0e0",
            surface0: "#363a4f", surface1: "#494d64", surface2: "#5b6078",
            overlay0: "#6e738d", overlay1: "#8087a2", overlay2: "#939ab7",
            blue: "#8aadf4", sapphire: "#7dc4e4", peach: "#f5a97f",
            green: "#a6da95", red: "#ed8796", mauve: "#c6a0f6",
            pink: "#f5bde6", yellow: "#eed49f", maroon: "#ee99a0", teal: "#8bd5ca"
        }
    })

    // ── 应用预设主题 ──
    function applyPreset(name) {
        var p = palettes[name];
        if (!p) return;
        root.base = p.base; root.mantle = p.mantle; root.crust = p.crust;
        root.text = p.text; root.subtext0 = p.subtext0; root.subtext1 = p.subtext1;
        root.surface0 = p.surface0; root.surface1 = p.surface1; root.surface2 = p.surface2;
        root.overlay0 = p.overlay0; root.overlay1 = p.overlay1; root.overlay2 = p.overlay2;
        root.blue = p.blue; root.sapphire = p.sapphire; root.peach = p.peach;
        root.green = p.green; root.red = p.red; root.mauve = p.mauve;
        root.pink = p.pink; root.yellow = p.yellow; root.maroon = p.maroon; root.teal = p.teal;
    }

    // ── 监听 cfg.themeName，非空时应用预设 ──
    Connections {
        target: typeof cfg !== "undefined" ? cfg : null
        enabled: target !== null
        function onThemeNameChanged() {
            if (cfg.themeName !== "") {
                root.applyPreset(cfg.themeName);
            }
        }
    }

    Component.onCompleted: {
        if (typeof cfg !== "undefined" && cfg.themeName !== "") {
            root.applyPreset(cfg.themeName);
        }
    }

    // ── Matugen 读取（仅在未选预设时启用） ──
    Process {
        id: themeReader
        command: ["cat", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/qs_colors.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (typeof cfg !== "undefined" && cfg.themeName !== "") return;
                try {
                    var c = JSON.parse(this.text.trim());
                    if (c.base) root.base = c.base;
                    if (c.mantle) root.mantle = c.mantle;
                    if (c.crust) root.crust = c.crust;
                    if (c.text) root.text = c.text;
                    if (c.subtext0) root.subtext0 = c.subtext0;
                    if (c.subtext1) root.subtext1 = c.subtext1;
                    if (c.surface0) root.surface0 = c.surface0;
                    if (c.surface1) root.surface1 = c.surface1;
                    if (c.surface2) root.surface2 = c.surface2;
                    if (c.overlay0) root.overlay0 = c.overlay0;
                    if (c.overlay1) root.overlay1 = c.overlay1;
                    if (c.overlay2) root.overlay2 = c.overlay2;
                    if (c.blue) root.blue = c.blue;
                    if (c.sapphire) root.sapphire = c.sapphire;
                    if (c.peach) root.peach = c.peach;
                    if (c.green) root.green = c.green;
                    if (c.red) root.red = c.red;
                    if (c.mauve) root.mauve = c.mauve;
                    if (c.pink) root.pink = c.pink;
                    if (c.yellow) root.yellow = c.yellow;
                    if (c.maroon) root.maroon = c.maroon;
                    if (c.teal) root.teal = c.teal;
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (typeof cfg === "undefined" || cfg.themeName === "") {
                themeReader.running = true;
            }
        }
    }
}
