FROM oven/bun:1-slim

# curl is here on purpose. Lab 4 verifies the published route from inside the
# cluster, and the allowed-images policy from Lab 1 blocks pulling a throwaway
# curl image — so the tool has to travel with the application.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Dependencies first, so a code change does not re-resolve the SDK every build.
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production

COPY tsconfig.json index.ts ./

# The policy baseline refuses containers that run as root, so the image ships
# with a non-root user already created. The Deployments set runAsUser: 10001.
RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin appuser \
 && chown -R 10001:10001 /app
USER 10001

EXPOSE 8080
CMD ["bun", "run", "index.ts"]
