local Test = {}

local Stream = require("stream")
local assert_equals = require("test.luaunit").assertEquals

-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---------------------------------STATIC METHODS---------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function Test:test_range_1()
  local aexp = { 1, 2, 3, 4, 5, 6, n = 6 }
  local aact = Stream.range(1, 7):toarray()
  assert_equals(aact, aexp)
end

function Test:test_range_2()
  local aexp = { 6, 5, 4, 3, 2, 1, n = 6 }
  local aact = Stream.range(6, 0):toarray()
  assert_equals(aact, aexp)
end

function Test:test_range_3()
  local aexp = { n = 0 }
  local aact = Stream.range(1, 1):toarray()
  assert_equals(aact, aexp)
end

function Test:test_rangeclosed_1()
  local aexp = { 1, 2, 3, 4, 5, 6, 7, n = 7 }
  local aact = Stream.rangeclosed(1, 7):toarray()
  assert_equals(aact, aexp)
end

function Test:test_rangeclosed_2()
  local aexp = { 7, 6, 5, 4, 3, 2, 1, n = 7 }
  local aact = Stream.rangeclosed(7, 1):toarray()
  assert_equals(aact, aexp)
end

function Test:test_rangeclosed_3()
  local aexp = { 1, n = 1 }
  local aact = Stream.rangeclosed(1, 1):toarray()
  assert_equals(aact, aexp)
end

function Test:test_empty_1()
  local aexp = { n = 0 }
  local aact = Stream.empty():toarray()
  assert_equals(aact, aexp)
end

function Test:test_empty_2()
  local exp, exp2 = nil, true
  local act, act2 = Stream.empty():next()
  assert_equals(act, exp)
  assert_equals(act2, exp2)
end

function Test:test_of()
  local aexp = { 1, 2, 3, 4, 5, 6, 7, n = 7 }
  local aact = Stream.of(1, 2, 3, 4, 5, 6, 7):toarray()
  assert_equals(aact, aexp)
end

function Test:test_of_2()
  local aexp = { 1, 2, 3, 4, nil, 6, 7, n = 7 }
  local aact = Stream.of(1, 2, 3, 4, nil, 6, 7):toarray()
  assert_equals(aact, aexp)
end

function Test:test_iterate_1()
  local incr = function(x) return x + 1, false end
  local aexp = { 1, 2, 3, 4, 5, 6, 7, n = 7 }
  local aact = Stream.iterate(0, incr):limit(#aexp):toarray()
  assert_equals(aact, aexp)
end

function Test:test_iterate_2()
  local aexp = { 1, 2, 3, 4, 5, 6, 7, n = 7 }
  local incr = function(x)
    if x >= aexp.n then return nil, true end
    return x + 1, false
  end
  local aact = Stream.iterate(0, incr):toarray()
  assert_equals(aact, aexp)
end

function Test:test_nonnil_1()
  local x = 0
  local incr = function()
    x = x + 1
    return x < 10 and x or nil
  end
  local aexp = { 1, 2, 3, 4, 5, 6, 7, 8, 9, n = 9 }
  local aact = Stream.nonnil(incr):toarray()
  assert_equals(aact, aexp)
end

function Test:test_nonnil_2()
  local aexp = { 1, 2, 3, 4, 5, 6, 7, n = 7 }
  local aact = Stream.nonnil({ 1, 2, 3, 4, 5, 6, 7, nil, 8, 9, 10, n = 11 }):toarray()
  assert_equals(aact, aexp)
end

function Test:test_nonnil_3()
  local aexp = { 1, 2, 3, n = 3 }
  local aact = Stream.nonnil(Stream.new({ 1, 2, 3, nil, 4, 5, 6, 7, n = 8 })):toarray()
  assert_equals(aact, aexp)
end

function Test:test_concat_1()
  local aexp = { 1, 2, 3, 4, 5, 6, 7, 8, 9, n = 9 }
  local aact = Stream.concat(Stream.new({ 1, 2, 3, 4 }), (Stream.new({ 5, 6, 7, 8, 9 }))):toarray()
  assert_equals(aact, aexp)
end

function Test:test_concat_2()
  local aexp = { 1, 2, 3, 4, 5, 6, 7, 8, 9, n = 9 }
  local aact = Stream.concat(Stream.new({ 1, 2, 3, 4 }), Stream.new({ 5, 6 }), Stream.new({ 7, 8, 9 })):toarray()
  assert_equals(aact, aexp)
end

return Test
