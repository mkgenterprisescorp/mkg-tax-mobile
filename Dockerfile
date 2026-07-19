# Staging Flutter web → nginx static site for DigitalOcean App Platform.
# Pin Flutter to docs/toolchain-versions.md / staging-apk.yml.
FROM ghcr.io/cirruslabs/flutter:3.44.6 AS build

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter config --enable-web \
  && flutter build web --release \
    --dart-define=API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1 \
    --dart-define=LARAVEL_API_BASE_URL=https://app.mkgtaxconsultants.com \
    --dart-define=WEB_BASE_URL=https://finance.mkgtaxconsultants.com

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health || exit 1
