#!/usr/bin/env lua
local Stream = require("stream")
local assert_equals = require("test.luaunit").assertEquals
local pack = table.pack or function(...) return { n = select("#", ...), ... } end

local Test = {}

function Test:test_toarray_1()
  local aexp = { 1, 2, 3, 4, 5, n = 5 }
  local aact = Stream.new({ 1, 2, 3, 4, 5 }):toarray()
  assert_equals(aact, aexp)
end

function Test:test_toarray_2()
  local aexp = { 1, 2, 1, 2, 3, 4, 5, n = 7 }
  local aact = Stream.new({ 1, 2, 3, 4, 5 }):toarray({ 1, 2 })
  assert_equals(aact, aexp)
end

function Test:test__call_metamethod()
  local aexp = Stream.new({ 1, 2, 3, 4 }):toarray()
  local aact = Stream({ 1, 2, 3, 4 }):toarray()
  assert_equals(aact, aexp)
end

function Test:test_iter_1()
  local exp = 0
  for act in Stream.new({ 1, 2, 3, 4, 5 }).iter do
    exp = exp + 1
    assert_equals(act, exp)
  end
end

function Test:test_iter_2()
  local exp = { 1, 2, 3, nil, 4, 5, n = 6 }
  local act = {}
  local n = 0
  local it = Stream.of(1, 2, 3, nil, 4, 5).iter
  local e, done = it()
  while not done do
    n = n + 1
    act[n] = e
    e, done = it()
  end
  act.n = n
  assert_equals(act, exp)
end

