module: dylan-user
author:  Eric Kidd
copyright: See LICENSE file in this distribution.

define library command-line-parser
  use common-dylan;
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
      reset-parser,
      argument-tokens-remaining?,
      get-argument-token,
      peek-argument-token,
      find-option,
      add-percent-substitution,

    // <option>
      option-present?,
      option-names, long-names, short-names,
      option-help,
      option-default,
      option-might-have-parameters?, option-might-have-parameters?-setter,
      option-value-is-collection?, option-value-is-collection?-setter,
      option-value, option-value-setter,
      option-variable,
    reset-option,
    parse-option,
    negative-option?,
    format-option-usage,

    <token>,
      token-value,
    <positional-option-token>,
    <option-token>,
    <short-option-token>,
      tightly-bound-to-next-token?, // XXX - not implemented fully
    <long-option-token>,
    <equals-token>;
end module option-parser-protocol;

// Used by most programs.
define module command-line-parser
  use common-dylan, exclude: { format-to-string };
  use format;
  use locators;
  use option-parser-protocol;
  use standard-io;
  use strings;
  use streams;

  export
    <command-line-parser>,
    positional-options,         // deprecated. not options.
    positional-arguments,
    add-option,
    parse-command-line,
    get-option-value,
    print-synopsis,

    // This is exported from the main module because it is expected to
    // be used relatively frequently for user types.
    parse-option-parameter,

    <option>,
    <flag-option>,
    <parameter-option>,
    <repeated-parameter-option>,
    <optional-parameter-option>,
    <choice-option>,
    <keyed-option>,

    <command-line-parser-error>,
      <usage-error>,
        <help-requested>,
    usage-error;

  export
    command-line-definer,
    defcmdline-rec,
    defcmdline-aux,
    defcmdline-class,
    defcmdline-init,
    defcmdline-accessors,
    defcmdline-synopsis;
end module command-line-parser;
