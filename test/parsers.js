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

function firstLine(text) {
  var trimmed = (text || "").trim();
  return trimmed ? trimmed.split("\n")[0] : "";
}

function listLabel(type) {
  if (type === "todo") return "待办";
  if (type === "idea") return "灵感";
  return "日志";
}

function parseListJson(text) {
  var value = JSON.parse((text || "").trim());
  if (!Array.isArray(value)) throw new Error("expected JSON array");
  return value;
}

function listFetchResult(type, exitCode, stdoutText, stderrText) {
  var label = listLabel(type);
  var out = (stdoutText || "").trim();

  if (exitCode !== 0) {
    var detail = firstLine(stderrText);
    return {
      ok: false,
      items: null,
      error: label + "获取失败" + (detail ? "：" + detail : "（退出码 " + exitCode + "）")
    };
  }

  if (!out) {
    return {
      ok: true,
      items: [],
      error: label + "数据为空，请确认 Starcatch 可用"
    };
  }

  try {
    return { ok: true, items: parseListJson(out), error: "" };
  } catch (e) {
    return { ok: false, items: null, error: label + "解析失败：" + e.message };
  }
}

function normalizeReloadType(type) {
  return type === "todo" || type === "idea" || type === "log" ? type : "all";
}

function mergeQueuedReload(current, next) {
  var normalized = normalizeReloadType(next);
  if (!current) return normalized;
  return current === normalized ? current : "all";
}

function completionDecision(exitCode, pendingReload) {
  return {
    close: exitCode === 0,
    reloadType: exitCode === 0 ? (pendingReload || "") : ""
  };
}

function pipeCompletionDecision(exitCode, pendingType, pendingText) {
  return {
    restoreText: exitCode === 0 ? "" : (pendingText || ""),
    reloadType: exitCode === 0 ? (pendingType || "") : "",
    clearPending: true
  };
}

function deleteCompletionDecision(exitCode, pendingType, hasSuccessCallback) {
  return {
    callSuccess: exitCode === 0 && !!hasSuccessCallback,
    reloadType: exitCode === 0 ? (pendingType || "") : ""
  };
}

function editLoadResult(exitCode, stdoutText, stderrText) {
  if (exitCode !== 0) {
    var detail = firstLine(stderrText);
    return {
      ok: false,
      data: null,
      error: "加载失败" + (detail ? "：" + detail : "（退出码 " + exitCode + "）")
    };
  }

  var out = (stdoutText || "").trim();
  if (!out) {
    return { ok: false, data: null, error: "加载失败：未取到数据" };
  }

  try {
    return { ok: true, data: JSON.parse(out), error: "" };
  } catch (e) {
    return { ok: false, data: null, error: "解析失败：" + e.message };
  }
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

module.exports = {
  parseJson,
  formatDate,
  parseTodos,
  parseIdeas,
  parseLogs,
  shellQuote,
  firstLine,
  parseListJson,
  listFetchResult,
  normalizeReloadType,
  mergeQueuedReload,
  completionDecision,
  pipeCompletionDecision,
  deleteCompletionDecision,
  editLoadResult,
  filterByStatus,
  filterByText
};
