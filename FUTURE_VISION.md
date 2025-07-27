# 🔥 ToukonExLambda - 将来構想ドキュメント

> シンプル・理解しやすい・高性能なElixir Lambda Runtime

## 📋 概要

ToukonExLambdaは、**シンプルさ**を重視したElixir用AWS Lambda Runtimeライブラリです。複雑なMagicを排除し、設定ベースの分かりやすい設計で、Elixir/BEAMの力をLambdaで最大限に活用します。

## 🎯 設計哲学

1. **シンプル First** - 複雑なマクロやMagicは不要
2. **設定ベース** - `config.exs`で明確な設定
3. **GenServer活用** - OTPの恩恵（自動復旧・状態管理）
4. **理解しやすさ** - コードを見れば動作が分かる

## �️ プロジェクト構成

```text
📦 toukon_ex_lambda/              # ライブラリリポジトリ
├── lib/
│   ├── toukon_ex_lambda.ex      # メインモジュール（Behaviour定義）
│   └── toukon_ex_lambda/
│       ├── application.ex       # OTP Application
│       └── runtime.ex           # GenServer Runtime実装
├── mix.exs                      # ライブラリ定義
└── README.md

📦 toukon_ex_lambda_starter/      # サンプル + インフラ
├── lambda_app/                  # Elixirアプリケーション
│   ├── lib/my_app/
│   │   └── handler.ex           # ビジネスロジック
│   ├── config/config.exs        # ⭐ キーポイント: handler設定
│   ├── mix.exs
│   └── Dockerfile
├── infra/                       # CDKインフラコード
└── README.md                    # 完全チュートリアル
```

## 🔧 ライブラリ設計 (`toukon_ex_lambda`)

### 1. メインモジュール - シンプルなBehaviour

```elixir
# lib/toukon_ex_lambda.ex
defmodule ToukonExLambda do
  @moduledoc """
  🔥 シンプルなElixir Lambda Runtime
  
  ## 使用方法（設定ベース - 推奨）
  
  1. Behaviourを実装
     defmodule MyApp.Handler do
       @behaviour ToukonExLambda
       
       def handle_event(event, context) do
         %{message: "Hello Lambda!"}
       end
     end
  
  2. config.exsで設定
     config :toukon_ex_lambda, handler: MyApp.Handler
  
  3. mix.exsでApplication指定
     def application do
       [mod: {ToukonExLambda.Application, []}]
     end
  
  これだけ！ シンプル！
  """
  
  @callback handle_event(event :: map(), context :: map()) :: map()
end
```

### 2. GenServer Runtime - 自動復旧対応

