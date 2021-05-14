# [ECOOP 2021][] artifact: Gradual Program Analysis for Null Pointers

The full version of the paper can be found here:
https://arxiv.org/abs/2105.06081

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
garden-variety "Hello, world!" Java program. The Docker image comes with
[`bat`][] installed, so you can view the program with syntax highlighting by
running this command (this doesn't show the actual terminal output, which is
fancier and includes line numbers):

```
~# batcat Hello.java
```
```java
class Hello {
  public static void main(String[] args) {
    System.out.println("Hello, world!");
  }
}
```

You can analyze it using our prototype like this:

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
  in this "Hello, world!" example. That is why the `GRADUAL_CHECK` (and also
  `GRADUAL_BOUNDARY`, as we'll see later) is colored yellow in the terminal
  output (although this README doesn't show the colors), while `GRADUAL_STATIC`
  will be colored red.

## Analyzing the `reverse` examples from section 2.2 of the paper

The preceding example was able to be very simple (just one `.java` file) because
it uses no `@Nullable` or `@NonNull` annotations, so we could just compile it
with `javac` and pass the results to `infer`. Our next goal is to analyze the
examples from section 2 of the paper, some of which use annotations, so we will
need to be able to pull in a dependency to define those annotations for us. For
this purpose, we will use [Gradle][].

All these examples (and the ones for section 2.3 as well) live in the
`~/examples` directory; you can see them all by running the `tree` command:

```
~# tree
.
|-- Hello.java
|-- README.md
`-- examples
    |-- 2.2
    |   |-- checker
    |   |   |-- poly
    |   |   |   |-- build.gradle
    |   |   |   `-- src
    |   |   |       `-- main
    |   |   |           `-- java
    |   |   |               `-- Main.java
    |   |   `-- unannotated
    |   |       |-- build.gradle
    |   |       `-- src
    |   |           `-- main
    |   |               `-- java
    |   |                   `-- Main.java
    |   |-- infer
    |   |   |-- nonnull
    |   |   |   |-- build.gradle
    |   |   |   `-- src
    |   |   |       `-- main
    |   |   |           `-- java
    |   |   |               `-- Main.java
    |   |   `-- unannotated
    |   |       |-- build.gradle
    |   |       `-- src
    |   |           `-- main
    |   |               `-- java
    |   |                   `-- Main.java
    |   `-- nullaway
    |       `-- unannotated
    |           |-- build.gradle
    |           `-- src
    |               `-- main
    |                   `-- java
    |                       `-- Main.java
    `-- 2.3
        |-- checker
        |   `-- unannotated
        |       |-- build.gradle
        |       `-- src
        |           `-- main
        |               `-- java
        |                   `-- Main.java
        |-- infer
        |   |-- nullable
        |   |   |-- build.gradle
        |   |   `-- src
        |   |       `-- main
        |   |           `-- java
        |   |               `-- Main.java
        |   `-- unannotated
        |       |-- build.gradle
        |       `-- src
        |           `-- main
        |               `-- java
        |                   `-- Main.java
        `-- nullaway
            `-- unannotated
                |-- build.gradle
                `-- src
                    `-- main
                        `-- java
                            `-- Main.java

45 directories, 20 files
```

### Infer [Eradicate][]

First, recall that you can use the `batcat` command to view the Java source code
for this example (again, running this in the terminal will give you line numbers
which are not shown here):

```
~# cd ~/examples/2.2/infer/unannotated
~/examples/2.2/infer/unannotated# batcat src/main/java/Main.java
```
```java

class Main {
  static String reverse(String str) {
    if (str == null) return new String();
    StringBuilder builder = new StringBuilder(str);
    builder.reverse();
    return builder.toString();
  }

  public static void main(String[] args) {
    String reversed = reverse(null);
    String frown = reverse(":)");
    String both = reversed.concat(frown);
    System.out.println(both);
  }
}
```

That same `batcat` command should also work for all the other examples that
follow, so the rest of this README will omit it and let you use it at your
leisure.

(Note that the only difference between this Java file and Figure 1 from the
paper is that lines 1 and 2 containing `class Main {` and the blank line have
been swapped with each other. This will allow us to use that blank line to put
`import`s later, and has the nice property that line numbers here will match up
exactly with the line numbers from the paper.)

Quoting the paper:

> The most straightforward approach to handling the missing annotations is to
> replace them with a fixed annotation. Infer Eradicate and the Java Nullness
> Checker both choose `@NonNull` as the default, since that is the most frequent
> annotation used in practice. Thus, in this example, they would treat
> `reverse`'s argument and return value as annotated with `@NonNull`. This
> correctly assigns `reversed` and `frown` as non-null on lines 11 and 12; and
> consequently, no false positive is reported when `reversed` is dereferenced on
> line 13. However, both tools will report a false positive each time `reverse`
> is called with `null`, as in line 11.

To verify this claim, let's run Eradicate on the example:

```
~/examples/2.2/infer/unannotated# infer run --eradicate-only -- gradle build
Capturing in gradle mode...
Running and capturing gradle compilation...
Found 1 source file to analyze in /root/examples/2.2/infer/unannotated/infer-out


Found 1 issue

src/main/java/Main.java:11: warning: ERADICATE_PARAMETER_NOT_NULLABLE
  `Main.reverse(...)` needs a non-null value in parameter 1 but argument `null` can be null. (Origin: null constant at line 11).
  9.
  10.     public static void main(String[] args) {
  11. >     String reversed = reverse(null);
  12.       String frown = reverse(":)");
  13.       String both = reversed.concat(frown);


Summary of the reports

  ERADICATE_PARAMETER_NOT_NULLABLE: 1
```

### Java Nullness [Checker][]

As mentioned in the quoted paragraph above, the nullness analysis from the
Checker framework does the same thing as Eradicate here:

```
~/examples/2.2/infer/unannotated# cd ~/examples/2.2/checker/unannotated
~/examples/2.2/checker/unannotated# gradle build

> Task :compileJava FAILED
/root/examples/2.2/checker/unannotated/src/main/java/Main.java:11: error: [argument.type.incompatible] incompatible argument for parameter str of reverse.
    String reversed = reverse(null);
                              ^
  found   : null (NullType)
  required: @Initialized @NonNull String
1 error

FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':compileJava'.
> Compilation failed; see the compiler error output for details.

* Try:
Run with --stacktrace option to get the stack trace. Run with --info or --debug option to get more log output. Run with --scan to get full insights.

* Get more help at https://help.gradle.org

BUILD FAILED in 6s
2 actionable tasks: 2 executed
```

### Java Nullness Checker and `@PolyNull`

Quoting from the paper again:

>  A more sophisticated choice would be the Java Nullness Checker's `@PolyNull`
>  annotation, which supports type qualifier polymorphism for methods annotated
>  with `@PolyNull`. If `reverse`'s method signature is annotated with
>  `@PolyNull`, then `reverse` would have two conceptual versions:
>
> ```
> static @Nullable String reverse(@Nullable String str)
>  static @NonNull String reverse(@NonNull String str)
> ```
>
> At a call site, the most precise applicable signature would be chosen; so,
> calling `reverse` with `null` (line 11) would result in the `@Nullable`
> signature, and calling `reverse` with `":)"` (line 12) would result in the
> `@NonNull` signature. Unfortunately, this strategy marks `reversed` on line 11
> as `@Nullable` even though it is `@NonNull`, and a false positive is reported
> when `reversed` is dereferenced on line 13.

Since the Checker framework (and NullAway, as we'll see later) integrates with
Gradle rather than capturing its compilation and then analyzing that, so running
it is a bit easier:

```
~/examples/2.2/checker/unannotated# cd ~/examples/2.2/checker/poly
~/examples/2.2/checker/poly# gradle build

> Task :compileJava FAILED
/root/examples/2.2/checker/poly/src/main/java/Main.java:13: error: [dereference.of.nullable] dereference of possibly-null reference reversed
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
2 actionable tasks: 2 executed
```

### Graduator

Now we use our prototype.

> In contrast, GNPA optimistically assumes both calls to `reverse` in `main`
> (lines 11-12) are valid without assigning fixed annotations to `reverse`'s
> argument or return value. Then, the analysis can continue relying on
> _contextual optimism_ when reasoning about the rest of `main`: `reversed` is
> assumed `@NonNull` to satisfy its dereference on line 13. Of course this is
> generally an unsound assumption, so a run-time check is insertedd to ascertain
> the non-nullness of `reversed` and preserve soundness.

When we run the analysis, that is exactly what we see (plus the check on
`System.out` which was explained above). Note that we run `gradle clean` so that
we can give Infer a clean build to analyze, since we've already run Eradicate on
this same example:

```
~/examples/2.2/checker/poly# cd ~/examples/2.2/infer/unannotated
~/examples/2.2/infer/unannotated# gradle clean

BUILD SUCCESSFUL in 361ms
1 actionable task: 1 executed
~/examples/2.2/infer/unannotated# infer run --gradual-only -- gradle build
Capturing in gradle mode...
Running and capturing gradle compilation...
Found 1 source file to analyze in /root/examples/2.2/infer/unannotated/infer-out


Found 2 issues

src/main/java/Main.java:14: warning: GRADUAL_CHECK
  check method call on ambiguous pointer `lang.System.java.lang.System.out`.
  12.       String frown = reverse(":)");
  13.       String both = reversed.concat(frown);
  14. >     System.out.println(both);
  15.     }
  16.   }

src/main/java/Main.java:13: warning: GRADUAL_CHECK
  check method call on ambiguous pointer `reversed`.
  11.       String reversed = reverse(null);
  12.       String frown = reverse(":)");
  13. >     String both = reversed.concat(frown);
  14.       System.out.println(both);
  15.     }


Summary of the reports

  GRADUAL_CHECK: 2
```

### Graduator and `@NonNull`

> Alternatively, a developer could annotate the return value of `reverse` with
> `@NonNull`. GNPA will operate as before except it will leverage this new
> information during static reasoning. Therefore, `reversed` will be marked
> `@NonNull` on line 11 and the dereference of `reversed` on line 13 will be
> statically proven safe without any run-time check.

```
~/examples/2.2/infer/unannotated# cd ~/examples/2.2/infer/nonnull
~/examples/2.2/infer/nonnull# infer run --gradual-only -- gradle build
Capturing in gradle mode...
Running and capturing gradle compilation...
Found 1 source file to analyze in /root/examples/2.2/infer/nonnull/infer-out


Found 2 issues

src/main/java/Main.java:7: warning: GRADUAL_BOUNDARY
  check ambiguous return in nonnull method `String Main.reverse(String)`.
  5.       StringBuilder builder = new StringBuilder(str);
  6.       builder.reverse();
  7. >     return builder.toString();
  8.     }
  9.

src/main/java/Main.java:14: warning: GRADUAL_CHECK
  check method call on ambiguous pointer `lang.System.java.lang.System.out`.
  12.       String frown = reverse(":)");
  13.       String both = reversed.concat(frown);
  14. >     System.out.println(both);
  15.     }
  16.   }


Summary of the reports

  GRADUAL_BOUNDARY: 1
     GRADUAL_CHECK: 1
```

As you can see from the output above, that claim is true, but we still have the
check on `System.out` as before, and now we also have a `GRADUAL_BOUNDARY` check
on line 7. This occurs for exactly the same reason as the check on `System.out`:
our analysis does not have any special logic to know that
[`StringBuilder#toString`][] never returns `null`, so to be safe, it notes that
we should insert a runtime check on the value of `builder.toString()` before
returning from `reverse`. This is something that the Java semantics will not do
automatically, so if somehow `builder.toString()` _were_ to return `null`, the
error would not be caught until the returned result is used on line 13. Again,
quoting from section 6.2 of the paper:

> A more complete implementation of GNPA would insert run-time checks as part of
> the build process. As a result, some bugs may be caught earlier when the
> gradual analysis inserts checks at method boundaries and field assignments.

### [NullAway][]

> NullAway assumes sinks are `@Nullable` and sources are `@NonNull` when
> annotations are missing. In fact, this strategy correctly annotates `reverse`,
> and so no false positives are reported by the tool for the program in Figure
> 1\.

As the below output shows, the only warning reported is not related to nullness,
and is simply scolding us for not nesting our Java code within a deeper
directory structure:

```
~/examples/2.2/infer/nonnull# cd ~/examples/2.2/nullaway/unannotated
~/examples/2.2/nullaway/unannotated# gradle build

> Task :compileJava
/root/examples/2.2/nullaway/unannotated/src/main/java/Main.java:2: warning: [DefaultPackage] Java classes shouldn't use default package
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

Other than some differences in annotations, all the above examples were using
the same Java source code. These last few examples will introduce one slight
change; quoting the paper:

> When Eradicate, NullAway, and the Java Nullness Checker handle missing
> annotations, they all give up soundness in an attempt to limit the number of
> false positives produced.
>
> To illustrate, consider the same program from Figure 1, with one single
> change: the `reverse` method now returns `null` instead of an empty string
> (line 4).
>
> ```java
> if (str == null) return null;
> ```
>
> All of the tools mentioned earlier, including NullAway, erroneously assume
> that the return value of `reverse` is `@NonNull`. On line 11, `reversed` is
> assigned `reverse(null)`'s return value of `null`; so, it is an error to
> dereference `reversed` on line 13. Unfortunately, all of the tools assume
> `reversed` is assigned a non-null value and do not report an error on line 13.
> This is a _false negative_, which means that at runtime the program will fail
> with a null-pointer exception.

The reader is invited to verify this claim by the example in each of the
following dirs:

- `~/examples/2.3/checker/unannotated`
- `~/examples/2.3/infer/unannotated`
- `~/examples/2.3/nullaway/unannotated`

One correction must be made to the paper here (we plan to address this in our
revision before submitting the camera-ready version). While it is true that none
of those three tools report an error on line 13, NullAway is the only one for
which this is genuinely a false negative. The other two analyses actually retain
soundness on this example by warning about the `return null;` statement on line
4\.

### Graduator

> GNPA is similarly optimistic about `reversed` being non-null on line 13.
> However, GNPA safeguards its optimistic static assumptions with run-time
> checks. Therefore, the analysis will correctly report an error on line 13.

Note that when the paper says "the analysis will report an error on line 13"
here, it is referring to the _dynamic_ run-time behavior of a hypothetical
implementation of our analysis that actually inserts run-time checks. While our
prototype does give a warning on line 13 as you can see below, this is in the
`GRADUAL_CHECK` category, and thus is not ultimately meant to be displayed to
the programmer.

```
~/examples/2.3/checker/unannotated# cd ~/examples/2.3/infer/unannotated
~/examples/2.3/infer/unannotated# gradle clean

BUILD SUCCESSFUL in 379ms
1 actionable task: 1 up-to-date
~/examples/2.3/infer/unannotated# infer run --gradual-only -- gradle build
Capturing in gradle mode...
Running and capturing gradle compilation...
Found 1 source file to analyze in /root/examples/2.3/infer/unannotated/infer-out


Found 2 issues

src/main/java/Main.java:14: warning: GRADUAL_CHECK
  check method call on ambiguous pointer `lang.System.java.lang.System.out`.
  12.       String frown = reverse(":)");
  13.       String both = reversed.concat(frown);
  14. >     System.out.println(both);
  15.     }
  16.   }

src/main/java/Main.java:13: warning: GRADUAL_CHECK
  check method call on ambiguous pointer `reversed`.
  11.       String reversed = reverse(null);
  12.       String frown = reverse(":)");
  13. >     String both = reversed.concat(frown);
  14.       System.out.println(both);
  15.     }


