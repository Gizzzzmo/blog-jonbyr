---
id: range-constrained-cpp
aliases:
  - constrained types
tags:
  - c++
code:
  cpp:
    header_link: https://github.com/Gizzzzmo/blog/tree/3b8646f1ee17dd89105165e3e57b7cd95e693f25/content/static/
    header_link_run: https://raw.githubusercontent.com/Gizzzzmo/blog/3b8646f1ee17dd89105165e3e57b7cd95e693f25/content/static/
    run_args: "{compiler: 'armv7-clang2010', options: '-std=c++20 -O1', run: true}"
description: Encoding preconditions in the C++ typesystem
export_markdown: true
number_sections: false
sidebar_numbered: true
title: Range Constrained Types in C++
---

One of the most common software bugs is the humble buffer overflow. In its
simplest form this can happen when an array is accessed out of bounds:

```cpp {run=compiler_explorer}
int arr[5];

int foo(int i) {
    return arr[i];
}

int main() {
    return foo(5);
}
```

The code above causes
[🌩*Undefined Behavior*🌩](https://blog.regehr.org/archives/213)<sup>TM</sup> (or
UB for short). That is to say that a standard-compliant compiler can produce
code that does *literally anything*. Roughly speaking this is to give the
compiler more leeway in making aggressive optimizations: it means that it can
assume UB never happens and optimize the code based on that assumption.

So more likely than not `foo` will simply compile to machine code that reads and
returns the memory at `&arr + i` (in fact you can click the little green
"Run"-button in the corner of the code to see that clang's codegen goes exactly
that). Since the array only occupies memory up to `&arr + 4`, calling `foo` like
above will try to read the memory of whatever object the compiler decided to
place after `arr`. If that object is always the same, then executing the binary
will consistently produce the same return code. Or maybe there is no object
after `arr` and the address right after `arr` is not mapped to a region that the
created process is allowed to read, resulting in a SEGFAULT.

# std::array

In this respect C-style arrays are considered unsafe, and many "modern" C++
style guides suggest using `std::array` instead. Objects of this type implement
the `at` function which checks that the supplied index is within the bounds of
the array. If it isn't, it throws an exception.

```cpp
#include <array>

std::array<int, 5> arr;

int foo(int i) {
    return arr.at(i);
}

int main() {
    return foo(5);
}
```

