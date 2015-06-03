# Introduction

This is a "simple as possible" set of DCG rules based upon the
contents of the page at [json.org](http://json.org), outlining the
JSON format we all know and love.

## TODO: Things I might need / want to add in a future version

 - having a callback predicate perform conversion on extracted
    terms for greater control of the final returned structure.

 - much better error handling insead of "fail"



# Caveats about JSON to Prolog term conversion

As always, converting between systems and formats always has issues
and GNU Prolog and JSON present their own special recipe.


## Objects

An object in JSON is presented as a bunch of keys and values within
curly braces, in Prolog I have used a function and a KV list liek so:

    obj([key1-value1, key2-value2, ...]).

Present your terms like that and everything should be fine. See the
source file `json_encode.pl` for a full explanation and some examples
that should hopefully explain it all.


## Arrays

The GNU Prolog list `[]` is used to hold the contents of a JSON
array. This is a pretty good fit and needs no more documentation
really. So, to encode a list of numbers in an object you might present
this to `json_encode/2`:

obj([numbers-[10, 20, 999]).


## Strings

Strings in GNU Prolog look *exactly like lists* so in order to
preserve the fact that a string was decoded, the functor `str()` is
used, it will contain the list of character codes.

Conversely you must wrap anything intended to be converted into a
string in the same functor, for example:

    obj([message-str("Hello World")]).

There is no deep inspection of the string data, it is passed through to the JSON so *be sure you know what is in it!* or you might get strange errors when the client consumes it. What this means though is that if you do this:

    obj([text-"I am\nsplit over\t\ta couple\nof lines!"]).

Then because GNU Prolog will have already converted the \n and \t
characters for you by the time the encoder gets hold of it, everything
will work out as expected.


### UTF-8 Support

GNU Prolog does not yet support UTF-8 encoding however, *UTF-8 is
opaquely supported* in that only the enclosing double quote and
backslash-double-quote are important during parsing. The end result is
that any byte sequence can be enclosed in the string and it will be
preserved after parsing.



## Numbers

JSON doesn't have integers, all numbers are floating point. In my
initial version I was converting numbers into real terms but this has
representation issues. If a client sends the value "3.14" then it
would be handed back as 3.1400000000000001 which may or may not cause
application level problems.

I took the decision therefore to return non-integer numbers as the
type `[character_code]` but wrapped in the functor `n()`, so 3.14
would be given as `n("3.14")`, or more literally
`n([51,46,49,52])`. This *only applies to fractional numbers*. The
value 42 would be treated as the number 42. I hope that makes
sense. It's easier to use than to explain!

*If the application code wants a number then it will have to do the
conversion as and when required.*


# Feedback

Us and abuse. Again, YMMV, it might contains bugs and aother flaws so
if you find anything wrong or want an addition or suggest an
improvement please get in touch.