Summary of the reports

  GRADUAL_CHECK: 2
```

### Graduator and `@Nullable`

> Alternatively, a developer could annotate the return value of `reverse` with
> `@Nullable`. By doing so, the gradual analysis will be able to exploit this
> information statically to report a static error, instead of a dynamic error.

```
~/examples/2.3/infer/unannotated# cd ~/examples/2.3/infer/nullable
~/examples/2.3/infer/nullable# infer run --gradual-only -- gradle build
Capturing in gradle mode...
Running and capturing gradle compilation...
Found 1 source file to analyze in /root/examples/2.3/infer/nullable/infer-out


Found 2 issues

src/main/java/Main.java:14: warning: GRADUAL_CHECK
  check method call on ambiguous pointer `lang.System.java.lang.System.out`.
  12.       String frown = reverse(":)");
  13.       String both = reversed.concat(frown);
  14. >     System.out.println(both);
  15.     }
  16.   }

src/main/java/Main.java:13: error: GRADUAL_STATIC
  method call on possibly-null pointer `reversed`.
  11.       String reversed = reverse(null);
  12.       String frown = reverse(":)");
  13. >     String both = reversed.concat(frown);
  14.       System.out.println(both);
  15.     }


Summary of the reports

  GRADUAL_STATIC: 1
   GRADUAL_CHECK: 1
