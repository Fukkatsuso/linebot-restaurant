FROM ruby:2.6.5

WORKDIR /app

RUN gem install bundler

EXPOSE 4567
