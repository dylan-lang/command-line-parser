module: command-line-parser
synopsis: Individual option parsers.
authors: Eric Kidd, Jeff Dubrule <igor@pobox.com>
copyright: see below

//======================================================================
//
//  Copyright (c) 1998-2012 Eric Kidd, Jeff Dubrule, and Dylan Hackers
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
//  <negative-option>
//======================================================================
//  Certain options may occur in positive and negative forms. This
//  absract class takes care of the details.

define abstract open primary class <negative-option> (<option>)
  constant slot negative-long-options :: <list> /* of: <string> */,
    init-keyword: negative-long-options:,
    init-value: #();
  constant slot negative-short-options :: <list> /* of: <string> */,
    init-keyword: negative-short-options:,
    init-value: #();
end class <negative-option>;

define method initialize
    (parser :: <negative-option>, #next next-method, #key, #all-keys)
 => ()
  next-method();
  // We keep our own local lists of option names, because we support two
  // different types--positive and negative. So we need to explain about
  // our extra options to parse-options by adding them to the standard
  // list.
  parser.long-option-names := concatenate(parser.long-option-names,
                                          parser.negative-long-options);
  parser.short-option-names := concatenate(parser.short-option-names,
                                           parser.negative-short-options);
end method;

define method negative-option?
    (parser :: <negative-option>, token :: <option-token>)
 => (negative? :: <boolean>)
  let negatives =
    select (token by instance?)
      <short-option-token> => parser.negative-short-options;
      <long-option-token> => parser.negative-long-options;
    end select;
  member?(token.token-value, negatives, test: \=)
end method negative-option?;


//======================================================================
//  <simple-option>
//======================================================================
//  Simple options represent Boolean values. They may default to #t or
//  #f, and exist in both positive and negative forms ("--foo" and
//  "--no-foo"). In the case of conflicting options, the rightmost
//  takes precedence to allow for abuse of the shell's "alias" command.
//
//  Examples:
//    -q, -v, --quiet, --verbose

define class <simple-option> (<negative-option>)
  // Information used to reset our parse state.
  slot option-default-value :: <boolean>,
    init-keyword: default:,
    init-value: #f;
end class <simple-option>;

define method initialize
    (parser :: <simple-option>, #next next-method, #key, #all-keys)
 => ()
  next-method();
  parser.option-might-have-parameters? := #f;
end method initialize;

define method reset-option
    (parser :: <simple-option>, #next next-method) => ()
  next-method();
  parser.option-value := parser.option-default-value;
end;

define method parse-option
    (parser :: <simple-option>,
     arg-parser :: <argument-list-parser>)
 => ()
  let option = get-argument-token(arg-parser);
  parser.option-value := ~negative-option?(parser, option);
end method parse-option;


//======================================================================
//  <parameter-option>
//======================================================================
//  Parameter options represent a single parameter with a string value.
//  If the option appears more than once, the rightmost value takes
//  precedence. If the option never appears, these will default to #f.
//
//  Examples:
//    -cred, -c=red, -c = red, --color red, --color=red

define class <parameter-option> (<option>)
end class <parameter-option>;

define method parse-option
    (parser :: <parameter-option>,
     arg-parser :: <argument-list-parser>)
 => ()
  get-argument-token(arg-parser);
  if (instance?(peek-argument-token(arg-parser), <equals-token>))
    get-argument-token(arg-parser);
  end if;
  parser.option-value := get-argument-token(arg-parser).token-value;
end method parse-option;


//======================================================================
//  <repeated-parameter-option>
//======================================================================
//  Similar to the above, but these options may appear more than once.
//  The final value is a deque of parameter values in the order they
//  appeared on the command line. It defaults to the empty deque.
//
//  Examples:
//    -wall, -w=all, -w = all, --warnings all, --warnings=all

define class <repeated-parameter-option> (<option>)
end class <repeated-parameter-option>;

define method reset-option
    (parser :: <repeated-parameter-option>, #next next-method) => ()
  next-method();
  parser.option-value := make(<deque> /* of: <string> */);
end;

define method parse-option
    (parser :: <repeated-parameter-option>,
     arg-parser :: <argument-list-parser>)
 => ()
  get-argument-token(arg-parser);
  if (instance?(peek-argument-token(arg-parser), <equals-token>))
    get-argument-token(arg-parser);
  end if;
  push-last(parser.option-value, get-argument-token(arg-parser).token-value);
end method parse-option;


//======================================================================
//  <optional-parameter-option>
//======================================================================
//  Similar to <parameter-option>, but the parameter is optional.
//  It must directly follow the option with no intervening whitespace,
//  or follow an "=" token. The value is #f if the option never appears,
//  #t if the option appears but the parameter does not, and the value
//  of the parameter otherwise.
//
//  Examples:
//    -z, -z3, -z=3, -z = 3, --zip, --zip=3, --zip = 3
//  Counter-examples:
//    -z 3, --zip 3, --zip3

// TODO(cgay): Get rid of this and make it an init-arg on <parameter-option>.
define class <optional-parameter-option> (<option>)
end class <optional-parameter-option>;

define method parse-option
    (parser :: <optional-parameter-option>,
     arg-parser :: <argument-list-parser>)
 => ()
  let token = get-argument-token(arg-parser);
  let next = argument-tokens-remaining?(arg-parser) &
    peek-argument-token(arg-parser);

  parser.option-value :=
    case
      instance?(next, <equals-token>) =>
        get-argument-token(arg-parser);
        get-argument-token(arg-parser).token-value;
      (instance?(token, <short-option-token>)
         & token.tightly-bound-to-next-token?) =>
        get-argument-token(arg-parser).token-value;
      otherwise =>
        #t;
    end case;
end method parse-option;


//======================================================================
//  <keyed-option>
//======================================================================
//  These are a bit obscure. The best example is d2c's '-D' flag, which
//  allows users to #define a C preprocessor name. The final value is a
//  <string-table> containing each specified key, with one of the
//  following values:
//    * #t: The user specified "-Dkey"
//    * a <string>: The user specified "-Dkey=value"
//  You can read this with element(table, key, default: #f) to get a
//  handy lookup table.
//
//  Examples:
//    -Dkey, -Dkey=value, -D key = value, --define key = value

define class <keyed-option> (<option>)
end class <keyed-option>;

define method reset-option
    (parser :: <keyed-option>, #next next-method) => ()
  next-method();
  parser.option-value := make(<string-table>);
end;

define method parse-option
    (parser :: <keyed-option>,
     arg-parser :: <argument-list-parser>)
 => ()
  get-argument-token(arg-parser);
  let key = get-argument-token(arg-parser).token-value;
  let value =
    if (instance?(peek-argument-token(arg-parser), <equals-token>))
      get-argument-token(arg-parser);
      get-argument-token(arg-parser).token-value;
    else
      #t;
    end if;
  parser.option-value[key] := value;
end method parse-option;
