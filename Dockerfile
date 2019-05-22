FROM ruby:2.5

RUN apt-get update
RUN apt-get -y install nodejs

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY ./ ./

EXPOSE 3030
CMD bundle exec rackup -o 0.0.0.0 -p 3030
