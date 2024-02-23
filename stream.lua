---@class Stream
local Stream = {}

---@alias StreamIterator<T> fun(): T?

---OPTIM: use a common iterator for empty streams
local function _empty_iter() end

---@generic T
---@param input T[]
---@return StreamIterator<T>
local function tbl_iterator(input)
  assert(type(input) == "table", "input must be of type table, but was a " .. type(input))
  local i, len = 0, #input
  if len == 0 then return _empty_iter end
  return function()
    i = i + 1
    if i > len then return nil end
    return input[i]
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
  return error("Stream.iter must be overridden by instances! If you are using this statically, then you have a bug!")
end

-- Returns the next (aka first) element of this stream, or nil if the stream is empty.
function Stream:next()
  return self.iter()
end

-- Returns a lazily concatenated stream whose elements are all the elements of this stream
-- followed by all the elements of the streams provided by the varargs parameter.
function Stream:concat(...)
  local streams = { self.iter }
  for i, s in ipairs({ ... }) do
    streams[i + 1] = s.iter -- collect all the iterators
  end
  local i, len = 1, #streams
  return Stream.new(function()
    if i > len then return nil end
    local it = streams[i]
    while true do
      local e = it()
      if e ~= nil then return e end
      i = i + 1 -- move onto the next stream
      if i > len then return nil end
      it = streams[i]
    end
  end)
end

-- Returns a stream consisting of the elements of this stream, additionally performing
-- the provided action on each element as elements are consumed from the resulting stream.
function Stream:peek(f)
  assert(type(f) == "function", "f must be of type function")
  return Stream.new(function()
    local e = self.iter()
    if e ~= nil then f(e) end
    return e
  end)
end

-- Returns a stream consisting of the elements of this stream that match the given predicate.
function Stream:filter(f)
  assert(type(f) == "function", "f must be of type function")
  return Stream.new(function()
    local e = self.iter()
    while e ~= nil do
      if f(e) then return e end
      e = self.iter()
    end
    return nil
  end)
end

-- Returns a stream consisting of chunks, made of n adjacent elements of the original stream.
function Stream:pack(n)
  return Stream.new(function()
    local result = nil
    for _ = 1, n do
      local e = self.iter()
      if e == nil then return result end
      result = result or {}
      table.insert(result, e)
    end
    return result
  end)
end

-- Returns a stream consisting of the results of applying the given function
-- to the elements of this stream.
function Stream:map(f)
  assert(type(f) == "function", "f must be of type function")
  return Stream.new(function()
    local e = self.iter()
    if e ~= nil then return f(e) end
    return nil
  end)
end

-- Returns a stream consisting of the flattened results
-- produced by applying the provided mapping function on each element.
function Stream:flatmap(f)
  assert(type(f) == "function", "f must be of type function")
  local it = nil
  return Stream.new(function()
    while true do
      if it == nil then -- we have no current iterator, generate a new one
        local e = self.iter()
        if e == nil then return nil end
        it = iterator(f(e)) -- support returning streams or iterators
      else -- call the iterator until it is exhausted
        local e = it()
        if e ~= nil then return e end
        it = nil
      end
    end
  end)
end

-- Returns a stream consisting of the flattened elements.
function Stream:flatten()
  return self:flatmap(function(e)
    return e
  end)
end

-- Returns a stream consisting of the distinct elements
-- (according to the standard Lua operator ==) of this stream.
function Stream:distinct()
  local processed = {}
  return Stream.new(function()
    for e in self.iter do
      if processed[e] == nil then
        processed[e] = true
        return e
      end
    end
  end)
end

-- Returns a stream consisting of the elements of this stream,
-- truncated to be no longer than maxsize in length.
function Stream:limit(max)
  local count = 0
  return Stream.new(function()
    count = count + 1
    if count > max then return nil end
    return self.iter()
  end)
end

-- Returns a stream consisting of the remaining elements of this stream
-- after discarding the first n elements of the stream. If this stream contains
-- fewer than n elements then an empty stream will be returned.
function Stream:skip(num)
  local i = 0
  return Stream.new(function()
    while i < num do -- skip n elements
      i = i + 1
      local e = self.iter()
      if e == nil then return nil end
    end
    return self.iter() -- return remaining elements
  end)
