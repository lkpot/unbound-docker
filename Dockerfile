FROM debian:bookworm-slim AS source

ENV VERSION=1.22.0 \
    CHECKSUM=4e32a36d57cda666b1c8ee02185ba73462330452162d1b9c31a5b91a853ba946

WORKDIR /source
ADD --checksum="sha256:${CHECKSUM}" "https://github.com/NLnetLabs/unbound/archive/refs/tags/release-${VERSION}.tar.gz" .

RUN tar -xf "release-${VERSION}.tar.gz" -C . --strip-components=1 && \
    rm "release-${VERSION}.tar.gz"

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
