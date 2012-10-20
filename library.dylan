module: dylan-user
author:  Eric Kidd
copyright: Copyright 1998 Eric Kidd

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

    // <option>
    <option>,
      option-present?,
      option-names, long-names, short-names,
      option-help,
      option-default,
      option-might-have-parameters?, option-might-have-parameters?-setter,
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
    positional-options,
    add-option,
    parse-command-line,
    get-option-value,
    print-synopsis,

    // This is exported from the main module because it is expected to
    // be used relatively frequently for user types.
    parse-option-parameter,

    <flag-option>,
    <parameter-option>,
    <repeated-parameter-option>,
    <optional-parameter-option>,
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
