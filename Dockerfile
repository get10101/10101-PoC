FROM gcr.io/distroless/cc

LABEL "org.opencontainers.image.source"="https://github.com/itchysats/10101"
LABEL "org.opencontainers.image.authors"="hello@itchysats.network"

ARG BINARY=./target/release/maker

USER 1000

COPY $BINARY /usr/bin/maker

# HTTP Port, LN P2P Port
EXPOSE 8000 9045

ENTRYPOINT ["/usr/bin/maker"]
