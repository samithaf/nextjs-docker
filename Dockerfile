FROM registry.access.redhat.com/ubi8/ubi-minimal:8.9-1137 as base

# base on https://github.com/sclorg/s2i-nodejs-container/tree/master/18-minimal

# Add $HOME/node_modules/.bin to the $PATH, allowing user to make npm scripts
# available on the CLI without using npm's --global installation mode
# This image will be initialized with "npm run $NPM_RUN"
# See https://docs.npmjs.com/misc/scripts, and your repo's package.json
# file for possible values of NPM_RUN
# Description
# Environment:
# * $NPM_RUN - Select an alternate / custom runtime mode, defined in your package.json files' scripts section (default: npm run "start").
# Expose ports:
# * 8080 - Unprivileged port used by nodejs application
ENV APP_ROOT=/opt/app-root \
    # The $HOME is not set by default, but some applications need this variable
    HOME=/opt/app-root/src \
    NPM_RUN=start \
    PLATFORM="el8" \
    NODEJS_VERSION=18 \
    NPM_RUN=start \
    NAME=nodejs

ENV SUMMARY="Minimal image for running Node.js $NODEJS_VERSION applications" \
    DESCRIPTION="Node.js $NODEJS_VERSION available as container is a base platform for \
running various Node.js $NODEJS_VERSION applications and frameworks. \
Node.js is a platform built on Chrome's JavaScript runtime for easily building \
fast, scalable network applications. Node.js uses an event-driven, non-blocking I/O model \
that makes it lightweight and efficient, perfect for data-intensive real-time applications \
that run across distributed devices." \
    NPM_CONFIG_PREFIX=$HOME/.npm-global \
    PATH=$HOME/node_modules/.bin/:$HOME/.npm-global/bin/:$PATH

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Node.js $NODEJS_VERSION Minimal" \
      com.redhat.dev-mode="DEV_MODE:false" \
      com.redhat.deployments-dir="${APP_ROOT}/src" \
      com.redhat.dev-mode.port="DEBUG_PORT:5858" \
      com.redhat.component="${NAME}-${NODEJS_VERSION}-minimal-container" \
      name="ubi8/$NAME-$NODEJS_VERSION-minimal" \
      version="1" \
      com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI" \
      maintainer="SoftwareCollections.org <sclorg@redhat.com>" \
      help="For more information visit https://github.com/sclorg/s2i-nodejs-container"

# Install Node.js packages and it's dependencies
RUN INSTALL_PKGS="nodejs npm findutils tar which" && \
    microdnf -y module disable nodejs && \
    microdnf -y module enable nodejs:$NODEJS_VERSION && \
    microdnf --nodocs --setopt=install_weak_deps=0 install $INSTALL_PKGS && \
    node -v | grep -qe "^v$NODEJS_VERSION\." && echo "Found VERSION $NODEJS_VERSION" && \
    microdnf clean all && \
    rm -rf /mnt/rootfs/var/cache/* /mnt/rootfs/var/log/dnf* /mnt/rootfs/var/log/yum.*

# Drop the root user and make the content of /opt/app-root owned by user 1001
RUN mkdir -p "$HOME" && chown -R 1001:0 "$APP_ROOT" && chmod -R ug+rwx "$APP_ROOT"
WORKDIR "$HOME"
USER 1001

FROM base as builder
WORKDIR "$HOME"
# Copy the Repo to HOME
COPY --from=repository . .
# Set Node env as production so we are enabling tree shaking and prod optimisations
ENV NODE_ENV test
# Uncomment the following line in case you want to disable telemetry during the build.
ENV NEXT_TELEMETRY_DISABLED 1
# Install the deps and run the lint and unit tests
RUN npm ci
# Set Node env as production for the build
ENV NODE_ENV production
# run the build
RUN npm run ci:build

FROM base as runner

# Set the ENV to production
ENV NODE_ENV production
# Uncomment the following line in case you want to disable telemetry during runtime
ENV NEXT_TELEMETRY_DISABLED 1

# TODO. We need to export the static assets to artifactory and during CD, these assets should be publish to Azure Blob storage.
COPY --from=builder $HOME/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=1001:1001 $HOME/.next/standalone ./
COPY --from=builder --chown=1001:1001 $HOME/.next/static ./.next/static

# Run the app as non privilaged 1001 user
USER 1001

EXPOSE 3000

ENV PORT 3000

ENTRYPOINT node apps/server.js
