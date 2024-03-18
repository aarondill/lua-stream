---Disable the duplicate warnings because they incorrectly mark all definitions in this file as duplicate (due to the symlink)
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: duplicate-doc-alias
local pack = table.pack or function(...) return { n = select("#"), ... } end
local unpack = table.unpack or unpack

---@class Stream
local Stream = {}
---@class StreamStatic
local StreamStatic = {}

---@alias StreamIterator<T> fun(): e: T, done: boolean
---A table.pack like table -- may also be a regular array
---@alias NTable<T> T[]|{n?: integer}

---@type StreamIterator<nil>
---OPTIM: use a common iterator for empty streams
local function _empty_iter() return nil, true end

---@generic T
---@param input NTable<T>
---@return StreamIterator<T>
local function tbl_iterator(input)
  assert(type(input) == "table", "input must be of type table, but was a " .. type(input))
  local i, len = 0, input.n or #input
  if len == 0 then return _empty_iter end
  return function()
    i = i + 1
    if i > len then return nil, true end
    return input[i], false
  end
end

---Get an iterator from the input
---@param input unknown
---@return StreamIterator<unknown>
local function iterator(input)
  if type(input) == "function" then return input end
  if type(input) == "table" then
    if type(input.iter) == "function" then
      return input.iter -- This is a stream (or a table with iter)!
    end
    return tbl_iterator(input)
  end
  if input == nil then return _empty_iter end
  return tbl_iterator({ input })
end

---the iterator function for the elements of this stream.
---@type StreamIterator<unknown>
function Stream.iter()
  error("Stream.iter must be overridden by instances! If you are using this statically, then you have a bug!")
end

-- Returns the next (aka first) element of this stream, or nil if the stream is empty.
---@return unknown
---@return boolean done
function Stream:next() return self.iter() end

-- Returns a lazily concatenated stream whose elements are all the elements of this stream
-- followed by all the elements of the streams provided by the varargs parameter.
---@param ... Stream
---@return Stream
function Stream:concat(...)
  local streams = { self.iter }
  for i, s in ipairs({ ... }) do
    streams[i + 1] = s.iter -- collect all the iterators
  end
  local i, len = 1, #streams
  return StreamStatic.new(function()
    if i > len then return nil, true end
    local it = streams[i]
    while true do
      local e, done = it()
      if not done then return e, false end
      i = i + 1 -- move onto the next stream
      if i > len then return nil, true end
      it = streams[i]
    end
  end)
end

-- Returns a stream consisting of the elements of this stream, additionally performing
-- the provided action on each element as elements are consumed from the resulting stream.
---@param f fun(e: unknown): any?
---@return Stream
function Stream:peek(f)
  assert(type(f) == "function", "f must be of type function")
  return StreamStatic.new(function()
    local e, done = self.iter()
    if not done then f(e) end
    return e, done
  end)
end

-- Returns a stream consisting of the elements of this stream that match the given predicate.
---@param f fun(e: unknown): boolean
---@return Stream
function Stream:filter(f)
  assert(type(f) == "function", "f must be of type function")
  return StreamStatic.new(function()
    while true do
      local e, done = self.iter()
      if done then break end
      if f(e) then return e, false end
    end
    return nil, true
  end)
end

-- Returns a stream consisting of chunks, made of n adjacent elements of the original stream.
---@param n integer
---@return Stream s a Stream<T[]> where [].n<=n
function Stream:pack(n)
  return StreamStatic.new(function() ---@return NTable<unknown>
    local result, len = nil, 0
    for _ = 1, n do
      local e, done = self.iter()
      if done then break end
      result = result or {}
      len = len + 1
      result[len] = e
    end
    if not result then return nil, true end
    result.n = len
    return result, false
  end)
end

---Returns a stream consisting of the results of applying the given function to
---the elements of this stream.
---@param f fun(e: unknown): unknown
---@return Stream
function Stream:map(f)
  assert(type(f) == "function", "f must be of type function")
  return StreamStatic.new(function()
    local e, done = self.iter()
    if done then return nil, true end
    return f(e), false
  end)
