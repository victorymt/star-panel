const assert = require("assert");
const {
  parseJson,
  formatDate,
  normalizeTodoProject,
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
  filterByProject,
  projectNames,
  filterTodos,
  filterByText,
  normalizeLogFilterDays,
  logListCommand,
  inlineImageSummary,
  pageRowCount,
  moveIndex,
  restoreIndex
} = require("./parsers");

let passed = 0;
function test(desc, fn) { try { fn(); passed++; } catch(e) { console.error("FAIL:", desc); throw e; } }

// ── parseJson ──
test("valid JSON", () => assert.deepStrictEqual(parseJson('[{"a":1}]'), [{a:1}]));
test("invalid JSON → empty array", () => assert.deepStrictEqual(parseJson("invalid"), []));
test("empty string → empty array", () => assert.deepStrictEqual(parseJson(""), []));
test("whitespace → empty array", () => assert.deepStrictEqual(parseJson("  "), []));

// ── formatDate ──
test("standard ISO", () => assert.strictEqual(formatDate("2024-06-27T14:30:00Z"), "06-27 14:30"));
test("single-digit month", () => assert.strictEqual(formatDate("2024-01-05T09:05:00"), "01-05 09:05"));
test("midnight", () => assert.strictEqual(formatDate("2024-12-01T00:00:00"), "12-01 00:00"));
test("no T separator → full string", () => assert.strictEqual(formatDate("nodatetime"), "nodatetime"));
test("empty string", () => assert.strictEqual(formatDate(""), ""));
test("null input", () => assert.strictEqual(formatDate(null), ""));
test("undefined input", () => assert.strictEqual(formatDate(undefined), ""));

// ── parseTodos ──
test("3 todos with full fields", () => {
  const todoInput = JSON.stringify([
    { id: "1", status: "Pending", priority: "P0", title: "Urgent", description: "desc1", tags: ["work"], project: "workbench", due_date: "2024-07-01" },
    { id: "2", status: "Done", priority: "P2", title: "Done task", tags: [], project: null, due_date: "2024-06-20" },
    { id: "3", status: "Archived", priority: "", title: "Archived", description: null }
  ]);
  const todos = parseTodos(todoInput);
  assert.strictEqual(todos.length, 3);
  assert.strictEqual(todos[0].id, "1");
  assert.strictEqual(todos[0].rawStatus, "Pending");
  assert.strictEqual(todos[0].priority, "🔴");
  assert.strictEqual(todos[0].status, "⬜");
  assert.strictEqual(todos[0].title, "Urgent");
  assert.strictEqual(todos[0].description, "desc1");
  assert.strictEqual(todos[0].project, "workbench");
  assert.deepStrictEqual(todos[0].tags, ["work"]);
  assert.strictEqual(todos[0].due, "2024-07-01");
  assert.strictEqual(todos[1].priority, "🟢");
  assert.strictEqual(todos[1].status, "✅");
  assert.strictEqual(todos[1].description, "");
  assert.strictEqual(todos[1].project, null);
  assert.strictEqual(todos[2].priority, "🟢");
  assert.strictEqual(todos[2].status, "📦");
  assert.strictEqual(todos[2].description, "");
  assert.strictEqual(todos[2].project, null);
  assert.strictEqual(todos[2].due, "-");
  assert.deepStrictEqual(todos[2].tags, []);
});
test("parseTodos empty input", () => {
  assert.deepStrictEqual(parseTodos("[]"), []);
  assert.deepStrictEqual(parseTodos("invalid"), []);
});

test("normalizeTodoProject keeps named projects and normalizes blank values", () => {
  assert.strictEqual(normalizeTodoProject("workbench"), "workbench");
  assert.strictEqual(normalizeTodoProject("  workbench  "), "workbench");
  assert.strictEqual(normalizeTodoProject(""), null);
  assert.strictEqual(normalizeTodoProject("   "), null);
  assert.strictEqual(normalizeTodoProject(null), null);
  assert.strictEqual(normalizeTodoProject(undefined), null);
});

