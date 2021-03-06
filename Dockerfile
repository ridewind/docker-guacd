FROM ghcr.io/linuxserver/baseimage-ubuntu:focal as builder

ARG GUACD_VERSION=1.3.0

COPY /buildroot /

RUN \
 echo "**** install build deps ****" && \
 apt-get update && \
 apt-get install -qy --no-install-recommends \
	autoconf \
	automake \
	checkinstall \
	curl \
	freerdp2-dev \
	gcc \
	libavcodec-dev \
	libavformat-dev \
	libavutil-dev \
	libcairo2-dev \
	libjpeg-turbo8-dev \
	libogg-dev \
	libossp-uuid-dev \
	libpango1.0-dev \
	libpulse-dev \
	libssh2-1-dev \
	libssl-dev \
	libswscale-dev \
	libtelnet-dev \
	libtool \
	libvncserver-dev \
	libvorbis-dev \
	libwebsockets-dev \
	libwebp-dev \
	make

RUN \
 echo "**** prep build ****" && \
 curl -o /tmp/guacd.tar.gz \
	-L "https://downloads.apache.org/guacamole/${GUACD_VERSION}/source/guacamole-server-${GUACD_VERSION}.tar.gz" && \
 tar -xf /tmp/guacd.tar.gz -C /tmp && \
 mv /tmp/guacamole-server* /tmp/guacd && \
 echo "**** build guacd ****" && \
 cd /tmp/guacd && \
 autoreconf -fi && \
 ./configure \
	--prefix=/usr \
	--disable-guaclog && \
 make -j 2 && \
 mkdir -p /tmp/out && \
 /list-dependencies.sh \
	"/tmp/guacd/src/guacd/.libs/guacd" \
	$(find /tmp/guacd | grep "so$") \
	> /tmp/out/DEPENDENCIES && \
 PREFIX=/usr checkinstall \
	-y \
	-D \
	--nodoc \
	--pkgname guacd \
	--pkgversion "${GUACD_VERSION}" \
	--pakdir /tmp \
	--exclude "/usr/share/man","/usr/include","/etc" && \
 mv \
	/tmp/guacd_${GUACD_VERSION}-*.deb \
	/tmp/out/guacd_${GUACD_VERSION}.deb

# runtime stage
FROM ghcr.io/linuxserver/baseimage-ubuntu:focal

# set version label
ARG BUILD_DATE
ARG VERSION
ARG GUACD_VERSION=1.3.0
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="Thelamer"

# Copy deb into this stage
COPY --from=builder /tmp/out /tmp/out

RUN \
 echo "**** install guacd ****" && \
 dpkg --path-include=/usr/share/doc/${PKG_NAME}/* \
	-i /tmp/out/guacd_${GUACD_VERSION}.deb && \
 apt-get update && \
 apt-get install --no-install-recommends -y \
	ca-certificates \
	fonts-liberation \
	fonts-dejavu \
	ghostscript \
	xfonts-terminus \
	fonts-wqy-zenhei \
	$(cat /tmp/out/DEPENDENCIES) && \
 echo "**** clean up ****" && \
 rm -rf \
	/tmp/* \
	/var/lib/apt/lists/* \
	/var/tmp/*

# add local files
COPY /root /

# ports and volumes
EXPOSE 4822
