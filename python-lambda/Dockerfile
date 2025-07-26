# 🔥 闘魂Python Lambda Dockerfile

# AWS Lambda Python ランタイムベースイメージを使用
FROM public.ecr.aws/lambda/python:3.11

# 作業ディレクトリ設定
WORKDIR /var/task

# Python依存関係ファイルをコピー（存在する場合）
COPY requirements.txt* ./

# 依存関係をインストール（requirements.txtが存在する場合）
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi

# Lambda関数コードをコピー
COPY lambda_function.py ./

# ハンドラー関数を指定
CMD ["lambda_function.lambda_handler"]
