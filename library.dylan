module: dylan-user
author:  Eric Kidd
copyright: See LICENSE file in this distribution.

define library command-line-parser
  use common-dylan;
  use dylan,
    import: { dylan-extensions };
  use io;
  use strings;
  use system;

  export
    command-line-parser,
    option-parser-protocol;
end library;

// Only used when defining new option-parser subclasses.
define module option-parser-protocol
  create
    // <command-line-parser>
      tokens-remaining?,
      pop-token,
      peek-token,
      find-option,
      add-pattern-substitution,
      selected-subcommand,
      positional-options,

    // <option>
      option-present?,
      option-names, long-names, short-names,
      option-help,
      option-default,
      option-might-have-parameters?, option-might-have-parameters?-setter,
      option-repeated?, option-repeated?-setter,
      option-value, option-value-setter,
      option-variable,
    parse-option,
    negative-option?,
    format-option-usage,

    <token>,
      token-value,
    <argument-token>,
    <option-token>,
    <short-option-token>,
      tightly-bound-to-next-token?, // XXX - not implemented fully
    <long-option-token>,
    <equals-token>;
end module option-parser-protocol;

// Used by most programs.
define module command-line-parser
  use common-dylan,
    exclude: { format-to-string };
  use dylan-extensions,
    import: { debug-name };
  use format;
  use locators;
  use option-parser-protocol;
  use standard-io;
  use strings;
  use streams;

  export
    <command-line-parser>,
    execute-command,
    add-option,
    parse-command-line,
    get-option-value,
    print-synopsis,

    parse-option-value;

  // Subcommands
  export
    <subcommand>,               // Subclass this for each subcommand...
    <help-subcommand>,          // ...except use this for the help subcommand.
    execute-subcommand;         // Override this for each subcommand.

  // Option classes
  export
    <option>,
    <flag-option>,               // --opt or --opt=yes/no
    <help-option>,               // --help (handled specially)
    <parameter-option>,          // --opt=value
    <choice-option>,             // --opt=<one of a, b, or c>
    <repeated-parameter-option>, // --opt=a --opt=b
    <optional-parameter-option>, // --opt (gives #t) or --opt=x
    <keyed-option>,              // --opt k1=v1 --opt k2=v2
    <positional-option>;         // Args with no - or -- preceding.
                                 // Must follow all - or -- options.

  // Error handling
  export
    <command-line-parser-error>,
      <abort-command-error>,    // Always catch this in main function.
        <usage-error>,          // Optionally handle this also.
    abort-command,              // Terminate the command with an exit status.
    exit-status,                // Status code from <abort-command-error>.
    usage-error;                // Terminate the command with a message.

  // define command-line
  export
    command-line-definer,
    defcmdline-rec,
    defcmdline-aux,
    defcmdline-class,
    defcmdline-init,
    defcmdline-accessors;

  // For the test suite. DO NOT DEPEND ON THESE!
  export
    program-name;
end module command-line-parser;
