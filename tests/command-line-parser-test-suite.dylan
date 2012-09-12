module: command-line-parser-test-suite
synopsis: Test suite for the command-line-parser  library.

//======================================================================
//
//  Copyright (c) 1998-2012 Eric Kidd and Dylan Hackers
//  All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
//  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//
//  A copy of this license may be obtained here:
//  https://raw.github.com/dylan-lang/opendylan/master/License.txt
//
//======================================================================

// Modified by Carl Gay to use the testworks library and to test
// defargparser.  Moved from src/tests to libraries/getopt/tests.
// 2006.11.29

// Now in libraries/utilities/command-line-parser/tests
// Hannes Mehnert 2007.02.23

define suite command-line-parser-test-suite
  (/* setup-function: foo, cleanup-function: bar */)
  test argument-list-parser-test;
  test defargparser-test;
end suite;


// Create a parser for our standard test argument list, parse the given
// argument list, return the parser.
define function parse (#rest argv)
  let parser = make(<argument-list-parser>);
  // Usage: progname [-qvfB] [-Q arg] [-O [arg]] [-W arg]* [-Dkey[=value]]*
  add-option-by-type(parser,
                     <flag-option>,
                     long-options: #("verbose"),
                     short-options: #("v"),
                     negative-long-options: #("quiet"),
                     negative-short-options: #("q"),
                     default: #t);
  add-option-by-type(parser,
                     <flag-option>,
                     long-options: #("foo"),
                     short-options: #("f"),
                     negative-long-options: #("no-foo"),
                     negative-short-options: #("B"),
                     default: #f);
  add-option-by-type(parser,
                     <parameter-option>,
                     long-options: #("quux"),
                     short-options: #("Q"));
  add-option-by-type(parser,
                     <optional-parameter-option>,
                     long-options: #("optimize"),
                     short-options: #("O"));
  add-option-by-type(parser,
                     <repeated-parameter-option>,
                     long-options: #("warning"),
                     short-options: #("W"));
  add-option-by-type(parser,
                     <keyed-option>,
                     long-options: #("define"),
                     short-options: #("D"));
  values(parser, parse-arguments(parser, argv))
end function parse;

define test argument-list-parser-test ()
  let (parser, parse-result) = parse("--frobozz");
  check-equal("parse-arguments returns #f for an unparsable command line",
              parse-result,
              #f);

  let (parser, parse-result) = parse("--quiet");
  check-equal("parse-arguments returns #t for a parsable command line",
              parse-result,
              #t);

  // A correct parse with all arguments specified in long format.
  let (parser, parse-result) = parse("--verbose", "--foo",
                                     "--quux", "quux-value",
                                     "--optimize=optimize-value",
                                     "--warning", "warning-value",
                                     "--define", "key", "=", "value");
  check-equal("verbose is true",
              get-option-value(parser, "verbose"),
              #t);
  check-equal("foo has correct value",
              get-option-value(parser, "foo"),
              #t);
  check-equal("quux has correct value",
              get-option-value(parser, "quux"),
              "quux-value");
  check-equal("optimize has correct value",
              get-option-value(parser, "optimize"),
              "optimize-value");
  check-equal("warning has correct value",
              get-option-value(parser, "warning"),
              #("warning-value"));
  let defines = get-option-value(parser, "define");
  check-equal("key is defined as 'value'", defines["key"], "value");
  check-true("regular arguments are empty", empty?(parser.regular-arguments));

end test argument-list-parser-test;


define argument-parser <defargparser-test-parser> ()
  synopsis print-defargparser-test-synopsis,
    usage: "test [options] file...",
    description: "Stupid test program doing nothing with the args.";
  option verbose?,
    "", "Explanation",
    short: "v",
    long: "verbose";
  option other,
    "", "foo",
    long: "other-option";
  option log-filename,
    "", "Log file pathname",
    kind: <parameter-option>,
    long: "log",
    short: "l";
  regular-arguments file-names;
end argument-parser;


define test defargparser-test ()
  let parser = make(<defargparser-test-parser>);
  parse-arguments(parser, #());
  check-false("Verbose flag is false if not supplied.",
              parser.verbose?);
  check-true("Regular arguments are empty.",
             empty?(parser.file-names));
end test defargparser-test;

// Prevent warnings for unused defs.
begin
  log-filename;
  print-defargparser-test-synopsis;
  other;
end;