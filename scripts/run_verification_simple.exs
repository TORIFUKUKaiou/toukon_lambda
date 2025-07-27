#!/usr/bin/env elixir

# 🔥 Lambda検証実行スクリプト（簡略化版）
#
# 使用方法:
#   elixir scripts/run_verification_simple.exs basic
#   elixir scripts/run_verification_simple.exs all

Mix.install([
  {:jason, "~> 1.4"},
  {:req, "~> 0.5.15"}
])

defmodule VerificationRunner do
  @moduledoc """
  Lambda検証テストの実行スクリプト（簡略化版）
  """

  # Lambda エンドポイント設定
  @lambda_url "http://localhost:8080/2015-03-31/functions/function/invocations"

  def main(args) do
    case args do
      ["basic"] -> run_basic_test()
      ["multiple"] -> run_multiple_payload_test()
      ["performance"] -> run_performance_test()
      ["performance", iterations] -> run_performance_test(String.to_integer(iterations))
      ["all"] -> run_all_tests()
      ["status"] -> check_container_status()
      _ -> show_usage()
    end
  end

  defp run_basic_test do
    IO.puts("🔥 基本Lambda呼び出しテスト実行...")

    payload = %{
      "test_type" => "basic",
      "message" => "基本テスト",
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case send_lambda_request(payload) do
      {:ok, response} ->
        IO.puts("🔥 基本テスト成功!")
        IO.puts("📄 レスポンス: #{inspect(response)}")
        {:ok, response}

      {:error, reason} ->
        IO.puts("❌ 基本テスト失敗: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp run_multiple_payload_test do
    IO.puts("🔥 複数ペイロードテスト実行...")

    payloads = [
      %{"test_type" => "string", "data" => "文字列データ"},
      %{"test_type" => "number", "data" => 12345},
      %{"test_type" => "array", "data" => [1, 2, 3, "test"]},
      %{"test_type" => "nested", "data" => %{"inner" => %{"value" => true}}}
    ]

    results =
      Enum.map(payloads, fn payload ->
        case send_lambda_request(payload) do
          {:ok, response} ->
            {:ok, %{payload: payload, response: response}}

          {:error, reason} ->
            {:error, %{payload: payload, reason: reason}}
        end
      end)

    passed = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))

    IO.puts("🔥 複数ペイロードテスト完了!")
    IO.puts("")
    IO.puts("=== テスト結果サマリー ===")
    IO.puts("総テスト数: #{length(results)}")
    IO.puts("成功: #{passed}")
    IO.puts("失敗: #{failed}")
    IO.puts("成功率: #{Float.round(passed / length(results) * 100, 2)}%")
    IO.puts("")

    IO.puts("=== 個別テスト結果 ===")

    Enum.each(results, fn
      {:ok, result} ->
        IO.puts("✅ #{result.payload["test_type"]}: 成功")

      {:error, result} ->
        IO.puts("❌ #{result.payload["test_type"]}: #{inspect(result.reason)}")
    end)
  end

  defp run_performance_test(iterations \\ 10) do
    IO.puts("🔥 パフォーマンステスト実行 (#{iterations}回)...")

    payload = %{
      "test_type" => "performance",
      "message" => "パフォーマンステスト"
    }

    results =
      1..iterations
      |> Enum.map(fn i ->
        IO.write(".")
        start_time = System.monotonic_time(:millisecond)

        case send_lambda_request(payload) do
          {:ok, response} ->
            duration = System.monotonic_time(:millisecond) - start_time
            {:ok, duration}

          {:error, reason} ->
            {:error, reason}
        end
      end)

    IO.puts("")

    durations =
      results
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, duration} -> duration end)

    if length(durations) > 0 do
      avg_duration = Enum.sum(durations) / length(durations)
      min_duration = Enum.min(durations)
      max_duration = Enum.max(durations)

      IO.puts("🔥 パフォーマンステスト完了!")
      IO.puts("")
      IO.puts("=== パフォーマンス統計 ===")
      IO.puts("実行回数: #{iterations}")
      IO.puts("成功数: #{length(durations)}")
      IO.puts("最小時間: #{min_duration}ms")
      IO.puts("最大時間: #{max_duration}ms")
      IO.puts("平均時間: #{Float.round(avg_duration, 2)}ms")
    else
      IO.puts("❌ パフォーマンステスト: 成功したリクエストがありませんでした")
    end
  end

  defp run_all_tests do
    IO.puts("🔥 全テスト実行開始...")
    IO.puts("")

    # コンテナ状態確認
    check_container_status()
    IO.puts("")

    # 基本テスト
    run_basic_test()
    IO.puts("")

    # 複数ペイロードテスト
    run_multiple_payload_test()
    IO.puts("")

    # パフォーマンステスト
    run_performance_test(5)
    IO.puts("")

    IO.puts("🔥 全テスト完了!")
  end

  defp check_container_status do
    IO.puts("🔥 コンテナ状態確認...")

    case System.cmd("docker", [
           "ps",
           "--filter",
           "name=toukon-lambda-test",
           "--format",
           "{{.Status}}"
         ]) do
      {output, 0} ->
        if String.trim(output) != "" do
          IO.puts("🔥 コンテナ正常稼働中")
        else
          IO.puts("💥 コンテナが実行されていません")
          IO.puts("以下のコマンドでコンテナを起動してください:")
          IO.puts("  make verify-complete")
          System.halt(1)
        end

      {error, _} ->
        IO.puts("💥 コンテナ状態確認失敗: #{error}")
        System.halt(1)
    end
  end

  # Lambda エンドポイントにリクエストを送信
  defp send_lambda_request(payload, options \\ []) do
    timeout = Keyword.get(options, :timeout, 5_000)

    case Req.post(@lambda_url,
           json: payload,
           receive_timeout: timeout
         ) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, exception}}
    end
  end

  defp show_usage do
    IO.puts("""
    🔥 Lambda検証実行スクリプト（簡略化版）

    使用方法:
      elixir scripts/run_verification_simple.exs <command>

    コマンド:
      basic                    - 基本Lambda呼び出しテスト
      multiple                 - 複数ペイロードテスト
      performance              - パフォーマンステスト (10回実行)
      performance <回数>       - パフォーマンステスト (指定回数実行)
      all                      - 全テスト実行
      status                   - コンテナ状態確認

    例:
      elixir scripts/run_verification_simple.exs basic
      elixir scripts/run_verification_simple.exs performance 20
      elixir scripts/run_verification_simple.exs all

    注意:
      テスト実行前にコンテナが起動していることを確認してください:
        make verify-complete
    """)
  end
end

# スクリプト実行
VerificationRunner.main(System.argv())
