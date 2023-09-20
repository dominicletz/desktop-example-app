FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

# Installing wxWidgets
RUN apt-get update
RUN apt-get install -y libssl-dev libjpeg-dev libpng-dev libtiff-dev zlib1g-dev libncurses5-dev libssh-dev unixodbc-dev libgmp3-dev libsctp-dev libgtk-3-dev libnotify-dev libsecret-1-dev catch mesa-common-dev libglu1-mesa-dev freeglut3-dev
RUN apt-get install -y git xxd curl g++ make libwebkit2gtk-4.0-dev 

ENV WXWIDGETS_REPO=https://github.com/vadz/wxWidgets.git
# ENV WXWIDGETS_REPO=https://github.com/TcT2k/wxWidgets.git
# ENV WXWIDGETS_REPO=https://github.com/dominicletz/wxWidgets.git
# ENV WXWIDGETS_REPO=https://github.com/wxWidgets/wxWidgets.git
RUN mkdir ~/projects && cd ~/projects && \
    git clone ${WXWIDGETS_REPO}

ENV CMAKE_VERSION=3.27.4
RUN curl -sSL https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.sh > cmake.sh && \
    sh cmake.sh --skip-license --prefix=/usr/local

# ENV WXWIDGETS_VERSION=v3.1.4
# ENV WXWIDGETS_VERSION=chromium
ENV WXWIDGETS_VERSION=wide-init-fix
# ENV WXWIDGETS_VERSION=master
RUN cd ~/projects/wxWidgets && \
    git fetch origin && \
    git reset --hard origin/${WXWIDGETS_VERSION} && \
    git submodule update --init

# ENV WXWIDGETS_DEBUG=--enable-debug
ENV WXWIDGETS_DEBUG=
RUN cd ~/projects/wxWidgets && \
    ./configure --prefix=/usr/local/wxWidgets ${WXWIDGETS_DEBUG} --enable-webview --enable-compat30 && \
    make -j16

# Installing Erlang
ENV OTP_VERSION=25.3.2.6
ENV ELIXIR_VERSION=1.13.4
ENV ASDF_DIR=/root/.asdf
RUN git clone https://github.com/asdf-vm/asdf.git ${ASDF_DIR} && \
    . ${ASDF_DIR}/asdf.sh && \
    asdf plugin add erlang && \
    asdf plugin add elixir && \
    echo "erlang ${OTP_VERSION}" >> .tool-versions && \
    echo "elixir ${ELIXIR_VERSION}-otp-25" >> .tool-versions && \
    export KERL_CONFIGURE_OPTIONS="--with-wxdir=/root/projects/wxWidgets" && \
    asdf install

# Compile and lint
COPY mix.exs mix.lock .formatter.exs /app/
RUN . ${ASDF_DIR}/asdf.sh && \
    cd /app && \
    cp /.tool-versions .tool-versions && \
    mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix lint && \
    mix deps.compile

# Build Release
ENV LD_LIBRARY_PATH=/root/projects/wxWidgets/lib/
COPY . /app/
RUN . ${ASDF_DIR}/asdf.sh && \
    cd /app && \
    cp /.tool-versions .tool-versions && \
    MIX_ENV=prod mix compile

# Build Installer
RUN . ${ASDF_DIR}/asdf.sh  && \
    cd /app && \
    mix deps.update desktop && \
    mix deps.update desktop_deployment && \
    mix assets.deploy && \
    mix desktop.installer
