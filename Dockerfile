FROM ruby:2.7.4

LABEL maintainer="Clearhaus"

WORKDIR /opt/pedicel-pay
COPY . /opt/pedicel-pay
RUN apt update && \
    apt install make libc-dev gcc && \
    bundle install --without development

ENTRYPOINT ["/opt/pedicel-pay/exe/pedicel-pay"]
