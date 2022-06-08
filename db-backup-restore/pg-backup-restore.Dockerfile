FROM alpine:3.15.4

RUN apk add --no-cache postgresql-client curl unzip aws-cli

COPY pg_dump_restore.sh /
RUN chmod +x /pg_dump_restore.sh