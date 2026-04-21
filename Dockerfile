# Use Elixir 1.15 image
FROM elixir:1.15-alpine

# Install build dependencies
RUN apk add --no-cache build-base git nodejs npm inotify-tools

# Prepare build directory
WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./
RUN mix deps.get

# Copy assets and install dependencies (if any)
# Note: assets/package.json might not exist if it's a minimal Phoenix install
# but looking at mix.exs, it has esbuild and tailwind.
COPY . .

# Expose Phoenix port
EXPOSE 4000

# Start command
CMD ["mix", "phx.server"]
