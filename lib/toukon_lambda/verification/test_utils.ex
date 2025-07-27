defmodule ToukonLambda.Verification.TestUtils do
  @moduledoc """
  🔥 闘魂Lambda テストユーティリティ
  
  検証テストで共通して使用されるユーティリティ関数を提供する
  """

  require Logger

  @doc """
  検証IDを生成する
  """
  def generate_verification_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  @doc """
  テストイベントを作成する
  """
  def create_test_event(test_type, payload \\ %{}) do
    %{
      "test_type" => test_type,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "payload" => payload,
      "metadata" => %{
        "elixir_version" => System.version(),
        "otp_release" => System.otp_release(),
        "generated_by" => "闘魂Lambda検証フレームワーク"
      }
    }
  end

  @doc """
  期待されるレスポンス構造を作成する
  """
  def create_expected_response(status \\ "success", data \\ %{}) do
    %{
      "status" => status,
      "processed_by" => "BEAM闘魂エンジン",
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "data" => data
    }
  end

  @doc """
  Lambdaレスポンスを検証する
  """
  def validate_lambda_response(response) when is_map(response) do
    required_fields = ["status", "processed_by"]
    
    missing_fields = required_fields
    |> Enum.filter(fn field -> not Map.has_key?(response, field) end)
    
    case missing_fields do
      [] -> 
        {:ok, response}
      fields -> 
        {:error, "必須フィールドが不足しています: #{Enum.join(fields, ", ")}"}
    end
  end

  def validate_lambda_response(_response) do
    {:error, "レスポンスはマップである必要があります"}
  end

  @doc """
  JSONの有効性を検証する
  """
  def validate_json(json_string) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, error} -> {:error, "JSON解析エラー: #{Exception.message(error)}"}
    end
  end

  def validate_json(_), do: {:error, "JSON文字列である必要があります"}

  @doc """
  レスポンス時間を測定する
  """
  def measure_response_time(fun) when is_function(fun, 0) do
    start_time = System.monotonic_time(:millisecond)
    result = fun.()
    end_time = System.monotonic_time(:millisecond)
    
    {result, end_time - start_time}
  end

  @doc """
  パフォーマンス要件を検証する
  """
  def validate_performance(duration_ms, max_duration_ms \\ 100) do
    if duration_ms <= max_duration_ms do
      {:ok, "パフォーマンス要件を満たしています (#{duration_ms}ms <= #{max_duration_ms}ms)"}
    else
      {:error, "パフォーマンス要件を満たしていません (#{duration_ms}ms > #{max_duration_ms}ms)"}
    end
  end

  @doc """
  エラーレスポンスを検証する
  """
  def validate_error_response(error_response) when is_map(error_response) do
    required_fields = ["errorMessage", "errorType"]
    
    missing_fields = required_fields
    |> Enum.filter(fn field -> not Map.has_key?(error_response, field) end)
    
    case missing_fields do
      [] -> 
        {:ok, error_response}
      fields -> 
        {:error, "エラーレスポンスに必須フィールドが不足しています: #{Enum.join(fields, ", ")}"}
    end
  end

  def validate_error_response(_), do: {:error, "エラーレスポンスはマップである必要があります"}

  @doc """
  テスト環境の情報を取得する
  """
  def get_environment_info do
    %{
      "elixir_version" => System.version(),
      "otp_release" => System.otp_release(),
      "system_architecture" => :erlang.system_info(:system_architecture) |> to_string(),
      "runtime_api" => System.get_env("AWS_LAMBDA_RUNTIME_API"),
      "function_name" => System.get_env("AWS_LAMBDA_FUNCTION_NAME"),
      "function_version" => System.get_env("AWS_LAMBDA_FUNCTION_VERSION"),
      "log_group_name" => System.get_env("AWS_LAMBDA_LOG_GROUP_NAME"),
      "log_stream_name" => System.get_env("AWS_LAMBDA_LOG_STREAM_NAME"),
      "memory_size" => System.get_env("AWS_LAMBDA_FUNCTION_MEMORY_SIZE"),
      "timeout" => System.get_env("AWS_LAMBDA_FUNCTION_TIMEOUT")
    }
  end

  @doc """
  構造化ログを出力する（情報レベル）
  """
  def log_info(message, metadata \\ %{}) do
    Logger.info(message, Map.merge(%{
      component: "verification_framework",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }, metadata))
  end

  @doc """
  構造化ログを出力する（エラーレベル）
  """
  def log_error(message, metadata \\ %{}) do
    Logger.error(message, Map.merge(%{
      component: "verification_framework",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }, metadata))
  end

  @doc """
  構造化ログを出力する（警告レベル）
  """
  def log_warning(message, metadata \\ %{}) do
    Logger.warning(message, Map.merge(%{
      component: "verification_framework",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }, metadata))
  end

  @doc """
  テストデータを生成する
  """
  def generate_test_data(type \\ :basic) do
    case type do
      :basic ->
        %{
          "message" => "闘魂テスト",
          "number" => 42,
          "boolean" => true,
          "array" => [1, 2, 3]
        }
        
      :complex ->
        %{
          "nested" => %{
            "deep" => %{
              "value" => "深い闘魂"
            }
          },
          "array_of_objects" => [
            %{"id" => 1, "name" => "闘魂1"},
            %{"id" => 2, "name" => "闘魂2"}
          ],
          "unicode" => "🔥闘魂🔥",
          "large_string" => String.duplicate("闘魂", 1000)
        }
        
      :invalid ->
        # 意図的に無効なデータ構造
        %{
          "circular_ref" => :self,
          "invalid_json" => "{invalid: json}"
        }
        
      :large ->
        # 大きなペイロード（6MB制限テスト用）
        large_data = String.duplicate("闘魂データ", 100_000)
        %{
          "large_payload" => large_data,
          "metadata" => %{
            "size_bytes" => byte_size(large_data)
          }
        }
    end
  end

  @doc """
  HTTPリクエストのタイムアウトを設定する
  """
  def http_options(timeout_ms \\ 30_000) do
    [
      timeout: timeout_ms,
      recv_timeout: timeout_ms,
      hackney: [pool: false]
    ]
  end

  @doc """
  リトライロジックを実行する
  """
  def retry(fun, max_attempts \\ 3, delay_ms \\ 1000) when is_function(fun, 0) do
    retry_with_backoff(fun, max_attempts, delay_ms, 1)
  end

  defp retry_with_backoff(fun, max_attempts, base_delay_ms, attempt) do
    case fun.() do
      {:ok, result} -> 
        {:ok, result}
        
      {:error, _reason} when attempt >= max_attempts ->
        {:error, "最大試行回数 (#{max_attempts}) に達しました"}
        
      {:error, reason} ->
        delay_ms = base_delay_ms * :math.pow(2, attempt - 1) |> round()
        
        log_warning("リトライ実行中", %{
          attempt: attempt,
          max_attempts: max_attempts,
          delay_ms: delay_ms,
          reason: reason
        })
        
        Process.sleep(delay_ms)
        retry_with_backoff(fun, max_attempts, base_delay_ms, attempt + 1)
    end
  end

  @doc """
  メモリ使用量を取得する
  """
  def get_memory_usage do
    memory_info = :erlang.memory()
    
    %{
      "total_bytes" => memory_info[:total],
      "processes_bytes" => memory_info[:processes],
      "system_bytes" => memory_info[:system],
      "atom_bytes" => memory_info[:atom],
      "binary_bytes" => memory_info[:binary],
      "ets_bytes" => memory_info[:ets]
    }
  end

  @doc """
  システム情報を取得する
  """
  def get_system_info do
    %{
      "schedulers" => :erlang.system_info(:schedulers),
      "logical_processors" => :erlang.system_info(:logical_processors),
      "process_count" => :erlang.system_info(:process_count),
      "port_count" => :erlang.system_info(:port_count),
      "uptime_ms" => :erlang.statistics(:wall_clock) |> elem(0)
    }
  end
end