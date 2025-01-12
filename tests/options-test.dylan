Module: command-line-parser-test-suite

// Note: when debugging tests it can be useful to wrap them in
//   block ()
//     ...
//   exception (ex :: <usage-error>)
//     signal(make(<simple-error>, ...))
//   end;
// so that Testworks' --debug=crashes works. This is only an issue when debugging
// command-line-parser tests. We might want to just wrap them all in a macro that
// does that.

define method parse-one (option, argv)
  let p = make(<command-line-parser>,
               help: "x",
               options: list(option));
  parse-command-line(p, argv);
  p
end;

define test test-flag-option ()
  assert-false(option-value(make(<flag-option>, name: "x", help: "x")),
               "boolean flag defaults to false?");
  local
    method parse (default, argv)
      let p = make(<command-line-parser>,
                   help: "x",
                   options: list(make(<flag-option>,
                                      names: #("verbose", "v"),
                                      help: "x",
                                      negative-names: #("quiet", "q"),
                                      default: default)));
      parse-command-line(p, argv);
      p
    end;
  for (item in list(/* list(#f, #["--verbose"], #t),
                    list(#t, #["--verbose"], #t),
                    list(#f, #["-v"],        #t),
                    list(#f, #["--quiet"],   #f), */
                    list(#t, #["--quiet"],   #f) /* ,
                    list(#f, #["-q"],        #f) */ ))
    let (default, argv, want) = apply(values, item);
    assert-equal(want,
                 get-option-value(parse(default, argv), "verbose"),
                 item);
  end;
end test;

define test test-parameter-option ()
  local
    method parse (argv)
      let p = make(<command-line-parser>, help: "x");
      add-option(p, make(<parameter-option>,
                         names: #("airport", "a"),
                         help: "x"));
      parse-command-line(p, argv);
      p
    end;
  // I've never seen any command line parser handle '=' with spaces around it.
  // Or maybe they do and I've just never seen it used? Should we even support
  // that? --cgay
  for (argv in list(vector("--airport", "BOS"),
                    vector("--airport=BOS"),
                    vector("--airport", "=", "BOS"),
                    vector("-aBOS"),
                    vector("-a=BOS"),
                    vector("-a", "=", "BOS")))
    let parser = parse(argv);
    assert-equal("BOS", get-option-value(parser, "airport"),
                 format-to-string("argv = %=", argv));
    assert-equal("BOS", get-option-value(parser, "a"),
                 format-to-string("argv = %=", argv));
  end;
end test;

define test test-keyed-option ()
  local method opt ()
          // Make a new one each time to ensure option-value slot cleared.
          make(<keyed-option>, names: #("define", "D"), help: "help")
        end;
  let cmd = parse-one(opt(), #[]);
  assert-true(empty?(get-option-value(cmd, "define")));
  assert-true(empty?(get-option-value(cmd, "D")));

  // When no "=value" given value defaults to #t?
  let cmd = parse-one(opt(), #["-Dkey"]);
  assert-equal(1, size(get-option-value(cmd, "D")));
  assert-equal(#t, get-option-value(cmd, "define")["key"]);

  // The rest should all set "key" => "value".
  for (args in #(#("-Dkey=value"),
                 #("-D", "key=value"),
                 #("-D", "key", "=", "value"),
                 #("--define", "key=value"),
                 #("--define", "key", "=", "value")))
    let cmd = parse-one(opt(), args);
    let table = get-option-value(cmd, "define");
    assert-true(table);
    assert-equal(1, size(table));
    assert-equal("value", table["key"]);
  end;
end test;

define test test-repeated-parameter-option ()
  let command = parse-one(make(<repeated-parameter-option>, name: "r", help: "help"),
                          #["-r", "a"]);
  assert-equal(as(<deque>, #["a"]), get-option-value(command, "r"));
end;

define test test-optional-parameter-option ()
end;

define test test-choice-option ()
  let name = "choice";
  local method opt (default)
          make(<choice-option>,
               name: name,
               choices: list("a", "b", "c"),
               default: default,
               help: "-")
        end;
  assert-equal("a",
               get-option-value(parse-one(opt("b"), #["--choice", "a"]), name),
               "valid value parses correctly");
  assert-signals(<usage-error>,
                 parse-one(opt("b"), #["--choice", "x"]),
                 "invalid value signals <usage-error>");
  assert-equal("b",
               get-option-value(parse-one(opt("b"), #[]), name),
               "default value is correct");

  // In general (for all options) we don't enforce that the default value must
  // be part of the option.option-type type, primarily so that they can default
  // to #f.
  assert-no-errors(make(<parameter-option>,
                        names: "n",
                        type: <integer>,
                        default: #f, // testing this doesn't signal
                        help: "h"));
end test;

define class <subcommand-a> (<subcommand>) end;

define test test-positional-option-validation ()
  let required-a = make(<positional-option>,
                        names: "a", help: "h", required?: #t, repeated?: #f);
  let required-b = make(<positional-option>,
                        names: "b", help: "h", required?: #t, repeated?: #f);
  let optional-c = make(<positional-option>,
                        names: "c", help: "h", required?: #f, repeated?: #f);
  let optional-d = make(<positional-option>,
                        names: "d", help: "h", required?: #f, repeated?: #f);
  let required-repeated-e = make(<positional-option>,
                                 names: "e", help: "h", required?: #t, repeated?: #t);
  let optional-repeated-f = make(<positional-option>,
                                 names: "e", help: "h", required?: #f, repeated?: #t);
  let flag = make(<flag-option>, names: "flag", help: "h");

  let valid-cases = list(list(flag, required-a, required-b),
                         list(required-a, optional-c),
                         list(required-a, optional-c, optional-d),
                         list(required-a, optional-c, optional-repeated-f),
                         list(optional-c, optional-d),
                         list(optional-repeated-f),
                         list(required-repeated-e));
  for (opts in valid-cases)
    assert-no-errors(make(<command-line-parser>, help: "h", options: opts),
                     format-to-string("valid case %=", opts));
    assert-no-errors(make(<subcommand-a>, name: "sub", help: "h", options: opts),
                     format-to-string("valid case (subcommand) %=", opts));
  end;

  let error-cases = list(list(optional-c, required-a),
                         list(required-repeated-e, required-a),
                         list(optional-repeated-f, required-a),
                         list(optional-repeated-f, required-a),
                         list(optional-repeated-f, optional-c));
  for (opts in error-cases)
    assert-signals(<command-line-parser-error>,
                   make(<command-line-parser>, help: "h", options: opts),
                   format-to-string("error case %=", opts));
    assert-signals(<command-line-parser-error>,
                   make(<subcommand-a>, name: "sub", help: "h", options: opts),
                   format-to-string("error case (subcommand) %=", opts));
  end;

  // Subcommands and positionals can't be added to the top-level parser.
  let sub = make(<subcommand-a>, help: "h", name: "a");
  assert-signals(<command-line-parser-error>,
                 make(<command-line-parser>,
                      help: "h",
                      options: list(required-a),
                      subcommands: list(sub)),
                 "subcommands and required positionals");
  assert-signals(<command-line-parser-error>,
                 make(<command-line-parser>,
                      help: "h",
                      options: list(optional-c),
                      subcommands: list(sub)),
                 "subcommands and optional positionals");
end test;

define test test-positional-option-parsing ()
  let p1 = make(<positional-option>, names: "p1", help: "h", required?: #t);
  let p2 = make(<positional-option>, names: "p2", help: "h", required?: #t);
  let p3 = make(<positional-option>, names: "p3", help: "h", required?: #f);
  let p4 = make(<positional-option>, names: "p4", help: "h", required?: #f);
  let p5 = make(<positional-option>, names: "p5", help: "h", required?: #f, repeated?: #t);
  let cmd = make(<command-line-parser>,
                 help: "h",
                 options: list(make(<flag-option>, names: "flag", help: "h"),
                               p1, p2, p3, p4, p5));
  assert-no-errors(parse-command-line(cmd, #["a", "b", "c", "d", "e", "f"]));
  assert-equal("a", p1.option-value);
  assert-equal("b", p2.option-value);
  assert-equal("c", p3.option-value);
  assert-equal("d", p4.option-value);
  assert-equal(#["e", "f"], p5.option-value);
end test;

define test test-unconsumed-arguments ()
  let p1 = make(<positional-option>, name: "p1", help: "?", required?: #f);
  let cmd1 = make(<command-line-parser>, help: "?", options: list(p1));
  assert-no-errors(parse-command-line(cmd1, #["x", "--", "y", "z"]));
  assert-equal(#["y", "z"], cmd1.unconsumed-arguments);
  assert-no-errors(parse-command-line(cmd1, #["--", "y", "z"]));
  assert-equal(#["y", "z"], cmd1.unconsumed-arguments);

  // Same assertions but with the final positional option allowing more than one arg.
  let p2 = make(<positional-option>, name: "p1", help: "?", required?: #f, repeated?: #t);
  let cmd2 = make(<command-line-parser>, help: "?", options: list(p2));
  assert-no-errors(parse-command-line(cmd2, #["x", "--", "y", "z"]));
  assert-equal(#["y", "z"], cmd2.unconsumed-arguments);
  assert-no-errors(parse-command-line(cmd2, #["--", "y", "z"]));
  assert-equal(#["y", "z"], cmd2.unconsumed-arguments);
end test;
