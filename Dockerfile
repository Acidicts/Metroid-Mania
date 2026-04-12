# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.4.7
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install system packages (These rarely change, keep them at the top)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips libpq5 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    PORT="80" \
    RAILS_SERVE_STATIC_FILES="1" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# --- BUILD STAGE ---
FROM base AS build

# 2. Install build tools with a cache mount
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config libpq-dev postgresql-client

# 3. Install Gems (Using cache mounts to avoid re-downloading)
COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/usr/local/bundle/cache \
    bundle install && \
    bundle exec bootsnap precompile -j 1 --gemfile

# 5. Copy code and compile assets
COPY . .
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Cache mount for assets to speed up subsequent precompiles
RUN --mount=type=cache,target=/rails/tmp/cache \
    HACKCLUB_CLIENT_ID=dummy HACKCLUB_CLIENT_SECRET=dummy SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# --- FINAL STAGE ---
FROM base
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]