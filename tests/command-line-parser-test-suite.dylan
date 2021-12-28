module: command-line-parser-test-suite
synopsis: Test suite for the command-line-parser  library.
copyright: See LICENSE file in this distribution.

// TODO(cgay): Suppress output to stderr from usage errors in tests.

// #:str: syntax
define function str-parser (s :: <string>) => (s :: <string>) s end;

// Create a parser for our standard test argument list, parse the given
// argument list, return the parser.
define function make-parser ()
  let parser = make(<command-line-parser>, help: "x");
  // Usage: progname [-qvfB] [-Q arg] [-O [arg]] [-W arg]* [-Dkey[=value]]*
  add-option(parser,
             make(<flag-option>,
                  names: #("verbose", "v"),
                  negative-names: #("quiet", "q"),
                  default: #t,
                  help: "Be more or less verbose."));
  add-option(parser,
             make(<flag-option>,
                  names: #("foo", "f"),
                  negative-names: #("no-foo", "B"),
                  default: #f,
                  help: "Be more or less foonly."));
  add-option(parser,
             make(<parameter-option>,
                  names: #("quux", "Q"),
                  help: "Quuxly quacksly"));
  add-option(parser,
             make(<optional-parameter-option>,
                  names: #("optimize", "O"),
                  help: "x",
                  variable: "LEVEL"));
  add-option(parser,
             make(<repeated-parameter-option>,
                  names: #("warning", "W"),
                  help: "x"));
  add-option(parser,
             make(<keyed-option>,
                  names: #("define", "D"),
                  help: "x"));
  parser
end function make-parser;

