#!/bin/bash
# 🔥 闘魂Python Lambda AWS デプロイスクリプト

set -euo pipefail

# 設定
AWS_REGION=${AWS_REGION:-"ap-northeast-1"}
FUNCTION_NAME=${FUNCTION_NAME:-"toukon-python-lambda"}
ECR_REPO_NAME=${ECR_REPO_NAME:-"toukon-python-lambda"}

echo "🔥 闘魂Python Lambda AWS デプロイ開始！"

# 現在のディレクトリを確認
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# AWS CLIとDockerが利用可能かチェック
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLIがインストールされていません"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "❌ Dockerがインストールされていません"
    exit 1
fi

# AWS アカウントIDを取得
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# ECRリポジトリURLを構築
ECR_REPO_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

echo "🏗️  ECRリポジトリを作成（既存の場合はスキップ）"
aws ecr create-repository \
    --repository-name ${ECR_REPO_NAME} \
    --region ${AWS_REGION} 2>/dev/null || echo "リポジトリが既に存在します"

echo "🔐 ECRにログイン"
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${ECR_REPO_URI}

echo "🏷️  Dockerイメージにタグ付け"
docker tag toukon-python-lambda:latest ${ECR_REPO_URI}:latest

echo "📤 ECRにプッシュ"
docker push ${ECR_REPO_URI}:latest

echo "🚀 Lambda関数を作成/更新"
if aws lambda get-function --function-name ${FUNCTION_NAME} --region ${AWS_REGION} &>/dev/null; then
    echo "📝 既存の関数を更新"
    aws lambda update-function-code \
        --function-name ${FUNCTION_NAME} \
        --image-uri ${ECR_REPO_URI}:latest \
        --region ${AWS_REGION}
else
    echo "🆕 新しい関数を作成"
    
    # IAMロールの作成（存在しない場合）
    ROLE_NAME="toukon-lambda-execution-role"
    if ! aws iam get-role --role-name ${ROLE_NAME} &>/dev/null; then
        echo "🔑 IAMロールを作成"
        aws iam create-role \
            --role-name ${ROLE_NAME} \
            --assume-role-policy-document '{
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Principal": {
                            "Service": "lambda.amazonaws.com"
                        },
                        "Action": "sts:AssumeRole"
                    }
                ]
            }'
        
        # 基本実行ロールポリシーをアタッチ
        aws iam attach-role-policy \
            --role-name ${ROLE_NAME} \
            --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
        
        echo "⏳ IAMロールの伝播を待機中..."
        sleep 10
    fi
    
    ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
    
    aws lambda create-function \
        --function-name ${FUNCTION_NAME} \
        --package-type Image \
        --code ImageUri=${ECR_REPO_URI}:latest \
        --role ${ROLE_ARN} \
        --region ${AWS_REGION} \
        --timeout 30 \
        --memory-size 512 \
        --description "🔥 闘魂Python Lambda - Dockerベース"
fi

echo "🔥 闘魂Python Lambda デプロイ完了！"
echo "関数名: ${FUNCTION_NAME}"
echo "リージョン: ${AWS_REGION}"
echo ""
echo "🧪 テスト実行:"
echo 'aws lambda invoke --function-name '${FUNCTION_NAME}' --payload '"'"'{"test": "toukon", "message": "AWS Lambda闘魂テスト"}'"'"' response.json --region '${AWS_REGION}
echo ""
echo "📄 レスポンス確認:"
echo "cat response.json | jq ."
