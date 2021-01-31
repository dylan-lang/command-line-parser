module: command-line-parser-test-suite
synopsis: Test suite for the command-line-parser  library.
copyright: See LICENSE file in this distribution.

// TODO(cgay): Suppress output to stderr from usage errors in tests.


// Create a parser for our standard test argument list, parse the given
// argument list, return the parser.
define function make-parser ()
  let parser = make(<command-line-parser>);
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
                  variable: "LEVEL"));
  add-option(parser,
             make(<repeated-parameter-option>,
                  names: #("warning", "W")));
  add-option(parser,
             make(<keyed-option>,
                  names: #("define", "D")));
  parser
end function make-parser;

define function parse (#rest argv)
  let parser = make-parser();
  values(parser, parse-command-line(parser, argv))
end;

define test test-command-line-parser ()
  check-condition("blah", <usage-error>, parse("--bad-option-no-donut"));

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
  check-true("positional options are empty",
             empty?(parser.positional-options));
end test test-command-line-parser;

// This test is pretty brittle.  Would be good to make it ignore
// whitespace to some extent.
define test test-synopsis-format ()
  let parser = make-parser();
  let synopsis = with-output-to-string (stream)
                   print-synopsis(parser, stream,
                                  usage: "Usage: foo",
                                  description: "ABCDEFG")
                 end;
  let expected = "Usage: foo\n"
                 "ABCDEFG\n"
                 "  -v, -q, --verbose, --quiet   Be more or less verbose.\n"
                 "  -f, -B, --foo, --no-foo      Be more or less foonly.\n"
                 "  -Q, --quux QUUX              Quuxly quacksly\n"
                 "  -O, --optimize LEVEL         \n"
                 "  -W, --warning WARNING        \n"
                 "  -D, --define DEFINE          \n";
  check-equal("synopsis same?", expected, synopsis);
end;

define test test-help-substitutions ()
  let option = make(<flag-option>,
                    names: #("flag"),
                    default: #t,
                    help: "%%%default%%prog%");
  check-equal("", "%#t%prog%", option.option-help);
end;

// Verify that the usage: and description: passed to parse-command-line
// are displayed correctly.
define test test-usage ()
  let parser = make(<command-line-parser>);
  add-option(parser, make(<flag-option>, names: #("x")));
  dynamic-bind (*standard-output* = make(<string-stream>,
                                         direction: #"output"))
    check-condition("", <help-requested>,
                    parse-command-line(parser, #("--help"),
                                       usage: "u", description: "d"));
    let actual = *standard-output*.stream-contents;
    let expected = "u\nd\n";
    check-true(format-to-string("%= starts with %=?", actual, expected),
               starts-with?(actual, expected));
  end;
end test;


define test test-duplicate-name-error ()
  let parser = make(<command-line-parser>);
  add-option(parser, make(<flag-option>, names: #("x")));
  check-condition("", <command-line-parser-error>,
                  add-option(parser, make(<flag-option>, names: #("x"))));
end;

define test test-option-type ()
  local method make-parser ()
          let parser = make(<command-line-parser>);
          add-option(parser, make(<parameter-option>,
                                  names: #("integer"),
                                  type: <integer>));
          add-option(parser, make(<parameter-option>,
                                  names: #("sequence"),
                                  type: <sequence>));
          add-option(parser, make(<parameter-option>,
                                  names: #("list"),
                                  type: <list>));
          add-option(parser, make(<parameter-option>,
                                  names: #("vector"),
                                  type: <vector>));
          add-option(parser, make(<parameter-option>,
                                  names: #("symbol"),
                                  type: <symbol>));
          add-option(parser, make(<parameter-option>,
                                  names: #("number"),
                                  type: <number>));
          add-option(parser, make(<parameter-option>,
                                  names: #("real"),
                                  type: <real>));
          add-option(parser, make(<parameter-option>,
                                  names: #("string"),
                                  type: <string>)); // uses default case, no conversion
          add-option(parser, make(<repeated-parameter-option>,
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
  let parser = make(<command-line-parser>);
  check-condition("bad default", <command-line-parser-error>,
                  add-option(parser, make(<parameter-option>,
                                          names: #("foo"),
                                          type: <integer>,
                                          default: "string")));
  check-no-condition("good default",
                     add-option(parser, make(<parameter-option>,
                                             names: #("bar"),
                                             type: <integer>,
                                             default: 1234)));
  check-condition("bad default for repeated option", <command-line-parser-error>,
                  add-option(parser, make(<repeated-parameter-option>,
                                          names: #("baz"),
                                          type: <integer>,
                                          default: 1234)));
  check-no-condition("good default for repeated option",
                     add-option(parser, make(<repeated-parameter-option>,
                                             names: #("fez"),
                                             type: <integer>,
                                             default: #[1, 2, 3, 4])));
end test test-option-default;


define test test-choice-option ()
  let parser = make(<command-line-parser>);
  add-option(parser, make(<choice-option>,
                          names: #("foo"),
                          choices: #("a", "b"),
                          test: string-equal-ic?));
  check-condition("bad choice", <usage-error>,
                  parse-command-line(parser, #("--foo=x")));

  check-no-condition("good 1", parse-command-line(parser, #("--foo=a")));
  check-equal("", "a", get-option-value(parser, "foo"));

  check-no-condition("nocase test", parse-command-line(parser, #("--foo=B")));
  check-equal("nocase value", "B", get-option-value(parser, "foo"));
end;

define command-line <defcmdline-test-parser> ()
  synopsis "test [options] file...",
    description: "Stupid test program doing nothing with the args.";
  option verbose?, names: #("v", "verbose"),
    help: "Explanation";
  option other, names: #("other-option"),
    help: "foo";
  option log-filename, names: #("log", "l"),
    help: "Log file pathname",
    kind: <parameter-option>;
  positional-options file-names;
end command-line;


define test test-defcmdline ()
  let parser = make(<defcmdline-test-parser>);
  parse-command-line(parser, #());
  check-false("Verbose flag is false if not supplied.",
              parser.verbose?);
  check-true("Positional options are empty.",
             empty?(parser.file-names));
end test test-defcmdline;

// Prevent warnings for unused defs.
ignore(log-filename);
ignore(other);

define test test-min-max-positional-options ()
  let parser = make(<command-line-parser>,
                    min-positional-options: 1,
                    max-positional-options: 2);
  assert-signals(<usage-error>, parse-command-line(parser, #[]), "xyz");
  assert-no-errors(parse-command-line(parser, #["a"]), "abc");
  assert-no-errors(parse-command-line(parser, #["a", "b"]), "xxx");
  assert-signals(<usage-error>, parse-command-line(parser, #["a", "b", "c"]), "yyy");
  assert-signals(<help-requested>, parse-command-line(parser, #["-h"]));
end test test-min-max-positional-options;
