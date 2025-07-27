# 🔥 闘魂Lambda Dockerfile - 統合最適化版
# マルチステージビルド + サイズ最適化 + AWS Lambda対応

# =============================================================================
# ビルドステージ（共通）
# =============================================================================
FROM hexpm/elixir:1.18.4-erlang-28.0.2-alpine-3.22.1 AS builder

WORKDIR /app

# ビルド依存関係を一括インストール（レイヤー最適化）
RUN apk add --no-cache --virtual .build-deps \
    build-base \
    git && \
    apk add --no-cache \
    libstdc++ \
    libgcc

# Mix設定（本番用最適化）
ENV MIX_ENV=prod \
    ERL_FLAGS="+JPperf true +sbwt very_short +swt very_low" \
    ELIXIR_ERL_OPTIONS="+JPperf true" \
    DEBIAN_FRONTEND=noninteractive \
    TERM=xterm

RUN mix local.hex --force && \
    mix local.rebar --force

# 依存関係ファイルをコピー（キャッシュ効率化）
COPY mix.exs mix.lock ./

# 本番用依存関係を取得・コンパイル
RUN mix deps.get --only prod && \
    mix deps.compile

# アプリケーションコードをコピー
COPY config ./config
COPY lib ./lib

# アプリケーションをコンパイル + リリース
RUN mix compile && \
    mix release --overwrite

# ビルド依存関係を削除（サイズ削減）
RUN apk del .build-deps

# =============================================================================
# 本番ランタイム（極限最適化版 - AWS Lambda推奨）
# =============================================================================
FROM alpine:3.22.1 AS runtime

# 最小限のランタイム依存関係のみ
RUN apk add --no-cache \
    libstdc++ \
    libgcc \
    ncurses-libs

# AWS Lambda RIE（開発・テスト用、本番では不要）
ARG INSTALL_RIE=false
RUN if [ "$INSTALL_RIE" = "true" ]; then \
        wget -q -O /usr/local/bin/aws-lambda-rie \
        https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie && \
        chmod +x /usr/local/bin/aws-lambda-rie; \
    fi

WORKDIR /var/task

# ビルドしたリリースをコピー
COPY --from=builder /app/_build/prod/rel/toukon_lambda ./

# 最適化ブートストラップスクリプト
COPY bootstrap.optimized /var/task/bootstrap
RUN chmod +x /var/task/bootstrap

# 環境変数（パフォーマンス最適化）
ENV PATH="/var/task/bin:$PATH" \
    ERL_FLAGS="+JPperf true +sbwt very_short +swt very_low" \
    ELIXIR_ERL_OPTIONS="+JPperf true"

# 極限サイズ削減（不要ファイル削除）
RUN find /var/task -type f \( -name "*.beam.cache" -o -name "*.app.src" -o -name "*.debug" \) -delete && \
    find /var/task -type d -name "src" -exec rm -rf {} + 2>/dev/null || true && \
    find /var/task -type d -name "include" -exec rm -rf {} + 2>/dev/null || true && \
    rm -rf /var/task/releases/*/lib/*/ebin/*.app.src 2>/dev/null || true

ENTRYPOINT ["/var/task/bootstrap"]

# =============================================================================
# 開発用ランタイム（ローカルテスト用 - RIE付き）
# =============================================================================
FROM runtime AS development

# 開発用に追加パッケージをインストール（bash + RIE）
RUN apk add --no-cache bash && \
    wget -q -O /usr/local/bin/aws-lambda-rie \
    https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie && \
    chmod +x /usr/local/bin/aws-lambda-rie

# 開発用ブートストラップ（RIE対応 - 元のbootstrapファイル）
COPY bootstrap /var/task/bootstrap
RUN chmod +x /var/task/bootstrap

ENTRYPOINT ["/var/task/bootstrap"]
