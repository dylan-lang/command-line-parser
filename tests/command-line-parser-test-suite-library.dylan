module: dylan-user

define library command-line-parser-test-suite
  use command-line-parser;
  use common-dylan;
  use io;
  use strings;
  use system;
  use testworks;
end library;

define module command-line-parser-test-suite
  use command-line-parser;
  use common-dylan, exclude: { format-to-string };
  use format;
  use option-parser-protocol;
  use standard-io;
  use streams;
  use strings;
  use testworks;
  use threads;
end module;
