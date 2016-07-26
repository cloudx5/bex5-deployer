FROM buildpack-deps:jessie-curl

RUN apt-get update && apt-get install -y --no-install-recommends \
		zip \
		unzip \
	&& rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat
ENTRYPOINT ["docker-entrypoint.sh"]