// ── project filtering ──
test("filterByProject matches an exact project name", () => {
  const items = [
    { project: "star-panel", title: "A" },
    { project: "Star-Panel", title: "B" },
    { project: "other", title: "C" },
    { project: "", title: "unassigned" },
    { project: null, title: "legacy" }
  ];
  assert.deepStrictEqual(filterByProject(items, "star-panel").map(item => item.title), ["A"]);
  assert.deepStrictEqual(filterByProject(items, "Star-Panel").map(item => item.title), ["B"]);
});
test("filterByProject supports all and unassigned selections", () => {
  const items = [{ project: "a" }, { project: "" }, { project: null }];
  assert.strictEqual(filterByProject(items, "").length, 3);
  assert.strictEqual(filterByProject(items, "  ").length, 3);
  assert.strictEqual(filterByProject(items, null).length, 2);
  assert.strictEqual(filterByProject(items, null)[0].project, "");
  assert.strictEqual(filterByProject(items, null)[1].project, null);
  assert.strictEqual(filterByProject(items, undefined).length, 3);
  assert.deepStrictEqual(filterByProject(null, "a"), []);
});
test("projectNames de-duplicates, normalizes, and sorts names", () => {
  const items = [
    { project: "zeta" }, { project: "alpha" }, { project: "alpha" }, { project: " beta " },
    { project: "" }, { project: null }, {}, { project: "alpha" }
  ];
  assert.deepStrictEqual(projectNames(items), ["alpha", "beta", "zeta"]);
});
test("filterTodos composes status, project, and text filters", () => {
  const items = [
    { rawStatus: "Pending", project: "work", title: "Fix parser", description: "" },
    { rawStatus: "Pending", project: "work", title: "Review UI", description: "" },
    { rawStatus: "Done", project: "work", title: "Fix parser", description: "" },
    { rawStatus: "Pending", project: null, title: "Fix parser", description: "" }
  ];
  assert.deepStrictEqual(
    filterTodos(items, "Pending", "work", "parser").map(item => item.title),
    ["Fix parser"]
  );
  assert.strictEqual(filterTodos(items, "Pending", null, "parser").length, 1);
});

// ── parseIdeas ──
test("parseIdeas with source", () => {
  const ideaInput = JSON.stringify([
    { id: "1", title: "Great idea", content: "Details", source: "chat", created_at: "2024-06-27T14:30:00Z", tags: ["tech"] },
    { id: "2", title: "No source", created_at: "2024-06-26T10:00:00Z", tags: [] }
  ]);
  const ideas = parseIdeas(ideaInput);
  assert.strictEqual(ideas.length, 2);
  assert.strictEqual(ideas[0].id, "1");
  assert.strictEqual(ideas[0].title, "Great idea");
  assert.strictEqual(ideas[0].content, "Details");
  assert.strictEqual(ideas[0].source, "chat");
  assert.strictEqual(ideas[0].time, "06-27 14:30");
  assert.deepStrictEqual(ideas[0].tags, ["tech"]);
  assert.strictEqual(ideas[1].content, "06-26 10:00", "no source → subtitle is just time");
  assert.strictEqual(ideas[1].source, "?");
});

// ── parseLogs ──
test("parseLogs with mood", () => {
  const logInput = JSON.stringify([
    { id: "1", content: "Today was good", mood: "😊", created_at: "2024-06-27T20:00:00Z", tags: ["life"], images: ["/tmp/starcatch/image-cache/a.png"] },
    { id: "2", content: "No mood entry", created_at: "2024-06-26T12:00:00Z" }
  ]);
  const logs = parseLogs(logInput);
  assert.strictEqual(logs.length, 2);
  assert.strictEqual(logs[0].id, "1");
  assert.strictEqual(logs[0].content, "Today was good");
  assert.strictEqual(logs[0].title, "06-27 20:00 · 😊");
  assert.deepStrictEqual(logs[0].tags, ["life"]);
  assert.deepStrictEqual(logs[0].images, ["/tmp/starcatch/image-cache/a.png"]);
  assert.strictEqual(logs[1].title, "06-26 12:00");
  assert.strictEqual(logs[1].tags.length, 0);
  assert.deepStrictEqual(logs[1].images, []);
});

