<!-- This file is generated from README.tmpl.md -->
# Lua-Stream

An updated version of: [Lua Stream API](https://github.com/mkarneim/lua-stream-api) created by [Michael Karneim](https://github.com/mkarneim/)
The updated implementation uses [Metatables](https://www.lua.org/pil/13.html) to reuse the methods for all
functions, reducing memory usage and code duplication.

## About

Lua-Stream brings the benefits of the stream-based functional programming style to [Lua](http://lua.org).
It provides a function `Stream()` that produces a sequential stream of elements taken from
an array or an iterator function. The stream object gives you the power of composing several
stream operations into a single stream pipeline.

For example, a basic stream pipeline could look like this:

```lua
Stream({3,4,5,1,2,3,4,4,4}):distinct():sort():foreach(print)
```

which results in the following output:

```lua
1
2
3
4
5
```

## License

To pay respect to the original author ([Michael Karneim](https://github.com/mkarneim/)), the source code of Lua-Stream is in the public domain.
For more information please read the LICENSE file.

## Supported Functions

### Creating a Stream

- `Stream(array)`
- `Stream(iter_func)`
- Note: `Stream(...)` is an alias for `Stream.new(...)`

### Intermediate Operations

- `:concat(streams...) -> stream`
- `:distinct() -> stream`
- `:filter(predicate) -> stream`
- `:flatmap(func) -> stream`
- `:flatten() -> stream`
- `:limit(maxnum) -> stream`
- `:map(func) -> stream`
- `:peek(consumer) -> stream`
- `:reverse() -> stream`
- `:skip(n) -> stream`
- `:sort(comparator) -> stream`
- `:split(func) -> stream, stream`

### Terminal Operations

- `:allmatch(predicate) -> boolean`
- `:anymatch(predicate) -> boolean`
- `:avg() -> number`
- `:collect(collector) -> any`
- `:count() -> number`
- `:foreach(c) -> nil`
- `:group(func) -> table`
- `:last() -> any`
- `:max(comparator) -> any`
- `:min(comparator) -> any`
- `:next() -> any`
- `:nonematch(predicate) -> boolean`
- `:reduce(init, op) -> any`
- `:sum() -> number`
- `:toarray() -> table`

## Getting Started

Lua-Stream consists of a single file called `stream.lua`. [download it](https://raw.githubusercontent.com/mkarneim/lua-stream-api/master/stream.lua) into
your project folder and include it into your program with `local Stream = require("stream")`.

### Creating a new stream from an array

You can create a new stream from any _Lua table_, provided that the table is an array _indexed with consecutive numbers from 1 to n_, containing no `nil` values (or, to be more precise, only as trailing elements. `nil` values can never be part of the stream).

Here is an example:

```lua
st = Stream({100.23, -12, "42"})
```

To print the contents to screen you can use `foreach(print)`:

```lua
st:foreach(print)
```

This will produce the following output:

```lua
100.23
-12
42
```

Later we will go into more details of the `foreach()` operation.

For now, let's have a look into another powerful alternative to create a stream.

### Creating a new stream from an iterator function

Internally each stream works with a [Lua iterator](https://www.lua.org/pil/7.1.html).
This is a parameterless function that produces a new element and a boolean value indicating whether the iterator is done.

You can create a new stream from any such function:

```lua
function zeros()
    return 0, false
end

st = stream(zeros)
```

Please note, that this creates an infinite stream of zeros. When you append  
a [terminal operation](#terminal-operations) to the end of the pipeline it will
actually never terminate:

```lua
stream(zeros):foreach(print)
0
0
0
0
...
```

To prevent this from happening you could `limit` the number of elements:

```lua
st:limit(100)
```

For example, this produces an array of 100 random numbers:

```lua
numbers = stream(math.random):limit(100):toarray()
```

Please note that `toarray()`, like `foreach()`, is a [terminal operation](#terminal-operations), which
means that it consumes elements from the stream. After this call the stream is
completely empty.

Another option to limit the number of elements is by limiting the iterator function itself.
This can be done by returning true when the production is finished.

Here is an example. The `range()` function is an _iterator factory_ that returns an iterator function
which produces consecutive numbers in a specified range:

```lua
function range(s,e,step)
  step = step or 1
  local next = s
  -- return an iterator function for numbers from s to e
  return function()
    -- this should stop any consumer from doing more calls
    if next > e then return nil, true end
    local current = next
    next = next + step
    return current, false
  end
end

numbers = stream(range(100,200)):toarray()
```

This produces an array with all integer numbers between 100 and 200 and assigns it to the `numbers` variable.

So far, so good. Now that you know how to create a stream, let's see what we can do with it.

### Looping over the elements using `stream.iter` (_NON-NIL VALUES ONLY_)

Further above you have seen that you can print all elements by using the `forach()` operation.
But this is not the only way to do it.

Since internally the stream always maintains an iterator function, you can also use it to process its content.
You can access it using `stream.iter`.

The following example shows how to process all elements with a standard Lua `for ... in ... do` loop:

```lua
for i in st.iter do
    print(i) -- do something with i, e.g. print it
end
```

This prints all elements of the stream to the output.

Please note that `iter` does not consume all elements immediately. Instead it does it lazily - element by element - whenever the produced
iterator function is called. So, if you break from the loop before all elements are consumed, there will be elements left on the stream.

### Looping over the elements using the next() operation

If you don't want to consume all elements at once but rather getting the first element of the stream, you may want to use the `next()` operation.
Note that the next() operation returns `value, done`. The parenthesis are important here.

```lua
st = stream({1,2,3})
print((st:next()))
print((st:next()))
```

This produces the following output:

```lua
1
2
```

### Getting the last element of a stream

The `last()` operation returns the last element of the stream.

```lua
st = stream({1,2,3})
print(st:last())
```

In contrast to `next()` this can only be called once, since it consumes all elements from the stream in order to find the last one. Subsequent calls will return `nil`.

### Looping over the elements with a consumer function

Another option for getting all elements of the stream is the `foreach()` operation.
We have used it already when we called it with the standard Lua `print` function in the examples above.

By using the `foreach(consumer)` operation you can loop over the stream's content by calling it with a _consumer function_.
This is any function with a single parameter.
It will be called repeatedly for each element until the stream is empty.

The following code prints all elements to the output:

```lua
st:foreach(function(e) print(e) end)
```

Or, even shorter, as we already have seen, use the reference to Lua's built-in `print()` function:

```lua
st:foreach(print)
```

Now that we know how to access the elements of the stream, let's see how we can modify it.

### Filtering Elements

Element-filtering is, besides _element-mapping_, one of the most used applications of stream pipelines.

It belongs to the group of [intermediate operations](#intermediate-operations). That means, when you append one of those to a stream, you actually are creating a new stream that is lazily backed by the former one, and which extends the pipeline by one more step. Not until you call a terminal operation on the last part of the pipeline it will actually pull elements from upstream, going through all intermediate operations that are placed in between.

By appending a `filter(predicate)` operation holding a _predicate function_, you can specify which elements should be passed downstream.
A predicate function is any function with a single parameter. It should return `true` if the argument should be passed down the stream, `false` otherwise.

Here is an example:

```lua
function is_even(x)
    return x % 2 == 0
end

stream({1,2,3,4,5,6,7,8,9}):filter(is_even):foreach(print)
```

This prints a stream of only even elements to the output:

```lua
2
4
6
8
```

In the meanwhile you might want to browse the [examples](./doc/examples.lua).

### Lines of code
<sup><sub>Generated at commit 82f3e65c78aa4b87ecf098aad13ca612320c632d</sub></sup>
cloc|github.com/AlDanial/cloc v 2.02
--- | ---

Language|files|blank|comment|code
:-------|-------:|-------:|-------:|-------:
Lua|6|673|1019|3346
Markdown|2|162|1|415
TOML|1|1|0|9
JSON|1|0|0|7
--------|--------|--------|--------|--------
SUM:|10|836|1020|3777
