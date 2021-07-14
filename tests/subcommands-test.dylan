Module: command-line-parser-test-suite


define class <subcommand-s1> (<subcommand>) end;

define test test-subcommand-parsing ()
  local method make-parser ()
          let global-a = make(<flag-option>,
                              name: "a", help: "a help");
          let global-b = make(<parameter-option>,
                              name: "b", help: "b help");
          let local-c  = make(<flag-option>,
                              name: "c", help: "c help");
          let positional-d = make(<positional-option>,
                                  name: "d", help: "d help", required?: #t);
          let positional-e = make(<positional-option>,
                                  name: "e", help: "e help", repeated?: #t);
          let s1 = make(<subcommand-s1>, name: "s1", help: "s1 help");
          add-option(s1, local-c);
          add-option(s1, positional-d);
          add-option(s1, positional-e);
          let p = make(<command-line-parser>,
                       help: "main help",
                       subcommands: list(s1));
          add-option(p, global-a);
          add-option(p, global-b);
          values(p, s1)
        end method;
  let (p, s1) = make-parser();
  assert-no-errors(parse-command-line(p, #["-a", "s1", "-c", "d", "e", "e"]));
  assert-true(get-option-value(p, "a"));
  assert-false(get-option-value(p, "b"));
  assert-true(get-option-value(s1, "c"));
  assert-equal("d", get-option-value(s1, "d"));
  assert-equal(#["e", "e"], get-option-value(s1, "e"));

  let p = make-parser();
  assert-signals(<command-line-parser-error>, parse-command-line(p, #["s1"]),
                 "missing required argument d signals error?");
end test;

// Perhaps making <subcommand> abstract was a bad idea and we should allow passing a
// "handler" function instead of writing an execute-subcommand method.
define class <subcommand-new> (<subcommand>) end;
define class <subcommand-workspace> (<subcommand>) end;
define class <subcommand-library> (<subcommand>) end;

define function make-multi-level-command ()
  let new = make(<subcommand-new>, name: "new", help: "help");
  let workspace = make(<subcommand-workspace>,
                       name: "workspace",
                       help: "help",
                       options: list(make(<flag-option>, name: "wf", help: "help"),
                                     make(<keyed-option>, name: "wk", help: "help"),
                                     make(<positional-option>,
                                          name: "name",
                                          help: "help",
                                          required?: #t)));
  let library = make(<subcommand-library>,
                     name: "library",
                     help: "help",
                     options: list(make(<parameter-option>,
                                        name: "lp",
                                        help: "help",
                                        default: "ld"),
                                   make(<positional-option>,
                                        name: "name",
                                        help: "help",
                                        required?: #t,
                                        repeated?: #t)));
  add-subcommand(new, workspace);
  add-subcommand(new, library);
  let p = make(<command-line-parser>, help: "help", subcommands: list(new));
  values(p, new, workspace, library)
end function;

define test test-subcommands-missing-positional-args ()
  let (p, new, workspace) = make-multi-level-command();
  assert-signals(<usage-error>, parse-command-line(p, #["new", "workspace"]));
  assert-equal(workspace, new.selected-subcommand);
  assert-equal(workspace, p.selected-subcommand);
end test;

define test test-subcommands-all-args-provided ()
  let (p, _, workspace) = make-multi-level-command();
  parse-command-line(p, #["new", "workspace", "--wf", "--wk", "A=B", "lib"]);
  assert-equal(workspace, p.selected-subcommand);
  assert-equal(#t, get-option-value(workspace, "wf"));
  assert-equal("B", get-option-value(workspace, "wk")["A"]);
  assert-equal("lib", get-option-value(workspace, "name"));
end test;

define test test-subcommands-too-many-positional-args ()
  let p = make-multi-level-command();
  assert-signals(<usage-error>,
                 parse-command-line(p, #["new", "workspace", "lib1", "lib2"]));
end test;

define test test-subcommands-missing-required-repeated-option ()
  // Missing required repeated option.
  let p = make-multi-level-command();
  assert-signals(<usage-error>,
                 parse-command-line(p, #["new", "library", "--lp", "lp-opt"]));
end test;

define test test-subcommands-multiple-repeated-args ()
  let (p, _, _, library) = make-multi-level-command();
  parse-command-line(p, #["new", "library", "--lp", "lp-opt", "a", "b", "c"]);
  assert-equal(library, p.selected-subcommand);
  assert-equal("lp-opt", get-option-value(library, "lp"));
  assert-equal(#["a", "b", "c"], get-option-value(library, "name"));
end test;

define test test-subcommands-support-help-option ()
  // There is no explicit condition for help being signaled so verify that it's
  // a direct instance of <abort-command-error>.
  let p = make-multi-level-command();
  block ()
    parse-command-line(p, #["new", "--help"]);
    assert-true(#f, "--help signaled an error?");
  exception (ex :: <abort-command-error>)
    assert-false(instance?(ex, <usage-error>),
                 "--help should not signal <usage-error>");
  end;
end test;

define test test-subcommands-do-not-support-help-subcommand ()
  let p = make-multi-level-command();
  assert-signals(<usage-error>, parse-command-line(p, #["new", "help"]));
end test;

define test test-subcommands-root-command-supports-help ()
  let p = make-multi-level-command();
  assert-no-errors(parse-command-line(p, #["help"]));
  assert-no-errors(parse-command-line(p, #["help", "new"]));
  assert-no-errors(parse-command-line(p, #["help", "new", "library"]));
end test;
