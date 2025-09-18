FROM debian:bookworm-slim AS source

ENV VERSION=1.24.0 \
    CHECKSUM=147b22983cc7008aa21007e251b3845bfcf899ffd2d3b269253ebf2e27465086

WORKDIR /source
ADD --checksum="sha256:${CHECKSUM}" "https://nlnetlabs.nl/downloads/unbound/unbound-${VERSION}.tar.gz" .

RUN tar -xf "unbound-${VERSION}.tar.gz" -C . --strip-components=1 && \
    rm "unbound-${VERSION}.tar.gz"

FROM debian:bookworm-slim AS build

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
      --enable-dnstap \
      --with-rootkey-file=/var/lib/unbound/root.key && \
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
      libexpat1 \
      libprotobuf-c1 && \
    rm -rf /var/lib/apt/lists/* && \
    useradd --system -s /usr/sbin/nologin unbound && \
    mkdir -p /var/lib/unbound && \
    (unbound-anchor -a /var/lib/unbound/root.key || :) && \
    chown -R unbound: /var/lib/unbound

USER unbound

ENTRYPOINT [ "unbound", "-d" ]
