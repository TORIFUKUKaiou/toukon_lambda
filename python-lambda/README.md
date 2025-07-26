# 🔥 闘魂Python Lambda

DockerベースのAWS Lambda Python関数。後でElixirに移行するためのプロトタイプ。

## 構成

```
python-lambda/
├── lambda_function.py    # メインのLambda関数
├── requirements.txt      # Python依存関係
├── Dockerfile           # Docker設定
├── .dockerignore        # Docker除外ファイル
└── README.md           # このファイル
```

## 実行方法

### 1. ローカルでのテスト実行

```bash
cd python-lambda
python lambda_function.py
```

### 2. Dockerビルド

```bash
cd python-lambda
docker build -t toukon-python-lambda .
```

### 3. Dockerでローカル実行

```bash
# コンテナ起動
docker run -p 9000:8080 toukon-python-lambda

# 別ターミナルでテスト
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d '{"test": "toukon", "message": "Python闘魂テスト"}'
```

### 4. 標準入力での実行（従来方式）

```bash
echo '{"test": "toukon", "message": "Python闘魂テスト"}' | \
  docker run -i --entrypoint python toukon-python-lambda lambda_function.py
```

## 機能

- ✅ AWS Lambda Runtime Interface Emulator (RIE) 対応
- ✅ 構造化ログ出力
- ✅ エラーハンドリング
- ✅ APIGateway形式レスポンス
- ✅ 日本語文字列対応
- ✅ タイプヒント

## AWS Lambdaデプロイ

1. ECRにイメージをプッシュ
2. Lambda関数を作成/更新
3. 関数を実行

詳細は親ディレクトリの `deploy.sh` を参照。

## 闘魂ポイント

- 🔥 シンプルで分かりやすい実装
- 🔥 Elixir移行を見据えた構造
- 🔥 本格的なエラーハンドリング
- 🔥 ログ出力とモニタリング対応
