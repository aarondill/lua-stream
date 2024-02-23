#!/usr/bin/env lua
-- Test cases for Lua Stream API
local thisfile = debug.getinfo(1, "S").source:sub(2)
local thisdir = thisfile:match("(.*)/") or "."
local rootdir = thisdir .. "/.." -- HACK: This file must be at the root of the tests/ directory
package.path = table.concat({ package.path, rootdir .. "/?.lua", rootdir .. "/?/init.lua" }, ";")

local Stream = require("stream")
local function check(cond, format, ...)
  local message = string.format("Test Failed! " .. format, ...)
  assert(cond, message)
end

local function assert_equals(actual, expected)
  if type(expected) ~= "table" then return check(actual == expected, "actual=%s, expected=%s", actual, expected) end
  check(#actual == #expected, "#actual=%s, #expected=%s", #actual, #expected)
  for i, act in pairs(actual) do
    local exp = expected[i]
    check(act == exp, "actual[%s]=%s, expected[%s]=%s", i, act, i, exp)
  end
end

do
  print("Testing toarray")
  local aexp = { 1, 2, 3, 4, 5 }
  local aact = Stream.new({ 1, 2, 3, 4, 5 }):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing __call metamethod")
  local aexp = Stream.new({ 1, 2, 3, 4 }):toarray()
  local aact = Stream({ 1, 2, 3, 4 }):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing iter")
  local exp = 0
  for act in Stream.new({ 1, 2, 3, 4, 5 }).iter do
    exp = exp + 1
    assert_equals(act, exp)
  end
end

do
  print("Testing foreach")
  local aexp = { 1, 2, 3, 4, 5 }
  local aact = {}
  local function consume(x)
    aact[#aact + 1] = x
  end
  Stream.new({ 1, 2, 3, 4, 5 }):foreach(consume)
  assert_equals(aact, aexp)
end

do
  print("Testing filter")
  local function isEven(x)
    return x % 2 == 0
  end
  local aexp = { 2, 4, 6, 8 }
  local aact = Stream.new({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):filter(isEven):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing reverse")
  local aexp = { 5, 4, 3, 2, 1 }
  local aact = Stream.new({ 1, 2, 3, 4, 5 }):reverse():toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing sort")
  local aexp = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
  local aact = Stream.new({ 5, 7, 6, 3, 4, 1, 2, 8, 9 }):sort():toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing map")
  local function square(x)
    return x * x
  end
  local aexp = { 1, 4, 9, 16, 25 }
  local aact = Stream.new({ 1, 2, 3, 4, 5 }):map(square):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing next")
  local aexp = { 1, 2, 3 }
  local aact = {}
  local s = Stream.new({ 1, 2, 3 })
  for _ = 1, #aexp do
    aact[#aact + 1] = s:next()
  end
  assert_equals(aact, aexp)
end

do
  print("Testing last")
  local act = Stream.new({ 2, 2, 2, 2, 1 }):last()
  local exp = 1
  assert_equals(act, exp)
end

do
  print("Testing count")
  local act = Stream.new({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):count()
  local exp = 9
  assert_equals(act, exp)
end

do
  print("Testing max")
  local act = Stream.new({ 5, 7, 6, 3, 4, 1, 2, 8, 9 }):max()
  local exp = 9
  assert_equals(act, exp)
end

do
  print("Testing statistics")
  local act = Stream.new({ 5, 7, 6, 3, 4, 1, 2, 8, 9 }):statistics()
  local exp = { count = 9, sum = 45, min = 1, max = 9 }
  assert_equals(act, exp)
end

do
  print("Testing min")
  local act = Stream.new({ 5, 7, 6, 3, 4, 1, 2, 8, 9 }):min()
  local exp = 1
  assert_equals(act, exp)
end

do
  print("Testing sum")
  local act = Stream.new({ 1, 2, 3, 4, 5 }):sum()
  local exp = 15
  assert_equals(act, exp)
end

do
  print("Testing avg")
  local act = Stream.new({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):avg()
  local exp = 5
  assert_equals(act, exp)
end

do
  print("Testing collect")
  local aexp = { 1, 2, 3, 4, 5 }
  local aact = {}
  local function read(iter)
    for x in iter do
      aact[#aact + 1] = x
    end
  end
  Stream.new({ 1, 2, 3, 4, 5 }):collect(read)
  assert_equals(aact, aexp)
end

do
  print("Testing limit")
  local aexp = { 1, 2, 3 }
  local aact = Stream.new({ 1, 2, 3, 4, 5 }):limit(3):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing skip")
  local aexp = { 4, 5 }
  local aact = Stream.new({ 1, 2, 3, 4, 5 }):skip(3):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing reverse")
  local aexp = { 5, 4, 3, 2, 1 }
  local aact = Stream.new({ 1, 2, 3, 4, 5 }):reverse():toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing distinct")
  local aexp = { 1, 2, 4, 5, 3 }
  local aact = Stream.new({ 1, 2, 4, 2, 4, 2, 5, 3, 5, 1 }):distinct():toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing peek")
  local aexp = { 1, 2, 3, 4, 5 }
  local aact = {}
  local function consume(x)
    aact[#aact + 1] = x
  end
  Stream.new({ 1, 2, 3, 4, 5 }):peek(consume):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing allmatch true")
  local function is_odd(x)
    return x % 2 == 0
  end
  local act = Stream.new({ 2, 4, 6, 8, 10 }):allmatch(is_odd)
  local exp = true
  assert_equals(act, exp)
end

do
  print("Testing allmatch false")
  local function is_odd(x)
    return x % 2 == 0
  end
  local act = Stream.new({ 2, 4, 6, 8, 11 }):allmatch(is_odd)
  local exp = false
  assert_equals(act, exp)
end

do
  print("Testing anymatch true")
  local function is_odd(x)
    return x % 2 == 0
  end
  local act = Stream.new({ 1, 2, 3 }):anymatch(is_odd)
  local exp = true
  assert_equals(act, exp)
end

do
  print("Testing anymatch false")
  local function is_odd(x)
    return x % 2 == 0
  end
  local act = Stream.new({ 1, 3, 5, 7 }):anymatch(is_odd)
  local exp = false
  assert_equals(act, exp)
end

do
  print("Testing nonematch true")
  local function is_odd(x)
    return x % 2 == 0
  end
  local act = Stream.new({ 1, 3, 5, 7 }):nonematch(is_odd)
  local exp = true
  assert_equals(act, exp)
end

do
  print("Testing nonematch false")
  local function is_odd(x)
    return x % 2 == 0
  end
  local act = Stream.new({ 1, 2, 3 }):nonematch(is_odd)
  local exp = false
  assert_equals(act, exp)
end

do
  print("Testing flatmap")
  local function duplicate(x)
    return { x, x }
  end
  local aexp = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5 }
  local aact = Stream.new({ 1, 2, 3, 4, 5 }):flatmap(duplicate):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing flatten")
  local aexp = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
  local aact = Stream.new({ { 1, 2 }, { 3, 4, 5, 6 }, { 7 }, {}, { 8, 9 } }):flatten():toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing concat 1")
  local aexp = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
  local aact = Stream.new({ 1, 2, 3, 4 }):concat(Stream.new({ 5, 6, 7, 8, 9 })):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing concat 2")
  local aexp = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
  local aact = Stream.new({ 1, 2, 3, 4 }):concat(Stream.new({ 5, 6 }), Stream.new({ 7, 8, 9 })):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing merge 1")
  local aexp = { 1, 5, 2, 6, 3, 7, 4, 8, 9 }
  local aact = Stream.new({ 1, 2, 3, 4 }):merge(Stream.new({ 5, 6, 7, 8, 9 })):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing merge 2")
  local aexp = { 1, 5, 7, 2, 6, 8, 3, 9, 4 }
  local aact = Stream.new({ 1, 2, 3, 4 }):merge(Stream.new({ 5, 6 }), Stream.new({ 7, 8, 9 })):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing group")
  local function is_odd(x)
    return x % 2 == 0
  end
  local aexp1 = { 2, 4 }
  local aexp2 = { 1, 3 }
  local mact = Stream.new({ 1, 2, 3, 4 }):group(is_odd)
  do
    local aact = mact[true]
    local aexp = aexp1
    assert_equals(aact, aexp)
  end
  do
    local aact = mact[false]
    local aexp = aexp2
    assert_equals(aact, aexp)
  end
end

do
  print("Testing split")
  local function is_odd(x)
    return x % 2 == 0
  end
  local aexp1 = { 2, 4 }
  local aexp2 = { 1, 3 }
  local s1, s2 = Stream.new({ 1, 2, 3, 4 }):split(is_odd)

  do
    local aexp = aexp1
    local aact = s1:toarray()
    assert_equals(aact, aexp)
  end
  do
    local aexp = aexp2
    local aact = s2:toarray()
    assert_equals(aact, aexp)
  end
end

do
  print("Testing reduce")
  local function add(a, b)
    return a + b
  end
  local act = Stream.new({ 1, 2, 3, 4, 5 }):reduce(0, add)
  local exp = 15
  assert_equals(act, exp)
end

do
  print("Testing pack")
  local aexp = { { 1, 2 }, { 3, 4 }, { 5, 6 }, { 7, 8 }, { 9 } }
  local aact = Stream.new({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):pack(2):toarray()

  check(#aact == #aexp, "#aact=%s, #aexp=%s", #aact, #aexp)
  for i = 1, #aact do -- Note: can't use assert_equals here because it's not recursive
    local exp = aexp[i]
    local act = aact[i]
    assert_equals(act, exp)
  end
end

do
  print("Testing Stream.range 1")
  local aexp = { 1, 2, 3, 4, 5, 6 }
  local aact = Stream.range(1, 7):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing Stream.range 2")
  local aexp = { 6, 5, 4, 3, 2, 1 }
  local aact = Stream.range(6, 0):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing Stream.range 3")
  local aexp = {}
  local aact = Stream.range(1, 1):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing Stream.rangeclosed 1")
  local aexp = { 1, 2, 3, 4, 5, 6, 7 }
  local aact = Stream.rangeclosed(1, 7):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing Stream.rangeclosed 2")
  local aexp = { 7, 6, 5, 4, 3, 2, 1 }
  local aact = Stream.rangeclosed(7, 1):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing Stream.rangeclosed 3")
  local aexp = { 1 }
  local aact = Stream.rangeclosed(1, 1):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing Stream.empty 1")
  local aexp = {}
  local aact = Stream.empty():toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing Stream.empty 2")
  local exp = nil
  local act = Stream.empty():next()
  assert_equals(act, exp)
end

do
  print("Testing Stream.of")
  local aexp = { 1, 2, 3, 4, 5, 6, 7 }
  local aact = Stream.of(1, 2, 3, 4, 5, 6, 7):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing Stream.iterate 1")
  local incr = function(x)
    return x + 1
  end
  local aexp = { 1, 2, 3, 4, 5, 6, 7 }
  local aact = Stream.iterate(0, incr):limit(#aexp):toarray()
  assert_equals(aact, aexp)
end

do
  print("Testing Stream.iterate 2")
  local aexp = { 1, 2, 3, 4, 5, 6, 7 }
  local incr = function(x)
    if x >= #aexp then return nil end
    return x + 1
  end
  local aact = Stream.iterate(0, incr):toarray()
  assert_equals(aact, aexp)
end
