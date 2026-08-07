const assert = require("assert");
const router = require("../src/CommandRouter.js");

let passed = 0;
function test(description, fn) {
  try {
    fn();
    passed++;
  } catch (error) {
    console.error("FAIL:", description);
    throw error;
  }
}

test("command catalog keeps aliases and descriptions", () => {
  const commands = router.allCommands();
  assert.strictEqual(commands.length, 19);
  assert.deepStrictEqual(commands[0], { cmd: ":q", desc: "关闭面板" });
  assert.strictEqual(commands.filter(item => item.cmd === ":edit").length, 1);
});

test("command name ignores arguments and normalizes case", () => {
  assert.strictEqual(router.commandName(":RELOAD now"), ":reload");
  assert.strictEqual(router.commandName("  :edit 42"), ":edit");
  assert.strictEqual(router.commandName(""), "");
});

test("command filtering preserves fuzzy matching", () => {
  const commands = router.allCommands();
  assert.deepStrictEqual(
    router.filterCommands(":a", commands).map(item => item.cmd),
    [":reload", ":idea", ":yank", ":archive"]
  );
  assert.deepStrictEqual(
    router.filterCommands(":e", commands).map(item => item.cmd),
    [":reload", ":idea", ":open", ":e", ":edit", ":delete", ":done", ":archive", ":reopen", ":help"]
  );
  assert.strictEqual(router.filterCommands(":", commands).length, commands.length);
});

test("aliases resolve to the same action", () => {
  assert.deepStrictEqual(router.resolve(":reload later"), { type: "reload" });
  assert.deepStrictEqual(router.resolve(":edit"), { type: "edit" });
  assert.deepStrictEqual(router.resolve(":copy"), { type: "copy" });
  assert.deepStrictEqual(router.resolve(":done"), { type: "todoAction", action: "done" });
});

test("unknown commands retain their normalized name", () => {
  assert.deepStrictEqual(router.resolve(":wat arg"), { type: "unknown", name: ":wat" });
  assert.deepStrictEqual(router.resolve(""), { type: "unknown", name: "" });
});

console.log(`✓ All ${passed} command router tests passed`);
