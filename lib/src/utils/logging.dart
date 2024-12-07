import 'dart:io' show stderr, stdout;

/// Print status message to stdout.
void printStatus(String message, {bool? newline}) {
  if (newline ?? true) {
    stdout.writeln(message);
  } else {
    stdout.write(message);
  }
}

/// Print error message to stderr.
void printError(String message, {bool? newline}) {
  if (newline ?? true) {
    stderr.writeln(message);
  } else {
    stderr.write(message);
  }
}

/// Print trace message to stdout.
void printTrace(String message) {
  stdout.writeln(message);
}
