#!/usr/bin/env lua
-- Test cases for Lua Stream API
local thisfile = debug.getinfo(1, "S").source:sub(2)
local thisdir = thisfile:match("(.*)/") or "."
local rootdir = thisdir .. "/.." -- HACK: This file must be at the root of the tests/ directory
package.path = table.concat({ rootdir .. "/?.lua", rootdir .. "/?/init.lua" }, ";")

---@param args string[]
---@return string[] opts, string[] suites
local function parse_args(args)
  ---@type string[], string[]
  local suites, opts = {}, {}
  local found_terminator = false
  for _, arg in ipairs(args) do
    if found_terminator or not arg:find("^%-") then
      suites[#suites + 1] = arg -- this arg is a suite name
    elseif arg == "--" then
      found_terminator = true
    else -- any options can be passed to the test runner
      opts[#opts + 1] = arg
    end
  end
  return opts, suites
end

local suites
arg, suites = parse_args(arg)

local ALL_SUITES = { "instance", "static" }

-- run all suites if no suites were specified
suites = #suites == 0 and ALL_SUITES or suites

local instances = {}
for _, test in ipairs(suites) do
  -- attach test modules (which export k/v tables of test fns) as alists
  local ok, suite = pcall(require, "test." .. test)
  if not ok then
    io.stderr:write("Suite '" .. test .. "' not found\n")
    os.exit(1)
  end
  for name, testfn in pairs(suite) do
    table.insert(instances, { name, testfn })
  end
end

local runner = require("test.luaunit").LuaUnit:new() ---@type LuaUnit
runner:setOutputType("TEXT")
runner:runSuiteByInstances(instances)
os.exit(runner.result.notSuccessCount == 0 and 0 or 1)