define function parse (#rest argv)
  let parser = make-parser();
  parse-command-line(parser, argv);
  parser
end function;

define test test-command-line-parser ()
  check-condition("blah", <usage-error>, parse("--bad-option-no-donut"));

  // A correct parse with all arguments specified in long format.
  let parser = parse("--verbose", "--foo",
                     "--quux", "quux-value",
                     "--optimize=optimize-value",
                     "--warning", "warning-value",
                     "--warning", "warning-value2",
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
              #("warning-value", "warning-value2"));
  let defines = get-option-value(parser, "define");
  check-equal("key is defined as 'value'", defines["key"], "value");
  check-true("positional options are empty",
             empty?(parser.positional-options));
end test test-command-line-parser;

// This test is pretty brittle.  Would be good to make it ignore whitespace to
// some extent. It verifies the basic formatting and that the options are
// displayed in the order they were added to the parser.
//
// TODO(cgay): test subcommand help
define test test-synopsis-format ()
  let parser = make-parser();
  let synopsis = with-output-to-string (stream)
                   print-help(parser, stream: stream)
                 end;
  let expected = #:str:"x

Usage: %s [options]

Options:
  -h, --help                   Display this message.
  -v, -q, --verbose, --quiet   Be more or less verbose.
  -f, -B, --foo, --no-foo      Be more or less foonly.
  -Q, --quux QUUX              Quuxly quacksly
  -O, --optimize LEVEL         x
  -W, --warning WARNING        x
  -D, --define DEFINE          x
";
  assert-equal(format-to-string(expected, program-name()), synopsis);
end;

define test test-help-substitutions ()
  let option = make(<flag-option>,
                    names: #("flag"),
                    default: #t,
                    // %default% => #t, %prog% => %prog%, %app% => app name
                    help: "%default% %prog% %app%");
  assert-equal(format-to-string("#t %%prog%% %s", program-name()),
               option.option-help);
end;

// Verify that the usage: and description: passed to parse-command-line
// are displayed correctly.
define test test-usage ()
  let parser = make(<command-line-parser>, help: "x");
  add-option(parser, make(<flag-option>,
                          names: #("x"),
                          help: "x"));
  dynamic-bind (*standard-output* = make(<string-stream>,
                                         direction: #"output"))
    assert-signals(<abort-command-error>,
                   parse-command-line(parser, #("--help")));
    let actual = *standard-output*.stream-contents;
    let expected = "x\n\nUsage:";
  assert-true(starts-with?(actual, expected),
              format-to-string("%= starts with %=?", actual, expected))
  end;
end test;


define test test-duplicate-name-error ()
  let parser = make(<command-line-parser>,
                    help: "a parser");
  add-option(parser, make(<flag-option>,
                          names: #("x"),
                          help: "x"));
  assert-signals(<command-line-parser-error>,
                 add-option(parser, make(<flag-option>,
                                         names: #("x"),
                                         help: "x")));
end test;

define test test-option-type ()
  local method make-parser ()
          let parser = make(<command-line-parser>, help: "a parser");
          add-option(parser, make(<parameter-option>,
                                  names: #("integer"),
                                  type: <integer>,
                                  help: "x"));
          add-option(parser, make(<parameter-option>,
                                  help: "x",
                                  names: #("sequence"),
                                  type: <sequence>));
          add-option(parser, make(<parameter-option>,
                                  help: "x",
                                  names: #("list"),
                                  type: <list>));
          add-option(parser, make(<parameter-option>,
                                  help: "x",
                                  names: #("vector"),
                                  type: <vector>));
          add-option(parser, make(<parameter-option>,
                                  help: "x",
                                  names: #("symbol"),
                                  type: <symbol>));
          add-option(parser, make(<parameter-option>,
                                  help: "x",
                                  names: #("number"),
                                  type: <number>));
          add-option(parser, make(<parameter-option>,
                                  help: "x",
                                  names: #("real"),
                                  type: <real>));
          add-option(parser, make(<parameter-option>,
                                  help: "x",
                                  names: #("string"),
                                  type: <string>)); // uses default case, no conversion
          add-option(parser, make(<repeated-parameter-option>,
                                  help: "x",
                                  names: #("repeated-integer"),
                                  type: <integer>));
          parser
        end method make-parser;
  let items = list(list("integer", "123", 123, <integer>),
                   list("integer", "0123", #o123, <integer>),
                   list("integer", "0x123", #x123, <integer>),
                   list("sequence", "1,2,3", #["1", "2", "3"], <sequence>),
                   list("list", "1,2,3", #("1", "2", "3"), <list>),
                   list("vector", "1,2,3", #["1", "2", "3"], <vector>),
                   list("symbol", "foo", #"foo", <symbol>),
                   list("number", "123", 123, <integer>),
                   list("real", "123", 123, <integer>),
                   list("string", "bar", "bar", <string>));
  for (item in items)
    let (name, param, expected-value, expected-type) = apply(values, item);
    let parser = make-parser();
    parse-command-line(parser, list(concatenate("--", name), param));
    check-equal(name, expected-value, get-option-value(parser, name));
  end;
  begin
    let name = "repeated-integer";
    let option = concatenate("--", name);
    let parser = make-parser();
    parse-command-line(parser, vector(option, "1", option, "2", option, "3"));
    check-equal(name, #[1, 2, 3], get-option-value(parser, name));
  end;
end test test-option-type;

define test test-option-default ()
  let parser = make(<command-line-parser>, help: "a parser");
  check-condition("bad default", <command-line-parser-error>,
                  add-option(parser, make(<parameter-option>,
                                          help: "x",
                                          names: #["foo"],
                                          type: <integer>,
                                          default: "string")));
  check-no-condition("good default",
                     add-option(parser, make(<parameter-option>,
                                             help: "x",
                                             names: #["bar"],
                                             type: <integer>,
                                             default: 1234)));
  check-condition("bad default for repeated option", <command-line-parser-error>,
                  add-option(parser, make(<repeated-parameter-option>,
                                          help: "x",
                                          names: #["baz"],
                                          type: <integer>,
                                          default: 1234)));
  check-no-condition("good default for repeated option",
                     add-option(parser, make(<repeated-parameter-option>,
                                             help: "x",
                                             names: #["fez"],
                                             type: <integer>,
                                             default: #[1, 2, 3, 4])));
end test test-option-default;


define command-line <defcmdline-test-parser> ()
  option defcmdline-verbose? :: <boolean>,
    names: #("v", "verbose"),
    help: "Explanation",
    kind: <flag-option>;
  option defcmdline-other,
    names: #("other"),
    help: "Other stuff";
  option defcmdline-log-filename :: <string>,
    names: #("log", "l"),
    kind: <parameter-option>,
    variable: "<file>",
    help: "Log file pathname";
end command-line;

ignorable(defcmdline-log-filename);
ignorable(defcmdline-other);

define test test-defcmdline ()
  let parser = make(<defcmdline-test-parser>, help: "x");
  assert-false(parser.defcmdline-verbose?);
  assert-false(parser.defcmdline-other);
  assert-false(parser.defcmdline-log-filename);

  parse-command-line(parser, #["-v", "--other", "--log", "/tmp/log"]);
  assert-true(parser.defcmdline-verbose?);
  assert-true(parser.defcmdline-other);
  assert-equal("/tmp/log", parser.defcmdline-log-filename);
end test;

define test test-min-max-positional-arguments ()
  local
    method make-parser ()
      make(<command-line-parser>,
           help: "x",
           options: list(make(<positional-option>,
                              name: "p1",
                              help: "x"),
                         make(<positional-option>,
                              name: "p2",
                              help: "x",
                              required?: #f)))
    end;
  assert-signals(<usage-error>, parse-command-line(make-parser(), #[]));

  let p = make-parser();
  assert-no-errors(parse-command-line(p, #["a"]));
  assert-equal("a", get-option-value(p, "p1"));
  assert-false(get-option-value(p, "p2"));

  let p = make-parser();
  assert-no-errors(parse-command-line(p, #["a", "b"]));
  assert-equal("a", get-option-value(p, "p1"));
  assert-equal("b", get-option-value(p, "p2"));

  assert-signals(<usage-error>,
                 parse-command-line(make-parser(), #["a", "b", "c"]));
  assert-signals(<abort-command-error>,
                 parse-command-line(make-parser(), #["-h"]));
end test;