function Test:test_foreach()
  local aexp = { 1, 2, 3, 4, 5 }
  local aact = {}
  local function consume(x) aact[#aact + 1] = x end
  Stream.new({ 1, 2, 3, 4, 5 }):foreach(consume)
  assert_equals(aact, aexp)
end

function Test:test_filter()
  local function isEven(x) return x % 2 == 0 end
  local aexp = { 2, 4, 6, 8, n = 4 }
  local aact = Stream.new({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):filter(isEven):toarray()
  assert_equals(aact, aexp)
end

function Test:test_reverse()
  local aexp = { 5, 4, 3, 2, 1, n = 5 }
  local aact = Stream.new({ 1, 2, 3, 4, 5 }):reverse():toarray()
  assert_equals(aact, aexp)
end

function Test:test_sort()
  local aexp = { 1, 2, 3, 4, 5, 6, 7, 8, 9, n = 9 }
  local aact = Stream.new({ 5, 7, 6, 3, 4, 1, 2, 8, 9 }):sort():toarray()
  assert_equals(aact, aexp)
end

function Test:test_map()
  local function square(x) return x * x end
  local aexp = { 1, 4, 9, 16, 25, n = 5 }
  local aact = Stream.new({ 1, 2, 3, 4, 5 }):map(square):toarray()
  assert_equals(aact, aexp)
end

function Test:test_next()
  local aexp = { 1, 2, 3 }
  local aact = {}
  local s = Stream.new({ 1, 2, 3 })
  local e, done = s:next()
  while not done do
    aact[#aact + 1] = e
    e, done = s:next()
  end
  assert_equals(aact, aexp)
end

function Test:test_last_1()
  local act = Stream.new({ 2, 2, 2, 2, 1 }):last()
  local exp = 1
  assert_equals(act, exp)
end

function Test:test_last_2()
  local act = Stream.new({ 2, 2, 2, 2, 1, nil, n = 6 }):last()
  local exp = nil
  assert_equals(act, exp)
end

function Test:test_last_3()
  local act = Stream.new({ 2, 2, 2, 2, 1, nil, 3, n = 7 }):last()
  local exp = 3
  assert_equals(act, exp)
end

function Test:test_count()
  local act = Stream.new({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):count()
  local exp = 9
  assert_equals(act, exp)
end

function Test:test_max_1()
  local act = Stream.new({ 5, 7, 6, 3, 4, 1, 2, 8, 9 }):max()
  local exp = 9
  assert_equals(act, exp)
end

function Test:test_max_2()
  local act = Stream.new({ 5, 7, 6, 3, 4, 1, 2, 8, 9 }):max(function(a, b) return a > b end)
  local exp = 1
  assert_equals(act, exp)
end

function Test:test_statistics()
  local act = Stream.new({ 5, 7, 6, 3, 4, 1, 2, 8, 9 }):statistics()
  local exp = { count = 9, sum = 45, min = 1, max = 9 }
  assert_equals(act, exp)
end

function Test:test_min()
  local act = Stream.new({ 5, 7, 6, 3, 4, 1, 2, 8, 9 }):min()
  local exp = 1
  assert_equals(act, exp)
end

function Test:test_sum()
  local act = Stream.new({ 1, 2, 3, 4, 5 }):sum()
  local exp = 15
  assert_equals(act, exp)
end

function Test:test_avg()
  local act = Stream.new({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):avg()
  local exp = 5
  assert_equals(act, exp)
end

function Test:test_collect()
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

function Test:test_limit()
  local aexp = { 1, 2, 3, n = 3 }
  local aact = Stream.new({ 1, 2, 3, 4, 5 }):limit(3):toarray()
  assert_equals(aact, aexp)
end

function Test:test_skip()
  local aexp = { 4, 5, n = 2 }
  local aact = Stream.new({ 1, 2, 3, 4, 5 }):skip(3):toarray()
  assert_equals(aact, aexp)
end

function Test:test_distinct()
  local aexp = { 1, 2, 4, 5, 3, n = 5 }
  local aact = Stream.new({ 1, 2, 4, 2, 4, 2, 5, 3, 5, 1 }):distinct():toarray()
  assert_equals(aact, aexp)
end

function Test:test_peek()
  local aexp = { 1, 2, 3, 4, 5 }
  local aact = {}
  local function consume(x) aact[#aact + 1] = x end
  Stream.new({ 1, 2, 3, 4, 5 }):peek(consume):count()
  assert_equals(aact, aexp)
end

function Test:test_allmatch_true()
  local function is_odd(x) return x % 2 == 0 end
  local act = Stream.new({ 2, 4, 6, 8, 10 }):allmatch(is_odd)
  local exp = true
  assert_equals(act, exp)
end

function Test:test_allmatch_false()
  local function is_odd(x) return x % 2 == 0 end
  local act = Stream.new({ 2, 4, 6, 8, 11 }):allmatch(is_odd)
  local exp = false
  assert_equals(act, exp)
end

function Test:test_anymatch_true()
  local function is_odd(x) return x % 2 == 0 end
  local act = Stream.new({ 1, 2, 3 }):anymatch(is_odd)
  local exp = true
  assert_equals(act, exp)
end

function Test:test_anymatch_false()
  local function is_odd(x) return x % 2 == 0 end
  local act = Stream.new({ 1, 3, 5, 7 }):anymatch(is_odd)
  local exp = false
  assert_equals(act, exp)
end

function Test:test_nonematch_true()
  local function is_odd(x) return x % 2 == 0 end
  local act = Stream.new({ 1, 3, 5, 7 }):nonematch(is_odd)
  local exp = true
  assert_equals(act, exp)
end

function Test:test_nonematch_false()
  local function is_odd(x) return x % 2 == 0 end
  local act = Stream.new({ 1, 2, 3 }):nonematch(is_odd)
  local exp = false
  assert_equals(act, exp)
end

function Test:test_flatmap()
  local function duplicate(x) return { x, x } end
  local aexp = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, n = 10 }
  local aact = Stream.new({ 1, 2, 3, 4, 5 }):flatmap(duplicate):toarray()
  assert_equals(aact, aexp)
end

function Test:test_flatten()
  local aexp = { 1, 2, 3, 4, 5, 6, 7, 8, 9, n = 9 }
  local aact = Stream.new({ { 1, 2 }, { 3, 4, 5, 6 }, { 7 }, {}, { 8, 9 } }):flatten():toarray()
  assert_equals(aact, aexp)
end

function Test:test_concat_1()
  local aexp = { 1, 2, 3, 4, 5, 6, 7, 8, 9, n = 9 }
  local aact = Stream.new({ 1, 2, 3, 4 }):concat(Stream.new({ 5, 6, 7, 8, 9 })):toarray()
  assert_equals(aact, aexp)
end

function Test:test_concat_2()
  local aexp = { 1, 2, 3, 4, 5, 6, 7, 8, 9, n = 9 }
  local aact = Stream.new({ 1, 2, 3, 4 }):concat(Stream.new({ 5, 6 }), Stream.new({ 7, 8, 9 })):toarray()
  assert_equals(aact, aexp)
end

function Test:test_merge_1()
  local aexp = { 1, 5, 2, 6, 3, 7, 4, 8, 9, n = 9 }
  local aact = Stream.new({ 1, 2, 3, 4 }):merge(Stream.new({ 5, 6, 7, 8, 9 })):toarray()
  assert_equals(aact, aexp)
end

function Test:test_merge_2()
  local aexp = { 1, 5, 7, 2, 6, 8, 3, 9, 4, n = 9 }
  local aact = Stream.new({ 1, 2, 3, 4 }):merge(Stream.new({ 5, 6 }), Stream.new({ 7, 8, 9 })):toarray()
  assert_equals(aact, aexp)
end

function Test:test_group()
  local function is_odd(x) return x % 2 == 0 end
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

function Test:test_split_1()
  local function is_even(x) return x % 2 == 0 end
  local aexp1 = { 2, 4, n = 2 }
  local aexp2 = { 1, 3, n = 2 }
  local s1, s2 = Stream.new({ 1, 2, 3, 4 }):split(is_even)

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

function Test:test_split_2()
  local function is_even(x) return x % 2 == 0 end
  local aexp1 = { 2, 4, 6, 8, 10, n = 5 }
  local aexp2 = { 1, 3, 5, 7, 9, n = 5 }
  local even, odd = Stream.rangeclosed(1, 10):split(is_even)

  do
    local aexp = aexp1
    local aact = even:toarray()
    assert_equals(aact, aexp)
  end
  do
    local aexp = aexp2
    local aact = odd:toarray()
    assert_equals(aact, aexp)
  end
end

function Test:test_reduce()
  local function add(a, b) return a + b end
  local act = Stream.new({ 1, 2, 3, 4, 5 }):reduce(0, add)
  local exp = 15
  assert_equals(act, exp)
end

function Test:test_unpack_1()
  local exp = { 1, 2, 3, 4, 5, n = 5 }
  local act = pack(Stream.new({ 1, 2, 3, 4, 5 }):unpack())
  assert_equals(act, exp)
end

function Test:test_unpack_2()
  local exp = { 2, 3, 4, n = 3 }
  local act = pack(Stream.new({ 1, 2, 3, 4, 5 }):limit(4):skip(1):unpack())
  assert_equals(act, exp)
end

function Test:test_join()
  local act = Stream.new({ 1, 2, 3, 4, 5 }):join(" ")
  local exp = "1 2 3 4 5"
  assert_equals(act, exp)
end

function Test:test_equals_1()
  local act = Stream.new({ 1, 2, 3, 4, 5 }):equals(Stream.new({ 1, 2, 3, 4, 5 }))
  local exp = true
  assert_equals(act, exp)
end

function Test:test_equals_2()
  local act = Stream.new({ 1, 2, 3, 4, 5 }):equals({ 1, 2, 2, 4, 5 })
  local exp = false
  assert_equals(act, exp)
end

function Test:test_equals_3()
  local act = Stream.new({ 1, 2, 3, 4, 5 }):equals({ 1, 2, 3, 4, 5, 6 })
  local exp = false
  assert_equals(act, exp)
end

function Test:test_equals_4()
  local act = Stream.new({ 1, 2, 3, 4, 5 }):equals({ 1, 2, 3, 4 })
  local exp = false
  assert_equals(act, exp)
end

function Test:test_equals_5()
  local act = Stream.new({ 1, 2, 3, 4, 5 })
    :equals({ -1, -2, -3, -4, -5 }, function(a, b) return math.abs(a) == math.abs(b) end)
  local exp = true
  assert_equals(act, exp)
end

function Test:test_pack()
  local aexp = { { 1, 2, n = 2 }, { 3, 4, n = 2 }, { 5, 6, n = 2 }, { 7, 8, n = 2 }, { 9, n = 1 }, n = 5 }
  local aact = Stream.new({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):pack(2):toarray()
  assert_equals(aact, aexp)
end

function Test:test_clone_1()
  local exp = { 1, 3, 2, n = 3 }
  local s1, s2 = Stream.new({ 1, 3, 2 }):clone()
  local act1, act2 = s1:toarray(), s2:toarray()
  assert_equals(act1, act2)
  assert_equals(act1, exp)
  assert_equals(act2, exp)
end

function Test:test_clone_2()
  local exp = { 1, 2, 3, 4, 5, 6, 7, 8, 9, n = 9 }
  local s1, s2 = Stream.iterate(0, function(i) return i + 1, (i + 1) >= 10 end):clone()
  local act1, act2 = s1:toarray(), s2:toarray()
  assert_equals(act1, act2)
  assert_equals(act1, exp)
  assert_equals(act2, exp)
end

return Test
