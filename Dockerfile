# Staging Flutter web → nginx static site for DigitalOcean App Platform.
# Install Flutter from the official git tag (pinned). Do NOT use
# ghcr.io/cirruslabs/flutter — Cirrus stopped publishing images (May 2026),
# so tags like 3.44.6 are MANIFEST_UNKNOWN on GHCR.
FROM debian:bookworm-slim AS build

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       ca-certificates curl git unzip xz-utils \
  && rm -rf /var/lib/apt/lists/*

ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"
# Pin to docs/toolchain-versions.md / staging-apk.yml / local SDK.
ARG FLUTTER_VERSION=3.44.6

RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" \
      https://github.com/flutter/flutter.git "${FLUTTER_HOME}" \
  && flutter config --no-analytics --enable-web \
  && flutter precache --web

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release \
      --dart-define=API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1 \
      --dart-define=LARAVEL_API_BASE_URL=https://app.mkgtaxconsultants.com \
      --dart-define=WEB_BASE_URL=https://finance.mkgtaxconsultants.com \
      --dart-define=APP_NAME=MKG\ Tax\ Consultants \
      --dart-define=APP_ENV=preview

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health || exit 1
# Listen on 0.0.0.0:8080 via nginx.conf. Leave App Platform Run Command blank.
CMD ["nginx", "-g", "daemon off;"]
