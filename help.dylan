Module: command-line-parser
Synopsis: Implements the --help flag and help subcommand


// TODO(cgay): Wrap the descriptions nicely

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
      print-synopsis(parser, subcmd);
    else
      usage-error("Subcommand %= not found.", name);
    end;
  else
    print-synopsis(parser, #f);     // 'app help' same as 'app --help'
  end;
end method;

// This has a class of its own so that the help option doesn't have to be
// identified by name (which should be user settable).
define open class <help-option> (<flag-option>)
end;

// make open generic?
define function add-help-option
    (parser :: <command-line-parser>) => ()
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

define open generic print-synopsis
    (parser :: <command-line-parser>, subcmd :: false-or(<subcommand>), #key stream);

define method print-synopsis
    (parser :: <command-line-parser>, subcmd == #f,
     #key stream :: <stream> = *standard-output*)
  format(stream, "%s\n", parser.command-help);
  format(stream, "\n%s\n", generate-usage(parser));
  print-options(stream, parser,
                if (empty?(parser-subcommands(parser)))
                  "Options:"
                else
                  "Global options:"
                end);
  if (~empty?(parser-subcommands(parser)))
    format(stream, "\nSubcommands:\n");
    let (names, docs) = subcommand-columns(parser);
    if (~empty?(names))
      let name-width = reduce1(max, map(size, names));
      for (name in names, doc in docs)
        format(stream, "%s  %s\n", pad-right(name, name-width), doc);
      end;
    end;
    let help-subcommand = find-subcommand(parser, <help-subcommand>);
    if (help-subcommand)
      format(stream, "\nUse '%s %s <subcommand>' to see subcommand options.\n",
             program-name(), subcommand-name(help-subcommand));
    end;
  end;
end method;

define method print-synopsis
    (parser :: <command-line-parser>, subcmd :: <subcommand>,
     #key stream :: <stream> = *standard-output*)
  format(stream, "%s\n", subcmd.command-help);
  format(stream, "\n%s\n", generate-usage(subcmd));
  print-options(stream, subcmd, "Options:");
  let help-option = find-option(parser, <help-option>);
  if (help-option)
    format(stream, "\nUse '%s %s' to see global options.\n",
           program-name(), help-option.canonical-name.visible-option-name);
  end;
end method;

define method print-options
    (stream :: <stream>, command :: <command>, header :: <string>) => ()
  let (names, docs) = option-columns(command);
  if (~empty?(names))
    format(stream, "\n%s\n", header);
    let name-width = reduce1(max, map(size, names));
    for (name in names, doc in docs)
      format(stream, "  %s  %s\n", pad-right(name, name-width), doc);
    end;
  end;
  let (names, docs) = positional-columns(command);
  if (~empty?(names))
    format(stream, "\nPositional arguments:\n");
    let name-width = reduce1(max, map(size, names));
    for (name in names, doc in docs)
      format(stream, "  %s  %s\n", pad-right(name, name-width), doc);
    end;
  end;
end method;

define function positional-columns
    (cmd :: <command>) => (names :: <sequence>, docs :: <sequence>)
  let names = make(<stretchy-vector>);
  let docs = make(<stretchy-vector>);
  for (opt in cmd.positional-options)
    let name = opt.option-variable;
    if (opt.option-repeated?)
      name := concatenate(name, "...");
    end;
    add!(names, name);
    add!(docs, opt.option-help);
  end;
  values(names, docs)
end function;

define function option-columns
    (parser :: <command>)
 => (names :: <sequence>, docs :: <sequence>)
  let names = make(<stretchy-vector>);
  let docs = make(<stretchy-vector>);
  let any-shorts? = any?(method (opt) ~empty?(opt.short-names) end,
                         parser.command-options);
  for (option in parser.pass-by-name-options)
    let longs = map(visible-option-name, option.long-names);
    let shorts = map(visible-option-name, option.short-names);
    let name = concatenate(join(concatenate(shorts, longs), ", "),
                           " ",
                           if (instance?(option, <flag-option>))
                             ""
                           else
                             option.option-variable | canonical-name(option);
                           end);
    let indent = if (empty?(shorts) & any-shorts?)
                   "    "       // Makes long options align (usually).
                 else
                   ""
                 end;
    add!(names, concatenate(indent, name));
    add!(docs, option.option-help);
  end for;
  values(names, docs)
end function;

// There is much work to be done to make this better.
define function subcommand-columns
    (parser :: <command-line-parser>)
 => (names :: <sequence>, docs :: <sequence>)
  let names = make(<stretchy-vector>);
  let docs = make(<stretchy-vector>);
  for (subcmd in parser.parser-subcommands)
    add!(names, concatenate("  ", subcmd.subcommand-name));
    // TODO(cgay): Wrap doc text.
    add!(docs, subcmd.command-help);
  end for;
  values(names, docs)
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
      format(stream, " [%soptions]", if (subs?) "global " else "" end);
    end;
    if (subs?)
      format(stream, " <subcommand> [sub options] args...")
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