// ── filterByStatus ──
test("filterByStatus Pending", () => {
  const items = [
    { rawStatus: "Pending", title: "A" },
    { rawStatus: "Done", title: "B" },
    { rawStatus: "Pending", title: "C" }
  ];
  assert.strictEqual(filterByStatus(items, "Pending").length, 2);
  assert.strictEqual(filterByStatus(items, "Done").length, 1);
  assert.strictEqual(filterByStatus(items, "Archived").length, 0);
});
test("filterByStatus empty input", () => assert.deepStrictEqual(filterByStatus([], "Pending"), []));

// ── filterByText ──
test("filterByText matches title", () => {
  const items = [
    { title: "买奶茶", description: "" },
    { title: "写代码", description: "修 bug" }
  ];
  assert.strictEqual(filterByText(items, "奶茶").length, 1);
  assert.strictEqual(filterByText(items, "bug").length, 1);
  assert.strictEqual(filterByText(items, "买").length, 1);
});
test("filterByText matches description", () => {
  const items = [
    { title: "Task", description: "买东西" },
    { title: "Other", description: "无关" }
  ];
  assert.strictEqual(filterByText(items, "东西").length, 1);
});
test("filterByText case insensitive", () => {
  const items = [{ title: "HELLO World", description: "" }];
  assert.strictEqual(filterByText(items, "hello").length, 1);
  assert.strictEqual(filterByText(items, "WORLD").length, 1);
});
test("filterByText empty query", () => {
  const items = [{ title: "A" }, { title: "B" }];
  assert.strictEqual(filterByText(items, "").length, 2);
  assert.strictEqual(filterByText(items, "  ").length, 2);
  assert.strictEqual(filterByText(items, null).length, 2);
  assert.strictEqual(filterByText(items, undefined).length, 2);
});
test("filterByText no match", () => assert.strictEqual(filterByText([{ title: "A" }], "Z").length, 0));
test("filterByText matches content field", () => {
  const items = [{ title: "Idea", content: "创新思维" }];
  assert.strictEqual(filterByText(items, "创新").length, 1);
});

// ── shellQuote ──
test("simple string", () => assert.strictEqual(shellQuote("hello"), "'hello'"));
test("single quote escaped", () => assert.strictEqual(shellQuote("it's"), "'it'\\''s'"));
test("empty string", () => assert.strictEqual(shellQuote(""), "''"));
test("multiple single quotes", () => assert.strictEqual(shellQuote("a'b'c"), "'a'\\''b'\\''c'"));
test("path with spaces", () => assert.strictEqual(shellQuote("/home/me/My Config/settings.json"), "'/home/me/My Config/settings.json'"));
test("path with single quote", () => assert.strictEqual(shellQuote("/home/o'hara/settings.json"), "'/home/o'\\''hara/settings.json'"));

