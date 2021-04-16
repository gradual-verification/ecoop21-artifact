# [ECOOP 2021][] artifact: Gradual Program Analysis for Null Pointers

Once you have [Docker][] installed, open a terminal and run this command to
download and run the Docker image for this artifact:

```
$ docker run --pull=always -it ghcr.io/gradual-verification/ecoop21:latest
```

Once the image finishes downloading and extracting, you should see a shell
prompt like this:

```
root@eecbf09d2ea6:/home/ecoop#
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
/home/ecoop# infer --version
Infer version v0.16.0-1d5615bfe
Copyright 2009 - present Facebook. All Rights Reserved.
```

Our build includes a few extra CLI flags for `infer`, all of which start with
`--gradual`:

```
/home/ecoop# infer --help | grep -C1 gradual

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
/home/ecoop# infer run --gradual-only -- javac Hello.java
Capturing in javac mode...
Found 1 source file to analyze in /home/ecoop/infer-out


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

[docker]: https://docs.docker.com/get-docker/
[ecoop 2021]: https://2021.ecoop.org/
[infer]: https://fbinfer.com/
[infer-gv-impl]: https://github.com/gradual-verification/graduator#infer-gv-impl
[`System.out`]: https://docs.oracle.com/javase/8/docs/api/java/lang/System.html#out
