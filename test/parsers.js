// Pure JS functions extracted from Panel.qml & Config.qml for testing
// These have no QML/Quickshell runtime dependencies.

function parseJson(text) {
  try { return JSON.parse(text.trim()); } catch(e) { return []; }
}

function formatDate(iso) {
  if (!iso) return "";
  var parts = iso.split("T");
  if (parts.length < 2) return parts[0] || "";
  return parts[0].slice(5) + " " + parts[1].slice(0, 5);
}

function parseTodos(text) {
  var raw = parseJson(text);
  var priorityIcon = { "P0": "🔴", "P1": "🟡", "P2": "🟢", "P3": "⚪" };
  var statusIcon = { "Pending": "⬜", "Done": "✅", "Archived": "📦" };
  return raw.map(function(item) {
    return {
      id: item.id,
      rawStatus: item.status,
      priority: priorityIcon[item.priority] || "🟢",
      status: statusIcon[item.status] || "⬜",
      title: item.title,
      description: item.description || "",
      tags: item.tags || [],
      due: item.due_date || "-"
    };
  });
}

function parseIdeas(text) {
  var raw = parseJson(text);
  return raw.map(function(item) {
    var time = formatDate(item.created_at);
    var subtitle = item.source ? "from: " + item.source + " · " + time : time;
    return {
      title: item.title,
      content: item.content || subtitle,
      tags: item.tags || [],
      time: time,
      source: item.source || "?"
    };
  });
}

function parseLogs(text) {
  var raw = parseJson(text);
  return raw.map(function(item) {
    var time = formatDate(item.created_at);
    return {
      title: time + (item.mood ? " · " + item.mood : ""),
      content: item.content,
      tags: item.tags || [],
      time: time
    };
  });
}

function shellQuote(s) {
  return "'" + s.replace(/'/g, "'\\''") + "'";
}

// Search/filter helpers (mirrors QML logic in TodoList/IdeaList/LogList)
function filterByStatus(items, status) {
  return items.filter(function(item) { return item.rawStatus === status; });
}

function filterByText(items, query) {
  if (!query || !query.trim()) return items;
  var q = query.trim().toLowerCase();
  return items.filter(function(item) {
    return (item.title && item.title.toLowerCase().indexOf(q) >= 0)
        || (item.description && item.description.toLowerCase().indexOf(q) >= 0)
        || (item.content && item.content.toLowerCase().indexOf(q) >= 0);
  });
}

module.exports = { parseJson, formatDate, parseTodos, parseIdeas, parseLogs, shellQuote, filterByStatus, filterByText };
