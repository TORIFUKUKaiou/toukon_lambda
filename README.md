# 🔥 闘魂Lambda

ElixirベースのAWS Lambda関数。AWS Lambda Runtime APIを実装。

## 構成

```
├── lib/
│   ├── toukon_lambda.ex          # メインモジュール
│   └── toukon_lambda/
│       ├── application.ex        # OTPアプリケーション
│       └── handler.ex           # Lambda Runtime APIハンドラー
├── config/
│   └── config.exs               # 設定ファイル

├── mix.exs                      # プロジェクト設定
├── mix.lock                     # 依存関係ロック
├── Dockerfile                   # Elixir Lambda用Docker設定
└── README.md                    # このファイル
```

## 実行方法

### 1. ローカル開発

```bash
# 依存関係のインストール
mix deps.get

# ローカルテスト（標準入力方式）
echo '{"test": "toukon", "message": "Elixir闘魂テスト"}' | mix run -e "ToukonLambda.Handler.handle_request()"
```

### 2. Dockerビルド

```bash
docker build -t toukon-lambda .
```

### 3. Lambda Runtime API テスト

```bash
# コンテナ起動
docker run -d -p 9000:8080 toukon-lambda

# テスト実行
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \\
  -d '{"test": "toukon", "message": "Elixir Lambda闘魂テスト"}'
```

## Lambda Runtime API実装

このプロジェクトは、AWSの公式Lambda Runtime APIを完全実装しています：

- **Next invocation**: `/runtime/invocation/next` (GET)
- **Invocation response**: `/runtime/invocation/{requestId}/response` (POST)
- **Initialization error**: `/runtime/init/error` (POST)
- **Invocation error**: `/runtime/invocation/{requestId}/error` (POST)

### 主要機能

- ✅ Lambda Runtime API v2018-06-01 完全対応
- ✅ エラーハンドリングとスタックトレース
- ✅ X-Ray トレーシング対応
- ✅ タイムアウト管理
- ✅ 構造化ログ出力
- ✅ M2 Mac対応

## AWS Lambda デプロイ

1. ECRリポジトリの作成
2. Dockerイメージのプッシュ
3. Lambda関数の作成
4. 関数の実行

詳細は `deploy.sh` スクリプトを参照。

## 闘魂ポイント

- 🔥 完全なLambda Runtime API実装
- 🔥 堅牢なエラーハンドリング
- 🔥 高性能BEAM VM活用
- 🔥 分散システム対応の基盤
