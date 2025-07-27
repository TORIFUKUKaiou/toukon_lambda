# 🔥 闘魂Lambda 設定

import Config

# ログレベル設定
config :logger, level: :info

# Reqの設定（Lambda Runtime API対応）
config :req,
  default_options: [
    receive_timeout: :infinity,
    pool_timeout: :infinity,
    connect_options: [
      timeout: :infinity
    ]
  ]

# 本番環境設定
if config_env() == :prod do
  # 本番環境でのログ設定
  config :logger,
    level: :info,
    backends: [:console]

  # Lambda環境での最適化
  config :req,
    default_options: [
      receive_timeout: 60_000,
      pool_timeout: 60_000
    ]
end
