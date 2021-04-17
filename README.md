# [ECOOP 2021][] artifact: Gradual Program Analysis for Null Pointers

Once you have [Docker][] installed, open a terminal and run this command to
download and run the Docker image for this artifact:

```
$ docker run --pull=always -it ghcr.io/gradual-verification/ecoop21:latest
```

Once the image finishes downloading and extracting, you should see a shell
prompt like this:

```
root@35ca77075a98:~#
```

The string between the `@` and the `:` will vary, and the rest of this README
will omit it by abbreviating the prompt to just include the cwd and the
octothorpe `#`.

If you run `ls`, you should see this `README.md` file in the current directory,
in case you'd prefer to view it with `less README.md` rather than reading this
webpage.

## Analyzing "Hello, world!"

This artifact comes with [our custom build][infer-gv-impl] of [Infer][]:

```
~# infer --version
Infer version v0.16.0-1d5615bfe
Copyright 2009 - present Facebook. All Rights Reserved.
```

Our build includes a few extra CLI flags for `infer`, all of which start with
`--gradual`:

```
~# infer --help | grep -C1 gradual

       --gradual
           Activates: the gradual @Nullable checker for Java annotations
           (Conversely: --no-gradual)           See also infer-analyze(1).

       --gradual-dereferences
           Activates: warns about all deferences; does not analyze
           (Conversely: --no-gradual-dereferences)           See also infer-analyze(1).

       --gradual-dereferences-only
           Activates: Enable --gradual-dereferences and disable all other
           checkers (Conversely: --no-gradual-dereferences-only)
    See also infer-analyze(1).

       --gradual-only
           Activates: Enable --gradual and disable all other checkers
           (Conversely: --no-gradual-only)           See also infer-analyze(1).

       --gradual-unannotated
           Activates: doesn't take annotations into account (Conversely:
           --no-gradual-unannotated)           See also infer-analyze(1).

       --gradual-unannotated-only
           Activates: Enable --gradual-unannotated and disable all other
           checkers (Conversely: --no-gradual-unannotated-only)
    See also infer-analyze(1).
```

We will be using the `--gradual-only` flag, which corresponds to the main
prototype described in our paper (specifically the one we use in section 6.3,
"Static Warnings", under section 6, "Empirical Evaluation").

Another file in the current directory is `Hello.java`, which contains your
garden-variety "Hello, world!" Java program. You can analyze it using our
prototype like this:

```
~# infer run --gradual-only -- javac Hello.java
Capturing in javac mode...
Found 1 source file to analyze in /root/infer-out


Found 1 issue

Hello.java:3: warning: GRADUAL_CHECK
  check method call on ambiguous pointer `lang.System.java.lang.System.out`.
  1.   class Hello {
  2.     public static void main(String[] args) {
  3. >     System.out.println("Hello, world!");
  4.     }
  5.   }


Summary of the reports

  GRADUAL_CHECK: 1
```

It may seem strange that our analyzer gives a "warning" for this simple example;
here is the explanation:

- Recall (from section 6.2, "Prototype"):

  > Infer does not support modifying Java source code, so Graduator simply
  > reports the locations where it should insert run-time checks rather than
  > inserting them directly. In fact, Graduator may output any of the following:
  >
  > - `GRADUAL_STATIC` - a static warning
  > - `GRADUAL_CHECK` - a location to check a possibly-null dereference.
  > - `GRADUAL_BOUNDARY` - another location to insert a check, such as passing
  >   an argument to a method, returning from a method, or assigning a value to
  >   a field.

- Because our prototype is fairly minimal, we do not build in special rules for
  Java's vast standard library. In particular, our prototype does not know that
  [`System.out`][] is always non-`null`. Therefore, it emits a `GRADUAL_CHECK`
  to indicate that it would insert a runtime check to ensure that `System.out`
  is non-`null` before calling `println` on it.

- Java's semantics include this runtime check anyway (although the compiler may
  optimize it away), so in a way, the `GRADUAL_CHECK` is redundant here.
  However, very commonly (around 67% of the time, according to our preliminary
  experiments in section 6.4, "Run-time Checks"), our prototype does _not_ emit
  a `GRADUAL_CHECK`, indicating that it has statically determined the
  dereference to be unnecessary.

- In any case:

  > A more complete implementation of GNPA would insert run-time checks as part
  > of the build process.

  This "more complete implementation" would only statically report the instances
  where our current prototype emits a `GRADUAL_STATIC`, of which there are none
  in this "Hello, world!" example.

## Analyzing the `reverse` examples from section 2.2 of the paper

