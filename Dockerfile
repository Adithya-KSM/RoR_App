FROM ruby:3.2.2-slim

RUN apt-get update -qq && apt-get install -y \
    build-essential \
    default-libmysqlclient-dev \
    pkg-config \
    nodejs \
    npm \
    nginx \
    curl

WORKDIR /app

COPY Gemfile Gemfile.lock ./

ENV BUNDLE_JOBS=1
ENV BUNDLE_RETRY=3

RUN bundle install

COPY . .

ENV RAILS_ENV=production

RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile

COPY nginx/default.conf /etc/nginx/sites-available/default

COPY start.sh /app/start.sh

RUN chmod +x /app/start.sh

EXPOSE 80

CMD ["/app/start.sh"]