// ── log images ──
test("splitImagePaths supports comma and newline", () => {
  assert.deepStrictEqual(
    splitImagePaths(" /tmp/a.png, /tmp/b.jpg\n/tmp/c.webp ,, "),
    ["/tmp/a.png", "/tmp/b.jpg", "/tmp/c.webp"]
  );
  assert.deepStrictEqual(splitImagePaths(""), []);
});
test("appendImagePath appends with normalized newlines", () => {
  assert.strictEqual(appendImagePath(" /tmp/a.png, /tmp/b.jpg ", "/tmp/c.webp"),
    "/tmp/a.png\n/tmp/b.jpg\n/tmp/c.webp");
});
test("appendImagePath does not duplicate an existing path", () => {
  assert.strictEqual(appendImagePath("/tmp/a.png\n/tmp/b.jpg\n/tmp/a.png", "/tmp/a.png"),
    "/tmp/a.png\n/tmp/b.jpg");
});
test("parseLogInput keeps quick log metadata out of content", () => {
  assert.deepStrictEqual(parseLogInput("shipped v2 mood:happy project:backend #work"), {
    content: "shipped v2",
    mood: "happy",
    tags: ["work"],
    project: "backend"
  });
});
test("parseLogInput supports separator metadata", () => {
  assert.deepStrictEqual(parseLogInput("shipped v2 | mood:happy #work project:backend"), {
    content: "shipped v2",
    mood: "happy",
    tags: ["work"],
    project: "backend"
  });
});
test("buildLogAddCommand returns null without images", () => {
  assert.strictEqual(buildLogAddCommand("plain log", ""), null);
});
test("buildLogAddCommand includes repeated image args", () => {
  assert.deepStrictEqual(
    buildLogAddCommand("shipped v2 mood:happy project:backend #work", "/tmp/a.png,/tmp/b.jpg"),
    {
      command: [
        "starcatch", "log", "add",
        "-m", "happy",
        "-t", "work",
        "-P", "backend",
        "--image", "/tmp/a.png",
        "--image", "/tmp/b.jpg",
        "--", "shipped v2"
      ]
    }
  );
});
test("buildLogAddCommand rejects empty image log content", () => {
  assert.deepStrictEqual(buildLogAddCommand("mood:happy #work", "/tmp/a.png"), { error: "内容不能为空" });
});
test("editLogImageArgs preserves unchanged image paths", () => {
  assert.deepStrictEqual(editLogImageArgs("/tmp/a.png\n/tmp/b.jpg", " /tmp/a.png, /tmp/b.jpg "), []);
});
test("editLogImageArgs clears images when emptied", () => {
  assert.deepStrictEqual(editLogImageArgs("/tmp/a.png", " "), ["--clear-images"]);
});
test("editLogImageArgs replaces image paths", () => {
  assert.deepStrictEqual(
    editLogImageArgs("/tmp/a.png", "/tmp/b.jpg\n/tmp/c.webp"),
    ["--image", "/tmp/b.jpg", "--image", "/tmp/c.webp"]
  );
});

// ── fetch result handling ──
test("firstLine trims and takes stderr first line", () => {
  assert.strictEqual(firstLine("  boom\nmore detail\n"), "boom");
  assert.strictEqual(firstLine(""), "");
  assert.strictEqual(firstLine(null), "");
});
test("parseListJson requires JSON array", () => {
  assert.deepStrictEqual(parseListJson('[{"id":"1"}]'), [{id: "1"}]);
  assert.throws(() => parseListJson('{"id":"1"}'), /expected JSON array/);
});
test("listFetchResult success JSON", () => {
  assert.deepStrictEqual(listFetchResult("todo", 0, '[{"id":"1"}]', ""), {
    ok: true,
    items: [{id: "1"}],
    error: ""
  });
});
test("listFetchResult empty stdout", () => {
  assert.deepStrictEqual(listFetchResult("idea", 0, "", ""), {
    ok: true,
    items: [],
    error: "灵感数据为空，请确认 Starcatch 可用"
  });
});
test("listFetchResult invalid JSON preserves caller data", () => {
  const result = listFetchResult("log", 0, "not json", "");
  assert.strictEqual(result.ok, false);
  assert.strictEqual(result.items, null);
  assert.match(result.error, /^日志解析失败：/);
});
test("listFetchResult non-zero exit prefers stderr", () => {
  assert.deepStrictEqual(listFetchResult("todo", 2, "", "db locked\ntrace"), {
    ok: false,
    items: null,
    error: "待办获取失败：db locked"
  });
});
test("listFetchResult non-zero exit falls back to exit code", () => {
  assert.deepStrictEqual(listFetchResult("log", 127, "", ""), {
    ok: false,
    items: null,
    error: "日志获取失败（退出码 127）"
  });
});

