FROM debian:bookworm-slim as source

ENV VERSION=1.19.3 \
    CHECKSUM=65494e69207fc64edf04fd1c2a42c31a3f350c3b74664af20148bcaa2e1e5d82

WORKDIR /source
ADD --checksum="sha256:${CHECKSUM}" "https://github.com/NLnetLabs/unbound/archive/refs/tags/release-${VERSION}.tar.gz" .

RUN tar -xf "release-${VERSION}.tar.gz" -C . --strip-components=1 && \
    rm "release-${VERSION}.tar.gz"

FROM debian:bookworm-slim as build

RUN apt-get update && \
    apt-get install -y \
      bison \
      build-essential \
      flex \
      libcap2-bin \
      libssl-dev \
      libevent-dev \
      libexpat1-dev \
      libprotobuf-c-dev \
      protobuf-c-compiler && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY --from=source /source .

RUN ./configure \
      --prefix=/usr \
      --sysconfdir=/etc \
      --with-run-dir="" \
      --with-pidfile="" \
      --with-libevent \
      --with-pthreads \
      --enable-dnstap && \
    make -j "$(nproc)" && \
    make install DESTDIR=/install

# Add NET_BIND_SERVICE capability
RUN setcap 'cap_net_bind_service=+ep' /install/usr/sbin/unbound

FROM debian:bookworm-slim

COPY --from=build /install /

RUN apt-get update && \
    apt-get install -y \
      ca-certificates \
      libevent-2.1-7 \
      libprotobuf-c1 && \
    rm -rf /var/lib/apt/lists/* && \
    useradd --system -s /usr/sbin/nologin unbound

USER unbound

ENTRYPOINT [ "unbound", "-d" ]