```elixir
# lib/toukon_ex_lambda/runtime.ex
defmodule ToukonExLambda.Runtime do
  @moduledoc """
  GenServer based Lambda Runtime
  - AWS Lambda Runtime API実装
  - 自動復旧機能
  - ローカル開発サポート
  """
  
  use GenServer
  require Logger
  
  def start_link(handler_module) do
    GenServer.start_link(__MODULE__, handler_module, name: __MODULE__)
  end
  
  def init(handler_module) do
    runtime_api = System.get_env("AWS_LAMBDA_RUNTIME_API")
    
    if runtime_api do
      Logger.info("🔥 AWS Lambda モード")
      Task.start_link(fn -> aws_lambda_loop(runtime_api, handler_module) end)
      {:ok, %{mode: :aws_lambda, handler: handler_module, runtime_api: runtime_api}}
    else
      Logger.info("🔥 ローカル開発モード")
      Task.start_link(fn -> local_execution(handler_module) end)
      {:ok, %{mode: :local, handler: handler_module}}
    end
  end
  
  # 🛡️ 自動復旧機能
  def handle_info({:restart_runtime, handler}, state) do
    Logger.info("� Runtime 再起動中...")
    
    case state.mode do
      :aws_lambda ->
        Task.start_link(fn -> aws_lambda_loop(state.runtime_api, handler) end)
      :local ->
        Task.start_link(fn -> local_execution(handler) end)
    end
    
    {:noreply, state}
  end
  
  def handle_info(msg, state) do
    Logger.debug("🔍 不明なメッセージ: #{inspect(msg)}")
    {:noreply, state}
  end
  
  # AWS Lambda Runtime APIループ
  defp aws_lambda_loop(runtime_api, handler_module) do
    base_url = "http://#{runtime_api}/2018-06-01/runtime"
    
    try do
      # Runtime API からリクエスト取得
      case Req.get("#{base_url}/invocation/next", receive_timeout: :infinity) do
        {:ok, %{status: 200, body: body, headers: headers}} ->
          # リクエスト処理
          process_lambda_request(base_url, body, headers, handler_module)
          
          # 次のリクエストを待機（再帰）
          aws_lambda_loop(runtime_api, handler_module)
          
        {:error, error} ->
          Logger.error("💥 Runtime API エラー: #{inspect(error)}")
          Process.sleep(1000)
          aws_lambda_loop(runtime_api, handler_module)
      end
    catch
      kind, error ->
        Logger.error("� 予期しないエラー: #{kind} - #{inspect(error)}")
        # GenServerに復旧を依頼
        send(__MODULE__, {:restart_runtime, handler_module})
    end
  end
  
  defp process_lambda_request(base_url, body, headers, handler_module) do
    request_id = get_header(headers, "lambda-runtime-aws-request-id")
    
    try do
      # イベント解析
      event = if is_binary(body), do: Jason.decode!(body), else: body
      
      # コンテキスト構築
      context = %{
        request_id: request_id,
        function_arn: get_header(headers, "lambda-runtime-invoked-function-arn"),
        deadline_ms: get_header(headers, "lambda-runtime-deadline-ms"),
        timestamp: DateTime.utc_now()
      }
      
      # ユーザーハンドラー呼び出し
      response = handler_module.handle_event(event, context)
      
      # レスポンス送信
      send_success_response(base_url, request_id, response)
      
    rescue
      error ->
        Logger.error("💥 処理エラー: #{inspect(error)}")
        send_error_response(base_url, request_id, error, __STACKTRACE__)
    end
  end
  
  # ローカル開発用実行
  defp local_execution(handler_module) do
    try do
      # 標準入力からJSONを読み取り
      event_json = IO.read(:stdio, :eof) |> String.trim()
      event = if event_json != "", do: Jason.decode!(event_json), else: %{}
      
      context = %{
        request_id: "local-#{System.unique_integer()}",
        function_arn: "arn:aws:lambda:local:000000000000:function:local-test",
        deadline_ms: "#{System.system_time(:millisecond) + 30_000}",
        timestamp: DateTime.utc_now()
      }
      
      # ハンドラー呼び出し
      response = handler_module.handle_event(event, context)
      
      # 標準出力にレスポンス
      IO.puts(Jason.encode!(response))
      
    rescue
      error ->
        Logger.error("💥 ローカル実行エラー: #{inspect(error)}")
        error_response = %{
          statusCode: 500,
          body: Jason.encode!(%{error: "処理エラー", details: inspect(error)})
        }
        IO.puts(Jason.encode!(error_response))
    catch
      kind, error ->
        Logger.error("💥 ローカル実行で予期しないエラー: #{kind} - #{inspect(error)}")
        send(__MODULE__, {:restart_runtime, handler_module})
    end
  end
  
  # ヘルパー関数
  defp get_header(headers, key) when is_map(headers) do
    Map.get(headers, key) || Map.get(headers, String.downcase(key))
  end
  defp get_header(headers, key) when is_list(headers) do
    case List.keyfind(headers, key, 0) do
      {^key, value} -> value
      nil -> 
        case List.keyfind(headers, String.downcase(key), 0) do
          {_, value} -> value
          nil -> nil
        end
    end
  end
  
  defp send_success_response(base_url, request_id, response) do
    Req.post("#{base_url}/invocation/#{request_id}/response",
             body: Jason.encode!(response),
             headers: [{"content-type", "application/json"}])
  end
  
  defp send_error_response(base_url, request_id, error, stacktrace) do
    error_payload = %{
      errorMessage: Exception.message(error),
      errorType: error.__struct__ |> to_string(),
      stackTrace: Exception.format_stacktrace(stacktrace)
    }
    
    Req.post("#{base_url}/invocation/#{request_id}/error",
             body: Jason.encode!(error_payload),
             headers: [{"content-type", "application/json"}])
  end
end
```