end

-- Returns a stream consisting of the flattened results
-- produced by applying the provided mapping function on each element.
---@param f fun(e: unknown): unknown[]|Stream|(fun(): unknown)
---@return Stream s a Stream<T> where f returns T[]|Stream<T>|Iterator<T>
function Stream:flatmap(f)
  assert(type(f) == "function", "f must be of type function")
  local it = nil
  return StreamStatic.new(function()
    while true do
      if it == nil then -- we have no current iterator, generate a new one
        local e, done = self.iter()
        if done then break end
        it = iterator(f(e)) -- support returning streams or iterators
      else -- call the iterator until it is exhausted
        local e, done = it()
        if not done then return e, false end
        it = nil
      end
    end
    return nil, true
  end)
end

-- Returns a stream consisting of the flattened elements.
---@return Stream s a Stream<T> where self is a Stream<T[]|Stream<T>|Iterator<T>>
function Stream:flatten()
  return self:flatmap(function(e) return e end)
end

-- Returns a stream consisting of the distinct elements
-- (according to the standard Lua operator ==) of this stream.
---@return Stream
function Stream:distinct()
  local processed, seen_nil = {}, false
  return StreamStatic.new(function()
    while true do
      local e, done = self.iter()
      if done then break end
      if e == nil then -- note: we can't index with nil
        if not seen_nil then -- we haven't seen a nil yet, return it
          seen_nil = true
          return e, false
        end
      elseif processed[e] == nil then
        processed[e] = true
        return e, false
      end
    end
    return nil, true
  end)
end

---TODO: make this work with nils!!!!!!

---Returns true if the stream is equal to the provided stream or array.
---Note: since nils aren't allowed in the stream, an array is considered equal
---if all elements up to the first nil are equal
---@param other Stream|unknown[]
---@param cond? fun(a: unknown, b: unknown): boolean default is a==b
function Stream:equals(other, cond)
  assert(type(other) == "table", "other must be of type table") -- Note: function iterators are not supported. If you must, create a stream and pass it.
  cond = cond or function(a, b) return a == b end
  local oiter = iterator(other)
  for a in self.iter do
    local b = oiter()
    if b == nil then return false end -- other is empty
    if not cond(a, b) then return false end -- other is not equal
  end -- we are now empty
  for _ in oiter do
    return false -- other is not empty
  end
  return true
end

-- Returns a stream consisting of the elements of this stream,
-- truncated to be no longer than maxsize in length.
---@param max integer
---@return Stream
function Stream:limit(max)
  local count = 0
  return StreamStatic.new(function()
    count = count + 1
    if count > max then return nil, true end
    return self.iter()
  end)
end

-- Returns a stream consisting of the remaining elements of this stream
-- after discarding the first n elements of the stream. If this stream contains
-- fewer than n elements then an empty stream will be returned.
---@param num integer
---@return Stream
function Stream:skip(num)
  local i = 0
  return StreamStatic.new(function()
    while i < num do -- skip n elements
      i = i + 1
      local _, done = self.iter()
      if done then return nil, true end
    end
    return self.iter() -- return remaining elements
  end)
end

-- Returns the last element of this stream.
---@return unknown
function Stream:last()
  local res = nil
  while true do
    local e, done = self.iter()
    if done then break end
    res = e
  end
  return res
end

---Performs the given action for each element of this stream.
---@param f fun(e: unknown): any?
function Stream:foreach(f)
  while true do
    local e, done = self.iter()
    if done then break end
    f(e)
  end
end

-- Returns an array containing the elements of this stream.
---@param ret? NTable<unknown> An array to append to - note: begins at first non-nil element!
---@return NTable<unknown>, integer len
function Stream:toarray(ret)
  local result = ret or {}
  local i = result.n or #result
  while true do
    local e, done = self.iter()
    if done then break end
    i = i + 1
    result[i] = e
  end
  result.n = i
  return result, i
end

