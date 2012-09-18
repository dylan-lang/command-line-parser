module: command-line-parser
synopsis: Interface macros for parser definition and option access.
authors: David Lichteblau <lichteblau@fhtw-berlin.de>
copyright: see below

//======================================================================
//
//  Copyright (c) 1999-2012 David Lichteblau and Dylan Hackers
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


// Introduction
// ============
//
// This is a set of macros designed to work on top of Eric Kidd's
// command-line-parser library.  The idea is to provide a more readable
// interface for parser definition and option access.
//
//
// Examples
// ========
//
// Below you can find a short overview of defcmdline's features.
// If you are looking for working examples, have a look at
//   <URL:http://www.inf.fu-berlin.de/~lichtebl/dylan/>
//
//
// Emacs
// =====
//
// You will want to edit your .emacs to recognize defcmdline macros and
// keywords:
//
// (add-hook 'dylan-mode-hook
//           (lambda ()
//             (add-dylan-keyword 'dyl-parameterized-definition-words
//                                "command-line")
//             (add-dylan-keyword 'dyl-other-keywords "option")
//             (add-dylan-keyword 'dyl-other-keywords "positional-options")
//             (add-dylan-keyword 'dyl-other-keywords "synopsis")))
//
//
// Command Line definition
// =======================
//
//     Use ``define command-line'' to define a new parser class.  This
//     macro is intended to look similar to ``define class'', but doesn't
//     define slots as such.  Instead it takes ``option'' clauses.  At
//     initialisation time of an instance, corresponding option parsers will
//     be made automatically.
//
//         define command-line <my-parser> ()
//           option verbose?, long: "verbose", short: "v";
//         end;
//
//     Notes:
//       - Default superclass is <command-line-parser>.
//
//       - Default option class is <flag-option>.
//
//         You can specify an alternative class with the kind: keyword:
//           option logfile, kind: <parameter-option>;
//
//       - For the options, default values are possible:
//           option logfile = "default.log",
//             kind: <parameter-option>,
//             long: "logfile", short: "L";
//
//       - You may want to specify types for an option:
//           option logfile :: false-or(<string>), ...
//         or
//           option logfile :: <string> = "default.log", ...
//
//         Currently type checking is done, but errors are not handled.
//         Future version will probably provide a facility for automatic
//         error handling and error message generation.
//
//       - Remaining keywords are handed as initargs to make.
//
//       - Besides ``option'' there is also ``positional-options'':
//           positional-options file-names;
//
//
// Parsing the Command Line
// ========================
//
//     Originally I had macros to make a command-line parser and do the
//     parsing transparently.  It wasn't consistent enough, though, and
//     therefore I decided to throw out that code for now.
//
//     Just do it manually:
//
//         define method main (appname, #rest args);
//           let parser = make(<my-parser>);
//           parse-options(parser, args);
//
//           // Here we go.
//         end method main;
//
//
// Accessing the options
// =====================
//
//     ``define command-line'' defines function to access the options as
//     if they were real slots:
//
//         define command-line <my-parser> ()
//           option verbose?, short: "v";
//         end command-line;
//
//         define method main (appname, #rest args);
//           let parser = make(<my-parser>);
//           parse-options(parser, args);
//
//           if (parser.verbose?)
//             ...
//           end if;
//         end method main;
//
//
//     If you happen to need the option parsers, they are accessible as
//     slots with "-parser" appended to the name:
//         let option-parser = parser.verbose?-parser;
//
//
// Synopsis generation
// ===================
//
//    Suppose you say
//
//         define command-line <main-parser> ()
//           synopsis print-synopsis,
//             usage: "test [options] file...",
//             description: "Stupid test program doing nothing with the args.";
//           option verbose?, "", "Explanation", short: "v", long: "verbose";
//           option other, "", "foo", long: "other-option";
//         end command-line;
//
//    Then print-synopsis(parser, stream) will print something like:
//
//         Usage: test [options] file...
//         Stupid test program doing nothing with the args.
//
//           -v, --verbose                Explanation
//               --other-option           foo
//


