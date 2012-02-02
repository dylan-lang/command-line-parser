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

  export
    command-line-parser,
    option-parser-protocol;
end library;

// Only used when defining new option-parser subclasses.
define module option-parser-protocol
  create
    // <argument-list-parser>
      argument-tokens-remaining?,
      get-argument-token,
      peek-argument-token,

    // <option-parser>
      short-option-names, short-option-names-setter,
      long-option-names, long-option-names-setter,
      option-description, option-description-setter,
      option-default-value, option-default-value-setter,
      option-might-have-parameters?, option-might-have-parameters?-setter,
      option-value-setter,
    reset-option-parser,
    parse-option,

    <negative-option-parser>,
    negative-option?,

    <argument-token>,
      token-value,
    <regular-argument-token>,
    <option-token>,
    <short-option-token>,
      tightly-bound-to-next-token?, // XXX - not implemented fully
    <long-option-token>,
    <equals-token>,

    usage-error;
end module;

// Used by most programs.
define module command-line-parser
  use common-dylan, exclude: { format-to-string };
  use option-parser-protocol;

  export
    <argument-list-parser>,
      regular-arguments,
    add-option-parser,
    add-option-parser-by-type,
    parse-arguments,
    option-parser-by-long-name,
    option-present?-by-long-name,
    option-value-by-long-name,
    print-synopsis,

    <option-parser>,
      option-present?,
      option-value,

    <simple-option-parser>,
    <parameter-option-parser>,
    <repeated-parameter-option-parser>,
    <optional-parameter-option-parser>,
    <keyed-option-parser>;

  use streams;
  use format;

  export
    argument-parser-definer,
    defargparser-rec,
    defargparser-aux,
    defargparser-class,
    defargparser-init,
    defargparser-accessors,
    defargparser-synopsis;
end module;
