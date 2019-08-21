# Build binutils
FROM debian:jessie as binutils
MAINTAINER Nobuhiro Iwamatsu <nobuhiro1.iwamatsu@toshiba.co.jp>

RUN echo deb-src http://deb.debian.org/debian jessie main >> /etc/apt/sources.list && \
    apt-get update

RUN mkdir -p /opt/debian/cross
WORKDIR /opt/debian/cross

RUN apt-get -y build-dep --no-install-recommends cross-binutils && \
    apt-get source cross-binutils && \
    dpkg-source -x cross-binutils_0.23.dsc && \
    cd cross-binutils-0.23 && dpkg-buildpackage -B

RUN rm -rf cross-binutils*

# build GCC
FROM debian:jessie as gcc

RUN apt-get update && apt-get install -y --no-install-recommends wget && \
    echo deb http://emdebian.org/tools/debian/ jessie main >> /etc/apt/sources.list && \
    echo deb-src http://emdebian.org/tools/debian/ jessie main >> /etc/apt/sources.list && \
    echo deb-src http://deb.debian.org/debian jessie main >> /etc/apt/sources.list && \
    wget -qO - http://emdebian.org/tools/debian/emdebian-toolchain-archive.key | apt-key add - && \
    apt-get update

# copy binutils package from container of building binutils
RUN mkdir -p /opt/debian/cross
WORKDIR /opt/debian/cross
COPY --from=binutils /opt/debian/cross/ /opt/debian/cross/

# install binutils and source binary package for gcc
RUN apt-get install -y --no-install-recommends binutils dpkg-dev cross-gcc-dev gcc-4.9-source && \
    dpkg -i binutils-arm-linux-gnueabihf_2.25-5+deb8u1_amd64.deb binutils-i586-linux-gnu_2.25-5+deb8u1_amd64.deb

# Adhoc / update source package
RUN sed -i -e "s/4.9.2-10/4.9.2-10+deb8u2/g" /usr/share/cross-gcc/cross-gcc-dev-helpers.sh

# add atchitecture
RUN dpkg --add-architecture armhf && dpkg --add-architecture i386 && \
    apt-get update && apt-get -y --no-install-recommends install debhelper gcc-4.9-source \
    build-essential netbase bison flex libtool gdb sharutils libcloog-isl-dev \
    libmpc-dev libmpfr-dev libgmp-dev systemtap-sdt-dev \
    autogen expect chrpath zlib1g-dev zip \
    libc6-dev:armhf linux-libc-dev:armhf libgcc1:armhf \
    libc6-dev:i386 linux-libc-dev:i386 libgcc1:i386 

# Build cross gcc for armhf
RUN TARGET_LIST="armhf" HOST_LIST="amd64" cross-gcc-gensource 4.9 && cd cross-gcc-packages-amd64/cross-gcc-4.9-armhf/ && \
    dpkg-buildpackage -B && cp ../*.deb ../../.

# Build cross gcc for i386
RUN TARGET_LIST="i386" HOST_LIST="amd64" cross-gcc-gensource 4.9 && cd cross-gcc-packages-amd64/cross-gcc-4.9-i386/ && \
    dpkg-buildpackage -B && cp ../*.deb ../../.

# Remove source
RUN rm -rf cross-gcc-packages-amd64

# Build env
FROM debian:jessie as buildenv

# copy binutils package from container of building binutils
RUN mkdir -p /opt/debian/cross
WORKDIR /opt/debian/cross
COPY --from=gcc /opt/debian/cross/ /opt/debian/cross/

# add atchitecture
RUN dpkg --add-architecture armhf && dpkg --add-architecture i386 && apt-get update

# install packages
RUN dpkg -i binutils-arm-linux-gnueabihf_2.25-5+deb8u1_amd64.deb || apt-get install -f -y --no-install-recommends
RUN dpkg -i binutils-i586-linux-gnu_2.25-5+deb8u1_amd64.deb || apt-get install -f -y --no-install-recommends
RUN dpkg -i gcc-4.9-arm-linux-gnueabihf_4.9.2-10+deb8u2_amd64.deb cpp-4.9-arm-linux-gnueabihf_4.9.2-10+deb8u2_amd64.deb \
            g++-4.9-arm-linux-gnueabihf_4.9.2-10+deb8u2_amd64.deb || apt-get install -f -y --no-install-recommends
RUN dpkg -i gcc-4.9-i586-linux-gnu_4.9.2-10+deb8u2_amd64.deb cpp-4.9-i586-linux-gnu_4.9.2-10+deb8u2_amd64.deb \
            g++-4.9-i586-linux-gnu_4.9.2-10+deb8u2_amd64.deb || apt-get install -f -y --no-install-recommends