The preceding example was able to be very simple (just one `.java` file) because
it uses no `@Nullable` or `@NonNull` annotations, so we could just compile it
with `javac` and pass the results to `infer`. Our next goal is to analyze the
examples from section 2 of the paper, some of which use annotations, so we will
need to be able to pull in a dependency to define those annotations for us. For
this purpose, we will use [Gradle][].

### Infer [Eradicate][]

```
~# cd ~/examples/2.2/infer/unannotated
~/examples/2.2/infer/unannotated# infer run --eradicate-only -- gradle build
Capturing in gradle mode...
Running and capturing gradle compilation...
Found 1 source file to analyze in /root/examples/2.2/infer/unannotated/infer-out


Found 1 issue

src/main/java/Main.java:12: warning: ERADICATE_PARAMETER_NOT_NULLABLE
  `Main.reverse(...)` needs a non-null value in parameter 1 but argument `null` can be null. (Origin: null constant at line 12).
  10.
  11.     public static void main(String[] args) {
  12. >     String reversed = reverse(null);
  13.       String frown = reverse(":)");
  14.       String both = reversed.concat(frown);


Summary of the reports

  ERADICATE_PARAMETER_NOT_NULLABLE: 1
```

### Java Nullness [Checker][]

```
~/examples/2.2/infer/unannotated# cd ~/examples/2.2/checker/unannotated
~/examples/2.2/checker/unannotated# gradle build

> Task :compileJava
/root/examples/2.2/checker/unannotated/src/main/java/Main.java:12: error: [argument.type.incompatible] incompatible argument for parameter str of reverse.
    String reversed = reverse(null);
                              ^
  found   : null (NullType)
  required: @Initialized @NonNull String
1 error

> Task :compileJava FAILED

FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':compileJava'.
> Compilation failed; see the compiler error output for details.

* Try:
Run with --stacktrace option to get the stack trace. Run with --info or --debug option to get more log output. Run with --scan to get full insights.

* Get more help at https://help.gradle.org

BUILD FAILED in 7s
2 actionable tasks: 2 executed
```

### Java Nullness Checker and `@PolyNull`

```
~/examples/2.2/checker/unannotated# cd ~/examples/2.2/checker/poly
~/examples/2.2/checker/poly# gradle build

> Task :compileJava FAILED
/root/examples/2.2/checker/poly/src/main/java/Main.java:14: error: [dereference.of.nullable] dereference of possibly-null reference reversed
    String both = reversed.concat(frown);
                  ^
1 error

FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':compileJava'.
> Compilation failed; see the compiler error output for details.

* Try:
Run with --stacktrace option to get the stack trace. Run with --info or --debug option to get more log output. Run with --scan to get full insights.

* Get more help at https://help.gradle.org

BUILD FAILED in 2s
2 actionable tasks: 2 execute
```

### Graduator

```
~/examples/2.2/checker/poly# cd ~/examples/2.2/infer/unannotated
~/examples/2.2/infer/unannotated# gradle clean

BUILD SUCCESSFUL in 413ms
1 actionable task: 1 executed
~/examples/2.2/infer/unannotated# infer run --gradual-only -- gradle build
Capturing in gradle mode...
Running and capturing gradle compilation...
Found 1 source file to analyze in /root/examples/2.2/infer/unannotated/infer-out


Found 2 issues

src/main/java/Main.java:15: warning: GRADUAL_CHECK
  check method call on ambiguous pointer `lang.System.java.lang.System.out`.
  13.       String frown = reverse(":)");
  14.       String both = reversed.concat(frown);
  15. >     System.out.println(both);
  16.     }
  17.   }

src/main/java/Main.java:14: warning: GRADUAL_CHECK
  check method call on ambiguous pointer `reversed`.
  12.       String reversed = reverse(null);
  13.       String frown = reverse(":)");
  14. >     String both = reversed.concat(frown);
  15.       System.out.println(both);
  16.     }


Summary of the reports

  GRADUAL_CHECK: 2
```

### Graduator and `@NonNull`

