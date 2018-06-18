# Pull base image
FROM alpine:3.7 AS bluenode

ARG INFLUXDB_NAME

LABEL maintener="Vincent Fages <vfagesgo@gmail.com>"
LABEL contributor="Vincent Fages <vfagesgo@gmail.com>"

RUN apk add --no-cache --update bash dpkg \
    && touch /var/lib/dpkg/status


# Check the platform architecture
RUN dpkgArch="$(dpkg --print-architecture)" \
    &&    case "${dpkgArch##*-}" in \
          amd64) ARCH='amd64';; \
          arm64) ARCH='arm64';; \
          armhf) ARCH='armhf';; \
          armel) ARCH='armel';; \
          *)     echo "Unsupported architecture: ${dpkgArch}"; exit 1;; \
        esac \
     && echo ${ARCH}

# Install influxdb & telegraf
# https://github.com/influxdata/influxdata-docker/blob/master/influxdb/nightly/alpine/Dockerfile
# https://github.com/entelo/docker-statsd-influxdb-grafana

ENV INFLUXDB_VERSION=1.5.3
ENV TELEGRAF_VERSION=1.6.3
ENV GRAFANA_VERSION=5.1.3
ENV GLIBC_VERSION=2.26-r0
ENV GOSU_VERSION=1.10

ENV GOLANG_VERSION 1.9.2
ENV GOLANG_SRC_URL https://storage.googleapis.com/golang/go$GOLANG_VERSION.src.tar.gz
ENV GOLANG_SRC_SHA256 665f184bf8ac89986cfd5a4460736976f60b57df6b320ad71ad4cef53bb143dc

