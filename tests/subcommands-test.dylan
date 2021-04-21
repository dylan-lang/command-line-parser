Module: command-line-parser-test-suite


define class <subcommand-s1> (<subcommand>) end;

define test test-subcommand-parsing ()
  let global-a = make(<flag-option>, names: #("a"), help: "a help");
  let global-b = make(<parameter-option>, names: #("b"), help: "b help");
  let local-c  = make(<flag-option>, names: #("c"), help: "c help");
  let positional-d = make(<positional-option>, names: #("d"), help: "d help");
  let positional-e = make(<positional-option>,
                          repeated?: #t, names: #("e"), help: "e help");
  let s1 = make(<subcommand-s1>, name: "s1", help: "s1 help");
  add-option(s1, local-c);
  add-option(s1, positional-d);
  add-option(s1, positional-e);
  let p = make(<command-line-parser>,
               help: "main help",
               subcommands: list(s1));
  add-option(p, global-a);
  add-option(p, global-b);

  // Done with setup

  assert-no-errors(parse-command-line(p, #["-a", "s1", "-c", "d", "e", "e"]));
  assert-true(get-option-value(p, "a"));
  assert-false(get-option-value(p, "b"));
  assert-true(get-option-value(s1, "c"));
  assert-equal("d", get-option-value(s1, "d"));
  assert-equal(#["e", "e"], get-option-value(s1, "e"));
end test;
