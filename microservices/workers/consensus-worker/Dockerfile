FROM alpine:latest
WORKDIR /root/
COPY ../../Dockerfile.workers /tmp/Dockerfile.workers
# placeholder: image will be built using multi-stage in Dockerfile.workers via docker-compose build
CMD ["/bin/sh","-c","echo consensus-worker image built via root Dockerfile.workers && sleep infinity"]