// Macro COMMAND-LINE-DEFINER--exported
// =======================================
// Syntax: define command-line ?:name (?supers:*) ?options end
//
//  - Let `?supers' default to <command-line-parser>.
//
//  - Transform human-readable `?options' into patterns of the form
//      [option-name, type, [default-if-any], #rest initargs]
//      [positional-options-name]
//      (synopsis-fn-name, usage, description)
//
//  - Hand it over to `defcmdline-rec'.
//
// Explanation: I have no idea what that is for.
//
define macro command-line-definer
    { define command-line ?:name () ?options end }
      => { defcmdline-rec ?name (<command-line-parser>) () ?options end }
    { define command-line ?:name (?supers) ?options end }
      => { defcmdline-rec ?name (?supers) () ?options end }

  supers:
    { ?super:expression, ... } => { ?super, ... }
    { } => { }

  options:
    { option ?:name :: ?value-type:expression, ?initargs:*; ... }
      => { [?name, ?value-type, [], ?initargs] ... }
    { option ?:name :: ?value-type:expression = ?default:expression,
        ?initargs:*; ... }
      => { [?name, ?value-type, [?default], ?initargs] ... }
    { positional-options ?:name; ... }
      => { [?name] ... }
    { synopsis ?fn:name, #rest ?keys:*,
      #key ?usage:expression = #f, ?description:expression = #f,
      #all-keys; ... }
      => { (?fn, ?usage, ?description) ... }
    { } => { }

  initargs:
    { ?syntax:expression, ?docstring:expression, #rest ?realargs:* }
      => { [?syntax, ?docstring], ?realargs }
    { ?docstring:expression, #rest ?realargs:* }
      => { ["", ?docstring], ?realargs }
    { #rest ?realargs:* }
      => { ["", ""], ?realargs }
end macro;

// Macro DEFCMDLINE-REC--internal
// ================================
// Syntax: defcmdline-rec ?:name (?supers:*) (?processed:*) ?options end
//
//   - Start out without `?processed' forms.
//   - (Recursively) take each `?options' form and add a pair
//       [?name, ?option]
//     to `?processed'.
//   - Finally, pass the `?processed' forms to `defcmdline-aux'.
//
// Explanation: The options will be processed by auxiliary rules.
// However, these need the `?name', which would be available to main
// rules only.  That's why we need the name/option pairs.
//
define macro defcmdline-rec
    { defcmdline-rec ?:name (?supers:*) (?processed:*) end }
      => { defcmdline-aux ?name (?supers) ?processed end }

    { defcmdline-rec ?:name (?supers:*) (?processed:*) [?option:*] ?rem:* end }
      => { defcmdline-rec ?name (?supers)
             (?processed [?name, ?option]) ?rem
           end }
    { defcmdline-rec ?:name (?supers:*) (?processed:*) (?usage:*) ?rem:* end }
      => { defcmdline-rec ?name (?supers)
             ((?usage) ?processed) ?rem
           end }
end macro;

// Macro DEFCMDLINE-AUX--internal
// ================================
// Syntax: defcmdline-aux ?:name (?supers:*) ?options end
//
// Explanation: This is rather staightforward; code generation is
// performed by auxillary macros that output
//
//   - (defcmdline-class) a class definition for `?name'
//
//   - (defcmdline-init) initialize methods that add our option
//     parsers (held in slots named `.*-parser') using add-option
//
//   - (defcmdline-accessors) accessors that ask the parsers for the
//     values that were found
//
//  - (defcmdline-synopsis) a method printing usage information
//
define macro defcmdline-aux
    { defcmdline-aux ?:name (?supers:*) ?options:* end }
      => { defcmdline-class ?name (?supers) ?options end;
           defcmdline-init ?name ?options end;
           defcmdline-accessors ?name ?options end;
           defcmdline-synopsis ?name ?options end }
end macro;

define macro defcmdline-class
    { defcmdline-class ?:name (?supers:*) ?slots end }
      => { define class ?name (?supers)
             ?slots
           end class }

  slots:
    { [?class:name, ?option:name, ?value-type:expression, [?default:*],
       [?docstrings:*], #rest ?initargs:*,
       #key ?kind:expression = <flag-option>,
            ?short:expression = #(),
            ?long:expression = #(),
       #all-keys] ... }
      => { constant slot ?option ## "-parser"
             = begin
                 let long = ?long;
                 let short = ?short;
                 make(?kind,
                      long-names: select (long by instance?)
                                    <list> => long;
                                    otherwise => list(long);
                                  end select,
                      short-names: select (short by instance?)
                                     <list> => short;
                                     otherwise => list(short);
                                   end select,
                      ?initargs);
               end; ... }
    { [?class:name, ?positional-options:name] ... }
      => {  ... }
    { (?usage:*) ... }
      => { ... }
    { } => { }
end macro;

define macro defcmdline-init
    { defcmdline-init ?:name ?adders end }
      => { define method initialize (instance :: ?name,
                                     #next next-method, #key, #all-keys)
            => ();
             next-method();
             ?adders
           end method initialize }

  adders:
    { [?class:name, ?option:name, ?value-type:expression, [?default:*],
       [?docstrings:*], ?initargs:*] ... }
      => { add-option(instance, ?option ## "-parser" (instance)); ... }
    { [?class:name, ?positional-options:name] ... }
      => {  ... }
    { (?usage:*) ... }
      => { ... }
    { } => { }
end macro;

define macro defcmdline-accessors
    { defcmdline-accessors ?:name ?accessors end }
      => { ?accessors }

  accessors:
    { [?class:name, ?option:name, ?value-type:expression,
       [], [?docstrings:*], ?initargs:*] ... }
      => { define method ?option (arglistparser :: ?class)
            => (value :: ?value-type);
             let optionparser = ?option ## "-parser" (arglistparser);
             option-value(optionparser);
           end method ?option; ... }
    { [?class:name, ?option:name, ?value-type:expression,
       [?default:expression], [?docstrings:*], ?initargs:*] ... }
      => { define method ?option (arglistparser :: ?class)
            => (value :: ?value-type);
             let optionparser = ?option ## "-parser" (arglistparser);
             if (option-present?(optionparser))
               option-value(optionparser);
             else
               ?default;
             end if;
           end method ?option; ... }
    { [?class:name, ?positional-options:name] ... }
      => { define method ?positional-options (arglistparser :: ?class)
            => (value :: <sequence>);
             positional-options(arglistparser);
           end method; ... }
    { (?usage:*) ... }
      => { ... }
    { } => { }
end macro;

define macro defcmdline-synopsis
    { defcmdline-synopsis ?:name
       (?fn:name, ?usage:expression, ?description:expression)
       ?options
      end }
      => { define method ?fn (parser :: ?name, stream :: <stream>, #key) => ();
             let usage = ?usage;
             let desc = ?description;
             if (usage) format(stream, "Usage: %s\n", usage); end if;
             if (desc) format(stream, "%s\n", desc); end if;
             if (usage | desc) new-line(stream); end if;
             local method print-option(short, long, syntax, description);
                     let short = select (short by instance?)
                                   <list> => first(short);
                                   <string> => short;
                                   otherwise => #f;
                                 end select;
                     let long = select (long by instance?)
                                  <pair> => first(long);
                                  <string> => long;
                                  otherwise => #f;
                                end select;
                     write(stream, "  ");
                     if (short)
                       format(stream, "-%s", short);
                       if (long)
                         write(stream, ", ");
                       else
                         write(stream, "  ");
                       end if;
                     else
                       write(stream, "    ");
                     end if;
                     if (long)
                       format(stream, "--%s%s", long, syntax);
                       for (i from 1 to (28 - 2 - size(long) - size(syntax)))
                         write-element(stream, ' ');
                       end for;
                     else
                       format(stream, "%28s", "");
                     end if;
                     write(stream, description);
                     new-line(stream);
                   end method print-option;
             ?options
           end method ?fn; }

    { defcmdline-synopsis ?:name ?ignore:* end }
      => { }

  options:
    { [?class:name, ?option:name, ?value-type:expression,
       [?default:*], [?syntax:expression, ?description:expression],
       #rest ?initargs:*,
       #key ?short:expression = #f,
            ?long:expression = #f,
       #all-keys] ... }
      => { print-option(?short, ?long, ?syntax, ?description); ... }
    { [?class:name, ?positional-options:name] ... }
      => { ... }
    { } => { }
end macro;

// EOF
