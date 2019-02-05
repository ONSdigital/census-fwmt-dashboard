FROM ruby:2.5

WORKDIR /usr/src/app

COPY ./ ./
COPY config.ru ./
COPY Gemfile Gemfile.lock ./

RUN bundle install

EXPOSE 3030
CMD bundle exec rackup -o 0.0.0.0 -p 3030
