FROM ubuntu:20.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --yes \
    autoconf automake bzip2 cmake curl gcc git libc6-dev libmpfr-dev \
    libsqlite3-dev make openjdk-8-jdk-headless patch pkg-config python2.7 \
    unzip zlib1g-dev
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
