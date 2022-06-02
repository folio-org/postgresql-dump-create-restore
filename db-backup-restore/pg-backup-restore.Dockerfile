FROM ubuntu:20.04

RUN apt update && apt install postgresql-client-12 curl unzip -y \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip && ./aws/install \
    && rm -rf /aws/ awscliv2.zip \

COPY pg_dump_restore.sh /
RUN chmod +x /pg_dump_restore.sh
