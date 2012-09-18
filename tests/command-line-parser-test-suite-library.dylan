module: dylan-user

define library command-line-parser-test-suite
  use command-line-parser;
  use common-dylan;
  use io;
  use testworks;

  export command-line-parser-test-suite;
end library;

define module command-line-parser-test-suite
  use command-line-parser;
  use common-dylan, exclude: { format-to-string };
  use format;
  use option-parser-protocol;
  use streams;
  use testworks;

  export command-line-parser-test-suite;
end module;
