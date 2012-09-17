module: command-line-parser
synopsis: Parse command-line options.
authors: Eric Kidd
copyright: see below

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

//======================================================================
//  The All-Singing, All-Dancing Argument Parser
//======================================================================
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
//  are options, and "bar" is a parameter. "baz" is a positional option.

// todo -- There is no error signalled if two options have the same short name
//         (or long name, I assume).  In fact there's a comment saying that the
//         rightmost argument with the same name takes precedence.  So this is
//         by design???
//
// todo -- There is no indication of default values in the generated synopsis,
//         and the syntax for specifying "syntax" and docstring is bizarre at
//         best.  --cgay 2006.11.27

// TODO(cgay): documentation!

// TODO(cgay): tests!

// TODO(cgay): <choice-option>: --foo=a|b|c (#f as choice means option
// value is optional?)

// TODO(cgay): Add type: option to all parsers that determines how to
// parse the inputs.  Validate that the provided default: argument is
// an instance of the type and give a good error.  Make extensible.

// TODO(cgay): long-optionS => long-name, short-optionS => short-name.
// Can allow a list of names, but 99% of the time people just want to
// give a single name for each option, so a string should work.  (And
// I documented it to work.)

// TODO(cgay): Automatic support for --help, with a way to rename or
// disable the option.  Includes improvements to print-synopsis such
// as supporting %prog, %default, %choices, etc. and displaying the
// option type.

// TODO(cgay): Add a required: (or required?: ?) init keyword that
// makes non-positional args required else an error is generated.

// TODO(cgay): Add support for specifying the min/max number of
// positional options when instantiating the parser.

// TODO(cgay): This error sucks: "<unknown-option>" is not present as
// a key for {<string-table>: size 12}.  How about "<unknown-option>
// is not a recognized command-line option."  See next item.

// TODO(cgay): Export usage-error and <usage-error> after fixing them
// up.  These are duplicated in testworks, so use them there.

// TODO(cgay): Get rid of <optional-parameter-option> and make it an
// init-arg on <parameter-option> instead.

// TODO(cgay): With an option that has negative options (e.g.,
// --verbose and --quiet in the same option) just show the positive
// option in the synopsis but add a comment to the doc about the
// negative option.  e.g. "--verbose Be verbose (negative option:
// --quiet)"


//======================================================================
//  Errors
//======================================================================

define class <option-parser-error> (<format-string-condition>, <error>)
end;

// For when the user provides an invalid command-line.
// These errors will be displayed to the user via condition-to-string.
define class <usage-error> (<option-parser-error>)
end;

