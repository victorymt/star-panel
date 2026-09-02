// JSON parsing and view-model mapping for Starcatch list responses.

function parseJson(text) {
    try { return JSON.parse((text || "").trim()); } catch (e) { return []; }
}

function parseListJson(text) {
    var value = JSON.parse((text || "").trim());
    if (!Array.isArray(value)) throw new Error("expected JSON array");
    return value;
}

function formatDate(iso) {
    if (!iso) return "";
    var parts = iso.split("T");
    if (parts.length < 2) return parts[0] || "";
    return parts[0].slice(5) + " " + parts[1].slice(0, 5);
}

// Starcatch projects are optional strings.  Normalize the optional value at
// the view-model boundary so QML can distinguish an unassigned todo (null)
// from the empty-string "all projects" filter.
function normalizeTodoProject(value) {
    if (typeof value !== "string") return null;
    var normalized = value.trim();
    return normalized ? normalized : null;
}

function mapTodos(raw) {
    var priorityIcon = { "P0": "🔴", "P1": "🟡", "P2": "🟢", "P3": "⚪" };
    var statusIcon = { "Pending": "⬜", "Done": "✅", "Archived": "📦" };
    return (Array.isArray(raw) ? raw : []).map(function(item) {
        return {
            id: item.id,
            rawStatus: item.status,
            priority: priorityIcon[item.priority] || "🟢",
            status: statusIcon[item.status] || "⬜",
            title: item.title,
            description: item.description || "",
            tags: item.tags || [],
            project: normalizeTodoProject(item.project),
            due: item.due_date || "-"
        };
    });
}

function mapIdeas(raw) {
    return (Array.isArray(raw) ? raw : []).map(function(item) {
        var time = formatDate(item.created_at);
        var subtitle = item.source ? "from: " + item.source + " · " + time : time;
        return {
            id: item.id,
            title: item.title,
            content: item.content || subtitle,
            tags: item.tags || [],
            time: time,
            source: item.source || "?"
        };
    });
}

function mapLogs(raw) {
    return (Array.isArray(raw) ? raw : []).map(function(item) {
        var time = formatDate(item.created_at);
        return {
            id: item.id,
            title: time + (item.mood ? " · " + item.mood : ""),
            content: item.content,
            tags: item.tags || [],
            images: item.images || [],
            time: time
        };
    });
}

function parseTodos(text) { return mapTodos(parseJson(text)); }
function parseIdeas(text) { return mapIdeas(parseJson(text)); }
function parseLogs(text) { return mapLogs(parseJson(text)); }

if (typeof module !== "undefined") {
    module.exports = {
        parseJson: parseJson,
        parseListJson: parseListJson,
        formatDate: formatDate,
        normalizeTodoProject: normalizeTodoProject,
        mapTodos: mapTodos,
        mapIdeas: mapIdeas,
        mapLogs: mapLogs,
        parseTodos: parseTodos,
        parseIdeas: parseIdeas,
        parseLogs: parseLogs
    };
}