### 3. シンプルなApplication

```elixir
# lib/toukon_ex_lambda/application.ex
defmodule ToukonExLambda.Application do
  @moduledoc """
  設定ベースの Application
  config.exs からハンドラーを取得して起動
  """
  
  use Application
  
  def start(_type, _args) do
    # 設定からハンドラー取得
    handler_module = get_handler_module()
    
    children = [
      {ToukonExLambda.Runtime, handler_module}
    ]
    
    opts = [strategy: :one_for_one, name: ToukonExLambda.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  defp get_handler_module do
    case Application.get_env(:toukon_ex_lambda, :handler) do
      nil ->
        raise """
        ハンドラーが設定されていません。
        config.exs で以下のように設定してください:
        
        config :toukon_ex_lambda, handler: MyApp.Handler
        """
      module when is_atom(module) ->
        module
      module when is_binary(module) ->
        String.to_existing_atom("Elixir.#{module}")
    end
  end
end
```

### 4. ライブラリmix.exs

```elixir
# mix.exs
defmodule ToukonExLambda.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :toukon_ex_lambda,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "🔥 シンプルなElixir Lambda Runtime",
      package: package()
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto]]
  end

  defp deps do
    [
      {:req, "~> 0.5.15"},
      {:jason, "~> 1.4"}
    ]
  end

  defp package do
    [
      maintainers: ["ToukonExLambda Team"],
      licenses: ["MIT"],
      files: ~w(lib mix.exs README.md LICENSE)
    ]
  end
end
```

## 🚀 サンプルプロジェクト (`toukon_ex_lambda_starter`)

### 1. 超シンプルなクライアント実装

```elixir
# lambda_app/lib/my_app/handler.ex  
defmodule MyApp.Handler do
  @behaviour ToukonExLambda  # シンプル！useは不要
  
  require Logger

  def handle_event(event, context) do
    Logger.info("🔥 リクエスト受信: #{context.request_id}")
    
    case event do
      %{"action" => "hello", "name" => name} ->
        hello_response(name, context)
        
      %{"httpMethod" => method, "path" => path} ->
        api_gateway_response(method, path, context)
        
      _ ->
        default_response(event, context)
    end
  end
  
  defp hello_response(name, context) do
    %{
      statusCode: 200,
      body: Jason.encode!(%{
        message: "🔥 こんにちは、#{name}さん！",
        request_id: context.request_id,
        timestamp: DateTime.utc_now()
      })
    }
  end
  
  defp api_gateway_response(method, path, context) do
    %{
      statusCode: 200,
      headers: %{"Content-Type" => "application/json"},
      body: Jason.encode!(%{
        message: "🔥 API Gateway 経由",
        method: method,
        path: path,
        request_id: context.request_id
      })
    }
  end
  
  defp default_response(event, context) do
    %{
      message: "🔥 ToukonExLambda で処理しました",
      event: event,
      request_id: context.request_id,
      timestamp: DateTime.utc_now()
    }
  end
end
```

### 2. 設定ベースmix.exs（キーポイント）

```elixir
# lambda_app/mix.exs
defmodule MyApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_app,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      # ⭐ ここがキーポイント！ライブラリのApplicationを直接使用
      mod: {ToukonExLambda.Application, []}
    ]
  end

  defp deps do
    [
      # 🔥 ライブラリを追加するだけ
      {:toukon_ex_lambda, "~> 1.0"}
    ]
  end
end
```

### 3. 設定ファイル（最重要）

```elixir
# lambda_app/config/config.exs
import Config

# ⭐ ここで全てが決まる！
config :toukon_ex_lambda,
  handler: MyApp.Handler

# ログ設定
config :logger,
  level: :info

# 環境別設定
import_config "#{Mix.env()}.exs"
```

### 4. 最適化Dockerfile

