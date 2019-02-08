FROM ruby:2.3

LABEL maintainer="Clearhaus"

WORKDIR /opt/pedicel-pay
COPY . /opt/pedicel-pay
RUN bundle install --without development

ENTRYPOINT ["/opt/pedicel-pay/exe/pedicel-pay"]
