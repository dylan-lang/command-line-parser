module: command-line-parser
synopsis: Parse command-line options.
authors: Eric Kidd, Carl Gay
copyright: See LICENSE file in this distribution.

//======================================================================
//  The All-Singing, All-Dancing Argument Parser
//======================================================================
//
//  Ole J. Tetlie wrote an option parser, and it was pretty good. But it
//  didn't support all the option types required by d2c, and besides, we
//  felt a need to overdo something.
//
//  So this code is redesigned and rewritten from the ground up. Our design
//  goals were to support all common types of options and allow the user of
//  the library to add support for the less common ones.
//
//  To parse a list of options, you need to perform the following steps:
//
//    1. Create an <command-line-parser>.
//    2. Create individual <option>s and attach them to it.
//    3. Tell the <command-line-parser> to parse a list of strings.
//    4. Call get-option-value to retrieve your option data.
//    5. Re-use your option parser by calling parse-command-line again, or
//       just forget about it.
//
//  A note about terminology:
//    foo -x --y=bar baz
//
//  All the tokens on that command line are arguments. "-x" and "--y"
//  are options, and "bar" is a parameter. "baz" is a positional argument.

// TODO(cgay): <choice-option>: --foo=a|b|c (#f as choice means option
// value is optional?)

// TODO(cgay): Add a required: (or required?: ?) init keyword that
// makes non-positional args required else an error is generated.

// TODO(cgay): With an option that has negative options (e.g.,
// --verbose and --quiet in the same option) just show the positive
// option in the synopsis but add a comment to the doc about the
// negative option.  e.g. "--verbose Be verbose (negative option:
// --quiet)"

// TODO(cgay): Create a default parser that can be used for libraries
// (as opposed to executables) to add options.  The executable can decide
// whether it wants to allow libraries' options by either using the
// default (shared) parser or not.  This is a really convenient way to
// make libraries easily configurable.  They would generally use a
// prefix to make their options unique, e.g., --log-* for the logging
// library.  --help should display only the executable's options and a
// note like "Use --helpall to list all options."

// TODO(cgay): (Related to above.)  Add a way to group options together
// so that there can be a heading above each group. Probably a `group`
// slot on the <option> class.

// TODO(cgay): Add a way to specify that several options are mutually
// exclusive.

// TODO(cgay): It might be worth exploring the separation of the parser
// from the description of the command line. Some of the naming would
// be clarified.

//======================================================================
//  Errors
//======================================================================

define open class <command-line-parser-error> (<format-string-condition>, <error>)
end;

// The one condition that we expect user code to handle around calls to
// parse-command-line and execute-command. Signaled by the help mechanism
// to exit the command with status 0.
define class <abort-command-error> (<command-line-parser-error>)
  constant slot exit-status :: <integer>, required-init-keyword: status:;
end;

define not-inline function abort-command
    (status :: <integer>) => ()
  error(make(<abort-command-error>, status: status));
end;

define open class <usage-error> (<abort-command-error>)
end;

