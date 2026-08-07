// Pure JS functions extracted from Panel.qml & Config.qml for testing
// These have no QML/Quickshell runtime dependencies.

const StarcatchCommands = require("../src/StarcatchCommands.js");
const CommandRouter = require("../src/CommandRouter.js");
const EntryInput = require("../src/EntryInput.js");
const EditorKeys = require("../src/EditorKeys.js");

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
  return EntryInput.splitImagePaths(text);
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
  return EntryInput.parseLogInput(raw);
}

function parseLogTokens(raw, collectContent) {
  return EntryInput.parseLogTokens(raw, collectContent);
}

function buildLogAddCommand(inputText, imageText) {
  var payload = EntryInput.buildLogPayload(inputText, imageText);
  if (!payload) return null;
  if (payload.error) return payload;

  return {
    command: StarcatchCommands.logAddCommand(
      "starcatch", payload.content, payload.mood, payload.tags,
      payload.project, payload.images
    )
  };
}

function normalizeImageText(text) {
  return EntryInput.normalizeImageText(text);
}

function editLogImageArgs(originalText, currentText) {
  return EntryInput.editLogImageArgs(originalText, currentText);
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
  var action = CommandRouter.resolve(name);
  if (action.type === "open") return "openCurrent";
  if (action.type === "edit") return "editCurrent";
  if (action.type === "delete") return "deleteCurrent";
  if (action.type === "todoAction")
    return currentTab === "todo" ? action.action : "todoOnly";
  if (action.type === "reload") return "reloadAll";
  return "unknown";
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
  var result = EditorKeys.apply(text, cursor, EditorKeys["KEY_" + key]);
  return { text: result.text, cursor: result.cursor };
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
  return StarcatchCommands.listCommand("starcatch", "log", normalizeLogFilterDays(value));
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
