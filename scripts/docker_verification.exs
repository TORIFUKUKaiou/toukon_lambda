#!/usr/bin/env elixir

# 🔥 Docker検証スクリプト
# 
# 使用方法:
#   elixir scripts/docker_verification.exs build
#   elixir scripts/docker_verification.exs start
#   elixir scripts/docker_verification.exs health
#   elixir scripts/docker_verification.exs logs
#   elixir scripts/docker_verification.exs stop

Mix.install([
  {:jason, "~> 1.4"},
  {:httpoison, "~> 2.0"}
])

defmodule DockerVerificationScript do
  @moduledoc """
  Docker検証操作のためのスクリプト
  """

  def main(args) do
    case args do
      ["build"] -> build_image()
      ["start"] -> start_container()
      ["health"] -> check_health()
      ["logs"] -> show_logs()
      ["logs", "--follow"] -> show_logs(follow: true)
      ["logs", "--tail", count] -> show_logs(tail: String.to_integer(count))
      ["stop"] -> stop_container()
      ["clean"] -> clean_all()
      _ -> show_usage()
    end
  end

  defp build_image do
    IO.puts("🔥 Dockerイメージビルド開始...")
    
    case System.cmd("docker", ["build", "-t", "toukon-lambda", "."], 
                   stderr_to_stdout: true, into: IO.stream()) do
      {_, 0} ->
        IO.puts("🔥 Dockerイメージビルド成功!")
        
      {_, exit_code} ->
        IO.puts("💥 Dockerイメージビルド失敗 (exit code: #{exit_code})")
        System.halt(1)
    end
  end

  defp start_container do
    IO.puts("🔥 RIEコンテナ起動開始...")
    
    # 既存コンテナを停止・削除
    System.cmd("docker", ["stop", "toukon-lambda-test"], stderr_to_stdout: true)
    System.cmd("docker", ["rm", "toukon-lambda-test"], stderr_to_stdout: true)
    
    docker_args = [
      "run",
      "-d",
      "--name", "toukon-lambda-test",
      "-p", "8080:8080",
      "toukon-lambda"
    ]
    
    case System.cmd("docker", docker_args, stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts("🔥 RIEコンテナ起動成功!")
        IO.puts("Container ID: #{String.trim(output)}")
        
        # ヘルスチェック実行
        IO.puts("🔥 ヘルスチェック実行中...")
        wait_for_health()
        
      {output, exit_code} ->
        IO.puts("💥 RIEコンテナ起動失敗 (exit code: #{exit_code})")
        IO.puts(output)
        System.halt(1)
    end
  end

  defp check_health do
    IO.puts("🔥 コンテナヘルスチェック実行...")
    
    case System.cmd("docker", ["ps", "-q", "-f", "name=toukon-lambda-test"], 
                   stderr_to_stdout: true) do
      {"", 0} ->
        IO.puts("💥 コンテナが実行されていません")
        System.halt(1)
        
      {container_id, 0} ->
        IO.puts("🔥 コンテナ実行中: #{String.trim(container_id)}")
        
        case check_lambda_endpoint() do
          :ok ->
            IO.puts("🔥 Lambda エンドポイント正常!")
            
          {:error, reason} ->
            IO.puts("💥 Lambda エンドポイントエラー: #{inspect(reason)}")
            System.halt(1)
        end
        
      {output, exit_code} ->
        IO.puts("💥 コンテナ状態確認失敗 (exit code: #{exit_code})")
        IO.puts(output)
        System.halt(1)
    end
  end

  defp show_logs(options \\ []) do
    log_args = ["logs"]
    
    log_args = if Keyword.get(options, :follow, false) do
      log_args ++ ["--follow"]
    else
      log_args
    end
    
    log_args = if tail = Keyword.get(options, :tail) do
      log_args ++ ["--tail", to_string(tail)]
    else
      log_args
    end
    
    log_args = log_args ++ ["--timestamps", "toukon-lambda-test"]
    
    case System.cmd("docker", log_args, stderr_to_stdout: true, into: IO.stream()) do
      {_, 0} ->
        :ok
        
      {_, exit_code} ->
        IO.puts("💥 ログ取得失敗 (exit code: #{exit_code})")
        System.halt(1)
    end
  end

  defp stop_container do
    IO.puts("🔥 コンテナ停止・削除...")
    
    System.cmd("docker", ["stop", "toukon-lambda-test"], stderr_to_stdout: true)
    System.cmd("docker", ["rm", "toukon-lambda-test"], stderr_to_stdout: true)
    
    IO.puts("🔥 コンテナ停止完了!")
  end

  defp clean_all do
    IO.puts("🔥 全リソース削除...")
    
    # コンテナ停止・削除
    stop_container()
    
    # イメージ削除
    case System.cmd("docker", ["rmi", "toukon-lambda"], stderr_to_stdout: true) do
      {_, 0} ->
        IO.puts("🔥 イメージ削除完了!")
        
      {output, _} ->
        IO.puts("⚠️ イメージ削除: #{output}")
    end
  end

  defp wait_for_health(attempts \\ 30) do
    if attempts <= 0 do
      IO.puts("💥 ヘルスチェックタイムアウト")
      System.halt(1)
    else
      case check_lambda_endpoint() do
        :ok ->
          IO.puts("🔥 Lambda エンドポイント準備完了!")
          
        {:error, _reason} ->
          IO.write(".")
          Process.sleep(1000)
          wait_for_health(attempts - 1)
      end
    end
  end

  defp check_lambda_endpoint do
    url = "http://localhost:8080/2015-03-31/functions/function/invocations"
    
    payload = Jason.encode!(%{
      "test_type" => "health_check",
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    })
    
    headers = [{"Content-Type", "application/json"}]
    
    case HTTPoison.post(url, payload, headers, recv_timeout: 5_000) do
      {:ok, %HTTPoison.Response{status_code: status_code}} when status_code in 200..299 ->
        :ok
        
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, {:http_error, status_code, body}}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, {:http_request_failed, reason}}
    end
  end

  defp show_usage do
    IO.puts("""
    🔥 Docker検証スクリプト

    使用方法:
      elixir scripts/docker_verification.exs <command>

    コマンド:
      build                 - Dockerイメージをビルド
      start                 - RIEコンテナを起動
      health                - コンテナヘルスチェック
      logs                  - コンテナログを表示
      logs --follow         - コンテナログをフォロー
      logs --tail <count>   - 最新N行のログを表示
      stop                  - コンテナを停止・削除
      clean                 - 全リソースを削除

    例:
      elixir scripts/docker_verification.exs build
      elixir scripts/docker_verification.exs start
      elixir scripts/docker_verification.exs logs --tail 50
    """)
  end
end

# スクリプト実行
DockerVerificationScript.main(System.argv())