```dockerfile
# lambda_app/Dockerfile
FROM hexpm/elixir:1.18.4-erlang-28.0.2-alpine-3.22.1 AS builder

WORKDIR /app

# ビルド依存関係
RUN apk add --no-cache build-base git && \
    mix local.hex --force && \
    mix local.rebar --force

# 依存関係
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# アプリケーション
COPY config/ ./config/
COPY lib/ ./lib/

# ビルド
ENV MIX_ENV=prod
RUN mix deps.compile && \
    mix compile && \
    mix release --overwrite

# === 本番ステージ ===
FROM alpine:3.22.1

RUN apk add --no-cache ncurses-libs libstdc++ libgcc openssl

# ユーザー作成
RUN addgroup -g 1000 elixir && \
    adduser -u 1000 -G elixir -h /app -D elixir

WORKDIR /app
USER elixir

# リリースファイル
COPY --from=builder --chown=elixir:elixir /app/_build/prod/rel/my_app ./

# エントリーポイント
ENTRYPOINT ["/app/bin/my_app", "start"]
```

## 🏗️ CDKインフラ（サンプル）

### Lambda Stack

```typescript
// infra/lib/lambda-stack.ts
import * as cdk from 'aws-cdk-lib';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as ecr from 'aws-cdk-lib/aws-ecr';
import { Construct } from 'constructs';

export class ToukonExLambdaStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // ECR Repository
    const repository = new ecr.Repository(this, 'ToukonExLambdaRepo', {
      repositoryName: 'toukon-ex-lambda'
    });

    // Lambda Function
    new lambda.Function(this, 'ToukonExLambdaFunction', {
      functionName: 'toukon-ex-lambda',
      code: lambda.Code.fromEcrImage(repository, { tagOrDigest: 'latest' }),
      handler: lambda.Handler.FROM_IMAGE,
      runtime: lambda.Runtime.FROM_IMAGE,
      timeout: cdk.Duration.seconds(30),
      memorySize: 512,
      environment: {
        MIX_ENV: 'prod'
      }
    });
  }
}
```

## � 使用方法

### ⭐ 推奨設計まとめ（重要）

```elixir
# === ライブラリの責任 ===
- Runtime API実装（GenServer + Task）
- エラーハンドリング・自動復旧
- 設定からハンドラー取得

# === クライアントの責任 ===  
- Behaviourを実装したハンドラー
- config.exsでハンドラー指定
- ビジネスロジックに集中

# === 使用手順（3ステップ） ===
1. mix.exs: {:toukon_ex_lambda, "~> 1.0"}
2. config.exs: config :toukon_ex_lambda, handler: MyApp.Handler  
3. ハンドラー実装: @behaviour ToukonExLambda
4. mix.exs: mod: {ToukonExLambda.Application, []}
```

### 新規プロジェクト作成

```bash
# プロジェクト作成
mix new my_lambda_app
cd my_lambda_app

# 依存関係追加
# mix.exs に {:toukon_ex_lambda, "~> 1.0"} を追加
mix deps.get

# ハンドラー作成
# lib/my_lambda_app/handler.ex を作成
# @behaviour ToukonExLambda を実装

# 設定追加
# config/config.exs に handler設定

# アプリケーション修正
# mix.exs の application に mod: {ToukonExLambda.Application, []}

# 完了！
```

### ローカル開発

```bash
# JSONファイルでテスト
echo '{"action": "hello", "name": "Elixir"}' | mix run --no-halt

# 期待される出力
{"statusCode":200,"body":"{\"message\":\"🔥 こんにちは、Elixirさん！\"}"}
```

## 🎯 開発計画

### Phase 1: 基本機能実装

- [x] 基本Runtime API実装
- [x] HTTPoison → Req 移行  
- [x] 現在のコードで動作確認
- [ ] ライブラリ分離・設計実装
- [ ] サンプルプロジェクト作成

### Phase 2: 高度な機能

- [ ] デッドレターキュー対応
- [ ] カスタムメトリクス  
- [ ] X-Ray トレーシング強化
- [ ] コールドスタート最適化

### Phase 3: エコシステム

- [ ] Mix タスク (`mix toukon_lambda.new`)
- [ ] ドキュメントサイト
- [ ] Hex.pm 公開
- [ ] コミュニティ拡大

## 🔗 関連リンク

- [AWS Lambda Runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html)
- [Elixir Documentation](https://elixir-lang.org/docs.html)
- [Req HTTP Client](https://hexdocs.pm/req/)

---

**🔥 シンプルさこそ最強！ Simple is the Best!**
