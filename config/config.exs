# 🔥 闘魂Lambda 設定

import Config

# ログレベル設定
config :logger, level: :info

# HTTPoisonの設定（Lambda Runtime API対応）
config :httpoison,
  timeout: :infinity,
  recv_timeout: :infinity,
  hackney: [
    pool: false,
    checkout_timeout: :infinity,
    recv_timeout: :infinity
  ]

# 本番環境設定
if config_env() == :prod do
  # 本番環境でのログ設定
  config :logger,
    level: :info,
    backends: [:console]
    
  # Lambda環境での最適化
  config :httpoison,
    timeout: 60_000,
    recv_timeout: 60_000
end
