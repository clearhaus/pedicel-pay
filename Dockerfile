FROM ruby:2.3-slim-stretch

LABEL maintainer="Clearhaus"

WORKDIR /opt/pedicel-pay
COPY . /opt/pedicel-pay
RUN apt-get update && \
    apt-get install -y gcc libc-dev libssl-dev make && \
    bundle install --without development && \
    apt-get --purge remove -y gcc libc-dev libssl-dev make && \
    apt-get --purge autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/opt/pedicel-pay/exe/pedicel-pay"]