```

Our first `GRADUAL_STATIC` error! As you can see by running this in the
terminal, this one is colored red instead of yellow, and uses the word `error`
instead of `warning` to indicate that in a full implementation of our analysis,
it would actually be displayed to the programmer as a static diagnostic.

## Analyzing your own programs

The Docker image comes with [Vim][] and [Git][] installed, so you are free to
modify any of these examples to try out ideas, or (if you're feeling
particularly adventurous) clone a repository to try to analyze it with our
prototype. Enjoy, and thanks for reading!

[`bat`]: https://github.com/sharkdp/bat
[checker]: https://checkerframework.org/manual/
[docker]: https://docs.docker.com/get-docker/
[ecoop 2021]: https://2021.ecoop.org/
[eradicate]: https://fbinfer.com/docs/checker-eradicate
[git]: https://git-scm.com/
[gradle]: https://gradle.org/
[infer]: https://fbinfer.com/
[infer-gv-impl]: https://github.com/gradual-verification/graduator#infer-gv-impl
[nullaway]: https://github.com/uber/NullAway
[`StringBuilder#toString`]: https://docs.oracle.com/javase/8/docs/api/java/lang/StringBuilder.html#toString--
[`System.out`]: https://docs.oracle.com/javase/8/docs/api/java/lang/System.html#out
[vim]: https://www.vim.org/
