module: command-line-parser
synopsis: Interface macros for parser definition and option access.
authors: David Lichteblau <lichteblau@fhtw-berlin.de>
copyright: See LICENSE file in this distribution.

// TODO(cgay): Two improvements for synopsis
//   1. We have almost all the information we need to automatically generate
//      the usage line: "test [options] file...". The `positional-arguments`
//      clause needs a `name:` option so the dylan name needn't be used.
//   2. It's odd that `description` is a keyword argument to the synopsis clause
//      when the description is the one thing that can't be auto-generated and
//      should always be specified. Make it its own `description` clause and
//      change `synopsis` to `usage`, which should usually not be needed.
//
// TODO(cgay): Support for min/max number of positional args. The parser already
//   supports them. (This will improve `usage` auto-generation too.)

// Introduction
// ============
//
// This is a set of macros designed to work on top of Eric Kidd's
// command-line-parser library.  The idea is to provide a more readable
// interface for parser definition and option access.
//
//
// Emacs
// =====
//
// You will want to edit your .emacs to recognize keywords:
//
// (add-hook 'dylan-mode-hook
//           (lambda ()
//             (add-dylan-keyword 'dyl-parameterized-definition-words
//                                "command-line")
//             (add-dylan-keyword 'dyl-other-keywords "option")
//             (add-dylan-keyword 'dyl-other-keywords "positional-arguments")
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
//           option verbose?, names: #("verbose", "v");
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
//             names: #("logfile", "L");
//
//       - If you omit ``names:'', the default name is the option name.
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
//       - Besides ``option'' there is also ``positional-arguments'' and
//         ``synopsis'':
//           positional-arguments file-names;
//           synopsis "Usage: foo\n",
//             description: "This program fooifies.\n";
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
//           parse-command-line(parser, args);
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
//           option verbose?, names: #("v");
//         end command-line;
//
//         define method main (appname, #rest args);
//           let parser = make(<my-parser>);
//           parse-command-line(parser, args);
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
//           synopsis "test [options] file...",
//             description: "Stupid test program doing nothing with the args.";
//           option verbose?, names: #("v", "verbose"),
//             help: "Explanation";
//           option other, names: #("other-option"),
//             help: "foo";
//           option version, help: "Show version";
//         end command-line;
//
//    Then print-synopsis(parser, stream) will print something like:
//
//         Usage: test [options] file...
//         Stupid test program doing nothing with the args.
//           -v, --verbose                Explanation
//               --other-option           foo
//               --version                Show version
//

// Note: add the `traced` adjective to the `define macro` definitions to get
// some help from the compiler when debugging these hairy macros.

// Macro COMMAND-LINE-DEFINER--exported
// =======================================
// Syntax: define command-line ?:name (?supers:*) ?options end
//
//  - Let `?supers' default to <command-line-parser>.
//
//  - Transform human-readable `?options' into patterns of the form
//      [option-name, type, [default-if-any], #rest initargs]
//      [positional-arguments-name]
//      (usage, description)
//
//  - Hand it over to `defcmdline-rec'.
//
// Explanation: This macro defines the visible syntax of the various clauses
// and converts each into the internal syntax described just above for
// processing by defcmdline-rec.
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
    { option ?:name :: ?value-type:expression, #rest ?initargs:*; ... }
      => { [?name, ?value-type, [], ?initargs] ... }
    { option ?:name :: ?value-type:expression = ?default:expression,
        #rest ?initargs:*; ... }
      => { [?name, ?value-type, [?default], ?initargs] ... }
    { positional-arguments ?:name; ... }
      => { [?name] ... }
    { synopsis ?usage:expression, #key ?description:expression = #f; ... }
      => { (?usage, ?description) ... }
    { } => { }
end macro;

// Macro DEFCMDLINE-REC--internal
// ================================
// Syntax: defcmdline-rec ?:name (?supers:*) (?processed:*) ?options end
//
//   - Start out without `?processed' forms.
//   - (Recursively) take each `?options' form and add it to ?processed,
//     prepending it with the parser class name in the case of "option"
//     or "positional-arguments" clauses. The resulting `?processed' form
//     is a sequence of the following forms:
//       (usage, description)
//       [class-name, option-name, value-type, [default], initargs]
//       [class-name, positional-arguments-name]
//   - Finally, pass the `?processed' forms to `defcmdline-aux'.
//
// Explanation: The options will be processed by auxiliary rules
// managed by ``defcmdline-aux''.  However, these rules need the class
// name ``?name'', which would be available to main rules only.  This
// macro makes the name accessible to the auxiliary rules.
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
       #rest ?initargs:*,
       #key ?kind:expression = <flag-option>,
            ?names:expression = #f,
       #all-keys] ... }
      => { constant slot ?option ## "-parser"
             = begin
                 let names = ?names;
                 make(?kind,
                      names: names | #( ?"option" ),
                      type: ?value-type,
                      ?default,
                      ?initargs);
               end; ... }
    { [?class:name, ?positional-arguments:name] ... }
      => {  ... }
    { (?usage:*) ... }
      => { ... }
    { } => { }

  default:
    { ?:expression }
      => { default: ?expression }
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
       ?initargs:*] ... }
      => { add-option(instance, ?option ## "-parser" (instance)); ... }
    { [?class:name, ?positional-arguments:name] ... }
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
       [?default:*], ?initargs:*] ... }
      => { // Value may differ from ?value-type for <repeated-parameter-option>
           define method ?option (arglistparser :: ?class)
            => (value);
             let optionparser = ?option ## "-parser" (arglistparser);
             option-value(optionparser);
           end method ?option; ... }
    { [?class:name, ?positional-arguments:name] ... }
      => { define method ?positional-arguments (arglistparser :: ?class)
            => (value :: <sequence>);
             positional-arguments(arglistparser);
           end method; ... }
    { (?usage:*) ... }
      => { ... }
    { } => { }
end macro;

define macro defcmdline-synopsis
    { defcmdline-synopsis ?:name (?usage:expression, ?description:expression)
        ?options:*
      end }
      => { define method print-synopsis (parser :: ?name, stream :: <stream>,
                                         #next next-method,
                                         #key usage, description)
            => ();
             let usage = usage | ?usage;
             let desc = description | ?description;
             next-method(parser, stream, usage: usage, description: desc)
           end method }

    { defcmdline-synopsis ?:name ?options:* end }
      => { }
end macro;
