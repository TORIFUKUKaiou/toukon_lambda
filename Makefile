# 🔥 闘魂Lambda 完全自動化Makefile

# =============================================================================
# 環境変数とデフォルト値
# =============================================================================
AWS_REGION ?= ap-northeast-1
ECR_REPO_NAME ?= toukon-lambda
LAMBDA_FUNCTION_NAME ?= toukon-elixir-lambda
LAMBDA_TIMEOUT ?= 30
LAMBDA_MEMORY ?= 512

# 自動取得される値
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "PLEASE_SET_AWS_ACCOUNT_ID")
ECR_URI = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME)
LAMBDA_ROLE = arn:aws:iam::$(AWS_ACCOUNT_ID):role/lambda-execution-role

# =============================================================================
# メインターゲット
# =============================================================================
.PHONY: help setup build-local build-aws test-local test-aws clean
.PHONY: setup-iam setup-ecr push create-lambda update-lambda test-lambda deploy status

# デフォルトターゲット
help:
	@echo "🔥 闘魂Lambda Makefile"
	@echo "======================================"
	@echo ""
	@echo "🚀 メインコマンド:"
	@echo "  deploy         - 完全デプロイ（全工程自動実行）"
	@echo "  status         - 現在の状況確認"
	@echo ""
	@echo "🔧 開発コマンド:"
	@echo "  build-local    - ローカル開発用ビルド (ARM64)"
	@echo "  build-aws      - AWS Lambda用ビルド (x86_64)"
	@echo "  test-local     - ローカルテスト"
	@echo "  test-aws       - AWS互換テスト"
	@echo ""
	@echo "☁️  AWSコマンド:"
	@echo "  setup          - AWS環境セットアップ（IAM + ECR）"
	@echo "  push           - ECRにプッシュ"
	@echo "  create-lambda  - Lambda関数作成"
	@echo "  update-lambda  - Lambda関数更新"
	@echo "  test-lambda    - 本番Lambda関数テスト"
	@echo ""
	@echo "🧹 その他:"
	@echo "  clean          - ローカルイメージ削除"
	@echo ""
	@echo "📊 現在の設定:"
	@echo "  AWS_REGION: $(AWS_REGION)"
	@echo "  ECR_URI: $(ECR_URI)"
	@echo "  LAMBDA_FUNCTION: $(LAMBDA_FUNCTION_NAME)"

# =============================================================================
# ビルド・テスト
# =============================================================================

# ローカル開発用（M2 Mac ARM64）
build-local:
	@echo "🔥 ローカル用ビルド開始..."
	docker build -t toukon-lambda:local .
	@echo "✅ ローカルビルド完了"
	@docker images toukon-lambda:local --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# AWS Lambda用（x86_64）
build-aws:
	@echo "🔥 AWS Lambda用ビルド開始..."
	docker build --platform linux/amd64 -t toukon-lambda:aws .
	@echo "✅ AWS互換ビルド完了"
	@docker images toukon-lambda:aws --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# ローカルテスト
test-local: build-local
	@echo "🔥 ローカルテスト実行..."
	echo '{"test": "local", "message": "ローカル闘魂テスト"}' | docker run -i toukon-lambda:local

# AWS互換テスト
test-aws: build-aws
	@echo "🔥 AWS互換テスト実行..."
	@docker run --platform linux/amd64 -d --name toukon-test -p 9000:8080 toukon-lambda:aws || true
	@sleep 3
	@echo "テストリクエスト送信..."
	@curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" \
	  -d '{"test": "aws", "message": "AWS闘魂テスト"}' || echo "❌ テスト失敗"
	@docker stop toukon-test && docker rm toukon-test || true

# =============================================================================
# AWS環境セットアップ
# =============================================================================

# 完全セットアップ
setup: setup-iam setup-ecr
	@echo "✅ AWS環境セットアップ完了！"

# IAMロール作成
setup-iam:
	@echo "🔥 IAMロール作成..."
	@aws iam create-role \
	  --role-name lambda-execution-role \
	  --assume-role-policy-document '{ \
	    "Version": "2012-10-17", \
	    "Statement": [{ \
	      "Effect": "Allow", \
	      "Principal": {"Service": "lambda.amazonaws.com"}, \
	      "Action": "sts:AssumeRole" \
	    }] \
	  }' 2>/dev/null || echo "⚠️  IAMロールは既に存在します"
	@aws iam attach-role-policy \
	  --role-name lambda-execution-role \
	  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
	@echo "✅ IAMロール準備完了"

# ECRリポジトリ作成
setup-ecr:
	@echo "🔥 ECRリポジトリ作成..."
	@aws ecr create-repository \
	  --repository-name $(ECR_REPO_NAME) \
	  --region $(AWS_REGION) 2>/dev/null || echo "⚠️  ECRリポジトリは既に存在します"
	@echo "✅ ECRリポジトリ準備完了"
	@echo "📍 ECR URI: $(ECR_URI)"

# =============================================================================
# デプロイ
# =============================================================================

