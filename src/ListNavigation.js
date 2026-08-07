// Shared, view-independent list navigation calculations.

function moveIndex(currentIndex, delta, length) {
    var count = Math.max(0, Number(length) || 0);
    if (count === 0) return 0;
    var current = Number(currentIndex);
    if (!isFinite(current)) current = 0;
    return Math.max(0, Math.min(count - 1, current + (Number(delta) || 0)));
}

function pageRowCount(viewHeight, currentRowHeight, fraction) {
    var height = Math.max(1, Number(currentRowHeight) || 56);
    var pageFraction = Number(fraction);
    if (!isFinite(pageFraction) || pageFraction <= 0) pageFraction = 1;
    return Math.max(1, Math.floor((Number(viewHeight) || 0) / height * pageFraction));
}

function restoreIndex(model, targetId, oldIndex) {
    var list = Array.isArray(model) ? model : [];
    for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].id === targetId) return i;
    }
    if (list.length === 0) return 0;
    var fallback = Number(oldIndex);
    if (!isFinite(fallback)) fallback = 0;
    return Math.max(0, Math.min(list.length - 1, fallback));
}

if (typeof module !== "undefined") {
    module.exports = {
        moveIndex: moveIndex,
        pageRowCount: pageRowCount,
        restoreIndex: restoreIndex
    };
}