// ── reload queue handling ──
test("normalizeReloadType defaults to all", () => {
  assert.strictEqual(normalizeReloadType("todo"), "todo");
  assert.strictEqual(normalizeReloadType("idea"), "idea");
  assert.strictEqual(normalizeReloadType("log"), "log");
  assert.strictEqual(normalizeReloadType(undefined), "all");
  assert.strictEqual(normalizeReloadType("bad"), "all");
});
test("mergeQueuedReload keeps same single type", () => {
  assert.strictEqual(mergeQueuedReload("", "todo"), "todo");
  assert.strictEqual(mergeQueuedReload("todo", "todo"), "todo");
});
test("mergeQueuedReload promotes different singles to all", () => {
  assert.strictEqual(mergeQueuedReload("todo", "idea"), "all");
  assert.strictEqual(mergeQueuedReload("idea", "log"), "all");
});
test("mergeQueuedReload keeps all priority", () => {
  assert.strictEqual(mergeQueuedReload("all", "todo"), "all");
  assert.strictEqual(mergeQueuedReload("todo", undefined), "all");
});
test("retryReloadType retries the timed-out request scope", () => {
  assert.strictEqual(retryReloadType("timed out", "all", "todo"), "all");
  assert.strictEqual(retryReloadType("timed out", "log", "todo"), "log");
});
test("retryReloadType uses the active tab for a normal error", () => {
  assert.strictEqual(retryReloadType("", "all", "idea"), "idea");
});

// ── command delete confirmation ──
test("deleteCommandDecision rejects a missing current item", () => {
  assert.deepStrictEqual(deleteCommandDecision("", "", "todo", ""), {
    action: "reject", type: "", id: ""
  });
});
test("deleteCommandDecision arms the first concrete target", () => {
  assert.deepStrictEqual(deleteCommandDecision("", "", "todo", 42), {
    action: "arm", type: "todo", id: "42"
  });
});
test("deleteCommandDecision only deletes the already armed target", () => {
  assert.deepStrictEqual(deleteCommandDecision("todo", "42", "todo", 42), {
    action: "delete", type: "todo", id: "42"
  });
  assert.deepStrictEqual(deleteCommandDecision("todo", "42", "todo", 43), {
    action: "arm", type: "todo", id: "43"
  });
  assert.deepStrictEqual(deleteCommandDecision("todo", "42", "idea", 42), {
    action: "arm", type: "idea", id: "42"
  });
});

// ── popup completion decisions ──
test("completionDecision success closes and reloads", () => {
  assert.deepStrictEqual(completionDecision(0, "todo"), {
    close: true,
    reloadType: "todo"
  });
});
test("completionDecision failure keeps popup open", () => {
  assert.deepStrictEqual(completionDecision(1, "todo"), {
    close: false,
    reloadType: ""
  });
});

// ── pipe completion decisions ──
test("pipeCompletionDecision success clears input and reloads", () => {
  assert.deepStrictEqual(pipeCompletionDecision(0, "idea", "new idea"), {
    restoreText: "",
    reloadType: "idea",
    clearPending: true
  });
});
test("pipeCompletionDecision failure restores input and skips reload", () => {
  assert.deepStrictEqual(pipeCompletionDecision(1, "todo", "buy tea"), {
    restoreText: "buy tea",
    reloadType: "",
    clearPending: true
  });
});

// ── delete completion decisions ──
test("deleteCompletionDecision success reloads and calls success callback", () => {
  assert.deepStrictEqual(deleteCompletionDecision(0, "log", true), {
    callSuccess: true,
    reloadType: "log"
  });
});
test("deleteCompletionDecision failure keeps context", () => {
  assert.deepStrictEqual(deleteCompletionDecision(2, "log", true), {
    callSuccess: false,
    reloadType: ""
  });
});

