module: command-line-parser
synopsis: Individual option parsers.
authors: Eric Kidd, Jeff Dubrule <igor@pobox.com>
copyright: See LICENSE file in this distribution.

//======================================================================
//  <flag-option>
//======================================================================
//  Flag options represent Boolean values. They may default to #t or
//  #f, and exist in both positive and negative forms ("--foo" and
//  "--no-foo"). In the case of conflicting options, the rightmost
//  takes precedence to allow for abuse of the shell's "alias" command.
//
//  Examples:
//    -q, -v, --quiet, --verbose

define open primary class <flag-option> (<option>)
  inherited slot option-might-have-parameters? = #f;
  constant slot negative-names :: <sequence> = #(),
    init-keyword: negative-names:;
  keyword type:, init-value: <boolean>;
end;

define method initialize
    (option :: <flag-option>, #key)
 => ()
  next-method();
  // We keep our own local list of option names because we support two
  // different types--positive and negative. So we need to explain about
  // our extra options to parse-options by adding them to the standard
  // list.
  // TODO(cgay): Do not like.  This is the only reason option-names can't
  // be a constant slot.  Replace option-names with %option-names slot
  // and make option-names do this concatenation.
  option.option-names := concatenate(option.option-names, option.negative-names);
end method;

define method negative-option?
    (option :: <flag-option>, token :: <option-token>)
 => (negative? :: <boolean>)
  member?(token.token-value, option.negative-names, test: \=)
end;

define method parse-option
    (option :: <flag-option>, parser :: <command-line-parser>)
 => ()
  let token = get-argument-token(parser);
  option.option-value := ~negative-option?(option, token);
end;


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
  keyword type:, init-value: <string>;
end class <parameter-option>;

define method parse-option
    (option :: <parameter-option>, parser :: <command-line-parser>)
 => ()
  get-argument-token(parser);
  if (instance?(peek-argument-token(parser), <equals-token>))
    get-argument-token(parser);
  end if;
  option.option-value
    := parse-option-parameter(get-argument-token(parser).token-value,
                              option.option-type);
end method parse-option;

define method format-option-usage
    (option :: <parameter-option>) => (usage :: <string>)
  format-to-string("%s=%s", option.canonical-option-name, option.option-variable)
end;


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
  inherited slot option-value-is-collection? = #t;
end class <repeated-parameter-option>;

define method reset-option
    (option :: <repeated-parameter-option>) => ()
  next-method();
  if (option.option-default)
    option.option-value := as(<deque>, option.option-default);
  else
    option.option-value := make(<deque> /*, of: <string> */);
  end;
end;

define method parse-option
    (option :: <repeated-parameter-option>,
     parser :: <command-line-parser>)
 => ()
  get-argument-token(parser);
  if (instance?(peek-argument-token(parser), <equals-token>))
    get-argument-token(parser);
  end if;
  push-last(option.option-value,
            parse-option-parameter(get-argument-token(parser).token-value,
                                   option.option-type));
end method parse-option;

define method format-option-usage
    (option :: <repeated-parameter-option>) => (usage :: <string>)
  format-to-string("%s=%s...", option.canonical-option-name, option.option-variable)
end;

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

define class <optional-parameter-option> (<option>)
end class <optional-parameter-option>;

define method parse-option
    (option :: <optional-parameter-option>, parser :: <command-line-parser>)
 => ()
  let token = get-argument-token(parser);
  let next = argument-tokens-remaining?(parser) &
    peek-argument-token(parser);

  option.option-value :=
    case
      instance?(next, <equals-token>) =>
        get-argument-token(parser);
        parse-option-parameter(get-argument-token(parser).token-value,
                               option.option-type);
      (instance?(token, <short-option-token>)
         & token.tightly-bound-to-next-token?) =>
        parse-option-parameter(get-argument-token(parser).token-value,
                               option.option-type);
      otherwise =>
        #t;
    end case;
end method parse-option;

define method format-option-usage
    (option :: <optional-parameter-option>) => (usage :: <string>)
  format-to-string("%s[=%s]", option.canonical-option-name, option.option-variable)
end;


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
    (option :: <keyed-option>) => ()
  next-method();
  option.option-value := make(<string-table>);
end;

define method parse-option
    (option :: <keyed-option>,
     parser :: <command-line-parser>)
 => ()
  get-argument-token(parser);
  let key = get-argument-token(parser).token-value;
  let value =
    if (instance?(peek-argument-token(parser), <equals-token>))
      get-argument-token(parser);
      parse-option-parameter(get-argument-token(parser).token-value,
                             option.option-type)
    else
      #t
    end;
  option.option-value[key] := value;
end method parse-option;

define method format-option-usage
    (option :: <keyed-option>) => (usage :: <string>)
  format-to-string("%sKEY=%s", option.canonical-option-name, option.option-variable)
end;


//======================================================================
//  <choice-option>
//======================================================================
//
// Limits possible values to a set of predefined choices.

// TODO(cgay): It should be possible to make one of the choices be
// no-value, but subclassing <optional-parameter-option> isn't right.
// Need to get rid of <optional-parameter-option> and replace it with
// a value-optional?: init arg on <option> or something.  Probably the
// same for repeated options.

define open class <choice-option> (<parameter-option>)
  constant slot option-choices :: <sequence>,
    required-init-keyword: choices:;
  constant slot option-test :: <function> = \=,
    init-keyword: test:;
end;

define method parse-option
    (option :: <choice-option>, parser :: <command-line-parser>)
 => ()
  next-method();
  if (~member?(option.option-value, option.option-choices,
               test: option.option-test))
    usage-error("%= is not a valid value for the %s option.  "
                  "Valid choices are %s.",
                option.option-value,
                option.canonical-option-name,
                join(option.option-choices, ", ", conjunction: " and "));
  end;
end method parse-option;
