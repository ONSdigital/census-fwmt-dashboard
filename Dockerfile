FROM ruby:2.5

WORKDIR /usr/src/app

COPY ./ ./
COPY config.ru ./
COPY Gemfile Gemfile.lock ./

RUN apt-get update
RUN apt-get -y install nodejs
RUN bundle install

EXPOSE 3030
CMD bundle exec rackup -o 0.0.0.0 -p 3030
