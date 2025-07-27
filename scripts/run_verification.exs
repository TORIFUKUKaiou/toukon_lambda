#!/usr/bin/env elixir

# 🔥 Lambda検証実行スクリプト
# 
# 使用方法:
#   elixir scripts/run_verification.exs basic
#   elixir scripts/run_verification.exs multiple
#   elixir scripts/run_verification.exs performance
#   elixir scripts/run_verification.exs logs
#   elixir scripts/run_verification.exs all

Mix.install([
  {:jason, "~> 1.4"},
  {:httpoison, "~> 2.0"}
])

# プロジェクトのモジュールを読み込み
Code.require_file("lib/toukon_lambda/verification/test_utils.ex")
Code.require_file("lib/toukon_lambda/verification/docker_verification.ex")
Code.require_file("lib/toukon_lambda/verification/local_lambda_test.ex")

defmodule VerificationRunner do
  @moduledoc """
  Lambda検証テストの実行スクリプト
  """

  alias ToukonLambda.Verification.{LocalLambdaTest, DockerVerification}

  def main(args) do
    case args do
      ["basic"] -> run_basic_test()
      ["multiple"] -> run_multiple_payload_test()
      ["performance"] -> run_performance_test()
      ["performance", iterations] -> run_performance_test(String.to_integer(iterations))
      ["error"] -> run_error_handling_test()
      ["invalid-json"] -> run_invalid_json_test()
      ["timeout"] -> run_timeout_test()
      ["init-error"] -> run_initialization_error_test()
      ["logs"] -> analyze_logs()
      ["all"] -> run_all_tests()
      ["status"] -> check_container_status()
      _ -> show_usage()
    end
  end

  defp run_basic_test do
    IO.puts("🔥 基本Lambda呼び出しテスト実行...")
    
    case LocalLambdaTest.test_basic_invocation() do
      {:ok, response} ->
        IO.puts("🔥 基本テスト成功!")
        IO.puts("ステータスコード: #{response.status_code}")
        IO.puts("レスポンス時間: #{response.duration_ms}ms")
        IO.puts("レスポンスサイズ: #{byte_size(response.body)} bytes")
        
        if byte_size(response.body) < 500 do
          IO.puts("レスポンス内容:")
          IO.puts(response.body)
        end
        
      {:error, reason} ->
        IO.puts("💥 基本テスト失敗: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp run_multiple_payload_test do
    IO.puts("🔥 複数ペイロードテスト実行...")
    
    case LocalLambdaTest.test_multiple_payloads() do
      {:ok, %{results: results, summary: summary}} ->
        IO.puts("🔥 複数ペイロードテスト完了!")
        IO.puts("")
        IO.puts("=== テスト結果サマリー ===")
        IO.puts("総テスト数: #{summary.total_tests}")
        IO.puts("成功: #{summary.passed}")
        IO.puts("失敗: #{summary.failed}")
        IO.puts("成功率: #{Float.round(summary.success_rate, 2)}%")
        IO.puts("平均レスポンス時間: #{Float.round(summary.average_duration_ms, 2)}ms")
        IO.puts("")
        
        IO.puts("=== 個別テスト結果 ===")
        Enum.each(results, fn
          {:ok, result} ->
            IO.puts("✅ #{result.name}: #{result.duration_ms}ms")
            
          {:error, result} ->
            IO.puts("❌ #{result.name}: #{inspect(result.error)} (#{result.duration_ms}ms)")
        end)
        
      {:error, reason} ->
        IO.puts("💥 複数ペイロードテスト失敗: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp run_error_handling_test do
    IO.puts("🔥 エラーハンドリングテスト実行...")
    
    case LocalLambdaTest.test_error_handling() do
      {:ok, %{results: results, summary: summary}} ->
        IO.puts("🔥 エラーハンドリングテスト完了!")
        IO.puts("")
        IO.puts("=== エラーハンドリング結果サマリー ===")
        IO.puts("総テスト数: #{summary.total_tests}")
        IO.puts("成功: #{summary.passed}")
        IO.puts("失敗: #{summary.failed}")
        IO.puts("成功率: #{Float.round(summary.success_rate, 2)}%")
        IO.puts("")
        
        IO.puts("=== 個別エラーテスト結果 ===")
        Enum.each(results, fn
          {:ok, result} ->
            IO.puts("✅ #{result.name} (#{result.error_type}): #{result.duration_ms}ms")
            
          {:error, result} ->
            IO.puts("❌ #{result.name}: #{inspect(result.error)} (#{result.duration_ms}ms)")
        end)
        
      {:error, reason} ->
        IO.puts("💥 エラーハンドリングテスト失敗: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp run_invalid_json_test do
    IO.puts("🔥 無効JSONペイロードテスト実行...")
    
    case LocalLambdaTest.test_invalid_json_payload() do
      {:ok, %{results: results, passed: passed, total: total}} ->
        IO.puts("🔥 無効JSONペイロードテスト完了!")
        IO.puts("")
        IO.puts("=== 無効JSON結果サマリー ===")
        IO.puts("総テスト数: #{total}")
        IO.puts("適切に処理: #{passed}")
        IO.puts("処理失敗: #{total - passed}")
        IO.puts("処理率: #{Float.round((passed / total) * 100, 2)}%")
        IO.puts("")
        
        IO.puts("=== 個別結果 ===")
        Enum.each(results, fn
          {:ok, result} ->
            status = if Map.get(result, :status_code) do
              "HTTP #{result.status_code}"
            else
              "Error: #{inspect(result.error)}"
            end
            IO.puts("✅ #{String.slice(result.payload, 0, 30)}... -> #{status}")
            
          {:error, result} ->
            IO.puts("❌ #{String.slice(result.payload, 0, 30)}... -> HTTP #{result.status_code} (未処理)")
        end)
        
      {:error, reason} ->
        IO.puts("💥 無効JSONペイロードテスト失敗: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp run_timeout_test do
    IO.puts("🔥 タイムアウトシナリオテスト実行...")
    
    case LocalLambdaTest.test_timeout_scenarios() do
      {:ok, %{result: :timeout_occurred}} ->
        IO.puts("🔥 タイムアウトテスト成功: 期待通りタイムアウトが発生")
        
      {:ok, %{result: :no_timeout, response: response}} ->
        IO.puts("🔥 タイムアウトテスト: タイムアウトなし (#{response.duration_ms}ms)")
        IO.puts("注意: Lambda関数が短時間で応答したため、タイムアウトは発生しませんでした")
        
      {:error, reason} ->
        IO.puts("💥 タイムアウトテスト失敗: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp run_initialization_error_test do
    IO.puts("🔥 初期化エラーテスト実行...")
    
    case LocalLambdaTest.test_initialization_errors() do
      {:ok, response} ->
        IO.puts("🔥 初期化エラーテスト完了!")
        IO.puts("ステータスコード: #{response.status_code}")
        IO.puts("レスポンス時間: #{response.duration_ms}ms")
        
        if byte_size(response.body) < 500 do
          IO.puts("レスポンス内容:")
          IO.puts(response.body)
        end
        
      {:error, reason} ->
        IO.puts("💥 初期化エラーテスト失敗: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp run_performance_test(iterations \\ 10) do
    IO.puts("🔥 パフォーマンステスト実行 (#{iterations}回)...")
    
    case LocalLambdaTest.test_response_time_performance(iterations) do
      {:ok, stats} ->
        IO.puts("🔥 パフォーマンステスト完了!")
        IO.puts("")
        IO.puts("=== パフォーマンス統計 ===")
        IO.puts("実行回数: #{stats.count}")
        IO.puts("最小時間: #{stats.min_ms}ms")
        IO.puts("最大時間: #{stats.max_ms}ms")
        IO.puts("平均時間: #{format_number(stats.avg_ms)}ms")
        IO.puts("中央値: #{format_number(stats.median_ms)}ms")
        IO.puts("P95: #{format_number(stats.p95_ms)}ms")
        IO.puts("P99: #{format_number(stats.p99_ms)}ms")
        
      {:error, reason} ->
        IO.puts("💥 パフォーマンステスト失敗: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp analyze_logs do
    IO.puts("🔥 コンテナログ解析実行...")
    
    case LocalLambdaTest.analyze_container_logs(tail: 100) do
      {:ok, analysis} ->
        IO.puts("🔥 ログ解析完了!")
        IO.puts("")
        IO.puts("=== ログ解析結果 ===")
        IO.puts("総行数: #{analysis.total_lines}")
        IO.puts("エラー数: #{analysis.error_count}")
        IO.puts("リクエスト数: #{analysis.request_count}")
        IO.puts("レスポンス数: #{analysis.response_count}")
        IO.puts("")
        
        if analysis.error_count > 0 do
          IO.puts("=== エラー詳細 ===")
          Enum.take(analysis.errors, 5)
          |> Enum.each(fn error ->
            IO.puts("❌ [#{error.severity}] #{error.timestamp}: #{error.message}")
          end)
          IO.puts("")
        end
        
        if length(analysis.performance_data) > 0 do
          durations = Enum.map(analysis.performance_data, & &1.duration_ms)
                     |> Enum.filter(& &1 != nil)
          
          if length(durations) > 0 do
            avg_duration = Enum.sum(durations) / length(durations)
            IO.puts("=== パフォーマンス情報 ===")
            IO.puts("平均実行時間: #{Float.round(avg_duration, 2)}ms")
            IO.puts("最小実行時間: #{Enum.min(durations)}ms")
            IO.puts("最大実行時間: #{Enum.max(durations)}ms")
          end
        end
        
      {:error, reason} ->
        IO.puts("💥 ログ解析失敗: #{inspect(reason)}")
        System.halt(1)
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
    
    # エラーハンドリングテスト
    run_error_handling_test()
    IO.puts("")
    
    # 無効JSONテスト
    run_invalid_json_test()
    IO.puts("")
    
    # タイムアウトテスト
    run_timeout_test()
    IO.puts("")
    
    # ログ解析
    analyze_logs()
    
    IO.puts("🔥 全テスト完了!")
  end

  defp check_container_status do
    IO.puts("🔥 コンテナ状態確認...")
    
    case DockerVerification.check_container_health() do
      :ok ->
        IO.puts("🔥 コンテナ正常稼働中")
        
      {:error, :container_not_running} ->
        IO.puts("💥 コンテナが実行されていません")
        IO.puts("以下のコマンドでコンテナを起動してください:")
        IO.puts("  elixir scripts/docker_verification.exs start")
        System.halt(1)
        
      {:error, reason} ->
        IO.puts("💥 コンテナ状態確認失敗: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp format_number(num) when is_float(num), do: Float.round(num, 2)
  defp format_number(num) when is_integer(num), do: num
  defp format_number(num), do: num

  defp show_usage do
    IO.puts("""
    🔥 Lambda検証実行スクリプト

    使用方法:
      elixir scripts/run_verification.exs <command>

    コマンド:
      basic                    - 基本Lambda呼び出しテスト
      multiple                 - 複数ペイロードテスト
      performance              - パフォーマンステスト (10回実行)
      performance <回数>       - パフォーマンステスト (指定回数実行)
      error                    - エラーハンドリングテスト
      invalid-json             - 無効JSONペイロードテスト
      timeout                  - タイムアウトシナリオテスト
      init-error               - 初期化エラーテスト
      logs                     - コンテナログ解析
      all                      - 全テスト実行
      status                   - コンテナ状態確認

    例:
      elixir scripts/run_verification.exs basic
      elixir scripts/run_verification.exs performance 20
      elixir scripts/run_verification.exs all

    注意:
      テスト実行前にコンテナが起動していることを確認してください:
        elixir scripts/docker_verification.exs start
    """)
  end
end

# スクリプト実行
VerificationRunner.main(System.argv())