// ── edit load handling ──
test("editLoadResult success JSON object", () => {
  assert.deepStrictEqual(editLoadResult(0, '{"id":"1","title":"A"}', ""), {
    ok: true,
    data: {id: "1", title: "A"},
    error: ""
  });
});
test("editLoadResult empty stdout", () => {
  assert.deepStrictEqual(editLoadResult(0, "", ""), {
    ok: false,
    data: null,
    error: "加载失败：未取到数据"
  });
});
test("editLoadResult invalid JSON", () => {
  const result = editLoadResult(0, "not json", "");
  assert.strictEqual(result.ok, false);
  assert.strictEqual(result.data, null);
  assert.match(result.error, /^解析失败：/);
});
test("editLoadResult non-zero exit prefers stderr", () => {
  assert.deepStrictEqual(editLoadResult(1, "", "not found\ntrace"), {
    ok: false,
    data: null,
    error: "加载失败：not found"
  });
});
test("editLoadResult non-zero exit falls back to exit code", () => {
  assert.deepStrictEqual(editLoadResult(127, "", ""), {
    ok: false,
    data: null,
    error: "加载失败（退出码 127）"
  });
});

// ── vim/emacs UX actions ──
test("commandAction maps current item commands", () => {
  assert.strictEqual(commandAction(":open", "idea"), "openCurrent");
  assert.strictEqual(commandAction(":e", "log"), "editCurrent");
  assert.strictEqual(commandAction(":edit", "log"), "editCurrent");
  assert.strictEqual(commandAction(":d", "idea"), "deleteCurrent");
  assert.strictEqual(commandAction(":delete", "idea"), "deleteCurrent");
});
test("commandAction gates todo-only commands", () => {
  assert.strictEqual(commandAction(":done", "todo"), "done");
  assert.strictEqual(commandAction(":archive", "todo"), "archive");
  assert.strictEqual(commandAction(":reopen", "todo"), "reopen");
  assert.strictEqual(commandAction(":done", "idea"), "todoOnly");
});
test("normalModeAction maps vim paging and tabs", () => {
  assert.strictEqual(normalModeAction("h"), "prevTab");
  assert.strictEqual(normalModeAction("l"), "nextTab");
  assert.strictEqual(normalModeAction("D", {ctrl: true}), "halfPageDown");
  assert.strictEqual(normalModeAction("U", {ctrl: true}), "halfPageUp");
  assert.strictEqual(normalModeAction("F", {ctrl: true}), "pageDown");
  assert.strictEqual(normalModeAction("B", {ctrl: true}), "pageUp");
  assert.strictEqual(normalModeAction("r"), "reloadCurrent");
  assert.strictEqual(normalModeAction("R"), "reloadAll");
});
test("todoShortcutAction maps completion toggle", () => {
  assert.strictEqual(todoShortcutAction("Space", "Pending"), "done");
  assert.strictEqual(todoShortcutAction("Space", "Done"), "reopen");
  assert.strictEqual(todoShortcutAction("Space", "Archived"), "reopen");
});
test("todoShortcutAction maps archive shortcut", () => {
  assert.strictEqual(todoShortcutAction("a", "Pending"), "archive");
  assert.strictEqual(todoShortcutAction("a", "Done"), "archive");
  assert.strictEqual(todoShortcutAction("a", "Archived"), "alreadyArchived");
});
test("emacsEditResult moves cursor", () => {
  assert.deepStrictEqual(emacsEditResult("abc", 1, "A"), { text: "abc", cursor: 0 });
  assert.deepStrictEqual(emacsEditResult("abc", 1, "E"), { text: "abc", cursor: 3 });
  assert.deepStrictEqual(emacsEditResult("abc", 1, "B"), { text: "abc", cursor: 0 });
  assert.deepStrictEqual(emacsEditResult("abc", 1, "F"), { text: "abc", cursor: 2 });
});
test("emacsEditResult kills text", () => {
  assert.deepStrictEqual(emacsEditResult("abc", 1, "K"), { text: "a", cursor: 1 });
  assert.deepStrictEqual(emacsEditResult("ab\ncd", 1, "K"), { text: "a\ncd", cursor: 1 });
  assert.deepStrictEqual(emacsEditResult("abc", 2, "U"), { text: "", cursor: 0 });
});

