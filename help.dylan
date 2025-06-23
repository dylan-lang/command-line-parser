Module: command-line-parser
Synopsis: Implements the --help flag and help subcommand


// TODO(cgay): Automatically display option default values. It's too easy to
// forget to add %default% to the help string.

define function program-name () => (name :: <string>)
  locator-base(as(<file-locator>, application-name()))
end function;

define method command-help
    (cmd :: <command>) => (help :: <string>)
  let result = cmd.%command-help;
  for (subst in *pattern-substitutions*)
    let replacement = subst.substitution-function(result);
    if (replacement)
      result := replace-substrings(result, subst.substitution-pattern, replacement);
    end;
  end;
  result
end method;

// make open generic?
define function add-help-subcommand
    (parser :: <command-line-parser>) => ()
  add-subcommand(parser,
                 make(<help-subcommand>,
                      name: "help",
                      help: "Display help for a subcommand.",
                      options: list(make(<positional-option>,
                                         name: "subcommand",
                                         required?: #f,
                                         repeated?: #t,
                                         help: "A subcommand name."))))
end function;

// TODO(cgay): we also have canonical-option-name, but I don't like it; it's
// overkill. Need to have a look at format-option-usage...
define function canonical-name
    (option :: <option>) => (name :: <string>)
  option.option-names[0]
end function;

define method option-help
    (option :: <option>) => (help :: <string>)
  let result = option.%option-help;
  for (subst in *pattern-substitutions*)
    let replacement = subst.substitution-function(option);
    result := replace-substrings(result, subst.substitution-pattern, replacement);
  end;
  result
end method;

define method option-variable
    (option :: <option>) => (variable-name :: <string>)
  option.%option-variable
    | uppercase(canonical-name(option))
end;

define class <help-subcommand> (<subcommand>)
  keyword name = "help";
  keyword help = "Display help message for a subcommand.";
end class;

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <help-subcommand>)
 => (status :: false-or(<integer>));
  let name = get-option-value(subcmd, "subcommand");
  if (name)
    let subcmd = find-subcommand(parser, name);
    if (subcmd)
      print-help(subcmd);
    else
      usage-error("Subcommand %= not found.", join(name, " "));
    end;
  else
    print-help(parser);         // 'app help' same as 'app --help'
  end;
end method;

// This has a class of its own so that the help option doesn't have to be
// identified by name (which should be user settable).
define open class <help-option> (<flag-option>)
end;

// make open generic?
define function add-help-option
    (parser :: <command>) => ()
  add-option(parser, make(<help-option>,
                          names: #("help", "h"),
                          help: "Display this message."));
end function;

define class <substitution> (<object>)
  constant slot substitution-pattern :: <string>, required-init-keyword: pattern:;
  constant slot substitution-function :: <function>, required-init-keyword: function:;
end class;

// TODO(cgay): "%choices%"
define variable *pattern-substitutions*
  = list(make(<substitution>,
              pattern: "%default%",
              function: method (option)
                          if (instance?(option, <option>))
                            // TODO(cgay): Make <boolean>s print as true/false in
                            // %default% substitutions.  There's some subtlety for
                            // <flag-option> because of negative options.
                            // Make a format-option-value generic?
                            format-to-string("%s", option.option-default)
                          end
                        end),
         make(<substitution>,
              pattern: "%app%",
              function: always(program-name())));

// For use by extension modules.
define function add-pattern-substitution
    (pattern :: <string>, fn :: <function>) => ()
  *pattern-substitutions*
    := concatenate(*pattern-substitutions*,
                   make(<substitution>, pattern: pattern, function: fn));
end function;

define method visible-option-name
    (raw-name :: <string>) => (dash-name :: <string>)
  concatenate(if (raw-name.size = 1) "-" else "--" end, raw-name)
end;

