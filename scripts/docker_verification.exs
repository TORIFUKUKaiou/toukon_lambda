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
  {:req, "~> 0.5.15"}
])

defmodule DockerVerification do
  @moduledoc """
  RIEコンテナでのDocker検証
  """

  @container_name "toukon-lambda-test"
  @image_tag "toukon-lambda:local"
  @port "8080"

  def main(args) do
    case args do
      ["build"] -> build_image()
      ["start"] -> start_container()
      ["health"] -> check_health()
      ["logs"] -> show_logs()
      ["logs", "--follow"] -> show_logs(follow: true)
      ["logs", "--tail", count] -> show_logs(tail: count)
      ["stop"] -> stop_container()
      ["clean"] -> clean_all()
      _ -> show_usage()
    end
  end

  defp build_image do
    IO.puts("🔨 Dockerイメージビルド中...")

    case System.cmd(
           "docker",
           [
             "build",
             "--platform",
             "linux/arm64",
             "--target",
             "development",
             "-t",
             @image_tag,
             "."
           ],
           cd: File.cwd!()
         ) do
      {output, 0} ->
        IO.puts("✅ ビルド成功")
        IO.puts(output)

      {error, code} ->
        IO.puts("❌ ビルド失敗 (exit: #{code})")
        IO.puts(error)
        System.halt(1)
    end
  end

  defp start_container do
    IO.puts("🚀 RIEコンテナ起動中...")

    # 既存コンテナを停止・削除
    System.cmd("docker", ["rm", "-f", @container_name], cd: File.cwd!())

    case System.cmd(
           "docker",
           [
             "run",
             "--platform",
             "linux/arm64",
             "-d",
             "-p",
             "#{@port}:8080",
             "--name",
             @container_name,
             @image_tag
           ],
           cd: File.cwd!()
         ) do
      {output, 0} ->
        IO.puts("✅ コンテナ起動成功")
        IO.puts("Container ID: #{String.trim(output)}")

        IO.puts("⏳ コンテナの準備待機中...")
        wait_for_health()

      {error, code} ->
        IO.puts("❌ コンテナ起動失敗 (exit: #{code})")
        IO.puts(error)
        System.halt(1)
    end
  end

  defp check_health do
    IO.puts("🔍 コンテナヘルスチェック...")

    case check_lambda_endpoint() do
      :ok ->
        IO.puts("✅ Lambda エンドポイント準備完了!")

      {:error, reason} ->
        IO.puts("❌ ヘルスチェック失敗: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp show_logs(opts \\ []) do
    IO.puts("📜 コンテナログ表示...")

    args = ["logs", @container_name]
    args = if opts[:follow], do: args ++ ["--follow"], else: args
    args = if opts[:tail], do: args ++ ["--tail", opts[:tail]], else: args

    case System.cmd("docker", args, cd: File.cwd!()) do
      {output, 0} ->
        IO.puts(output)

      {error, code} ->
        IO.puts("❌ ログ取得失敗 (exit: #{code})")
        IO.puts(error)
        System.halt(1)
    end
  end

  defp stop_container do
    IO.puts("🛑 コンテナ停止中...")

    case System.cmd("docker", ["stop", @container_name], cd: File.cwd!()) do
      {_, 0} ->
        IO.puts("✅ コンテナ停止完了")

        case System.cmd("docker", ["rm", @container_name], cd: File.cwd!()) do
          {_, 0} ->
            IO.puts("✅ コンテナ削除完了")

          {error, code} ->
            IO.puts("⚠️ コンテナ削除失敗 (exit: #{code}): #{error}")
        end

      {error, code} ->
        IO.puts("❌ コンテナ停止失敗 (exit: #{code})")
        IO.puts(error)
        System.halt(1)
    end
  end

  defp clean_all do
    IO.puts("🧹 全リソース削除中...")

    # コンテナ停止・削除
    System.cmd("docker", ["rm", "-f", @container_name], cd: File.cwd!())

    # イメージ削除
    case System.cmd("docker", ["rmi", @image_tag], cd: File.cwd!()) do
      {_, 0} ->
        IO.puts("✅ 全リソース削除完了")

      {error, code} ->
        IO.puts("⚠️ イメージ削除失敗 (exit: #{code}): #{error}")
    end
  end

  defp wait_for_health(attempts \\ 30) do
    IO.write("Health check")

    if attempts <= 0 do
      IO.puts("\n❌ ヘルスチェックタイムアウト")
      System.halt(1)
    else
      case check_lambda_endpoint() do
        :ok ->
          IO.puts("\n🔥 Lambda エンドポイント準備完了!")

        {:error, _reason} ->
          IO.write(".")
          Process.sleep(1000)
          wait_for_health(attempts - 1)
      end
    end
  end

  defp check_lambda_endpoint do
    url = "http://localhost:8080/2015-03-31/functions/function/invocations"

    payload = %{
      "test_type" => "health_check",
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case Req.post(url,
           json: payload,
           receive_timeout: 5_000
         ) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, exception}}
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

# メイン実行
case System.argv() do
  [] -> DockerVerification.main([])
  args -> DockerVerification.main(args)
end
