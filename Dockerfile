FROM ubuntu:20.04
LABEL org.opencontainers.image.source https://github.com/gradual-verification/ecoop21-artifact

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --yes \
    autoconf automake bzip2 cmake curl gcc git libc6-dev libmpfr-dev \
    libsqlite3-dev make openjdk-8-jdk-headless patch pkg-config python2.7 \
    tree unzip vim zlib1g-dev

RUN curl -sL \
    https://github.com/ocaml/opam/releases/download/2.0.8/opam-2.0.8-x86_64-linux \
    > /usr/bin/opam
RUN chmod +x /usr/bin/opam
RUN opam init --disable-sandboxing
RUN eval $(opam env)

RUN git clone https://github.com/gradual-verification/infer-gv-impl.git
WORKDIR /infer-gv-impl
RUN ./build-infer.sh java
RUN make install

WORKDIR /
RUN curl -LO https://services.gradle.org/distributions/gradle-6.8.3-bin.zip
RUN mkdir /opt/gradle
RUN unzip -d /opt/gradle gradle-6.8.3-bin.zip
ENV GRADLE_HOME=/opt/gradle/gradle-6.8.3
ENV PATH=$PATH:$GRADLE_HOME/bin

WORKDIR /root/examples/2.2/infer/unannotated
COPY build.gradle .
COPY SafeReverse.java src/main/java/Main.java

WORKDIR /root/examples/2.2/checker/unannotated
COPY build-checker.gradle build.gradle
COPY SafeReverse.java src/main/java/Main.java

WORKDIR /root/examples/2.2/checker/poly
COPY build-checker.gradle build.gradle
COPY SafeReversePoly.java src/main/java/Main.java

WORKDIR /root/examples/2.2/infer/nonnull
COPY build.gradle .
COPY SafeReverseNonNull.java src/main/java/Main.java

WORKDIR /root/examples/2.2/nullaway/unannotated
COPY build-nullaway.gradle build.gradle
COPY SafeReverse.java src/main/java/Main.java

WORKDIR /root/examples/2.3/infer/unannotated
COPY build.gradle .
COPY Reverse.java src/main/java/Main.java

WORKDIR /root/examples/2.3/nullaway/unannotated
COPY build-nullaway.gradle build.gradle
COPY Reverse.java src/main/java/Main.java

WORKDIR /root/examples/2.3/checker/unannotated
COPY build-checker.gradle build.gradle
COPY Reverse.java src/main/java/Main.java

WORKDIR /root/examples/2.3/infer/nullable
COPY build.gradle .
COPY ReverseNullable.java src/main/java/Main.java

WORKDIR /root
COPY README.md .
COPY Hello.java .