RUN set -ex \
    && apk add --no-cache --virtual .build-deps wget gnupg tar ca-certificates \
    && update-ca-certificates  \
    && for key in \
        05CE15085FC09D18E99EFB22684A14CF2582E0C5 ; \
    do \
        gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" || \
        gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
        gpg --keyserver keyserver.pgp.com --recv-keys "$key" ; \
    done \
    && ARCH= && dpkgArch="$(dpkg --print-architecture)" \
    &&    case "${dpkgArch##*-}" in \
          amd64) ARCH='amd64';; \
          arm64) ARCH='arm64';; \
          armhf) ARCH='armhf';; \
          armel) ARCH='armel';; \
          *)     echo "Unsupported architecture: ${dpkgArch}"; exit 1;; \
        esac \
    # Install influxdb
    && wget --no-verbose https://dl.influxdata.com/influxdb/releases/influxdb-${INFLUXDB_VERSION}_linux_${ARCH}.tar.gz.asc \
    && wget --no-verbose https://dl.influxdata.com/influxdb/releases/influxdb-${INFLUXDB_VERSION}_linux_${ARCH}.tar.gz \
    && gpg --batch --verify influxdb-${INFLUXDB_VERSION}_linux_${ARCH}.tar.gz.asc influxdb-${INFLUXDB_VERSION}_linux_${ARCH}.tar.gz \

    && mkdir -p /usr/src \
    && tar -C /usr/src -xzf influxdb-${INFLUXDB_VERSION}_linux_${ARCH}.tar.gz \

    && rm -f /usr/src/influxdb-*/influxdb.conf \
    && chmod +x /usr/src/influxdb-*/* \
    && cp -a /usr/src/influxdb-*/usr/bin/* /usr/bin/ \

    # Install telegraf
    && wget --no-verbose https://dl.influxdata.com/telegraf/releases/telegraf-${TELEGRAF_VERSION}_linux_${ARCH}.tar.gz.asc \
    && wget --no-verbose https://dl.influxdata.com/telegraf/releases/telegraf-${TELEGRAF_VERSION}_linux_${ARCH}.tar.gz \
    && gpg --batch --verify telegraf-${TELEGRAF_VERSION}_linux_${ARCH}.tar.gz.asc telegraf-${TELEGRAF_VERSION}_linux_${ARCH}.tar.gz \
    && tar -C /usr/src -xzf telegraf-${TELEGRAF_VERSION}_linux_${ARCH}.tar.gz \
    && mkdir -p /etc/telegraf \
    && mv /usr/src/telegraf/etc/telegraf/telegraf.conf /etc/telegraf/ \

    && chmod +x /usr/src/telegraf*/* \
    && cp -a /usr/src/telegraf/usr/* /usr/ \

    && rm -rf *.tar.gz* /usr/src /root/.gnupg \
    && apk del .build-deps

VOLUME /var/influxdb

EXPOSE 8086

EXPOSE 8125/udp 8092/udp 8094

RUN set -ex \
 && ARCH= && dpkgArch="$(dpkg --print-architecture)" \
     &&    case "${dpkgArch##*-}" in \
           amd64) ARCH='amd64';; \
           arm64) ARCH='arm64';; \
           armhf) ARCH='armhf';; \
           armel) ARCH='armel';; \
           *)     echo "Unsupported architecture: ${dpkgArch}"; exit 1;; \
         esac \
 && addgroup -S grafana \
 && adduser -S -G grafana grafana \
 && apk add --no-cache ca-certificates openssl fontconfig bash curl \
 && apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/community dumb-init \
 && curl -sL https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${ARCH} > /usr/sbin/gosu \
 && chmod +x /usr/sbin/gosu  \
 && wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://raw.githubusercontent.com/sgerrand/alpine-pkg-glibc/master/sgerrand.rsa.pub \
 && wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk \
 && apk add glibc-${GLIBC_VERSION}.apk \

 && GRAFANA_SRC= && RELEASE='release' && dpkgArch="$(dpkg --print-architecture)" \
      && case "${dpkgArch##*-}" in \
            amd64) GRAFANA_SRC='linux-amd64';; \
            arm64) GRAFANA_SRC='linux-arm64';; \
            armhf) GRAFANA_SRC='linux-armhf';; \
            armel) RELEASE='master'; GRAFANA_VERSION='5.2.0-18422pre1'; GRAFANA_SRC='linux-arm64';; \
            *)     echo "Unsupported architecture: ${dpkgArch}"; exit 1;; \
        esac \
 #wget https://github.com/fg2it/grafana-on-raspberry/releases/download/v${GRAFANA_VERSION}/grafana-${GRAFANA_VERSION}.${GRAFANA_SRC}.tar.gz;; \
 #wget https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana-${GRAFANA_VERSION}.${GRAFANA_SRC}.tar.gz;; \

 && GRAFANA_FILE=grafana-$GRAFANA_VERSION.${GRAFANA_SRC}.tar.gz \
 && wget --no-verbose https://github.com/vfagesgo/grafana/releases/download/v$GRAFANA_VERSION/$GRAFANA_FILE \
#RUN wget --no-verbose https://github.com/vfagesgo/grafana/releases/download/v5.1.3/grafana-5.1.3.linux-amd64.tar.gz \
 && tar -xzf grafana-$GRAFANA_VERSION.${GRAFANA_SRC}.tar.gz \
 && mv grafana-$GRAFANA_VERSION/ /var/grafana/ \
 && mv /var/grafana/bin/* /usr/local/bin/ \
 && mkdir -p /var/grafana/dashboards /var/grafana/data /var/grafana/logs /var/grafana/plugins /var/grafana/datasources \
 && mkdir /var/lib/grafana/ \
 && ln -s /var/grafana/plugins /var/lib/grafana/plugins \
 && grafana-cli plugins update-all \
 && rm -f /var/grafana/conf/*.ini \
 && rm grafana-$GRAFANA_VERSION.${GRAFANA_SRC}.tar.gz /etc/apk/keys/sgerrand.rsa.pub glibc-${GLIBC_VERSION}.apk \
 && apk del curl

VOLUME /var/grafana/data

EXPOSE 3000


# Install supervisord
RUN apk --no-cache add supervisor
COPY ./conf/supervisord.conf /etc/supervisord.conf

# Install python3
RUN apk add --no-cache python3 && \
    python3 -m ensurepip && \
    rm -r /usr/lib/python*/ensurepip && \
    pip3 install --upgrade pip setuptools && \
    if [ ! -e /usr/bin/pip ]; then ln -s pip3 /usr/bin/pip ; fi && \
    if [[ ! -e /usr/bin/python ]]; then ln -sf /usr/bin/python3 /usr/bin/python; fi && \
    rm -r /root/.cache

# Configuration
COPY ./conf/grafana.ini /var/grafana/conf/defaults.ini
COPY ./conf/telegraf.conf /etc/telegraf/telegraf.conf
COPY ./conf/influxdb.conf /etc/influxdb/influxdb.conf
COPY ./conf/blueinit.sh /etc/bluenote/blueinit.sh

RUN chown -R grafana:grafana /var/grafana \
    &&chmod +x /etc/bluenote/blueinit.sh

#COPY ./csv_feader/* /etc/bluenote/

#install influxdb python client
RUN pip3 install influxdb


ENTRYPOINT ["supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]


VOLUME /var/bluenote
WORKDIR /var/bluenote
