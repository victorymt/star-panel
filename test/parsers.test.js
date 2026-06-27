const assert = require("assert");
const { parseJson, formatDate, parseTodos, parseIdeas, parseLogs, shellQuote } = require("./parsers");

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
    { id: "1", status: "Pending", priority: "P0", title: "Urgent", description: "desc1", tags: ["work"], due_date: "2024-07-01" },
    { id: "2", status: "Done", priority: "P2", title: "Done task", tags: [], due_date: "2024-06-20" },
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
  assert.deepStrictEqual(todos[0].tags, ["work"]);
  assert.strictEqual(todos[0].due, "2024-07-01");
  assert.strictEqual(todos[1].priority, "🟢");
  assert.strictEqual(todos[1].status, "✅");
  assert.strictEqual(todos[1].description, "");
  assert.strictEqual(todos[2].priority, "🟢");
  assert.strictEqual(todos[2].status, "📦");
  assert.strictEqual(todos[2].description, "");
  assert.strictEqual(todos[2].due, "-");
  assert.deepStrictEqual(todos[2].tags, []);
});
test("parseTodos empty input", () => {
  assert.deepStrictEqual(parseTodos("[]"), []);
  assert.deepStrictEqual(parseTodos("invalid"), []);
});

// ── parseIdeas ──
test("parseIdeas with source", () => {
  const ideaInput = JSON.stringify([
    { id: "1", title: "Great idea", content: "Details", source: "chat", created_at: "2024-06-27T14:30:00Z", tags: ["tech"] },
    { id: "2", title: "No source", created_at: "2024-06-26T10:00:00Z", tags: [] }
  ]);
  const ideas = parseIdeas(ideaInput);
  assert.strictEqual(ideas.length, 2);
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
    { id: "1", content: "Today was good", mood: "😊", created_at: "2024-06-27T20:00:00Z", tags: ["life"] },
    { id: "2", content: "No mood entry", created_at: "2024-06-26T12:00:00Z" }
  ]);
  const logs = parseLogs(logInput);
  assert.strictEqual(logs.length, 2);
  assert.strictEqual(logs[0].content, "Today was good");
  assert.strictEqual(logs[0].title, "06-27 20:00 · 😊");
  assert.deepStrictEqual(logs[0].tags, ["life"]);
  assert.strictEqual(logs[1].title, "06-26 12:00");
  assert.strictEqual(logs[1].tags.length, 0);
});

// ── shellQuote ──
test("simple string", () => assert.strictEqual(shellQuote("hello"), "'hello'"));
test("single quote escaped", () => assert.strictEqual(shellQuote("it's"), "'it'\\''s'"));
test("empty string", () => assert.strictEqual(shellQuote(""), "''"));
test("multiple single quotes", () => assert.strictEqual(shellQuote("a'b'c"), "'a'\\''b'\\''c'"));

// ── All done ──
console.log(`✓ All ${passed} tests passed`);
