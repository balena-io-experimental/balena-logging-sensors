FROM balenalib/armv7hf-debian:stretch

COPY run.sh /run.sh

RUN install_packages wget gettext-base

WORKDIR /opt

RUN wget https://dl.grafana.com/oss/release/grafana-6.0.0.linux-armv7.tar.gz 2>/dev/null && \
    tar -zxvf grafana-6.0.0.linux-armv7.tar.gz

WORKDIR /opt/grafana-6.0.0

COPY provisioning ./conf/provisioning

CMD [ "/run.sh" ]