---Returns a stream consisting of the elements of this stream, ordered randomly.
---Call math.randomseed( os.time() ) first to get nice random orders.
---Note: this must pull all the elements of the stream!
---@return Stream
function Stream:shuffle()
  local result, len = self:toarray()
  local iterations = len
  local rand = math.random
  for i = iterations, 2, -1 do
    local j = rand(i) -- pick a random index
    result[i], result[j] = result[j], result[i]
  end
  return StreamStatic.new(result)
end

-- Returns a table which is grouping the elements of this stream by keys provided from
-- the specified classification function.
---@param f fun(e: unknown): string returns key to group by
---@return table
function Stream:group(f)
  assert(type(f) == "function", "f must be of type function")
  local result = {}
  while true do
    local e, done = self.iter()
    if done then break end
    local key = f(e)
    local values = result[key]
    if values == nil then
      values = {}
      result[key] = values
    end
    values[#values + 1] = e
  end
  return result
end

-- Returns two streams consisting of the elements of this stream separated by
-- the given predicate.
---@param f fun(e: unknown): boolean return true for the first stream, false for the second
---@return Stream trueStream
---@return Stream falseStream
function Stream:split(f)
  assert(type(f) == "function", "f must be of type function")
  local iter = self.iter
  --- A cache to store elements when s1 is pulled from and doesn't match (and vise-versa)
  --- If s1 is pulled and finds a non-matching element, then it should be added to a2
  --- Then, when s2 is pulled, it should check a2 for cached elements
  local a1, a2 = { n = 0 }, { n = 0 }
  ---@param match boolean
  ---@param amatch NTable<unknown>
  ---@param anomatch NTable<unknown>
  local function pull(match, amatch, anomatch)
    return function() ---@type StreamIterator
      if amatch.n > 0 then -- if there's pending matches, return the matches
        amatch.n = amatch.n - 1 -- remove from the count
        return table.remove(amatch, 1), false
      end
      while true do
        local e, done = iter()
        if done then break end
        if f(e) == match then return e, false end
        table.insert(anomatch, e)
        anomatch.n = anomatch.n + 1 -- add to the count
      end
      return nil, true
    end
  end
  return StreamStatic.new(pull(true, a1, a2)), StreamStatic.new(pull(false, a2, a1))
end

-- Returns a lazily merged stream whose elements are all the elements of this stream
-- and of the streams provided by the varargs parameter. The elements are taken from all
-- streams round-robin.
---@param ... Stream must all be non-nil!
---@return Stream
function Stream:merge(...)
  local itarr = { self.iter }
  for i, s in ipairs({ ... }) do
    itarr[i + 1] = s.iter
  end
  local idx = 1
  return StreamStatic.new(function()
    local len = #itarr
    if len == 0 then return nil, true end
    for _ = 1, len do
      if idx > len then idx = 1 end
      local it = itarr[idx]
      local e, done = it()
      if not done then
        idx = idx + 1
        return e, false
      end
      table.remove(itarr, idx)
      len = #itarr
    end

    local donecount = 0
    local result = {}
    for i, it in ipairs(itarr) do
      local e, done = it()
      if done then
        donecount = donecount + 1
      else
        result[i - donecount] = e
      end
    end

    if donecount >= #itarr then return nil, true end
    return result, false
  end)
end

-- Returns the result of the given collector that is supplied
-- with an iterator for the elements of this stream.
---@generic T
---@param c fun(iter: StreamIterator<unknown>): T
---@return T
function Stream:collect(c) return c(self.iter) end

-- Performs a reduction on the elements of this stream, using the provided initial value
-- and the associative accumulation function, and returns the reduced value.
---@generic T
---@param init T
---@param op fun(acc: T, e: unknown): T
---@return T
function Stream:reduce(init, op)
  assert(type(op) == "function", "f must be of type function")
  local result = init
  while true do
    local e, done = self.iter()
    if done then break end
    result = op(result, e)
  end
  return result
end

---Returns a stream consisting of the elements of this stream in reversed order.
---Note: this must pull all the elements of the stream!
---@return Stream
function Stream:reverse()
  local result, len = self:toarray()
  for i = 1, len / 2 do
    result[i], result[len - i + 1] = result[len - i + 1], result[i]
  end
  return StreamStatic.new(result)
end

-- Returns a stream consisting of the elements of this stream, sorted according to the
-- provided comparator.
-- See table.sort for details on the comp parameter.
-- If comp is not given, then the standard Lua operator < is used.
---@param comp? fun(a: unknown, b: unknown): boolean
---@return Stream
function Stream:sort(comp)
  local result = self:toarray()
  table.sort(result, comp)
  return StreamStatic.new(result)
end

--- Returns the concatenation of elements by delim
--- See table.concat for details
---@param delim? string
---@return string
function Stream:join(delim)
  local arr = self:toarray()
  return table.concat(arr, delim, 1, arr.n)
end

--- Returns each element of this stream
--- Note: to use unpack(s, i, j), call stream:limit(j):skip(i):unpack()
---@return ...: the stream elements
--- NOTE: unpack has an inherent limit on the number of elements it can return
--- (around 255). If you need more, use :toarray instead!
function Stream:unpack()
  local arr = self:toarray()
  return unpack(arr, 1, arr.n)
end

-- Returns the count of elements in this stream.
---@return integer
function Stream:count()
  local result = 0
  while true do
    local _, done = self.iter()
    if done then break end
    result = result + 1
  end
  return result
end

-- Returns the maximum element of this stream according to the provided comparator,
-- or nil if this stream is empty.
-- See table.sort for details on the comp parameter.
-- If comp is not given, then the standard Lua operator > is used.
---@param comp? fun(a, b): boolean true if a<b, false if a>b
---@return unknown
function Stream:max(comp)
  local result = nil
  while true do
    local e, done = self.iter()
    if done then break end
    if result == nil then
      result = e
    elseif comp ~= nil then
      if not comp(e, result) then result = e end
    else
      if e > result then result = e end
    end
  end
  return result
end

-- Returns the minimum element of this stream according to the provided comparator,
-- or nil if this stream is empty.
-- See table.sort for details on the comp parameter.
-- If comp is not given, then the standard Lua operator < is used.
---@param comp? fun(a, b): boolean true if a<b, false if a>b
---@return unknown
function Stream:min(comp)
  local result = nil
  while true do
    local e, done = self.iter()
    if done then break end
    if result == nil then
      result = e
    elseif comp ~= nil then
      if comp(e, result) then result = e end
    else
      if e < result then result = e end
    end
  end
  return result
end

---Returns the sum of elements in this stream.
---Note: This will throw if any element is not a number!
---@return number
function Stream:sum()
  local result = 0
  while true do
    local e, done = self.iter()
    if done then break end
    result = result + e
  end
  return result
end

-- Returns the arithmetic mean of elements of this stream, or nil if this stream is empty.
function Stream:avg()
  local sum, count = 0, 0
  while true do
    local e, done = self.iter()
    if done then break end
    count = count + 1
    sum = sum + e
  end
  if count == 0 then return nil end
  return sum / count
end
---@alias statistics {count: integer, sum: integer, min: integer, max: integer}

---Note: All elements of the stream must be able to be added to each other, else an error is thrown
---@return statistics
function Stream:statistics()
  ---@type statistics
  local statistics = { count = 0, sum = 0, min = math.huge, max = -math.huge }
  return self:reduce(statistics, function(stats, e)
    stats.count = stats.count + 1
    stats.sum = stats.sum + e
    if e < stats.min then stats.min = e end
    if e > stats.max then stats.max = e end
    return stats
  end)
end

-- Returns whether all elements of this stream match the provided predicate.
-- If the stream is empty then true is returned and the predicate is not evaluated.
---@param p fun(e: unknown): boolean
---@return boolean
function Stream:allmatch(p)
  assert(type(p) == "function", "f must be of type function")
  while true do
    local e, done = self.iter()
    if done then break end
    if not p(e) then return false end
  end
  return true
end

-- Returns whether any elements of this stream match the provided predicate.
-- If the stream is empty then false is returned and the predicate is not evaluated.
---@param p fun(e: unknown): boolean
---@return boolean
function Stream:anymatch(p)
  assert(type(p) == "function", "f must be of type function")
  while true do
    local e, done = self.iter()
    if done then break end
    if p(e) then return true end
  end
  return false
end

-- Returns whether no elements of this stream match the provided predicate.
-- If the stream is empty then true is returned and the predicate is not evaluated.
---@param p fun(e: unknown): boolean
---@return boolean
function Stream:nonematch(p) return not self:anymatch(p) end

------------------------------------------------------------------------------
-------------------------------- Constructors --------------------------------
------------------------------------------------------------------------------
---This function returns a sequential stream with the provided input as its source.
---Depending on the type of `input`, a different stream is returned:
---* table:     The new stream is created from the integer elements of the table, just like ipairs
---* stream:    The new stream is a copy of the input stream (note: the streams use the same iterator, so exhausting one will exhaust the other!)
---* function:  The new stream is created with `input` as its iterator function.
---* nil:       The new stream is empty.
---* otherwise: The new stream contains `input` as its only element.
---@param input unknown|StreamIterator<unknown>
---@return Stream
function StreamStatic.new(input)
  local iter = iterator(input)
  local self = { iter = iter }
  return setmetatable(self, { __index = Stream })
end

---This function acts exactly like Stream.new, but the stream ends when an element is nil
---@param input unknown|StreamIterator<unknown>
---@return Stream
function StreamStatic.nonnil(input)
  local iter = iterator(input)
  return StreamStatic.new(function()
    while true do
      local e = iter()
      return e, e == nil
    end
  end)
end

---Returns an empty stream
---@return Stream
function StreamStatic.empty() return StreamStatic.new(_empty_iter) end

---Returns a new stream containing the elements passed as parameters
---@param ... unknown
---@return Stream
function StreamStatic.of(...) return StreamStatic.new(pack(...)) end

---Returns a new sequential stream whose elements are generated by the given generator function.
---Each element is generated by calling the generator with the previous element
---Example generate infinite stream of all x>0: Stream.iterate(0, function(x) return x + 1 end)
---If has_next(seed) return false, the stream is considered empty
---@generic T
---@param seed T
---@param generator fun(prev: T): T, done: boolean
---@return Stream
function StreamStatic.iterate(seed, generator)
  local done, e
  return StreamStatic.new(function()
    if done then return nil, true end -- we've already emptied this generator.
    e, done = generator(seed) -- get the next element and done
    seed = e -- use for the next time
    return e, done
  end)
end

---Note: if start < end, the stream will count down
---@param startInclusive integer
---@param endExclusive integer
---@return Stream
function StreamStatic.range(startInclusive, endExclusive)
  if startInclusive == endExclusive then return StreamStatic.empty() end
  local delta = endExclusive > startInclusive and 1 or -1
  --- Note: (startInclusive - d) because the first result will be (startInclusive-d)+d
  return StreamStatic.iterate(startInclusive - delta, function(x)
    local res = x + delta
    --- HACK: return NaN. Any correct implementation will ignore this value because done=true
    if endExclusive > startInclusive and res >= endExclusive then return 0 / 0, true end
    if endExclusive < startInclusive and res <= endExclusive then return 0 / 0, true end
    return res, false
  end)
end

---Note: if start < end, the stream will count down
---@param startInclusive integer
---@param endInclusive integer
---@return Stream
function StreamStatic.rangeclosed(startInclusive, endInclusive)
  local delta = endInclusive >= startInclusive and 1 or -1
  --- Note: (startInclusive - d) because the first result will be (startInclusive-d)+d
  return StreamStatic.iterate(startInclusive - delta, function(x)
    local res = x + delta
    --- HACK: return NaN. Any correct implementation will ignore this value because done=true
    if endInclusive >= startInclusive and res > endInclusive then return 0 / 0, true end
    if endInclusive < startInclusive and res < endInclusive then return 0 / 0, true end
    return res, false
  end)
end

--- The metatable for the stream module.
local mt = {}
function mt:__call(...) return StreamStatic.new(...) end
return setmetatable(StreamStatic, mt)
