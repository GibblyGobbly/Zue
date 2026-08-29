# Errors

How Zue reports a mistake, how to read the report, and every error code. The aim is that an error
tells you where, what, and what to write instead.

## Reading an error

```
Type Error [E0201] in prog.zu at line 3:
  cannot use '+' on int and string

   3 | print(total + name)
     |       ----- ^ ---- string
     |       |
     |       int

Hint: '+' joins two strings. Build text with interpolation, "{x} and {y}", or convert with to_string(x)
```

| Part | Meaning |
|---|---|
| `Type Error` | The kind: Syntax Error, Type Error, Name Error, Index Error, Argument Error, Runtime Error, Assertion Error or Fatal Error |
| `[E0201]` | The error code. `zue explain E0201` describes it |
| `prog.zu at line 3` | The file and the line |
| The message | What is wrong, in one sentence |
| The source line | The line itself, with a tab shown as four spaces |
| `^^^` | The exact text that is wrong, drawn under the line |
| `---` | Related text, with a short note: here the two operands and their types |
| `Hint:` | What to write instead |
| `Note:` | An extra remark |

A label may point at another line: a repeated name shows where it was first declared, a wrong
assignment shows where the variable got its type, a call with the wrong arguments shows where the
function is defined, and a missing bracket shows the bracket that was left open.

## Every error in one run

The lexer, the parser and the type checker do not stop at the first mistake. They record it, go on,
and print all of them in the order of the source, followed by `N errors found.`

- After a syntax error the parser skips to the start of the next statement, so one mistake does not
  cause a string of false ones. A forgotten closing bracket is noticed where the next line starts.
- At most one syntax error is reported for a line.
- A function body is checked once for each set of argument types, but a mistake in it is reported once.
- A name that is declared nowhere in the file is reported with a suggestion: `Did you mean 'items'?`

`zue check prog.zu` finds the lexical, syntax, type and import errors without building. It prints nothing and
exits with status 0 when there are none.

## Errors while the program runs

An error that happens at run time has the same shape, and the carets point at the exact operation:

```
Index Error [E0401] in prog.zu at line 6:
  Index 6 is out of bounds for list of length 3

   6 |     return xs[n]
     |            ^^^^^ index 6, valid indexes are 0 to 2

Hint: Ensure your index is between 0 and len-1
Call stack, innermost call first:
  in inner(), called at line 9: return inner(n + 5)
  in outer(), called at line 11: print(outer(pass(1)))
```

- For a binary operation the caret is under the operator and dashes are under the operands, with their types.
- For a builtin called with a wrong argument the caret is under that argument.
- The call stack lists the calls that were running, innermost first, with the line of each call. A long
  chain shows the first six calls, the last three, and how many were left out.
- A crash (an invalid memory access or an arithmetic fault) is caught and reported as a `Fatal Error`
  with the line it happened near and the call stack. The exit status is 128 plus the signal number.

## Machine-readable errors

| How | Output |
|---|---|
| `zue check --error-format=json prog.zu` (also `build`, `run`, `emit`) | One JSON object per compile error on its own line, with `kind`, `code`, `file`, `line`, `column`, `end_line`, `end_column`, `message`, `text`, `hint`, `labels`, `notes`, `trace` |
| `ZUE_ERROR_FORMAT=json ./program` | One JSON object for the run-time error, on standard error, with `kind`, `code`, `file`, `line`, `column`, `end_column`, `message`, `hint`, `stack` |

Columns count bytes from 1, and an end column is the column just after the last byte.

## Debugging a program: `zue build -g`

`-g` adds a line table to the program, so that `gdb`, `lldb`, `valgrind` and `perf` show the Zue file,
function and line instead of generated names. It is off by default because it makes the compiled
IR larger. `zue run -g prog.zu` and `zue emit -g prog.zu` take it too.

## Reporting a compiler bug

If LLVM rejects the IR that Zue generated, the message says `Internal compiler error`. That is a bug in
Zue, not in your program. The IR is kept in `C/<name>.ll`; `compiler/llvm_build.sh -c -o /dev/null C/<name>.ll`
shows what LLVM objected to. Please report the Zue file and the IR.

## The error codes

`zue explain` lists them, and `zue explain E0201` describes one with an example and the fix. The
descriptions live in `compiler/error_codes.txt`; `tools/gen_error_codes.py` turns that file into the
tables the compiler and the runtime use and into the list below, and `make codes-check` runs every
example to be sure it causes the error it claims to.

<!-- codes:start -->
| Code | Meaning |
|---|---|
| `E0101` | A string has no closing quote |
| `E0102` | An escape sequence is not known |
| `E0103` | A character is not part of the language |
| `E0104` | A number is written wrongly |
| `E0105` | A character literal is not one character |
| `E0106` | A string interpolation is not closed or not valid |
| `E0110` | An expression was expected |
| `E0111` | A closing bracket, brace or parenthesis is missing |
| `E0112` | A closing brace has no opening brace |
| `E0113` | A name is declared twice in one scope |
| `E0114` | A name was expected |
| `E0115` | A parameter without a default follows one with a default |
| `E0116` | Something that is not a variable is changed |
| `E0117` | A declaration has the wrong number of values |
| `E0118` | A type annotation is not valid |
| `E0119` | A map literal key is not a string |
| `E0120` | A field declaration is not allowed |
| `E0121` | A use or export is not valid |
| `E0122` | A switch has something other than case or default |
| `E0124` | A conversion or its 'else' is written wrongly |
| `E0125` | A named argument does not fit the call |
| `E0123` | A token other than the expected one was found |
| `E0420` | Two lists have different sizes |
| `E0201` | An operator is used on values of the wrong types |
| `E0202` | A function was given the wrong kind of value |
| `E0203` | A function was called with the wrong number of arguments |
| `E0204` | A value of the wrong type is stored |
| `E0205` | A condition is not true or false |
| `E0206` | An index or a slice position is not valid |
| `E0207` | A division by zero |
| `E0208` | Strict mode needs a type that is not known |
| `E0209` | A type name is not known |
| `E0210` | A typed field is given the wrong type |
| `E0211` | A call or value cannot be used this way |
| `E0301` | A name is not defined |
| `E0302` | An import cannot be resolved |
| `E0401` | An index or slice is outside its list or string |
| `E0402` | A field or key does not exist |
| `E0403` | A search found nothing |
| `E0410` | An integer calculation overflowed |
| `E0411` | A float calculation went out of range or outside its domain |
| `E0412` | A function was given a value it cannot work with |
| `E0413` | Text cannot be read as a number |
| `E0414` | A conversion would change the value |
| `E0430` | A function was given a list or value of the wrong shape |
| `E0440` | The program ran out of stack or memory |
| `E0450` | A file operation failed |
| `E0451` | The operating system could not give random bytes |
| `E0452` | A thread or a channel cannot go on |
| `E0460` | An unsafe rule was broken |
| `E0470` | A bloc or template rule was broken |
| `E0480` | An assertion failed |
| `E0490` | Crash |
<!-- codes:end -->
