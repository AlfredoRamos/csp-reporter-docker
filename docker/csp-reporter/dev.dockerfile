# ---[ Arguments ]---
ARG ALPINE_VERSION=3.20
ARG GO_VERSION=1.23.1-alpine

# ---[ Backend ]---
FROM golang:${GO_VERSION} AS backend-build
LABEL maintainer "Alfredo Ramos <alfredoramos@duck.com>"

# Backend setup
ENV CGO_ENABLED=0
RUN apk add --no-cache --virtual .build-backend postgresql-dev
WORKDIR /srv/http/backend
RUN rm -fR tmp
COPY backend/go.mod backend/go.sum ./
RUN go mod tidy
COPY backend/ ./
RUN go build -o /usr/local/bin/csp-reporter . && chmod a+x /usr/local/bin/csp-reporter; \
	go install github.com/hibiken/asynq/tools/asynq@latest; \
	apk del .build-backend

# ---[ Application ]---
FROM alpine:${ALPINE_VERSION}
LABEL maintainer "Alfredo Ramos <alfredoramos@duck.com>"

# Install OS dependencies
RUN apk add --no-cache curl

# App setup
WORKDIR /srv/http
RUN adduser -D -g http http
COPY docker/csp-reporter/start.sh /
RUN chmod a+x /start.sh
COPY --from=backend-build /srv/http/backend/.env backend/
COPY --from=backend-build /usr/local/bin/csp-reporter /go/bin/asynq /usr/local/bin/
COPY --from=backend-build /srv/http/backend/keys/ backend/keys/
COPY --from=backend-build /srv/http/backend/casbin/ backend/casbin/
COPY --from=backend-build /srv/http/backend/templates/ backend/templates/
COPY --from=backend-build /srv/http/backend/tasks/config.yml backend/tasks/

# Filesystem setup
RUN chown -R http:http .

# Non-root user
USER http

# Start server
CMD ["/start.sh"]
