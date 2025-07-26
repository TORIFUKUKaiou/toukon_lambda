# マルチステージビルドで最適化（M2 Mac + AWS Lambda対応）
FROM hexpm/elixir:1.18.4-erlang-28.0.2-alpine-3.22.1 AS builder

# 作業ディレクトリ設定
WORKDIR /app

# 依存関係解決に必要なパッケージをインストール（M2 Mac対応）
RUN apk add --no-cache build-base git libstdc++ libgcc curl

# Mix設定（非対話モード）
ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm
RUN mix local.hex --force && \
    mix local.rebar --force

# 依存関係ファイルをコピー（Docker層キャッシュ最適化）
COPY mix.exs mix.lock ./

# 本番用依存関係を取得
ENV MIX_ENV=prod
RUN mix deps.get --only prod

# 依存関係をコンパイル
RUN mix deps.compile

# アプリケーションコードをコピー
COPY config ./config
COPY lib ./lib

# アプリケーションをコンパイル
RUN mix compile

# リリースビルド（最適化）
RUN mix release --overwrite

# === ランタイムステージ（M2 Mac + AWS Lambda対応） ===
FROM alpine:3.22.1 AS runtime

# 必要なランタイム依存関係をインストール（M2 Mac対応 + AWS Lambda対応）
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    bash \
    ca-certificates \
    libstdc++ \
    libgcc \
    curl

# AWS Lambda Runtime Interface Emulator (RIE)をインストール
RUN curl -Lo /usr/local/bin/aws-lambda-rie \
    https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie && \
    chmod +x /usr/local/bin/aws-lambda-rie

# 作業ディレクトリ設定
WORKDIR /var/task

# ビルドしたリリースをコピー
COPY --from=builder /app/_build/prod/rel/toukon_lambda ./

# Lambda用ブートストラップスクリプトをコピー
COPY bootstrap /var/task/bootstrap
RUN chmod +x /var/task/bootstrap

# Lambda Runtime Interface Emulator用の設定
ENV PATH="/var/task/bin:$PATH"

# エントリポイント設定
ENTRYPOINT ["/var/task/bootstrap"]
