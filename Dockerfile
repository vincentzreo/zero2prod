# builder stage
FROM lukemathwalker/cargo-chef:latest-rust-1.83.0 as chef
WORKDIR /app
RUN apt update && apt install lld clang -y

# planner stage
FROM chef as planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

# builder stage
FROM chef as builder
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json
COPY . .
ENV SQLX_OFFLINE=true
RUN cargo build --release --bin zero2prod

# runner stage
FROM debian:bookworm-slim as runtime

WORKDIR /app
RUN apt-get update -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    openssl \
    ca-certificates \
    # clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/zero2prod zero2prod
COPY configuration configuration
ENV APP_ENVIRONMENT=production
ENV RUST_LOG=info
ENTRYPOINT ["./zero2prod"]