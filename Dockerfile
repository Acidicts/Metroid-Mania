# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.4.7
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# 1. Install system packages (These rarely change, keep them at the top)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# --- BUILD STAGE ---
FROM base AS build

# 2. Install build tools with a cache mount
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config

# 3. Install Gems (Using cache mounts to avoid re-downloading)
COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/usr/local/bundle/cache \
    bundle install && \
    bundle exec bootsnap precompile -j 1 --gemfile

# 4. NOW declare ARGs (They only invalidate the code copy below, not the gems above)
ARG APP_URL
ARG AUTO_ADMIN
ARG AUTO_ADMIN_EMAIL
ARG AUTO_ADMIN_PASSWORD
ARG HACKATIME_API_KEY
ARG HACKCLUB_CLIENT_ID
ARG HACKCLUB_CLIENT_SECRET
ARG COOLIFY_URL
ARG COOLIFY_FQDN
ARG COOLIFY_BRANCH
ARG COOLIFY_RESOURCE_UUID

# 5. Copy code and compile assets
COPY . .
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Cache mount for assets to speed up subsequent precompiles
RUN --mount=type=cache,target=/rails/tmp/cache \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# --- FINAL STAGE ---
FROM base
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]