# ECRプッシュ
push: build-aws setup-ecr
	@echo "🔥 ECRプッシュ開始..."
	@echo "🔐 ECRにログイン中..."
	@aws ecr get-login-password --region $(AWS_REGION) | \
	  docker login --username AWS --password-stdin $(ECR_URI) || \
	  (echo "❌ ECRログイン失敗。AWS認証情報を確認してください" && exit 1)
	
	@echo "🏷️  イメージタグ付け..."
	docker tag toukon-lambda:aws $(ECR_URI):latest
	docker tag toukon-lambda:aws $(ECR_URI):v1.0.0
	
	@echo "📤 ECRプッシュ実行..."
	docker push $(ECR_URI):latest
	docker push $(ECR_URI):v1.0.0
	
	@echo "✅ ECRプッシュ完了！"
	@echo "🔗 Lambda関数作成用URI: $(ECR_URI):latest"

# Lambda関数作成
create-lambda: setup-iam
	@echo "🔥 Lambda関数作成開始..."
	@aws lambda create-function \
	  --function-name $(LAMBDA_FUNCTION_NAME) \
	  --package-type Image \
	  --code ImageUri=$(ECR_URI):latest \
	  --role $(LAMBDA_ROLE) \
	  --timeout $(LAMBDA_TIMEOUT) \
	  --memory-size $(LAMBDA_MEMORY) \
	  --region $(AWS_REGION) \
	  --description "🔥 闘魂Elixir Lambda Runtime" \
	  --architectures x86_64 || \
	  (echo "❌ Lambda関数作成失敗。ECRイメージを確認してください" && exit 1)
	@echo "✅ Lambda関数作成完了！"
	@echo "🌐 AWS Console: https://$(AWS_REGION).console.aws.amazon.com/lambda/home?region=$(AWS_REGION)#/functions/$(LAMBDA_FUNCTION_NAME)"

# Lambda関数更新（コード変更時）
update-lambda:
	@echo "🔥 Lambda関数更新開始..."
	@aws lambda update-function-code \
	  --function-name $(LAMBDA_FUNCTION_NAME) \
	  --image-uri $(ECR_URI):latest \
	  --region $(AWS_REGION) || \
	  (echo "❌ Lambda関数更新失敗" && exit 1)
	@echo "✅ Lambda関数更新完了！"

# Lambda関数テスト
test-lambda:
	@echo "🔥 本番Lambda関数テスト実行..."
	@aws lambda invoke \
	  --function-name $(LAMBDA_FUNCTION_NAME) \
	  --payload '{"test": "production", "message": "本番闘魂テスト", "timestamp": "'$$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
	  --region $(AWS_REGION) \
	  response.json > /dev/null
	@echo "📄 Lambda実行結果:"
	@cat response.json | jq . || cat response.json
	@rm -f response.json
	@echo ""
	@echo "📊 最新ログ確認:"
	@aws logs tail /aws/lambda/$(LAMBDA_FUNCTION_NAME) --since 2m --region $(AWS_REGION) || \
	  echo "⚠️  ログ取得失敗（関数が新しい場合は数分後に再試行してください）"

# =============================================================================
# 統合コマンド
# =============================================================================

# 完全デプロイ（初回用）
deploy: build-aws setup push create-lambda test-lambda
	@echo ""
	@echo "🎉🔥🎉🔥🎉🔥🎉🔥🎉🔥🎉🔥🎉🔥🎉"
	@echo "     闘魂Elixir Lambda デプロイ完了！    "
	@echo "🎉🔥🎉🔥🎉🔥🎉🔥🎉🔥🎉🔥🎉🔥🎉"
	@echo ""
	@echo "🌐 AWS Console URL:"
	@echo "   https://$(AWS_REGION).console.aws.amazon.com/lambda/home?region=$(AWS_REGION)#/functions/$(LAMBDA_FUNCTION_NAME)"
	@echo ""
	@echo "🧪 手動テスト:"
	@echo "   make test-lambda"
	@echo ""
	@echo "🔄 コード更新時:"
	@echo "   make build-aws push update-lambda"

# 現在の状況確認
status:
	@echo "🔥 闘魂Lambda 現在の状況"
	@echo "=================================="
	@echo ""
	@echo "📊 AWS設定:"
	@echo "  Account ID: $(AWS_ACCOUNT_ID)"
	@echo "  Region: $(AWS_REGION)"
	@echo "  ECR URI: $(ECR_URI)"
	@echo ""
	@echo "🐳 ローカルイメージ:"
	@docker images toukon-lambda --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" 2>/dev/null || echo "  なし"
	@echo ""
	@echo "☁️  ECRイメージ:"
	@aws ecr describe-images --repository-name $(ECR_REPO_NAME) --region $(AWS_REGION) \
	  --query 'imageDetails[0].{Pushed:imagePushedAt,Size:imageSizeInBytes,Tags:imageTags}' \
	  --output table 2>/dev/null || echo "  ECRイメージなし"
	@echo ""
	@echo "🚀 Lambda関数:"
	@aws lambda get-function --function-name $(LAMBDA_FUNCTION_NAME) --region $(AWS_REGION) \
	  --query 'Configuration.{Name:FunctionName,State:State,Memory:MemorySize,Timeout:Timeout,Updated:LastModified}' \
	  --output table 2>/dev/null || echo "  Lambda関数なし"

# =============================================================================
# クリーンアップ
# =============================================================================

# ローカルクリーンアップ
clean:
	@echo "🔥 ローカルクリーンアップ..."
	@docker rmi toukon-lambda:local toukon-lambda:aws 2>/dev/null || true
	@docker system prune -f
	@echo "✅ クリーンアップ完了"