define method canonical-option-name
    (option :: <option>, #key plain?) => (dash-name :: <string>)
  if (plain?)
    option.option-names.first
  else
    option.option-names.first.visible-option-name
  end
end;

// Return a string showing how this option is used on the command-line.
// TODO(cgay): this is not called. I probably broke it at some point.
// I think it should affect the way the option is displayed in the Options:
// table. e.g., "--flag[=yes/no]"
define open generic format-option-usage
    (option :: <option>) => (usage :: <string>);

define method format-option-usage
    (option :: <option>) => (usage :: <string>)
  option.canonical-option-name
end;

define function print-help
    (cmd :: <command>, #key stream :: <stream> = *standard-output*)
  format(stream, "%s\n", command-help(cmd));
  format(stream, "\n%s\n", generate-usage(cmd));
  print-options(cmd, stream);
  if (cmd.has-subcommands?)
    format(stream, "\nSubcommands:\n");
    let rows = subcommand-rows(cmd);
    if (~empty?(rows))
      columnize(stream, $subcommand-columns, rows);
      new-line(stream);
    end;
    let help-subcommand = find-subcommand(cmd, <help-subcommand>);
    if (help-subcommand)
      new-line(stream);
      format(stream, "Use '%s %s <cmd> [<cmd> ...]' to see subcommand options.\n",
             program-name(), subcommand-name(help-subcommand));
    end;
  end;
  if (~instance?(cmd, <command-line-parser>))
    let help-option = find-option(cmd, <help-option>);
    if (help-option)
      new-line(stream);
      format(stream, "Use '%s %s' to see global options.\n",
             program-name(), help-option.canonical-name.visible-option-name);
    end;
  end;
end function;

define function print-options
    (cmd :: <command>, stream :: <stream>) => ()
  // Column widths are chosen to have a max table width of 79 until columnist can
  // determine the screen width.
  let o-rows = option-rows(cmd);
  if (~empty?(o-rows))
    format(stream, "\nOptions:\n");
    columnize(stream, $optional-options-columns, o-rows);
    new-line(stream);
  end;
  let p-rows = positional-option-rows(cmd);
  if (~empty?(p-rows))
    format(stream, "\nPositional arguments:\n");
    columnize(stream, $positional-option-columns, p-rows);
    new-line(stream);
  end;
end function;

define constant $positional-option-columns
  = list(make(<column>),
         make(<column>, maximum-width: 25),
         make(<column>, maximum-width: 50, pad?: #f));

define function positional-option-rows
    (cmd :: <command>) => (rows :: <sequence>)
  let rows = make(<stretchy-vector>);
  for (opt in cmd.positional-options)
    let name = opt.option-variable;
    if (opt.option-repeated?)
      name := concatenate(name, "...");
    end;
    add!(rows, list("", name, opt.option-help));
  end;
  rows
end function;

define constant $optional-options-columns
  = list(make(<column>),                    // empty string, creates column border
         make(<column>),                    // short option names
         make(<column>, maximum-width: 25),            // long option names
         make(<column>, maximum-width: 50, pad?: #f)); // docs

// Return rows of #[short-names, long-names, documentation]
define function option-rows
    (parser :: <command>) => (rows :: <sequence>)
  let rows = make(<stretchy-vector>);
  for (option in parser.pass-by-name-options)
    let flag? = instance?(option, <flag-option>);
    add!(rows,
         vector("",             // causes a two space indent
                join(map(visible-option-name, option.short-names), ", "),
                join(map(method (name)
                           concatenate(visible-option-name(name),
                                       flag? & "" | "=",
                                       flag? & "" | (option.option-variable
                                                       | canonical-name(option)))
                         end,
                         option.long-names),
                     " "),
                option.option-help));
  end for;
  rows
end function;

define constant $subcommand-columns
  = list(make(<column>),        // empty string, creates column border
         make(<column>),        // subcommand name
         make(<column>,         // subcommand doc
              maximum-width: 50, pad?: #f));

define function subcommand-rows
    (cmd :: <command>) => (rows :: <sequence>)
  let rows = make(<stretchy-vector>);
  iterate loop (subs = as(<list>, cmd.command-subcommands), indent = "")
    if (~empty?(subs))
      let subcmd = subs[0];
      add!(rows, list("",
                      concatenate(indent, subcmd.subcommand-name),
                      subcmd.command-help));
      if (subcmd.has-subcommands?)
        loop(subcmd.command-subcommands, concatenate(indent, "  "));
      end;
      loop(tail(subs), indent)
    end;
  end iterate;
  rows
end function;

// Generate a one-line usage message showing the order of options and arguments.
define generic generate-usage
    (cmd :: <command>) => (usage :: <string>);

define method generate-usage
    (cmd :: <command-line-parser>) => (usage :: <string>)
  with-output-to-string (stream)
    // Be careful to show where the two sets of options (global/sub) must go.
    let subs? = cmd.has-subcommands?;
    format(stream, "Usage: %s", program-name());
    if (cmd.pass-by-name-options.size > 0)
      format(stream, " [options]");
    end;
    if (subs?)
      format(stream, " <cmd> [cmd options] args...")
    end;
    print-positional-args(stream, cmd);
  end
end method;

define method generate-usage
    (subcmd :: <subcommand>) => (usage :: <string>)
  with-output-to-string (stream)
    format(stream, "Usage: %s %s%s", program-name(), subcommand-name(subcmd),
           if (subcmd.pass-by-name-options.size > 0)
             " [options]"
           else
             ""
           end);
    print-positional-args(stream, subcmd);
  end;
end method;

define function print-positional-args
    (stream :: <stream>, cmd :: <command>) => ()
  // When positional options are added to the command we verify that certain
  // constraints are met, like you can't add a repeated arg before a
  // non-repeated arg or add an optional arg before a required arg, so here we
  // assume those properties hold.
  for (option in cmd.positional-options)
    let var = option.option-variable;
    format(stream,
           if (option.option-required?) " %s%s" else " [%s]%s" end,
           var,
           if (option.option-repeated?) " ..." else "" end);
  end;
end function;
