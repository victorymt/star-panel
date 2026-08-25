const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");
const commands = require("../src/StarcatchCommands.js");

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

test("list commands use the configured executable", () => {
  const executable = "/opt/Starcatch Builds/starcatch";
  assert.deepStrictEqual(commands.listCommand(executable, "todo"), [
    executable, "--json", "todo", "list", "--all"
  ]);
  assert.deepStrictEqual(commands.listCommand(executable, "idea", 7), [
    executable, "--json", "idea", "list", "-d", "7"
  ]);
  assert.deepStrictEqual(commands.listCommand(executable, "log", 30), [
    executable, "--json", "log", "list", "-d", "30"
  ]);
  assert.deepStrictEqual(commands.listCommand(executable, "log", 0), [
    executable, "--json", "log", "list", "--all"
  ]);
});

test("empty executable falls back to starcatch", () => {
  assert.strictEqual(commands.showCommand("", "idea", 42)[0], "starcatch");
});

test("show, delete, and todo action commands preserve ids", () => {
  assert.deepStrictEqual(commands.showCommand("sc", "log", "id with spaces"), [
    "sc", "--json", "log", "show", "id with spaces"
  ]);
  assert.deepStrictEqual(commands.deleteCommand("sc", "idea", "17"), [
    "sc", "idea", "delete", "17"
  ]);
  assert.deepStrictEqual(commands.todoActionCommand("sc", "archive", "9"), [
    "sc", "todo", "archive", "9"
  ]);
});

test("unsupported entry types and todo actions are rejected", () => {
  assert.throws(() => commands.listCommand("sc", "note"), /unsupported Starcatch entry type/);
  assert.throws(() => commands.todoActionCommand("sc", "remove", "1"), /unsupported Starcatch todo action/);
});

test("edit commands preserve explicit empty fields", () => {
  assert.deepStrictEqual(commands.todoEditCommand("sc", "1", {
    title: "Title",
    description: "",
    priority: "P1",
    due: "",
    tags: "",
    project: ""
  }), [
    "sc", "todo", "edit", "1",
    "--title", "Title", "--desc", "", "-p", "P1",
    "--due", "", "-t", "", "-P", ""
  ]);
});

test("log edit appends image changes after editable fields", () => {
  assert.deepStrictEqual(commands.logEditCommand("sc", "3", {
    content: "updated",
    mood: "calm",
    tags: "daily",
    project: "journal"
  }, ["--image", "/tmp/a b.png", "--image", "/tmp/c.png"]), [
    "sc", "log", "edit", "3",
    "-c", "updated", "-m", "calm", "-t", "daily", "-P", "journal",
    "--image", "/tmp/a b.png", "--image", "/tmp/c.png"
  ]);
});

test("log add terminates options before leading-hyphen content", () => {
  assert.deepStrictEqual(commands.logAddCommand(
    "sc", "- first\n- second", "happy", ["work", "daily"], "notes", ["/tmp/a.png"]
  ), [
    "sc", "log", "add", "-m", "happy", "-t", "work,daily", "-P", "notes",
    "--image", "/tmp/a.png", "--", "- first\n- second"
  ]);
});

test("pipe helper forwards literal text without evaluating shell syntax", () => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "star-panel-command-test-"));
  try {
    const fakeCli = path.join(tempRoot, "fake starcatch");
    const argsFile = path.join(tempRoot, "args");
    const stdinFile = path.join(tempRoot, "stdin");
    const markerFile = path.join(tempRoot, "must-not-exist");
    fs.writeFileSync(fakeCli, [
      "#!/usr/bin/env bash",
      "set -euo pipefail",
      "printf '%s\\0' \"$@\" > \"$FAKE_STARCATCH_ARGS\"",
      "cat > \"$FAKE_STARCATCH_STDIN\""
    ].join("\n") + "\n", { mode: 0o700 });

    const input = "it's literal\n$(touch " + markerFile + ")\n--leading-option";
    const helper = path.resolve(__dirname, "../src/starcatch-pipe.sh");
    const command = commands.pipeCommand(helper, fakeCli, "idea", input);
    const result = spawnSync(command[0], command.slice(1), {
      env: Object.assign({}, process.env, {
        FAKE_STARCATCH_ARGS: argsFile,
        FAKE_STARCATCH_STDIN: stdinFile
      }),
      encoding: "utf8"
    });

    assert.strictEqual(result.status, 0, result.stderr);
    assert.deepStrictEqual(
      fs.readFileSync(argsFile).toString().split("\0").filter(Boolean),
      ["pipe", "idea"]
    );
    assert.strictEqual(fs.readFileSync(stdinFile, "utf8"), input + "\n");
    assert.strictEqual(fs.existsSync(markerFile), false);
  } finally {
    fs.rmSync(tempRoot, { recursive: true, force: true });
  }
});

console.log(`✓ All ${passed} Starcatch command tests passed`);
