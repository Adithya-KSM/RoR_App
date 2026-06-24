FROM ruby:3.2.2-slim

RUN apt-get update -qq && apt-get install -y \
    build-essential \
    default-libmysqlclient-dev \
    pkg-config \
    nodejs \
    npm \
    nginx \
    curl \
    wget \
    unzip \
 && rm -rf /var/lib/apt/lists/*

# ── Install CloudWatch Agent ──────────────────────────────────────────────────
RUN wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/debian/amd64/latest/amazon-cloudwatch-agent.deb \
 && dpkg -i amazon-cloudwatch-agent.deb \
 && rm amazon-cloudwatch-agent.deb

WORKDIR /app

COPY Gemfile Gemfile.lock ./
ENV BUNDLE_JOBS=1
ENV BUNDLE_RETRY=3
RUN bundle install

COPY . .

ENV RAILS_ENV=production
RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile

# ── Copy configs ──────────────────────────────────────────────────────────────
COPY nginx/default.conf /etc/nginx/sites-available/default
COPY cloudwatch-agent-config.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 80
CMD ["/app/start.sh"]