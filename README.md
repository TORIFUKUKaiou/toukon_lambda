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
├── scripts/
│   └── run_verification.exs     # 検証テストスクリプト
├── .kiro/specs/                 # 検証システム仕様書
├── mix.exs                      # プロジェクト設定
├── mix.lock                     # 依存関係ロック
├── Dockerfile                   # Elixir Lambda用Docker設定
├── bootstrap                    # AWS Lambda エントリポイント
├── Makefile                     # 自動化スクリプト
└── README.md                    # このファイル
```

## 🚀 **クイックスタート（Makefile使用）**

### **一発デプロイ（推奨）**
```bash
# AWS認証設定済みであることを確認
aws sts get-caller-identity

# 完全自動デプロイ（IAM + ECR + Lambda作成 + テスト）
make deploy
```

### **段階的実行**
```bash
# 1. ローカルビルドとテスト
make build-local test-local

# 2. AWS環境セットアップ
make setup

# 3. ECRプッシュ
make push

# 4. Lambda関数作成
make create-lambda

# 5. 本番テスト
make test-lambda
```

### **開発サイクル**
```bash
# コード変更後の更新
make build-aws push update-lambda test-lambda

# 現在の状況確認
make status
```

## 🔧 **手動実行方法**

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

### **📋 Makefileコマンド一覧**

```bash
# ヘルプ表示
make help

# 🚀 メインコマンド
make deploy         # 完全デプロイ（全工程自動実行）
make status         # 現在の状況確認

# 🔧 開発コマンド  
make build-local    # ローカル開発用ビルド (ARM64)
make build-aws      # AWS Lambda用ビルド (x86_64)
make test-local     # ローカルテスト
make test-aws       # AWS互換テスト

# ☁️ AWSコマンド
make setup          # AWS環境セットアップ（IAM + ECR）
make push           # ECRにプッシュ
make create-lambda  # Lambda関数作成
make update-lambda  # Lambda関数更新
make test-lambda    # 本番Lambda関数テスト

# 🧹 その他
make clean          # ローカルイメージ削除
```

### **📊 環境変数設定**

```bash
# デフォルト設定（変更可能）
export AWS_REGION=ap-northeast-1
export ECR_REPO_NAME=toukon-lambda
export LAMBDA_FUNCTION_NAME=toukon-elixir-lambda
export LAMBDA_TIMEOUT=30
export LAMBDA_MEMORY=512
```

### **🎯 手動実行（レガシー）**

従来通り手動でステップ実行したい場合：

1. ECRリポジトリの作成
2. Dockerイメージのプッシュ
3. Lambda関数の作成
4. 関数の実行

## 闘魂ポイント

- 🔥 完全なLambda Runtime API実装
- 🔥 堅牢なエラーハンドリング
- 🔥 高性能BEAM VM活用
- 🔥 分散システム対応の基盤
- 🔥 **完全自動化Makefile**（NEW！）
- 🔥 **包括的検証システム**（NEW！）

## 🧪 **検証システム**

`.kiro/specs/lambda-verification/` に詳細な検証システム仕様があります：

- **requirements.md** - 検証要件定義
- **design.md** - アーキテクチャ設計  
- **tasks.md** - 実装計画

### **検証テスト実行**

```bash
# 基本テスト
elixir scripts/run_verification.exs basic

# パフォーマンステスト
elixir scripts/run_verification.exs performance

# 全テスト実行
elixir scripts/run_verification.exs all
```

## 🚀 **次のステップ**

1. **ローカル開発**: `make build-local test-local`
2. **AWS デプロイ**: `make deploy` 
3. **検証実行**: `elixir scripts/run_verification.exs all`
4. **本番運用**: AWS Lambda Console で監視

**闘魂Elixir Lambda で AWS サーバーレスの新境地を開拓しましょう！** 🔥
