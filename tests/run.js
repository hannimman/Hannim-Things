// Runs the Lua unit tests with fengari (Lua 5.3 in JS) and syntax-checks driver sources.
// Usage: cd tests && npm install && npm test
const path = require("path");
const fs = require("fs");
const luaparse = require("luaparse");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const root = path.resolve(__dirname, "..");
const tests = [
  ["aoyan-motion/src", "aoyan_reconfigure_test.lua"],
  ["aoyan-motion/src", "aoyan_motion_test.lua"],
  ["neo-motion/src", "neo_phantom_filter_test.lua"],
  ["neo-motion/src", "neo_held_phantom_test.lua"],
];

let failed = false;
for (const [srcDir, file] of tests) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  lua.lua_pushstring(L, to_luastring(path.join(root, srcDir).split(path.sep).join("/")));
  lua.lua_setglobal(L, to_luastring("arg_dir"));
  if (lauxlib.luaL_dofile(L, to_luastring(path.join(__dirname, file))) !== 0) {
    console.log("FAIL", file, lua.lua_tojsstring(L, -1));
    failed = true;
  }
}

const sources = [
  "aoyan-motion/src/init.lua",
  "aoyan-motion/src/aoyan_reconfigure.lua",
  "aoyan-motion/src/motion_timeout/init.lua",
  "aoyan-motion/src/motion_timeout/fingerprints.lua",
  "neo-motion/src/init.lua",
  "neo-motion/src/phantom_filter.lua",
  "neo-motion/src/sensor_handlers/attribute_handlers.lua",
];
for (const f of sources) {
  try {
    luaparse.parse(fs.readFileSync(path.join(root, f), "utf8"), { luaVersion: "5.3" });
  } catch (e) {
    console.log("SYNTAX FAIL", f, e.message);
    failed = true;
  }
}
console.log(failed ? "FAILED" : "all tests passed");
process.exit(failed ? 1 : 0);
