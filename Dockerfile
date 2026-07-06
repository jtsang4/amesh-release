# Runs the amesh hub. Binaries are the published release assets; the image
# workflow stages them under build/linux_<arch>/ before building.
FROM scratch
ARG TARGETARCH
COPY build/linux_${TARGETARCH}/amesh /amesh
# WORKDIR creates the dirs in the image: /tmp for sqlite spill files, /data for the db
WORKDIR /tmp
WORKDIR /data
EXPOSE 8787
ENTRYPOINT ["/amesh"]
CMD ["hub", "run", "--listen", ":8787", "--db", "/data/hub.sqlite"]