define not-inline function usage-error
    (format-string :: <string>, #rest format-args)
  error(make(<usage-error>,
             status: 2,
             format-string: format-string,
             format-arguments: format-args))
end function;

// For incorrect usage of the library interface.
define not-inline function parser-error
    (format-string :: <string>, #rest format-args)
  error(make(<command-line-parser-error>,
             format-string: format-string,
             format-arguments: format-args))
end function;


//======================================================================
//  <command> and subclasses
//======================================================================

define abstract class <command> (<object>)
  slot command-options :: <sequence> = make(<stretchy-vector>),
    init-keyword: options:;
  constant slot %command-help :: <string>,
    required-init-keyword: help:;
  // Subcommands may be arbitrarily nested.
  slot command-subcommands :: <sequence> = #[],
    init-keyword: subcommands:;
  slot selected-subcommand :: false-or(<subcommand>) = #f;
end class;

// The --help option is added by default but we provide a way to turn it off here.
define method initialize
    (cmd :: <command>, #key help-option? :: <boolean> = #t, #all-keys)
 => ()
  if (help-option?)
    add-help-option(cmd);
  end;
  next-method();
  validate-options(cmd);
end method;

define open abstract class <subcommand> (<command>)
  constant slot subcommand-name :: <string>,
    required-init-keyword: name:;
end class;

define method debug-name
    (subcmd :: <subcommand>) => (name :: <string>)
  subcmd.subcommand-name
end method;

define function validate-options
    (cmd :: <command>) => ()
  let description = if (instance?(cmd, <subcommand>))
                      format-to-string("Subcommand %=", cmd.subcommand-name)
                    else
                      "Command"
                    end;
  if (cmd.has-subcommands? & cmd.positional-options.size > 0)
    parser-error("%s has both subcommands and positional options", description);
  end;
  // Don't care if positionals are mixed in with pass-by-names because
  // positional-options will extract them in order.
  let names = make(<stretchy-vector>);
  let repeated-positional = #f;
  let optional-positional = #f;
  for (option in cmd.command-options)
    for (name in option.option-names)
      if (member?(name, names, test: \=))
        parser-error("%s has duplicate option name: %=", description, name);
      end;
      add!(names, name);
    end;
    if (repeated-positional)
      parser-error("%s has options following repeated positional option %=",
                   description, repeated-positional.canonical-name);
    end;
    if (instance?(option, <positional-option>))
      if (option.option-repeated?)
        repeated-positional := option;
      end;
      if (option.option-required? & optional-positional)
        parser-error("%s has required positional option %= following"
                       " optional positional option %=",
                     description, option.canonical-name,
                     optional-positional.canonical-name);
      end;
      if (~option.option-required?)
        optional-positional := option;
      end;
    end;
  end for;
end function;

define function positional-options
    (cmd :: <command>) => (options :: <sequence>)
  choose(rcurry(instance?, <positional-option>),
         cmd.command-options)
end;

define function pass-by-name-options
    (cmd :: <command>) => (options :: <sequence>)
  choose(method (o)
           ~instance?(o, <positional-option>)
         end,
         cmd.command-options)
end function;

define function has-subcommands?
    (cmd :: <command>) => (_ :: <boolean>)
  cmd.command-subcommands.size > 0
end;

define generic find-subcommand
    (cmd :: <command>, object)
 => (subcommand :: false-or(<subcommand>));

define method find-subcommand
    (cmd :: <command>, class :: subclass(<subcommand>))
 => (subcommand :: false-or(<subcommand>))
  let subs = cmd.command-subcommands;
  let key = find-key(subs, rcurry(instance?, class));
  key & subs[key]
end method;

define method find-subcommand
    (cmd :: <command>, name :: <string>)
 => (subcommand :: false-or(<subcommand>))
  let subs = cmd.command-subcommands;
  let key = find-key(subs, method (subcmd)
                             name = subcmd.subcommand-name
                           end);
  key & subs[key]
end method;

define method find-subcommand
    (cmd :: <command>, path :: <sequence>)
 => (subcommand :: false-or(<subcommand>))
  iterate loop (cmd = cmd, i = 0)
    if (i >= path.size)
      cmd
    else
      let subs = cmd.command-subcommands;
      let name = path[i];
      let k = find-key(subs, method (subcmd)
                               name = subcmd.subcommand-name
                             end);
      k & loop(subs[k], i + 1)
    end
  end
end method;

define function add-subcommand
    (cmd :: <command>, subcmd :: <subcommand>) => ()
  let name = subcommand-name(subcmd);
  if (cmd.positional-options.size > 0)
    parser-error("a command may not have both positional"
                   " options and subcommands");
  end;
  if (find-subcommand(cmd, name))
    parser-error("a subcommand named %= already exists", name);
  end;
  cmd.command-subcommands := add!(cmd.command-subcommands, subcmd);
end function;

define open generic execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <object>)
 => (status :: false-or(<integer>));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <object>)
 => (status :: false-or(<integer>))
  error("don't know how to execute subcommand %=. add an execute-subcommand method?",
        subcmd);
end method;

// A <command-line-parser> is just a top-level command that handles the overall command
// line processing.
define open class <command-line-parser> (<command>)
  constant slot parser-tokens :: <deque> = make(<deque>); // of: <token>
end class;

define method initialize
    (cmd :: <command-line-parser>, #key help-subcommand? :: <boolean> = #t, #all-keys)
 => ()
  next-method();
  // A "help" subcommand is added only if there are other subcommands since adding
  // subcommands changes the way the overall command is parsed.
  //
  // TODO(cgay): This isn't called if someone uses the pattern
  //   let cmd = make(<command-line-parser>, ...no subcommands: argument...);
  //   add-subcommand(cmd, subcmd);
  // So for now if you use that pattern you have to add the help subcommand manually.
  // I don't like that it means there's a different level of knowledge necessary for
  // that pattern. We could stash away the value of `help-subcommand?` here and use
  // it later if add-subcommand is called. I want to see how the new macros look before
  // deciding how to handle this though.
  if (help-subcommand? & cmd.has-subcommands?)
    add-help-subcommand(cmd);
  end;
end method;

// This wasn't really well thought out. It's only useful to call if you have subcommands
// and each one has its own subclass.
define generic execute-command
    (parser :: <command-line-parser>)
 => (status :: false-or(<integer>));

define method execute-command
    (parser :: <command-line-parser>) => (status :: false-or(<integer>))
  let subcmd = parser.selected-subcommand;
  if (subcmd)
    execute-subcommand(parser, subcmd);
  else
    format(*standard-error*, "Please specify a subcommand.");
    let help = find-subcommand(parser, <help-subcommand>);
    if (help)
      format(*standard-error*, " Use '%s %s' to see a list of subcommands.",
             program-name(), help.subcommand-name);
    end;
    2                           // usage error
  end
end method;

define generic add-option (cmd :: <command>, option :: <option>) => ();

define method add-option
    (cmd :: <command>, option :: <option>) => ()
  cmd.command-options := add(cmd.command-options, option);
  validate-options(cmd);
end method;

define generic find-option
    (cmd :: <command>, id :: <object>)
 => (option :: false-or(<option>));

define method find-option
    (cmd :: <command>, class :: <class>) => (option :: false-or(<option>))
  let options = cmd.command-options;
  let key = find-key(options, rcurry(instance?, class));
  key & options[key]
end method;

define method find-option
    (cmd :: <command>, name :: <string>) => (option :: false-or(<option>))
  let options = cmd.command-options;
  let key = find-key(options,
                     method (option)
                       member?(name, option.option-names, test: \=)
                     end);
  key & options[key]
end method;

define function get-option-value
    (parser, name :: <string>) => (value :: <object>)
  let option = find-option(parser, name);
  if (option)
    option.option-value
  else
    usage-error("Command line option %= not found.", name);
  end;
end function;

define function add-argument-token
    (parser :: <command-line-parser>, class :: <class>, value :: <string>,
     #rest keys, #key, #all-keys)
 => ()
  push-last(parser.parser-tokens, apply(make, class, value: value, keys));
end;

define function tokens-remaining?
    (parser :: <command-line-parser>) => (remaining? :: <boolean>)
  ~parser.parser-tokens.empty?
end;

// TODO(cgay): This says it returns false-or, but it doesn't. I think it would be an
// improvement to make it do that and get rid of tokens-remaining?.
define function peek-token
    (parser :: <command-line-parser>) => (token :: false-or(<token>))
  unless (tokens-remaining?(parser))
    usage-error("Ran out of arguments.")
  end;
  parser.parser-tokens[0];
end;

define function pop-token
    (parser :: <command-line-parser>) => (token :: false-or(<token>))
  unless (tokens-remaining?(parser))
    usage-error("Ran out of arguments.")
  end;
  pop(parser.parser-tokens);
end;


//======================================================================
//  <option>
//======================================================================

define abstract open class <option> (<object>)
  slot option-names :: <sequence>,
    required-init-keyword: names:;

  constant slot option-type :: <type> = <object>,
    init-keyword: type:;

  slot option-might-have-parameters? :: <boolean> = #t;

  // Whether or not the option may be specified multiple times.  If the option
  // is also `option-required?` then it must be specified at least once.
  slot option-repeated? :: <boolean> = #f,
    init-keyword: repeated?:;

  // If true, the option must be specified at least once on the command-line.
  // TODO(cgay): This should be valid for both pass-by-name and positional
  // options but is currently not enforced for named options.
  constant slot option-required? :: <boolean> = #f,
    init-keyword: required?:;

  // Text to display for the --help option or `help` subcommand.
  constant slot %option-help :: <string>,
    required-init-keyword: help:;

  // This shows up in the generated synopsis after the option name.
  // e.g., "HOST" in  "--hostname  HOST  A host name."  If not supplied
  // it defaults to the first long option name.
  constant slot %option-variable :: false-or(<string>) = #f,
    init-keyword: variable:;

  // TODO(cgay): This should be a unique-id instead of #f.
  constant slot option-default :: <object> = #f,
    init-keyword: default:;

  // Information generated by parsing arguments.
  slot option-present? :: <boolean> = #f;
  slot option-value :: <object> = #f;
end class <option>;

define method make
    (class :: subclass(<option>), #rest args, #key name, names) => (o :: <option>)
  // Allow `name: "foo"` (the common case, I hope) or `names: #("foo", "f")`.
  // Is this featuritis? I hate having to say `names: #("foo")` when there's
  // only one name.
  let names = if (instance?(names, <string>))
                list(names)
              else
                names | #()
              end;
  if (name)
    names := concatenate(list(name), names);
  end;
  apply(next-method, class, names: names, args)
end method;

define method initialize
    (option :: <option>, #key) => ()
  next-method();
  if (empty?(option.option-names))
    parser-error("At least one option name is required: %=", option);
  end;
  let default = option.option-default;
  let type = option.option-type;
  if (default)
    if (option.option-repeated?)
      // TODO(cgay): Verify that each element of the default value can be converted to an
      // instance of the option's type via parse-option-value. (I forget whether the
      // default is normally converted to the type: or not....)
      type := <collection>
    end;
    if (~instance?(default, type))
      parser-error("The default value (%=) for option %= is not of the correct "
                     "type (%s).", default, option.option-names, type);
    end;
    option.option-value := default;
  end;
end method initialize;

define method debug-name
    (option :: <option>) => (name :: <string>)
  join(option.option-names, ", ")
end method;


// ----------------------
// parse-option-value
// ----------------------

// Parse a value passed on the command line (a string) to the type specified by
// option-type.
define open generic parse-option-value
    (parameter :: <string>, type :: <type>) => (value :: <object>);

// Default method just returns the value.
define method parse-option-value
    (param :: <string>, type :: <type>) => (value :: <string>)
  param
end;

// This is essentially for "float or int", which could be <real>, but
// <number> is also a natural choice.
define method parse-option-value
    (param :: <string>, type :: subclass(<number>)) => (value :: <number>)
  let arg = lowercase(param);
  /*  no string-to-float yet
  if (member?('.', arg) | member?('e', arg))
    string-to-float(param)
  */
  if (starts-with?(param, "0x") & hexadecimal-digit?(param, start: 2))
    string-to-integer(copy-sequence(param, start: 2), base: 16)
  elseif (starts-with?(param, "0") & octal-digit?(param))
    string-to-integer(param, base: 8)
  elseif (decimal-digit?(param))
    string-to-integer(param)
  else
    usage-error("Expected a number but got %=", param);
  end
end;

define method parse-option-value
    (param :: <string>, type == <boolean>) => (value :: <boolean>)
  if (member?(param, #("yes", "true", "on"), test: string-equal-ic?))
    #t
  elseif (member?(param, #("no", "false", "off"), test: string-equal-ic?))
    #t
  else
    usage-error("Expected yes/no, true/false, or on/off but got %=", param);
  end
end;

define method parse-option-value
    (param :: <string>, type == <symbol>) => (value :: <symbol>)
  as(<symbol>, param)
end;

define method parse-option-value
    (param :: <string>, type :: subclass(<sequence>)) => (value :: <sequence>)
  as(type, map(strip, split(param, ",")))
end;

// override subclass(<sequence>) method
define method parse-option-value
    (param :: <string>, type :: subclass(<string>)) => (value :: <string>)
  param
end;


define generic short-names (option :: <option>) => (names :: <list>);

define method short-names (option :: <positional-option>) => (names :: <list>)
  #()
end;

define method short-names (option :: <option>) => (names :: <list>)
  choose(method (name :: <string>)
           name.size = 1
         end,
         option.option-names)
end;

define generic long-names (option :: <option>) => (names :: <list>);

define method long-names (option :: <positional-option>) => (names :: <list>)
  #()
end;

define method long-names
    (option :: <option>) => (names :: <list>)
  choose(method (name :: <string>)
           name.size > 1
         end,
         option.option-names)
end;


//======================================================================
//  <token> (and subclasses)
//======================================================================

define abstract class <token> (<object>)
  constant slot token-value :: <string>,
    required-init-keyword: value:;
end;

define method debug-name
    (token :: <token>) => (name :: <string>)
  token.token-value
end method;

define class <argument-token> (<token>)
end;

define abstract class <option-token> (<token>)
end;

define class <short-option-token> (<option-token>)
  constant slot tightly-bound-to-next-token?,
    init-keyword: tightly-bound?:,
    init-value: #f;
end;

define class <long-option-token> (<option-token>)
end;

define class <equals-token> (<token>)
end;


//======================================================================
//  parse-command-line
//======================================================================

// Break up our arguments around '--' in the traditional fashion.
define function split-args(argv)
 => (clean-args :: <sequence>, extra-args :: <sequence>)
  let splitter = find-key(argv, curry(\=, "--"));
  if (splitter)
    let clean-args = copy-sequence(argv, end: splitter);
    let extra-args = copy-sequence(argv, start: splitter + 1);
    values(clean-args, extra-args);
  else
    values(argv, #());
  end if;
end function split-args;

// Chop things up around '=' characters.
define function chop-args(clean-args)
 => (chopped :: <deque> /* of: <string> */)
  let chopped = make(<deque> /* of: <string> */);
  local method store(str)
          push-last(chopped, str);
        end method store;
  for (arg in clean-args)
    case
      (arg.size = 0) =>
        store("");
      (arg[0] = '=') =>
        store("=");
        if (arg.size > 1)
          store(copy-sequence(arg, start: 1));
        end if;
      (arg[0] = '-') =>
        let break = subsequence-position(arg, "=");
        if (break)
          store(copy-sequence(arg, end: break));
          store("=");
          if (arg.size > break + 1)
            store(copy-sequence(arg, start: break + 1));
          end if;
        else
          store(arg);
        end if;
      otherwise =>
        store(arg);
    end case;
  end for;
  chopped;
end function chop-args;

// Turn a deque of args into an internal deque of tokens.
define function tokenize-args
    (parser :: <command-line-parser>, args :: <deque> /* of: <string> */)
 => ()
  local
    // Attempt to get the next argument a little bit early.
    method next-arg () => (arg :: <string>)
      if (empty?(args))
        usage-error("Ran out of arguments.");
      else
        pop(args)
      end
    end,
    // Add a token to our deque
    method add-token (class :: <class>, value :: <string>,
                      #rest keys, #key, #all-keys) => ()
      apply(add-argument-token, parser, class, value, keys);
    end,
    method parse-short-option (arg)
      block (done)
        for (i from 1 below arg.size)
          let name = copy-sequence(arg, start: i, end: i + 1);
          let opt = find-option(parser, name);
          if (opt
                & opt.option-might-have-parameters?
                & i + 1 < arg.size)
            // Take rest of argument, and use it as a parameter.
            add-token(<short-option-token>, name, tightly-bound?: #t);
            add-token(<argument-token>, copy-sequence(arg, start: i + 1));
            done();
          else
            // A solitary option with no parameter. Do not exit the loop because there
            // may be multiple short options strung together as in 'ls -ltR'.
            add-token(<short-option-token>, name);
          end if;
        end for;
      end block;
    end method;
  until (args.empty?)
    let arg = pop(args);
    case
      (arg = "=") =>
        add-token(<equals-token>, "=");
        add-token(<argument-token>, next-arg());

      starts-with?(arg, "--") =>
        add-token(<long-option-token>, copy-sequence(arg, start: 2));

      starts-with?(arg, "-") =>
        if (arg.size = 1)
          // Probably a fake filename representing stdin ('cat -')
          add-token(<argument-token>, "-");
        else
          parse-short-option(arg);
        end if;

      otherwise =>
        add-token(<argument-token>, arg);
    end case;
  end until;
end function tokenize-args;

define open generic parse-command-line
    (parser :: <command-line-parser>, argv :: <sequence>)
 => ();

// Parse the command line, side-effecting the parser, its options, and its
// subcommands with the parsed values. `args` is a sequence of command line
// arguments (strings). It must not include the command name.
define method parse-command-line
    (parser :: <command-line-parser>, args :: <sequence>)
 => ()
  // Split our args around '--' and chop them around '='.
  let (clean-args, extra-args) = split-args(args);
  let chopped-args = chop-args(clean-args);
  tokenize-args(parser, chopped-args);
  process-tokens(program-name(), parser, #f);

  if (~empty?(extra-args))
    // Append any more positional options from after the '--'.  If there's a
    // subcommand the extra args go with that.
    // (This feels hackish. Can we handle this directly in process-tokens?)
    let command = parser.selected-subcommand | parser;
    let option = last(command.command-options);
    if (~(instance?(option, <positional-option>)
            & option.option-repeated?))
      let opts = command.positional-options;
      usage-error("Only %d positional argument%s allowed.",
                  opts.size,
                  if (opts.size = 1) "" else "s" end);
    end;
    for (arg in extra-args)
      option.option-value := add!(option.option-value,
                                  parse-option-value(arg, option.option-type));
    end for;
  end;
end method;

// Read tokens from the command line and decide how to store them.
// Implement this for each new option class.
define open generic parse-option
    (option :: <option>, args :: <command>) => ();

// Process the tokens, side-effecting the <command>, the <subcommand>s (if any), and the
// <option>s. If a subcommand is encountered, the remaining tokens are passed to it and
// this is called recursively. Only the last (sub)command may have positional args.
//
// One bit of subtlety here (which would be cleaned up by separating the parser
// from the command descriptions) is that the full tokenized command line is
// stored in the <command-line-parser> while some of the options may be stored
// in a <subcommand>.
define function process-tokens
    (name :: <string>, parser :: <command-line-parser>, subcmd :: false-or(<subcommand>))
  let cmd = subcmd | parser;
  let pos-opts = as(<list>, cmd.positional-options);
  if (~empty?(pos-opts) & cmd.has-subcommands?)
    // TODO(cgay): move this to validate-options or equivalent so that it happens at
    // instantiation time.
    usage-error("The %= %s has subcommands so it may not have its own positional"
                  " arguments.",
                name,
                if (instance?(cmd, <subcommand>)) "subcommand" else "command" end);
  end;
  while (tokens-remaining?(parser))
    let token = peek-token(parser);
    let value = token.token-value;
    select (token by instance?)
      <argument-token> =>
        // Got an argument token without a preceding <short/long-option-token>
        // so it must be a subcommand or a positional argument.
        if (cmd.has-subcommands?)
          let sub = find-subcommand(cmd, value)
            | usage-error("%= does not name a subcommand.", value);
          pop-token(parser);
          // Store the selected subcommand in the parent subcommand, and the top-level
          // parser always receives the final subcommand.
          cmd.selected-subcommand := sub;
          parser.selected-subcommand := sub;
          process-tokens(sub.subcommand-name, parser, sub);
        else
          if (empty?(pos-opts))
            usage-error("Too many positional arguments: %=", value);
          end;
          let option = head(pos-opts);
          if (option.option-repeated?)
            assert(pos-opts.size = 1); // Repeated option must be last option.
          else
            pos-opts := tail(pos-opts);
          end;
          parse-option(option, parser); // Parser contains the unprocessed tokens.
          option.option-present? := #t;
        end;
      <short-option-token>, <long-option-token> =>
        let option = find-option(cmd, value)
          | usage-error("Unrecognized option: %s%s",
                        if (value.size = 1) "-" else "--" end,
                        value);
        if (instance?(option, <help-option>))
          // Handle --help early in case the remainder of the command line is
          // invalid or there are missing required arguments.
          print-help(cmd);
          abort-command(0);
        end;
        parse-option(option, parser);
        option.option-present? := #t;
      otherwise =>
        usage-error("Unexpected token: %=", value);
    end select;
  end while;
  let missing = choose(method (o)
                         o.option-required? & ~o.option-present?
                       end,
                       pos-opts);
  if (missing.size > 0)
    usage-error("Missing argument%s: %s",
                if (missing.size = 1) "" else "s" end,
                join(missing, ", ", key: canonical-name));
  end;
end function;
/*
  Semi-comprehensible design notes, here for historical interest:

  add-option-templates
  parse-options
  find-option-value
  print-synopsis
  hypothetical: execute-program?

  don't forget --help and --version, which exit immediately
  program names...
  erroneous argument lists

  Parameterless options:
   -b, --bar, --no-bar
     Present or absent. May have opposites; latter values override
     previous values.

  Parameter options:
   -f x, --foo=x
     May be specified multiple times; this indicates multiple values.

  Immediate-exit options:
   --help, --version

  Key/value options:
   -DFOO -DBAR=1

  Degenerate options forms we don't approve of:
   -vvvvv (multiple verbosity)
   -z3 (optional parameter)

  Tokenization:
   b -> -b
   f x -> -f x
   fx -> -f x
   foo=x -> -foo =x
   DFOO -> -D FOO
   DBAR=1 -> -D BAR =1
   bfx -> b f x
   fbx -> f bx

  Four kinds of tokens:
   Options
   Values
   Explicit parameter values
   Magic separator '--' (last token; no more!)

  <option-descriptor> protocol:
    define method on process-option
    call get-parameter and get-optional-parameter as needed
*/
