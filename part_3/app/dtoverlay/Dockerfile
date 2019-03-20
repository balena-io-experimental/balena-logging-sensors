FROM balenalib/armv7hf-alpine:latest

# Allow the user to override or specify the version of the DTC compiler to use.
# Default to the latest one at the time of this image's creation (1.4.7).
ARG DTC_TAG=v1.4.7

# Environment variables that control the behavior of the scripts.
# Default location to read and write overlay source and binary files.
ENV OVERLAYS_DIR=/overlays
ENV DTC_EXTRA_ARGS=

# Install dependencies.
RUN apk update && \
    apk add build-base flex bison git

# Compile and install the dtc compiler.
WORKDIR /opt
RUN git clone https://github.com/dgibson/dtc.git
WORKDIR /opt/dtc
RUN git checkout tags/$DTC_TAG -b release && \
    make && \
    cp dtc /usr/bin/

# Install scripts into usr/bin so the user can perform device tree commands.
COPY ./scripts/ /usr/bin/

# Install the balena_entrypoint.sh script to control which devices run this service.
COPY balena_entrypoint.sh /balena_entrypoint.sh

# Copy and compile any overlays into this container so they can later be loaded.
WORKDIR /overlays
COPY ./overlays/ /overlays/
RUN compile_overlays /overlays

ENTRYPOINT [ "/balena_entrypoint.sh" ]
CMD [ "help_text" ]
