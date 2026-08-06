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
      images: item.images || [],
      time: time
    };
  });
}

function shellQuote(s) {
  return "'" + s.replace(/'/g, "'\\''") + "'";
}

function splitImagePaths(text) {
  var raw = (text || "").split(/[\n,]/);
  var paths = [];
  for (var i = 0; i < raw.length; i++) {
    var path = raw[i].trim();
    if (path) paths.push(path);
  }
  return paths;
}

function appendImagePath(text, path) {
  var currentPaths = splitImagePaths(text);
  var paths = [];
  for (var i = 0; i < currentPaths.length; i++) {
    if (paths.indexOf(currentPaths[i]) < 0) paths.push(currentPaths[i]);
  }
  var next = (path || "").trim();
  if (next && paths.indexOf(next) < 0) paths.push(next);
  return paths.join("\n");
}

function parseLogInput(raw) {
  var text = (raw || "").trim();
  var sep = text.indexOf("|");
  if (sep >= 0) {
    var meta = parseLogTokens(text.slice(sep + 1), false);
    meta.content = text.slice(0, sep).trim();
    return meta;
  }
  return parseLogTokens(text, true);
}

function parseLogTokens(raw, collectContent) {
  var tokens = (raw || "").trim().split(/\s+/);
  var result = { content: collectContent ? "" : "", mood: "", tags: [], project: "" };
  var contentParts = [];
  for (var i = 0; i < tokens.length; i++) {
    var token = tokens[i];
    if (!token) continue;
    if (token.indexOf("mood:") === 0 || token.indexOf("mood：") === 0) {
      var mood = token.slice(5).trim();
      if (!mood && i + 1 < tokens.length) mood = tokens[++i];
      result.mood = mood;
    } else if (token.indexOf("project:") === 0 || token.indexOf("project：") === 0) {
      var project = token.slice(8).trim();
      if (!project && i + 1 < tokens.length) project = tokens[++i];
      result.project = project;
    } else if (token[0] === "#") {
      var tag = token.slice(1).replace(/[，,。.!?！？；;：:]+$/, "").trim();
      if (tag) result.tags.push(tag);
    } else if (collectContent) {
      contentParts.push(token);
    }
  }
  if (collectContent) result.content = contentParts.join(" ");
  return result;
}

function buildLogAddCommand(inputText, imageText) {
  var images = splitImagePaths(imageText);
  if (images.length === 0) return null;

  var parsed = parseLogInput(inputText);
  var content = (parsed.content || "").trim();
  if (!content) return { error: "内容不能为空" };

  var cmd = ["starcatch", "log", "add", content];
  if (parsed.mood) cmd.push("-m", parsed.mood);
  if (parsed.tags.length > 0) cmd.push("-t", parsed.tags.join(","));
  if (parsed.project) cmd.push("-P", parsed.project);
  for (var i = 0; i < images.length; i++) {
    cmd.push("--image", images[i]);
  }
  return { command: cmd };
}

function normalizeImageText(text) {
  return splitImagePaths(text).join("\n");
}

function editLogImageArgs(originalText, currentText) {
  if (normalizeImageText(originalText) === normalizeImageText(currentText)) return [];
  var paths = splitImagePaths(currentText);
  if (paths.length === 0) return ["--clear-images"];
  var args = [];
  for (var i = 0; i < paths.length; i++) {
    args.push("--image", paths[i]);
  }
  return args;
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

function retryReloadType(timeoutError, timeoutReloadType, activeType) {
  if (timeoutError && timeoutReloadType) return normalizeReloadType(timeoutReloadType);
  return normalizeReloadType(activeType);
}

function deleteCommandDecision(armedType, armedId, currentType, currentId) {
  var type = currentType || "";
  var id = currentId ? String(currentId) : "";
  var confirmedId = armedId ? String(armedId) : "";

  if (!id) return { action: "reject", type: "", id: "" };
  if (armedType === type && confirmedId === id) {
    return { action: "delete", type: type, id: id };
  }
  return { action: "arm", type: type, id: id };
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

function commandAction(name, currentTab) {
  switch (name) {
    case ":open": return "openCurrent";
    case ":e":
    case ":edit": return "editCurrent";
    case ":d":
    case ":delete": return "deleteCurrent";
    case ":done":
    case ":archive":
    case ":reopen": return currentTab === "todo" ? name.slice(1) : "todoOnly";
    case ":r":
    case ":reload": return "reloadAll";
    default: return "unknown";
  }
}

function normalModeAction(key, modifiers) {
  modifiers = modifiers || {};
  if (modifiers.ctrl && key === "D") return "halfPageDown";
  if (modifiers.ctrl && key === "U") return "halfPageUp";
  if (modifiers.ctrl && key === "F") return "pageDown";
  if (modifiers.ctrl && key === "B") return "pageUp";
  if (key === "h") return "prevTab";
  if (key === "l") return "nextTab";
  if (key === "r") return "reloadCurrent";
  if (key === "R") return "reloadAll";
  return "";
}

function todoShortcutAction(key, rawStatus) {
  if (key === "Space") return rawStatus === "Pending" ? "done" : "reopen";
  if (key === "a") return rawStatus === "Archived" ? "alreadyArchived" : "archive";
  return "";
}

function emacsEditResult(text, cursor, key) {
  if (key === "A") return { text: text, cursor: 0 };
  if (key === "E") return { text: text, cursor: text.length };
  if (key === "B") return { text: text, cursor: Math.max(0, cursor - 1) };
  if (key === "F") return { text: text, cursor: Math.min(text.length, cursor + 1) };
  if (key === "U") return { text: "", cursor: 0 };
  if (key === "K") {
    var end = text.indexOf("\n", cursor);
    return {
      text: end >= 0 ? text.slice(0, cursor) + text.slice(end) : text.slice(0, cursor),
      cursor: cursor
    };
  }
  return { text: text, cursor: cursor };
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

function normalizeLogFilterDays(value) {
  var days = Number(value);
  return days === 1 || days === 3 || days === 7 || days === 30 ? days : 3;
}

function logListCommand(value) {
  return ["starcatch", "--json", "log", "list", "-d", String(normalizeLogFilterDays(value))];
}

function inlineImageSummary(images, maxVisible) {
  var all = Array.isArray(images) ? images : [];
  var limit = Math.max(0, maxVisible === undefined ? 3 : maxVisible);
  return {
    visible: all.slice(0, limit),
    hiddenCount: Math.max(0, all.length - limit)
  };
}

function pageRowCount(viewHeight, currentRowHeight, fraction) {
  var rowHeight = Math.max(1, currentRowHeight || 56);
  return Math.max(1, Math.floor((viewHeight / rowHeight) * fraction));
}

module.exports = {
  parseJson,
  formatDate,
  parseTodos,
  parseIdeas,
  parseLogs,
  shellQuote,
  splitImagePaths,
  appendImagePath,
  parseLogInput,
  buildLogAddCommand,
  editLogImageArgs,
  firstLine,
  parseListJson,
  listFetchResult,
  normalizeReloadType,
  mergeQueuedReload,
  retryReloadType,
  deleteCommandDecision,
  completionDecision,
  pipeCompletionDecision,
  deleteCompletionDecision,
  editLoadResult,
  commandAction,
  normalModeAction,
  todoShortcutAction,
  emacsEditResult,
  filterByStatus,
  filterByText,
  normalizeLogFilterDays,
  logListCommand,
  inlineImageSummary,
  pageRowCount
};