end

-- Returns the last element of this stream.
function Stream:last()
  local result = nil
  for e in self.iter do
    result = e
  end
  return result
end

-- Performs the given action for each element of this stream.
function Stream:foreach(f)
  assert(type(f) == "function", "f must be of type function")
  for e in self.iter do
    f(e)
  end
end

-- Returns an array containing the elements of this stream.
function Stream:toarray()
  local result = {}
  local i = 0
  for e in self.iter do
    i = i + 1
    result[i] = e
  end
  return result
end

-- Returns a stream consisting of the elements of this stream, ordered randomly.
-- Call math.randomseed( os.time() ) first to get nice random orders.
function Stream:shuffle()
  local result = self:toarray()
  local rand = math.random
  local iterations = #result
  local j
  for i = iterations, 2, -1 do
    j = rand(i)
    result[i], result[j] = result[j], result[i]
  end
  return Stream.new(result)
end

-- Returns a table which is grouping the elements of this stream by keys provided from
-- the specified classification function.
function Stream:group(f)
  assert(type(f) == "function", "f must be of type function")
  local result = {}
  for e in self.iter do
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

-- Returns two streams consisting of the elements of this stream
-- separated by the given predicate.
function Stream:split(f)
  assert(type(f) == "function", "f must be of type function")
  local iter = self.iter
  local a1, a2 = {}, {}
  local function pull(match, amatch, anomatch)
    return function()
      if amatch[1] ~= nil then return table.remove(amatch, 1) end
      local e = iter()
      while e ~= nil do
        if f(e) == match then return e end
        table.insert(anomatch, e)
        e = iter()
      end
    end
  end
  local it1 = pull(true, a1, a2)
  local it2 = pull(false, a2, a1)
  return Stream.new(it1), Stream.new(it2)
end

-- Returns a lazily merged stream whose elements are all the elements of this stream
-- and of the streams provided by the varargs parameter. The elements are taken from all
-- streams round-robin.
function Stream:merge(...)
  local itarr = { self.iter }
  for i, s in ipairs({ ... }) do
    itarr[i + 1] = s.iter
  end
  local idx = 1
  return Stream.new(function()
    local len = #itarr
    if len == 0 then return nil end
    for i = 1, len do
      if idx > len then idx = 1 end
      local it = itarr[idx]
      local e = it()
      if e ~= nil then
        idx = idx + 1
        return e
      else
        table.remove(itarr, idx)
        len = #itarr
      end
    end

    local nilcount = 0
    local result = {}
    for i, it in ipairs(itarr) do
      local e = it()
      if e == nil then
        nilcount = nilcount + 1
      else
        result[i - nilcount] = e
      end
    end
    if nilcount >= #itarr then
      return nil
    else
      return result
    end
  end)
end

-- Returns the result of the given collector that is supplied
-- with an iterator for the elements of this stream.
function Stream:collect(c)
  return c(self.iter)
end

-- Performs a reduction on the elements of this stream, using the provided initial value
-- and the associative accumulation function, and returns the reduced value.
function Stream:reduce(init, op)
  assert(type(op) == "function", "f must be of type function")
  local result = init
  for e in self.iter do
    result = op(result, e)
  end
  return result
end

-- Returns a stream consisting of the elements of this stream in reversed order.
function Stream:reverse()
  local result = self:toarray()
  local len = #result
  for i = 1, len / 2 do
    result[i], result[len - i + 1] = result[len - i + 1], result[i]
  end
  return Stream.new(result)
end

-- Returns a stream consisting of the elements of this stream, sorted according to the
-- provided comparator.
-- See table.sort for details on the comp parameter.
-- If comp is not given, then the standard Lua operator < is used.
function Stream:sort(comp)
  local result = self:toarray()
  table.sort(result, comp)
  return Stream.new(result)
end

-- Returns the count of elements in this stream.
function Stream:count()
  local result = 0
  for _ in self.iter do
    result = result + 1
  end
  return result
