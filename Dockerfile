FROM debian:11.5-slim AS downloader

RUN apt-get update \
  && apt-get install -y \
    curl \
    equivs \
    rsync \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /setup

RUN curl https://tug.org/texlive/files/debian-equivs-2022-ex.txt --output texlive-local \
  && sed -i "s/2022/9999/" texlive-local \
  && equivs-build texlive-local \
  && mkdir -p /dst/dummy-texlive \
  && cp texlive-local_9999.99999999-1_all.deb /dst/dummy-texlive/

COPY ./config/*.txt /config/

RUN mkdir -p /dst \
  && rsync -av --stats --exclude-from=/config/exclude.txt \
    rsync://rsync.dante.ctan.org/CTAN/systems/texlive/tlnet/ /dst/texlive \
  && for file in $(cat /config/archive-include.txt); \
    do \
      rsync -lv --stats --exclude-from=/config/archive-exclude.txt \
        rsync://rsync.dante.ctan.org/CTAN/systems/texlive/tlnet/archive/$file \
        /dst/texlive/archive; \
    done;

COPY ./config/install.profile /dst/texlive/

FROM debian:11.5-slim AS slim

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    # ConTeXt cache can be created on runtime and does not need to
    # increase image size
    TEXLIVE_INSTALL_NO_CONTEXT_CACHE=1 \
    # As we will not install regular documentation why would we want to
    # install perl docs…
    NOPERLDOC=1

RUN apt-get update \
  && apt-get install -qy --no-install-recommends \
    # basic utilities for TeX Live installation
    curl \
    git \
    unzip \
    # miscellaneous dependencies for TeX Live tools
    make \
    fontconfig \
    perl \
    default-jre \
    libgetopt-long-descriptive-perl \
    libdigest-perl-md5-perl \
    libncurses5 \
    libncurses6 \
    # for syntax highlighting
    python3 \
    python3-pygments \
    # for telive-local dummy
    freeglut3 \
    gpg \
    gpg-agent \
  && rm -rf /var/lib/apt/lists/*

# download and install equivs file for dummy package
RUN --mount=from=downloader,source=/dst/dummy-texlive,target=/dummy-texlive \
  cd /dummy-texlive \
  && dpkg -i texlive-local_9999.99999999-1_all.deb \
  && apt-get install -yf --no-install-recommends \
  && apt-get autoremove -y --purge \
  && rm -rf /var/lib/apt/lists/*

RUN --mount=from=downloader,source=/dst/texlive,target=/texlive \
  cd texlive \
  && ./install-tl -profile install.profile
  # && $(find /usr/local/texlive -name tlmgr) path add

ENV PATH "/usr/local/texlive/2022/bin/x86_64-linux/:${PATH}"

COPY fastlatex /usr/local/bin/

WORKDIR /latex

FROM slim AS final

RUN apt-get update \
  && apt-get install poppler-utils -y \
  && rm -rf /var/lib/apt/lists/*

RUN tlmgr install \
    scheme-small \
    a4wide \
    apptools \
    bbm \
    bbm-macros \
    comment \
    fixme