// Making this inline stifles return type warnings.
define inline function usage-error
    (format-string :: <string>, #rest format-args) => ()
  error(make(<usage-error>,
             format-string: format-string,
             format-arguments: format-args))
end;

// Making this inline stifles return type warnings.
define inline function parser-error
    (format-string :: <string>, #rest format-args) => ()
  error(make(<option-parser-error>,
             format-string: format-string,
             format-arguments: format-args))
end;


//======================================================================
//  <command-line-parser>
//======================================================================

define open class <command-line-parser> (<object>)
  // Retained across calls to parse-command-line.
  slot option-parsers :: <stretchy-vector> /* of <option> */ =
    make(<stretchy-vector> /* of <option> */);
  constant slot option-short-name-map :: <string-table> /* of <option> */ =
    make(<string-table>);
  constant slot option-long-name-map :: <string-table> /* of <option> */ =
    make(<string-table>);
  constant slot parameter-options :: <string-table> /* of <boolean> */ =
    make(<string-table>);

  // Information generated by parsing arguments.
  constant slot tokens :: <deque> /* of: <token> */ =
    make(<deque> /* of: <token> */);
  slot positional-options :: <stretchy-vector> /* of: <string> */ =
    make(<stretchy-vector> /* of: <string> */);
end class <command-line-parser>;

define function add-option
    (args-parser :: <command-line-parser>, option :: <option>)
 => ()
  local method add-to-table(table, items, value) => ()
          for (item in items)
            table[item] := value;
          end for;
        end method add-to-table;
  args-parser.option-parsers := add!(args-parser.option-parsers, option);
  add-to-table(args-parser.option-long-name-map,
               option.long-option-names,
               option);
  add-to-table(args-parser.option-short-name-map,
               option.short-option-names,
               option);
  if (option.option-might-have-parameters?)
    add-to-table(args-parser.parameter-options,
                 option.short-option-names,
                 #t);
  end if;
end function add-option;

define method find-option
    (parser :: <command-line-parser>, name :: <string>)
 => (option :: <option>)
  element(parser.option-long-name-map, name, default: #f)
    | element(parser.option-short-name-map, name, default: #f)
    | error(make(<option-parser-error>,
                 format-string: "Option not found: %=",
                 format-arguments: name))
end;

define function option-present?-by-long-name
    (parser :: <command-line-parser>, long-name :: <string>)
 => (present? :: <boolean>)
  find-option(parser, long-name).option-present?
end;

define function get-option-value
    (parser :: <command-line-parser>, name :: <string>)
 => (value :: <object>)
  find-option(parser, name).option-value
end;

define function add-argument-token
    (parser :: <command-line-parser>,
     class :: <class>,
     value :: <string>,
     #rest keys, #key, #all-keys)
 => ()
  push-last(parser.tokens, apply(make, class, value: value, keys));
end;

define function argument-tokens-remaining?
    (parser :: <command-line-parser>)
 => (remaining? :: <boolean>)
  ~parser.tokens.empty?
end;

define function peek-argument-token
    (parser :: <command-line-parser>)
 => (token :: false-or(<token>))
  unless (argument-tokens-remaining?(parser))
    usage-error("Ran out of arguments.")
  end;
  parser.tokens[0];
end;

define function get-argument-token
    (parser :: <command-line-parser>)
 => (token :: false-or(<token>))
  unless (argument-tokens-remaining?(parser))
    usage-error("Ran out of arguments.")
  end;
  pop(parser.tokens);
end;


//======================================================================
//  <option>
//======================================================================

define abstract open primary class <option> (<object>)
  // Information supplied by creator.
  slot long-option-names :: <list> = #(),
    init-keyword: long-options:;
  slot short-option-names :: <list> = #(),
    init-keyword: short-options:;
  slot option-might-have-parameters? :: <boolean> = #t;
  slot option-help :: <string> = "",
    init-keyword: help:;
  // This shows up in the generated synopsis after the option name.
  // e.g., "HOST" in  "--hostname  HOST  A host name."  If not supplied
  // it defaults to the first long option name.
  slot option-variable :: false-or(<string>) = #f,
    init-keyword: variable:;
  slot option-default :: <boolean> = #f,
    init-keyword: default:;

  // Information generated by parsing arguments.
  slot option-present? :: <boolean> = #f;
  slot option-value :: <object> = #f;
end class <option>;

define method initialize
    (option :: <option>, #key)
 => ()
  next-method();
  if (empty?(option.long-option-names)
        & empty?(option.short-option-names))
    parser-error("Either long-options: or short-options: must be supplied.");
  end;
end method initialize;

define open generic reset-option(option :: <option>) => ();

define method reset-option(option :: <option>) => ()
  option.option-present? := #f;
  option.option-value := option.option-default;
end method reset-option;

define open generic parse-option
    (option :: <option>, args :: <command-line-parser>) => ();

define function add-option-by-type
    (parser :: <command-line-parser>, class :: <class>, #rest keys)
 => ()
  add-option(parser, apply(make, class, keys));
end function add-option-by-type;


//======================================================================
//  <token> (and subclasses)
//======================================================================

define abstract class <token> (<object>)
  constant slot token-value :: <string>,
    required-init-keyword: value:;
end;

define class <positional-option-token> (<token>)
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
    values (clean-args, extra-args);
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
    (parser :: <command-line-parser>,
     args :: <deque> /* of: <string> */)
 => ()
  until (args.empty?)
    let arg = pop(args);
    local

      // Attempt to get the next argument a little bit early.
      method next-arg() => (arg :: <string>)
        if (~args.empty?)
          pop(args)
        else
          usage-error("Ran out of arguments.");
        end
      end method,

      // Add a token to our deque
      method token(class :: <class>, value :: <string>,
                   #rest keys, #key, #all-keys) => ()
        apply(add-argument-token, parser, class, value, keys);
      end method;

    // Process an individual argument
    case
      (arg = "=") =>
        token(<equals-token>, "=");
        token(<positional-option-token>, next-arg());

      (arg.size > 2 & arg[0] = '-' & arg[1] = '-') =>
        token(<long-option-token>, copy-sequence(arg, start: 2));

      (arg.size > 0 & arg[0] = '-') =>
        if (arg.size = 1)
          // Probably a fake filename representing stdin ('cat -')
          token(<positional-option-token>, "-");
        else
          block (done)
            for (i from 1 below arg.size)
              let opt = make(<string>, size: 1, fill: arg[i]);
              let opt-parser = element(parser.option-short-name-map,
                                       opt, default: #f);
              if (opt-parser & opt-parser.option-might-have-parameters?
                    & i + 1 < arg.size)
                // Take rest of argument, and use it as a parameter.
                token(<short-option-token>, opt, tightly-bound?: #t);
                token(<positional-option-token>,
                      copy-sequence(arg, start: i + 1));
                done();
              else
                // A solitary option with no parameter.
                token(<short-option-token>, opt);
              end if;
            end for;
          end block;
        end if;

      otherwise =>
        token(<positional-option-token>, arg);
    end case;
  end until;
end function tokenize-args;

define function parse-command-line
    (parser :: <command-line-parser>, argv :: <sequence>)
 => (success? :: <boolean>)
  block (exit-block)
    parser.tokens.size := 0;
    parser.positional-options.size := 0;
    do(reset-option, parser.option-parsers);

    // Split our args around '--' and chop them around '='.
    let (clean-args, extra-args) = split-args(argv);
    let chopped-args = chop-args(clean-args);

    // Tokenize our arguments and suck them into the parser.
    tokenize-args(parser, chopped-args);

    // Process our tokens.
    while (argument-tokens-remaining?(parser))
      let token = peek-argument-token(parser);
      select (token by instance?)
        <positional-option-token> =>
          get-argument-token(parser);
          parser.positional-options := add!(parser.positional-options,
                                           token.token-value);
        <short-option-token> =>
          let opt-parser =
            element(parser.option-short-name-map, token.token-value, default: #f)
              | exit-block(#f);
          parse-option(opt-parser, parser);
          opt-parser.option-present? := #t;
        <long-option-token> =>
          let opt-parser =
            element(parser.option-long-name-map, token.token-value, default: #f)
              | exit-block(#f);
          parse-option(opt-parser, parser);
          opt-parser.option-present? := #t;
        otherwise =>
          error(make(<option-parser-error>,
                     format-string: "Unrecognized token: %=",
                     format-arguments: list(token)));
      end select;
    end while;

    // And append any more positional options from after the '--'.
    for (arg in extra-args)
      parser.positional-options := add!(parser.positional-options, arg);
    end for;

    #t
  exception (<option-parser-error>)
    #f
  end block
end function parse-command-line;

define open generic print-synopsis
 (parser :: <command-line-parser>, stream :: <stream>, #key);

// todo -- Generate the initial "Usage: ..." line as well.
// TODO(cgay): Show all option names, not just the first.
//
// Example output:
// Usage: foo [options] arg1 ...
//   -c, --coolness  LEVEL      Level of coolness, 1-3.
//   -r              RECURSIVE  Be cool recursively.
//       --alacrity  ALACRITY   Level of alacrity.
// Short options come first on a line because they're always the
// same length (except when there are many).  Long options start
// indented past one short option if there is no corresponding
// short option.  If there is no variable: provided for the option
// it defaults to the first long option name.
define method print-synopsis
    (parser :: <command-line-parser>, stream :: <stream>,
     #key usage :: false-or(<string>),
          help :: false-or(<string>))
  usage & format(stream, "Usage: %s\n", usage);
  help & format(stream, "%s\n", help);

  // These contain an entry for every line, sometimes just "".
  let (names, variables, docs) = synopsis-columns(parser);
  let name-width = reduce1(max, map(size, names));
  let var-width = reduce1(max, map(size, variables));
  for (name in names, var in variables, doc in docs)
    format(stream, "%s  %s  %s\n",
           pad-right(name, name-width), pad-right(var, var-width), doc);
  end;
end method print-synopsis;

define function synopsis-columns
    (parser :: <command-line-parser>)
 => (names :: <sequence>, vars :: <sequence>, docs :: <sequence>)
  let names = make(<stretchy-vector>);
  let vars = make(<stretchy-vector>);
  let docs = make(<stretchy-vector>);
  let any-shorts? = any?(method (opt) ~empty?(opt.short-option-names) end,
                         parser.option-parsers);
  for (option in parser.option-parsers)
    // TODO(cgay): Make these prefixes (-- and -) configurable.
    let longs = map(curry(concatenate, "--"), option.long-option-names);
    let shorts = map(curry(concatenate, "-"), option.short-option-names);
    if (empty?(shorts) & any-shorts?)
      shorts := #("  ");  // Makes long options align (usually).
    end;
    add!(names, join(concatenate(shorts, longs), ", "));
    add!(vars,
         if (instance?(option, <flag-option>))
           ""
         elseif (empty?(longs))
           "ARG"
         else
           option.option-variable | uppercase(option.long-option-names[0])
         end);
    // TODO(cgay): Wrap doc text.
    add!(docs, option.option-help);
  end for;
  values(names, vars, docs)
end function synopsis-columns;


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