end

-- Returns the maximum element of this stream according to the provided comparator,
-- or nil if this stream is empty.
-- See table.sort for details on the comp parameter.
-- If comp is not given, then the standard Lua operator < is used.
function Stream:max(comp)
  local result = nil
  for e in self.iter do
    if result == nil or (comp ~= nil and comp(result, e)) or result < e then result = e end
  end
  return result
end

-- Returns the minimum element of this stream according to the provided comparator,
-- or nil if this stream is empty.
-- See table.sort for details on the comp parameter.
-- If comp is not given, then the standard Lua operator < is used.
function Stream:min(comp)
  local result = nil
  for e in self.iter do
    if result == nil or (comp ~= nil and comp(e, result)) or e < result then result = e end
  end
  return result
end

-- Returns the sum of elements in this stream.
function Stream:sum()
  local result = 0
  for e in self.iter do
    result = result + e
  end
  return result
end

-- Returns the arithmetic mean of elements of this stream, or nil if this stream is empty.
function Stream:avg()
  local sum, count = 0, 0
  for e in self.iter do
    count = count + 1
    sum = sum + e
  end
  if count == 0 then return nil end
  return sum / count
end

-- Returns whether all elements of this stream match the provided predicate.
-- If the stream is empty then true is returned and the predicate is not evaluated.
function Stream:allmatch(p)
  assert(type(p) == "function", "f must be of type function")
  for e in self.iter do
    if not p(e) then return false end
  end
  return true
end

-- Returns whether any elements of this stream match the provided predicate.
-- If the stream is empty then false is returned and the predicate is not evaluated.
function Stream:anymatch(p)
  assert(type(p) == "function", "f must be of type function")
  for e in self.iter do
    if p(e) then return true end
  end
  return false
end

-- Returns whether no elements of this stream match the provided predicate.
-- If the stream is empty then true is returned and the predicate is not evaluated.
function Stream:nonematch(p)
  return not self:anymatch(p)
end

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
---@param input unknown
---@return Stream
function Stream.new(input)
  local iter = iterator(input)
  local self = { iter = iter }
  return setmetatable(self, { __index = Stream })
end

---Returns an empty stream
function Stream.empty()
  return Stream.new(nil)
end

---Returns a new stream containing the elements passed as parameters
---@param ... unknown
function Stream.of(...)
  return Stream.new(table.pack(...))
end

---Returns a new sequential stream whose elements are generated by the given generator function.
---Each element is generated by calling the generator with the previous element
---Example generate infinite stream of all x>0: Stream.iterate(0, function(x) return x + 1 end)
function Stream.iterate(seed, generator)
  assert(type(generator) == "function", "generator must be of type function")
  return Stream.new(function()
    seed = generator(seed)
    return seed
  end)
end

---Note: if start < end, the stream will count down
---@param startInclusive integer
---@param endExclusive integer
---@return Stream
function Stream.range(startInclusive, endExclusive)
  if startInclusive == endExclusive then return Stream.empty() end
  local delta = endExclusive > startInclusive and 1 or -1
  --- Note: (startInclusive - d) because the first result will be (startInclusive-d)+d
  return Stream.iterate(startInclusive - delta, function(x)
    local res = x + delta
    if endExclusive > startInclusive and res >= endExclusive then return nil end
    if endExclusive < startInclusive and res <= endExclusive then return nil end
    return res
  end)
end

---Note: if start < end, the stream will count down
---@param startInclusive integer
---@param endInclusive integer
---@return Stream
function Stream.rangeClosed(startInclusive, endInclusive)
  local delta = endInclusive >= startInclusive and 1 or -1
  --- Note: (startInclusive - d) because the first result will be (startInclusive-d)+d
  return Stream.iterate(startInclusive - delta, function(x)
    local res = x + delta
    if endInclusive > startInclusive and res > endInclusive then return nil end
    if endInclusive < startInclusive and res < endInclusive then return nil end
    return res
  end)
end

--- The metatable for the stream module.
local mt = {}
function mt:__call(...)
  return Stream.new(...)
end
return setmetatable(Stream, mt)