test("normalizeLogFilterDays accepts supported presets", () => {
  assert.strictEqual(normalizeLogFilterDays(0), 0);
  assert.strictEqual(normalizeLogFilterDays(1), 1);
  assert.strictEqual(normalizeLogFilterDays(3), 3);
  assert.strictEqual(normalizeLogFilterDays("7"), 7);
  assert.strictEqual(normalizeLogFilterDays(30), 30);
});
test("normalizeLogFilterDays falls back to three days", () => {
  assert.strictEqual(normalizeLogFilterDays(14), 3);
  assert.strictEqual(normalizeLogFilterDays(undefined), 3);
});
test("logListCommand uses the normalized time range", () => {
  assert.deepStrictEqual(logListCommand(7), ["starcatch", "--json", "log", "list", "-d", "7"]);
  assert.deepStrictEqual(logListCommand(99), ["starcatch", "--json", "log", "list", "-d", "3"]);
});
test("logListCommand uses --all for the all range", () => {
  assert.deepStrictEqual(logListCommand(0), ["starcatch", "--json", "log", "list", "--all"]);
});

test("inlineImageSummary limits thumbnails and reports overflow", () => {
  assert.deepStrictEqual(inlineImageSummary(["a", "b", "c", "d", "e"], 3), {
    visible: ["a", "b", "c"],
    hiddenCount: 2
  });
  assert.deepStrictEqual(inlineImageSummary(null, 3), { visible: [], hiddenCount: 0 });
});
test("pageRowCount accounts for thumbnail-expanded rows", () => {
  assert.strictEqual(pageRowCount(600, 60, 1), 10);
  assert.strictEqual(pageRowCount(600, 120, 1), 5);
  assert.strictEqual(pageRowCount(600, 120, 0.5), 2);
});
test("moveIndex clamps navigation to list bounds", () => {
  assert.strictEqual(moveIndex(0, -1, 3), 0);
  assert.strictEqual(moveIndex(1, 1, 3), 2);
  assert.strictEqual(moveIndex(2, 4, 3), 2);
  assert.strictEqual(moveIndex(0, 1, 0), 0);
});
test("restoreIndex prefers item id and clamps fallback index", () => {
  const items = [{id: "a"}, {id: "b"}, {id: "c"}];
  assert.strictEqual(restoreIndex(items, "b", 0), 1);
  assert.strictEqual(restoreIndex(items, "gone", 99), 2);
  assert.strictEqual(restoreIndex(items, "gone", -1), 0);
  assert.strictEqual(restoreIndex([], "gone", 4), 0);
});
test("restoreIndex matches numeric and string ids", () => {
  const items = [{id: 101}, {id: 202}, {id: 303}];
  assert.strictEqual(restoreIndex(items, "202", 0), 1);
  assert.strictEqual(restoreIndex([{id: "202"}], 202, 0), 0);
});
test("restoreIndex accepts QML-style array-like models", () => {
  const model = {0: {id: "a"}, 1: {id: "b"}, 2: {id: "c"}, length: 3};
  assert.strictEqual(restoreIndex(model, "b", 0), 1);
  assert.strictEqual(restoreIndex(model, "gone", 2), 2);
});
test("restoreIndex keeps the deleted row and clamps to the new last row", () => {
  const itemsAfterMiddleDelete = [{id: "a"}, {id: "c"}, {id: "d"}];
  const itemsAfterLastDelete = [{id: "a"}, {id: "b"}];
  assert.strictEqual(restoreIndex(itemsAfterMiddleDelete, "deleted", 1), 1);
  assert.strictEqual(restoreIndex(itemsAfterLastDelete, "deleted", 2), 1);
  assert.strictEqual(restoreIndex([], "deleted", 2), 0);
});

// ── All done ──
console.log(`✓ All ${passed} tests passed`);
