defmodule ToukonLambda.Verification.DockerVerification do
  @moduledoc """
  🔥 Docker/RIE環境での検証機能

  Dockerコンテナのビルド、起動、ヘルスチェック機能を提供
  """

  require Logger
  alias ToukonLambda.Verification.TestUtils

  @docker_image_name "toukon-lambda"
  @container_name "toukon-lambda-test"
  @rie_port 8080
  @health_check_timeout 30_000
  @health_check_interval 1_000

  @doc """
  Dockerイメージをビルドする
  """
  def build_docker_image(options \\ []) do
    TestUtils.log_info("🔥 Dockerイメージビルド開始", %{image: @docker_image_name})

    build_args = get_build_args(options)

    case System.cmd("docker", ["build", "-t", @docker_image_name] ++ build_args ++ ["."],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        TestUtils.log_info("🔥 Dockerイメージビルド成功", %{
          image: @docker_image_name,
          output: String.slice(output, -500, 500)
        })

        {:ok, output}

      {output, exit_code} ->
        TestUtils.log_error("💥 Dockerイメージビルド失敗", %{
          image: @docker_image_name,
          exit_code: exit_code,
          output: output
        })

        {:error, {:build_failed, exit_code, output}}
    end
  end

  @doc """
  RIEでコンテナを起動する
  """
  def start_container_with_rie(options \\ []) do
    TestUtils.log_info("🔥 RIEコンテナ起動開始", %{
      container: @container_name,
      port: @rie_port
    })

    # 既存のコンテナを停止・削除
    stop_and_remove_container()

    docker_args = build_docker_run_args(options)

    case System.cmd("docker", docker_args, stderr_to_stdout: true) do
      {output, 0} ->
        TestUtils.log_info("🔥 RIEコンテナ起動成功", %{
          container: @container_name,
          output: String.slice(output, -200, 200)
        })

        # ヘルスチェック実行
        case wait_for_container_health() do
          :ok ->
            {:ok, %{container_name: @container_name, port: @rie_port}}

          {:error, reason} ->
            stop_and_remove_container()
            {:error, reason}
        end

      {output, exit_code} ->
        TestUtils.log_error("💥 RIEコンテナ起動失敗", %{
          container: @container_name,
          exit_code: exit_code,
          output: output
        })

        {:error, {:container_start_failed, exit_code, output}}
    end
  end

  @doc """
  コンテナのヘルスチェックを実行する
  """
  def check_container_health(container_name \\ @container_name) do
    TestUtils.log_info("🔥 コンテナヘルスチェック開始", %{container: container_name})

    # コンテナが実行中かチェック
    case System.cmd("docker", ["ps", "-q", "-f", "name=#{container_name}"],
           stderr_to_stdout: true
         ) do
      {"", 0} ->
        {:error, :container_not_running}

      {_container_id, 0} ->
        # HTTP経由でヘルスチェック
        check_lambda_endpoint_health()

      {output, exit_code} ->
        TestUtils.log_error("💥 コンテナ状態確認失敗", %{
          container: container_name,
          exit_code: exit_code,
          output: output
        })

        {:error, {:health_check_failed, exit_code, output}}
    end
  end

  @doc """
  コンテナを停止・削除する
  """
  def stop_and_remove_container(container_name \\ @container_name) do
    TestUtils.log_info("🔥 コンテナ停止・削除", %{container: container_name})

    # コンテナ停止
    System.cmd("docker", ["stop", container_name], stderr_to_stdout: true)

    # コンテナ削除
    System.cmd("docker", ["rm", container_name], stderr_to_stdout: true)

    :ok
  end

  @doc """
  コンテナのログを取得する
  """
  def get_container_logs(container_name \\ @container_name, options \\ []) do
    log_args = build_log_args(options)

    case System.cmd("docker", ["logs"] ++ log_args ++ [container_name], stderr_to_stdout: true) do
      {logs, 0} ->
        {:ok, logs}

      {output, exit_code} ->
        TestUtils.log_error("💥 コンテナログ取得失敗", %{
          container: container_name,
          exit_code: exit_code,
          output: output
        })

        {:error, {:log_fetch_failed, exit_code, output}}
    end
  end

  # プライベート関数

  defp get_build_args(options) do
    build_args = []

    # ビルド引数があれば追加
    if build_arg = Keyword.get(options, :build_arg) do
      ["--build-arg", build_arg] ++ build_args
    else
      build_args
    end
  end

  defp build_docker_run_args(options) do
    base_args = [
      "run",
      # デタッチモード
      "-d",
      "--name",
      @container_name,
      "-p",
      "#{@rie_port}:8080"
    ]

    # 環境変数設定
    env_args = get_env_args(options)

    # ボリュームマウント設定
    volume_args = get_volume_args(options)

    base_args ++ env_args ++ volume_args ++ [@docker_image_name]
  end

  defp get_env_args(options) do
    env_vars = Keyword.get(options, :env_vars, [])

    Enum.flat_map(env_vars, fn {key, value} ->
      ["-e", "#{key}=#{value}"]
    end)
  end

  defp get_volume_args(options) do
    volumes = Keyword.get(options, :volumes, [])

    Enum.flat_map(volumes, fn {host_path, container_path} ->
      ["-v", "#{host_path}:#{container_path}"]
    end)
  end

  defp wait_for_container_health do
    TestUtils.log_info("🔥 コンテナヘルスチェック待機開始", %{
      timeout: @health_check_timeout,
      interval: @health_check_interval
    })

    end_time = System.monotonic_time(:millisecond) + @health_check_timeout

    wait_for_health_loop(end_time)
  end

  defp wait_for_health_loop(end_time) do
    current_time = System.monotonic_time(:millisecond)

    if current_time >= end_time do
      TestUtils.log_error("💥 ヘルスチェックタイムアウト", %{
        timeout: @health_check_timeout
      })

      {:error, :health_check_timeout}
    else
      case check_lambda_endpoint_health() do
        :ok ->
          TestUtils.log_info("🔥 コンテナヘルスチェック成功", %{})
          :ok

        {:error, _reason} ->
          Process.sleep(@health_check_interval)
          wait_for_health_loop(end_time)
      end
    end
  end

  defp check_lambda_endpoint_health do
    url = "http://localhost:#{@rie_port}/2015-03-31/functions/function/invocations"

    # 簡単なヘルスチェック用のペイロード
    payload = %{
      "test_type" => "health_check",
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case Req.post(url,
           json: payload,
           receive_timeout: 5_000
         ) do
      {:ok, %{status: status_code}} when status_code in 200..299 ->
        :ok

      {:ok, %{status: status_code, body: body}} ->
        TestUtils.log_error("💥 Lambda エンドポイントエラー", %{
          status_code: status_code,
          body: String.slice(body, 0, 200)
        })

        {:error, {:http_error, status_code, body}}

      {:error, exception} ->
        {:error, {:request_failed, exception}}
    end
  end

  defp build_log_args(options) do
    args = []

    # ログの行数制限
    args =
      if tail = Keyword.get(options, :tail) do
        ["--tail", to_string(tail)] ++ args
      else
        args
      end

    # タイムスタンプ表示
    args =
      if Keyword.get(options, :timestamps, false) do
        ["--timestamps"] ++ args
      else
        args
      end

    # フォローモード
    args =
      if Keyword.get(options, :follow, false) do
        ["--follow"] ++ args
      else
        args
      end

    args
  end
end
