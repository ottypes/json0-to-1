# JSON0 to JSON1 Operation conversion library

> TODO: This needs some all around love. Its missing packaging and a proper test suite. It works, but you're on your own using this for the moment! Sorry.

This is a simple library function to convert from
[JSON0](https://github.com/ottypes/json0) to
[JSON1](https://github.com/ottypes/json1) operations. This code is currently
missing tests, but should be correct.

Note that JSON0 and JSON1 use slightly incompatible string types. If you're
using embedded string edits, you can either convert json0 ot-text string edits
to ot-text-unicode json1 string edits (TODO standard function for this) or
register & embed ot-text edits in JSON1.



## License

Copyright (c) 2013-2018, Joseph Gentle &lt;me@josephg.com&gt;

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.

