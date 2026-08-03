FROM ruby:3.4

LABEL maintainer="Clearhaus"

WORKDIR /opt/pedicel-pay
COPY . /opt/pedicel-pay
RUN apt update && \
    apt install -y make libc-dev gcc && \
    bundle config set without 'development' && \
    bundle install

ENTRYPOINT ["/opt/pedicel-pay/exe/pedicel-pay"]