Now the program will (predictably!) fail; And of course we could add error
handling by catching the exception. Somewhat annoyingly though, there are also
lots of folks who consider using exceptions at all to be
[bad practice](http://shanekirk.com/2015/06/c-exceptions-the-good-the-bad-and-the-ugly/).
If we compile the code with clang and `-fno-exceptions` the code above will
still compile (and still fail) but whenever any element is accessed out of
bounds, the program will call `abort` killing the process and precluding any
error handling.

And besides, who wants bounds checks anyway? We are writing C++ after all. What
we want is ***performance***! Every unnecessary CPU cycle brings dishonor to us
and our family.

When *iterating* such an array the fancy new type can still help us out. Using a
range based for-loop allows us to access all array elements without bounds
checking, and the guarantee that we don't overflow the buffer.

```cpp
#include <array>

std::array<int, 5> arr;

int sum() {
    int x = 0;
    for (int el : arr) {
        x += el;
    }

    return x;
}
```

But what about accessing just a single element? In some other languages it is
possible to create integer subtypes, where only certain values allowed. Then the
api for array accesses could explicitly take only elements of that subtype;
let's call it `InRange<T, n, m>`, where `T` is an integral type, and `n` and `m`
are of type `T`. These objects then carry a value of type `T` that is somehow
guaranteed to be >= `n` and < `m`. Leaving aside the question of how to
implement this behavior for now, this is what `array`'s subscript operator could
look like:

```cpp
#include <cstddef>

template<typename T, T n, T m>
class InRange;

template<typename T, size_t n>
class safe_array {
//...
public:
    T& operator[](InRange<size_t, 0, n> x) {
        return data[x];
    }
//...
private:
    T data[n];
};
```

Another way of thinking about this is that we are encoding a
[precondition](https://akrzemi1.wordpress.com/2013/01/04/preconditions-part-i/)
of `safe_array`'s subscript operator in the type system. So how can we design
`InRange` to guarantee this implied precondition? Ideally we would want to be
able to use it just like the integral type `T` that it is built on top of, i.e.
being able to do arithmetic, performing comparisons, etc.

# Constraining the argument

For one thing whenever we create a new `InRange` object or assign to an existing
one from an arbitrary integer we need to obviously check that the constraint is
satisfied:

```cpp
template<typename T, T n, T m>
class InRange {
    using Self = InRange<T, n, m>;
public:
    InRange(T value) : x(value) {
        if (!check_constraint(value))
            throw 1;
    }
    Self& operator=(T value) {
        if (!check_constraint(value))
            throw 1;
        x = value;
        return *this;
    }

private:
    static bool check_constraint(T x) {
        return (x >= n && x < m);
    }
    T x;
};
```

With the single-argument constructor objects of type `T` can now also implicitly
convert to `InRange<T, ...>` , meaning the introductory example already almost
works with our custom integer subtype. The only thing missing is some way of
retrieving the `x` from within `InRange`. By adding a conversion operator back
to `T` we can both fix this and partly achieve our objective of being able to
use `InRange<T, ...>` just like `T`:

```cpp
operator T() {
    return x;
}
```

The code below will now compile:

```cpp
#include "in_range_naive.h"

safe_array<int, 5> arr;

int main() {
    InRange<int, 0, 5> var(3);
    var = var + 1;
    return arr[5] + var;
}
```

... however, we still have all the same problems as with `std::array` and `.at`:
a runtime check takes place when the 5 is implicitly converted to
`InRange<size_t, 0, 5>`, and when it fails an exception is thrown that has to
either be caught or else the process will terminate.

We also have runtime checks on the creation of, and assignment to `var`. While
any half-descent optimizer will likely be able to get rid of these here (after
all the compiler can see all the integer literals involved in the calculations)
this is not always the case and we would like a stronger guarantee that the
information available at compile-time is in fact used to eliminate unnecessary
checks.

Ideally it should also realize *at compile-time* that the access to `arr[5]` is
illegal, refusing to compile, instead of throwing an exception at run-time.

# Compile-time checks

Since C++ 20 there is a very simple solution: add the `consteval` keyword to the
constructor, and assignment operator of `InRange`:

```cpp
template<typename T, T n, T m>
class InRange {
    using Self = InRange<T, n, m>;
public:
    consteval InRange(T value) : x(value) {
        if (!check_constraint(value))
            throw 1;
    }
    consteval Self& operator=(T value) {
        if (!check_constraint(value))
            throw 1;
        x = value;
        return *this;
    }

private:
    constexpr bool check_constraint(T x) {
        return (x >= n && x < m);
    }
    T x;
};
```

This guarantees that the functions will be called at a compile time, and when it
throws this results in a compilation failure. Try compiling the same code as
before in compiler explorer; this time with our new implementation:

```cpp {run=compiler_explorer}
#include "in_range.h"

safe_array<int, 5> arr;

int main() {
    InRange<int, 0, 5> var(3);
    return arr[5] + var;
}
```

Right now we are getting an error, but if you change `arr[5]` to `arr[4]` the
code will compile successfully, and there are no runtime checks involved.

We can make sure of it by simplifying to the (now correct version of the)
introductory example and looking at the generated assembly (I'm showing arm
assembly because that's what I'm most used to, but you can switch to x86 or
whatever isa you prefer in compiler explorer):

```cpp {run=compiler_explorer run_args="{compiler: 'armv7-clang2010', options: '-std=c++20 -O1', run: false}"}
#include "in_range.h"

safe_array<int, 5> arr;

int foo(InRange<size_t, 0, 5> i) {
    return arr[i];
}
```

```arm
foo(InRange<unsigned int, 0u, 5u>):
        ldr     r1, .LCPI0_0
.LPC0_0:
        add     r1, pc, r1
        ldr     r0, [r1, r0, lsl #2]
        bx      lr
.LCPI0_0:
        .long   arr-(.LPC0_0+8)

arr:
        .zero   20
```

The first two `ldr` and `add` instructions load the address of `arr` into `r0`.
Then that memory is read at an offset based on the value of `i` (coming from
`r0`; the `lsl #2` multiplies the offset by 4 which is the size of an `int`) and
the result is returned.

This is in fact exactly the same code that is generated for out initial unsafe
`foo` implementation, but since the compiler prevents us from providing an
out-of-bounds index, we can be sure that no UB will occur at runtime.

# Problems

There are unfortunately some problems to working with `InRange` objects as it
is. The only way to create or assign to one is with constants known at
compile-time. On the one hand that is kind of the point, but it is also too
restrictive. We don't need to know exactly what the value is, only that it falls
within the right range.

The first thing to add would be a way of explicitly doing a bounds check that
allows transforming any old integer into an `InRange` at run-time _if_ it
satisfies the constraint:

```cpp
#include <optional>

using std::optional;

template<typename T, T n, T m>
class InRange {
private:
    InRange(T value, bool) : x(value) {}
public:
    static optional<InRange<T, n, m>> try_create(T value) {
        if (check_constraint(value)) {
            return InRange<T, n, m>(value, true);
        } else {
            return std::nullopt;
        }
    }
    //...
}
```

Now I know the point was to avoid runtime checks, but the nice thing here is
that we only have to perform it once. We could imagine a function that is part
of a public API, which is responsible for validating user input, but then
forwards the arguments internally using `InRange` to ensure safety without
further checks:

```cpp
#include <iostream>
#include "in_range.h"

safe_array<int, 100> arr;

void process(InRange<size_t, 0, 100> index) {
    std::cout 
        << "Array at " << index 
        << ": " << arr[index] << "\n";
}

int main() {
    size_t user_input;
    std::cin >> user_input;

    auto index = InRange<size_t, 0, 100>
        ::try_create(user_input);
    if (index) {
        process(*index);
    } else {
        std::cerr 
            << "Error: index out of range\n";
    }
}
```

However this still only works as long as we never transform `InRange` objects in
any way. To do any arithmetic for example we first need to get convert back to
`T`, do the arithmetic, and then convert back to `InRange`. Since we're not
working with a compile constant at that point the only way to do that is with
another `try_create`, i.e. another runtime bounds check.

In general we won't be able to get around this, because the result of e.g.
addition with an arbitrary integer can be anything. But when both operands are
of type `InRange` then we *can deduce something* about the result. For example
if we add two `InRange<int, 0, 5>` objects the result must be at least 0 and
never be more than 8. So we can implement addition like this:

```cpp
template<typename T, T n, T m>
class InRange {
public:
    //...
    template<T n2, T m2>
    InRange<T, n + n2, m + m2 - 1> operator+(InRange<T, n2, m2> y) {
        return InRange<T, n + n2, m + m2 - 1>(x + y, true);
    }
}
```

> **C++ Quiz time:** <br> Why won't this code compile yet, even with the
> addition operator overloaded?
>
> ```cpp
>
> InRange<int, 0, 19> foo(InRange<int, 0, 10> x) {
>     return x + InRange<int, 0, 10>(5);
> }
> ```
>
> ::: spoiler
>
> The non-consteval constructor is private, and the operator isn't creating an
> object of the same type as the class we are in . What we need is a `friend`
> declaration for all possible instances of the class:
>
> ```cpp
> // ...
> template<typename T, T n, T m>
> class InRange {
>    template<typename U, U a, U b>
>    friend class InRange;
> //...
> };
> ```
>
> :::
