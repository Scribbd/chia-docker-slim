# CHIA BUILD STEP
FROM python:3.9 AS chia_build

ARG BRANCH=latest

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
        lsb-release sudo

WORKDIR /chia-blockchain

RUN echo "cloning ${BRANCH}" && \
    git clone --branch ${BRANCH} --recurse-submodules=mozilla-ca https://github.com/Chia-Network/chia-blockchain.git . && \
    echo "running build-script" && \
    /bin/sh ./install.sh

ARG VDF_BUILD
# The current iteration of the install-timelord.sh script can't differentiate between Debian-Bullseye and Ubuntu assuming them to be the same.
# Snap will not work inside a container so this needs to be addressed upstream.
RUN if [ $VDF_BUILD = "true" ]; then \
        echo "building vdf-client" && \
        DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y cmake && \
        sed '/ubuntu_cmake_install$/d' ./install-timelord.sh > ./install-timelord-mod.sh && \
        . ./activate && \
        /bin/sh ./install-timelord-mod.sh ; \
    fi

# IMAGE BUILD
FROM python:3.9-slim

EXPOSE 8555 8444 8446

ENV CHIA_ROOT=/root/.chia/mainnet
ENV keys="generate"
ENV service="farmer"
ENV plots_dir="/plots"
ENV farmer_address=
ENV farmer_port=
ENV testnet="false"
ENV TZ="UTC"
ENV upnp="true"
ENV log_to_file="true"

# Deprecated legacy options
ENV harvester="false"
ENV farmer="false"

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y tzdata && \
    rm -rf /var/lib/apt/lists/* && \
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

COPY --from=chia_build /chia-blockchain /chia-blockchain

ENV PATH=/chia-blockchain/venv/bin:$PATH
WORKDIR /chia-blockchain

COPY docker-start.sh /usr/local/bin/
COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["docker-start.sh"]
