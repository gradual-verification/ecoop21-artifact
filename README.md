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

## Analyzing a simple Java program

This artifact comes with our custom build of [Infer][]:

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

[docker]: https://docs.docker.com/get-docker/
[ecoop 2021]: https://2021.ecoop.org/
[infer]: https://fbinfer.com/
