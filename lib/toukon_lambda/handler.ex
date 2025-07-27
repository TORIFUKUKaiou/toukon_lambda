defmodule ToukonLambda.Handler do
  @moduledoc """
  🔥 闘魂Lambda Handler
  AWS Lambda Runtime APIを実装してLambdaイベントを処理する
  """

  require Logger

  @api_version "2018-06-01"

  def handle_request do
    try do
      # 標準入力からLambdaイベントを読み取り（ローカルテスト用）
      event_json = IO.read(:stdio, :eof) |> String.trim()

      Logger.info("🔥 闘魂注入開始: #{event_json}")

      # JSONデコード
      event =
        case Jason.decode(event_json) do
          {:ok, decoded} -> decoded
          {:error, _} -> %{}
        end

      # メイン処理
      response = process_event(event)

      # レスポンスを標準出力に出力
      response_json = Jason.encode!(response)
      IO.puts(response_json)

      Logger.info("🔥 闘魂注入完了!")
    rescue
      error ->
        Logger.error("💥 闘魂エラー: #{inspect(error)}")

        error_response = %{
          "statusCode" => 500,
          "body" =>
            Jason.encode!(%{
              "error" => "闘魂処理でエラーが発生しました",
              "details" => inspect(error)
            })
        }

        IO.puts(Jason.encode!(error_response))
    end
  end

  # AWS Lambda Runtime API対応のハンドラー
  def handle_lambda_request do
    try do
      # AWS Lambda Runtime APIからのリクエストを処理
      runtime_api = System.get_env("AWS_LAMBDA_RUNTIME_API")

      if runtime_api do
        # AWS Lambda環境での実行
        Logger.info("🔥 AWS Lambda Runtime API モード: #{runtime_api}")
        lambda_loop(runtime_api)
      else
        # ローカル実行（従来の方式）
        Logger.info("🔥 ローカル実行モード")
        handle_request()
      end
    rescue
      error ->
        Logger.error("💥 Lambda Runtime エラー: #{inspect(error)}")
        exit(1)
    end
  end

  defp lambda_loop(runtime_api) do
    base_url = "http://#{runtime_api}/#{@api_version}/runtime"

    # 次のinvocationを取得（無限待機対応）
    case Req.get("#{base_url}/invocation/next",
           receive_timeout: :infinity,
           pool_timeout: :infinity
         ) do
      {:ok, %{status: 200, body: body, headers: headers}} ->
        Logger.info("🔥 Headers format: #{inspect(headers)}")
        request_id = get_header_value(headers, "lambda-runtime-aws-request-id")
        deadline_ms = get_header_value(headers, "lambda-runtime-deadline-ms")
        function_arn = get_header_value(headers, "lambda-runtime-invoked-function-arn")
        trace_id = get_header_value(headers, "lambda-runtime-trace-id")

        Logger.info("🔥 Lambda リクエスト受信: #{request_id}")
        Logger.info("🔥 Function ARN: #{function_arn}")
        Logger.info("🔥 Deadline: #{deadline_ms}")
        Logger.info("🔥 Trace ID: #{inspect(trace_id)}")

        # X-Ray Trace IDを設定
        if trace_id && is_binary(trace_id) do
          System.put_env("_X_AMZN_TRACE_ID", trace_id)
        end

        # イベントを処理
        try do
          event =
            cond do
              is_map(body) ->
                body

              is_binary(body) ->
                case Jason.decode(body) do
                  {:ok, decoded} -> decoded
                  {:error, _} -> %{}
                end

              true ->
                %{}
            end

          response =
            process_lambda_event(event, %{
              request_id: request_id,
              deadline_ms: deadline_ms,
              function_arn: function_arn
            })

          # 成功レスポンスを送信
          send_response(base_url, request_id, response)
        rescue
          error ->
            Logger.error("💥 Lambda 処理エラー: #{inspect(error)}")
            stacktrace = __STACKTRACE__
            send_error(base_url, request_id, error, stacktrace)
        end

        # 次のリクエストを待機（再帰）
        lambda_loop(runtime_api)

      {:error, error} ->
        Logger.error("💥 Lambda Runtime API エラー: #{inspect(error)}")
        # 初期化エラーを送信
        send_init_error(runtime_api, error)
        exit(1)
    end
  end

  defp send_response(base_url, request_id, response) do
    url = "#{base_url}/invocation/#{request_id}/response"

    case Req.post(url, json: response) do
      {:ok, %{status: 202}} ->
        Logger.info("🔥 Lambda レスポンス送信完了: #{request_id}")
        :ok

      {:error, error} ->
        Logger.error("💥 Lambda レスポンス送信エラー: #{inspect(error)}")
        :error
    end
  end

  defp send_error(base_url, request_id, error, stacktrace \\ []) do
    {error_type, formatted_stacktrace} =
      case error do
        %{__exception__: true} ->
          {error.__struct__ |> to_string(), Exception.format_stacktrace(stacktrace)}

        _ ->
          {"Runtime.Error", []}
      end

    error_payload = %{
      "errorMessage" => Exception.message(error),
      "errorType" => error_type,
      "stackTrace" => formatted_stacktrace
    }

    url = "#{base_url}/invocation/#{request_id}/error"

    case Req.post(url, json: error_payload) do
      {:ok, %{status: 202}} ->
        Logger.info("🔥 Lambda エラーレスポンス送信完了: #{request_id}")
        :ok

      {:error, error} ->
        Logger.error("💥 Lambda エラーレスポンス送信失敗: #{inspect(error)}")
        :error
    end
  end

  defp send_init_error(runtime_api, error) do
    error_payload = %{
      "errorMessage" => "初期化エラー: #{Exception.message(error)}",
      "errorType" => "Runtime.InitError",
      "stackTrace" => []
    }

    url = "http://#{runtime_api}/#{@api_version}/runtime/init/error"

    Req.post(url, json: error_payload)
  end

  defp get_header_value(headers, header_name) when is_map(headers) do
    # Reqはheadersをmapで返す場合
    key = String.downcase(header_name)
    headers[key] || headers[header_name]
  end

  defp get_header_value(headers, header_name) when is_list(headers) do
    # 従来のリスト形式の場合
    case Enum.find(headers, fn {name, _value} ->
           String.downcase(name) == String.downcase(header_name)
         end) do
      {_name, value} -> value
      nil -> nil
    end
  end

  defp get_header_value(_headers, _header_name), do: nil

  defp process_lambda_event(event, context) do
    # Lambda環境用の処理
    current_time = DateTime.utc_now() |> DateTime.to_iso8601()

    %{
      "message" => "🔥 闘魂Elixir Lambda 成功だ！",
      "timestamp" => current_time,
      "request_id" => context.request_id,
      "elixir_version" => System.version(),
      "otp_release" => System.otp_release(),
      "input_event" => event,
      "processed_by" => "BEAM闘魂エンジン",
      "status" => "VICTORY!",
      "function_arn" => context.function_arn,
      "deadline_ms" => context.deadline_ms
    }
  end

  defp process_event(event) do
    current_time = DateTime.utc_now() |> DateTime.to_iso8601()

    %{
      "statusCode" => 200,
      "headers" => %{
        "Content-Type" => "application/json",
        "X-Toukon-Power" => "MAX"
      },
      "body" =>
        Jason.encode!(%{
          "message" => "🔥 闘魂Elixir Lambda 成功だ！",
          "timestamp" => current_time,
          "elixir_version" => System.version(),
          "otp_release" => System.otp_release(),
          "input_event" => event,
          "processed_by" => "BEAM闘魂エンジン",
          "status" => "VICTORY!"
        })
    }
  end
end
