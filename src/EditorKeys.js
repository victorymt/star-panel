// Pure text transformations for the shared Emacs-style editing shortcuts.

var KEY_A = 0x41;
var KEY_B = 0x42;
var KEY_E = 0x45;
var KEY_F = 0x46;
var KEY_K = 0x4b;
var KEY_U = 0x55;

function apply(text, cursor, key) {
    var value = text === undefined || text === null ? "" : String(text);
    var position = Math.max(0, Math.min(value.length, Number(cursor) || 0));

    if (key === KEY_A) return result(true, value, 0);
    if (key === KEY_E) return result(true, value, value.length);
    if (key === KEY_B) return result(true, value, Math.max(0, position - 1));
    if (key === KEY_F) return result(true, value, Math.min(value.length, position + 1));
    if (key === KEY_K) {
        var end = value.indexOf("\n", position);
        var next = end >= 0
            ? value.slice(0, position) + value.slice(end)
            : value.slice(0, position);
        return result(true, next, position);
    }
    if (key === KEY_U) return result(true, "", 0);
    return result(false, value, position);
}

function result(handled, text, cursor) {
    return { handled: handled, text: text, cursor: cursor };
}

if (typeof module !== "undefined") {
    module.exports = {
        KEY_A: KEY_A,
        KEY_B: KEY_B,
        KEY_E: KEY_E,
        KEY_F: KEY_F,
        KEY_K: KEY_K,
        KEY_U: KEY_U,
        apply: apply
    };
}