```
~/examples/2.2/infer/unannotated# cd ~/examples/2.2/infer/nonnull
~/examples/2.2/infer/nonnull# infer run --gradual-only -- gradle build
Capturing in gradle mode...
Running and capturing gradle compilation...
Found 1 source file to analyze in /root/examples/2.2/infer/nonnull/infer-out


Found 2 issues

src/main/java/Main.java:8: warning: GRADUAL_BOUNDARY
  check ambiguous return in nonnull method `String Main.reverse(String)`.
  6.       StringBuilder builder = new StringBuilder(str);
  7.       builder.reverse();
  8. >     return builder.toString();
  9.     }
  10.

src/main/java/Main.java:15: warning: GRADUAL_CHECK
  check method call on ambiguous pointer `lang.System.java.lang.System.out`.
  13.       String frown = reverse(":)");
  14.       String both = reversed.concat(frown);
  15. >     System.out.println(both);
  16.     }
  17.   }


Summary of the reports

  GRADUAL_BOUNDARY: 1
     GRADUAL_CHECK: 1
```

### [NullAway][]

```
~/examples/2.2/infer/nonnull# cd ~/examples/2.2/nullaway/unannotated
~/examples/2.2/nullaway/unannotated# gradle build

> Task :compileJava
/root/examples/2.2/nullaway/unannotated/src/main/java/Main.java:3: warning: [DefaultPackage] Java classes shouldn't use default package
class Main {
^
    (see https://errorprone.info/bugpattern/DefaultPackage)
1 warning

Deprecated Gradle features were used in this build, making it incompatible with Gradle 7.0.
Use '--warning-mode all' to show the individual deprecation warnings.
See https://docs.gradle.org/6.8.3/userguide/command_line_interface.html#sec:command_line_warnings

BUILD SUCCESSFUL in 5s
2 actionable tasks: 2 executed
```

## Analyzing the modified `reverse` examples from section 2.3 of the paper

### Existing checkers

- `~/examples/2.3/infer/unannotated`
- `~/examples/2.3/nullaway/unannotated`
- `~/examples/2.3/checker/unannotated`

### Graduator

```
~/examples/2.3/checker/unannotated# cd ~/examples/2.3/infer/unannotated
~/examples/2.3/infer/unannotated# gradle clean

BUILD SUCCESSFUL in 3s
1 actionable task: 1 up-to-date
~/examples/2.3/infer/unannotated# infer run --gradual-only -- gradle build
Capturing in gradle mode...
Running and capturing gradle compilation...
Found 1 source file to analyze in /root/examples/2.3/infer/unannotated/infer-out


Found 2 issues

src/main/java/Main.java:15: warning: GRADUAL_CHECK
  check method call on ambiguous pointer `lang.System.java.lang.System.out`.
  13.       String frown = reverse(":)");
  14.       String both = reversed.concat(frown);
  15. >     System.out.println(both);
  16.     }
  17.   }

src/main/java/Main.java:14: warning: GRADUAL_CHECK
  check method call on ambiguous pointer `reversed`.
  12.       String reversed = reverse(null);
  13.       String frown = reverse(":)");
  14. >     String both = reversed.concat(frown);
  15.       System.out.println(both);
  16.     }


Summary of the reports

  GRADUAL_CHECK: 2
```

### Graduator and `@Nullable`

```
~/examples/2.3/infer/unannotated# cd ~/examples/2.3/infer/nullable
~/examples/2.3/infer/nullable# infer run --gradual-only -- gradle build
Capturing in gradle mode...
Running and capturing gradle compilation...
Found 1 source file to analyze in /root/examples/2.3/infer/nullable/infer-out


Found 2 issues

src/main/java/Main.java:15: warning: GRADUAL_CHECK
  check method call on ambiguous pointer `lang.System.java.lang.System.out`.
  13.       String frown = reverse(":)");
  14.       String both = reversed.concat(frown);
  15. >     System.out.println(both);
  16.     }
  17.   }

src/main/java/Main.java:14: error: GRADUAL_STATIC
  method call on possibly-null pointer `reversed`.
  12.       String reversed = reverse(null);
  13.       String frown = reverse(":)");
  14. >     String both = reversed.concat(frown);
  15.       System.out.println(both);
  16.     }


Summary of the reports

  GRADUAL_STATIC: 1
   GRADUAL_CHECK: 1
```

## Analyzing your own programs

The Docker image comes with [Vim][] and [Git][] installed.

[checker]: https://checkerframework.org/manual/
[docker]: https://docs.docker.com/get-docker/
[ecoop 2021]: https://2021.ecoop.org/
[eradicate]: https://fbinfer.com/docs/checker-eradicate
[git]: https://git-scm.com/
[gradle]: https://gradle.org/
[infer]: https://fbinfer.com/
[infer-gv-impl]: https://github.com/gradual-verification/graduator#infer-gv-impl
[nullaway]: https://github.com/uber/NullAway
[`System.out`]: https://docs.oracle.com/javase/8/docs/api/java/lang/System.html#out
[vim]: https://www.vim.org/
