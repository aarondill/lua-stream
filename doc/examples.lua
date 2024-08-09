-- Demonstration of Lua-Stream

--- Setup package.path to ensure stream can be require'd
--- This shouldn't be necessary in your own project!
do
  local thisfile = debug.getinfo(1, "S").source:sub(2)
  local thisdir = thisfile:match("(.*)/") or "."
  local rootdir = thisdir .. "/.." -- HACK: This file must be at the root of the doc/ directory
  package.path = table.concat({ package.path, rootdir .. "/?.lua", rootdir .. "/?/init.lua" }, ";")
end

local stream = require("stream")

-- Here are some helper functions:
local function isEven(x) return x % 2 == 0 end
local function square(x) return x * x end
---Use :avg() instead, this is just for demonstration purposes
local function myavg(iter) ---@param iter StreamIterator<number>
  local sum, count = 0, 0
  while true do
    local e, done = iter()
    if done then break end
    count, sum = count + 1, sum + e
  end
  if count == 0 then return nil end
  return sum / count
end
local function fibbon(x)
  local f = {}
  if x > 0 then
    f[1] = 1
    if x > 1 then
      f[2] = 1
      for i = 3, x do
        f[i] = f[i - 2] + f[i - 1]
      end
    end
  end
  return f
end
local function sum(a, b) return a + b end

-- Here starts the demo:

do
  print("iter")
  local it = stream.new({ 1, 2, 3, 4, 5 }).iter
  local i, done = it()
  while not done do
    print(i)
    i, done = it()
  end
end

do
  print("foreach")
  stream.new({ 1, 2, 3, 4, 5 }):foreach(print)
end

do
  print("filter")
  stream.new({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):filter(isEven):foreach(print)
end

do
  print("reverse")
  stream.new({ 1, 2, 3, 4, 5 }):reverse():foreach(print)
end

do
  print("sort")
  stream.new({ 5, 7, 6, 3, 4, 1, 2, 8, 9 }):sort():foreach(print)
end

do
  print("map")
  stream.new({ 1, 2, 3, 4, 5 }):map(square):foreach(print)
end

do
  print("next")
  local s1 = stream.new({ 1, 2, 3, 4, 5 })
  local first, firstdone = s1:next()
  if not firstdone then
    print(first)
    local second, seconddone = s1:next()
    if not seconddone then print(second) end
  end
end

do
  print("next loop")
  local s1 = stream.new({ 1, 2, 3, 4, 5 })

  --- This can also be written as:
  --- while true do
  ---   local next, done = s1:next()
  ---   if not done then break end
  ---   print(next)
  --- end
  repeat
    local next, done = s1:next()
    if not done then print(next) end
  until done
end

do
  print("last")
  local last = stream.new({ 1, 2, 3, 4, 5 }):last()
  print(last)
end

do
  print("max")
  local max = stream.new({ 5, 7, 6, 3, 4, 1, 2, 8, 9 }):max()
  print(max)
end

do
  print("min")
  local min = stream.new({ 5, 7, 6, 3, 4, 1, 2, 8, 9 }):min()
  print(min)
end

do
  print("sum")
  local _sum = stream.new({ 1, 2, 3, 4, 5 }):sum()
  print(_sum)
end

do
  print("avg")
  local avg = stream.new({ 5, 7, 6, 3, 4, 1, 2, 8, 9 }):avg()
  print(avg)
end

do
  print("collect(myavg)")
  local _myavg = stream.new({ 5, 7, 6, 3, 4, 1, 2, 8, 9 }):collect(myavg)
  print(_myavg)
end

do
  print("toarray")
  local array = stream.new({ 1, 2, 3, 4, 5 }):toarray()
  for idx = 1, array.n do
    print(array[idx])
  end
end

do
  print("range")
  stream.rangeclosed(1, 5):foreach(print)
end

do
  print("limit")
  stream.new(math.random):limit(5):foreach(print)
end

do
  print("count")
  local count = stream.new({ 1, 2, 3, 4, 5 }):count()
  print(count)
end

do
  print("skip")
  stream.new({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):skip(5):foreach(print)
end

do
  print("reverse")
  stream.new({ 1, 2, 3, 4, 5 }):reverse():foreach(print)
end

do
  print("distinct")
  stream.new({ 1, 2, 3, 2, 4, 2, 5, 2, 5, 1 }):distinct():foreach(print)
end

do
  print("peek")
  stream.new({ 1, 2, 3, 4 }):peek(print):last()
end

do
  print("allmatch")
  local allmatch = stream.new({ 2, 4, 6, 8 }):allmatch(isEven)
  print(allmatch)
end

do
  print("anymatch")
  local anymatch = stream.new({ 1, 2, 3 }):anymatch(isEven)
  print(anymatch)
end

do
  print("nonematch")
  local nonematch = stream.new({ 1, 3, 5, 7 }):nonematch(isEven)
  print(nonematch)
end

do
  print("flatmap")
  stream.new({ 0, 4, 5 }):flatmap(fibbon):foreach(print)
end

do
  print("flatten")
  stream.new({ { 1, 2, 3 }, { 4, 5 }, { 6 }, {}, { 7, 8, 9 } }):flatten():foreach(print)
end

do
  print("concat 1")
  stream.new({ 1, 2, 3, 4, 5 }):concat(stream.new({ 6, 7, 8, 9 })):foreach(print)
end

do
  print("concat 2")
  stream.new({ 1, 2, 3 }):concat(stream.new({ 4, 5, 6 }), stream.new({ 7, 8, 9 })):foreach(print)
end

do
  print("concat 3")
  stream
    .concat({
      stream.new({ 1, 2, 3 }),
      stream.new({ 4, 5, 6 }),
      stream.new({ 7, 8, 9 }),
    })
    :foreach(print)
end

do
  print("group")
  local group = stream.new({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):group(isEven)
  stream.new(group[true]):foreach(print)
  stream.new(group[false]):foreach(print)
end

do
  print("split")
  local even, odd = stream.rangeclosed(1, 10):split(isEven)
  even:foreach(print)
  odd:foreach(print)
end

do
  print("reduce")
  local _sum = stream.new({ 1, 2, 3, 4, 5 }):reduce(0, sum)
  print(_sum)
end

do
  print("merge")
  local s1 = stream.new({ 1, 2, 3 })
  local s2 = stream.new({ 5, 6, 7, 8 })
  local s3 = stream.new({ 9 })
  s1:merge(s2, s3):foreach(print)
end
