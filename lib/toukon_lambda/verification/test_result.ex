defmodule ToukonLambda.Verification.TestResult do
  @moduledoc """
  🔥 闘魂Lambda テスト結果データモデル
  
  検証テストの結果を構造化して管理する
  """

  @type status :: :passed | :failed | :skipped
  @type environment :: :local | :localstack | :aws

  @type test_result :: %{
    name: String.t(),
    status: status(),
    duration_ms: non_neg_integer(),
    response: map() | nil,
    error: Exception.t() | nil,
    metadata: map()
  }

  @type verification_result :: %{
    verification_id: String.t(),
    timestamp: DateTime.t(),
    environment: environment(),
    test_cases: [test_result()],
    summary: summary()
  }

  @type summary :: %{
    total_tests: non_neg_integer(),
    passed: non_neg_integer(),
    failed: non_neg_integer(),
    skipped: non_neg_integer(),
    success_rate: float(),
    total_duration_ms: non_neg_integer(),
    average_duration_ms: float()
  }

  @doc """
  成功したテスト結果を作成する
  """
  def create_success_result(test_name, response, duration_ms, metadata \\ %{}) do
    %{
      name: test_name,
      status: :passed,
      duration_ms: duration_ms,
      response: response,
      error: nil,
      metadata: Map.merge(%{timestamp: DateTime.utc_now()}, metadata)
    }
  end

  @doc """
  失敗したテスト結果を作成する
  """
  def create_failure_result(test_name, error, duration_ms, metadata \\ %{}) do
    %{
      name: test_name,
      status: :failed,
      duration_ms: duration_ms,
      response: nil,
      error: error,
      metadata: Map.merge(%{
        timestamp: DateTime.utc_now(),
        error_message: Exception.message(error),
        error_type: error.__struct__ |> to_string()
      }, metadata)
    }
  end

  @doc """
  スキップされたテスト結果を作成する
  """
  def create_skipped_result(test_name, reason, metadata \\ %{}) do
    %{
      name: test_name,
      status: :skipped,
      duration_ms: 0,
      response: nil,
      error: nil,
      metadata: Map.merge(%{
        timestamp: DateTime.utc_now(),
        skip_reason: reason
      }, metadata)
    }
  end

  @doc """
  テスト結果のサマリーを生成する
  """
  def generate_summary(test_results) when is_list(test_results) do
    total_tests = length(test_results)
    passed = count_by_status(test_results, :passed)
    failed = count_by_status(test_results, :failed)
    skipped = count_by_status(test_results, :skipped)
    
    total_duration_ms = test_results
    |> Enum.map(& &1.duration_ms)
    |> Enum.sum()
    
    average_duration_ms = if total_tests > 0 do
      total_duration_ms / total_tests
    else
      0.0
    end
    
    success_rate = if total_tests > 0 do
      (passed / total_tests) * 100.0
    else
      0.0
    end

    %{
      total_tests: total_tests,
      passed: passed,
      failed: failed,
      skipped: skipped,
      success_rate: Float.round(success_rate, 2),
      total_duration_ms: total_duration_ms,
      average_duration_ms: Float.round(average_duration_ms, 2)
    }
  end

  @doc """
  検証結果全体を作成する
  """
  def create_verification_result(verification_id, environment, test_results) do
    %{
      verification_id: verification_id,
      timestamp: DateTime.utc_now(),
      environment: environment,
      test_cases: test_results,
      summary: generate_summary(test_results)
    }
  end

  @doc """
  テスト結果をJSON形式で出力する
  """
  def to_json(verification_result) do
    verification_result
    |> convert_datetime_to_string()
    |> Jason.encode!()
  end

  @doc """
  テスト結果が成功かどうかを判定する
  """
  def success?(test_result) do
    test_result.status == :passed
  end

  @doc """
  テスト結果が失敗かどうかを判定する
  """
  def failure?(test_result) do
    test_result.status == :failed
  end

  @doc """
  検証全体が成功かどうかを判定する
  """
  def verification_success?(verification_result) do
    verification_result.summary.failed == 0
  end

  # プライベート関数

  defp count_by_status(test_results, status) do
    test_results
    |> Enum.count(fn result -> result.status == status end)
  end

  defp convert_datetime_to_string(data) when is_map(data) do
    data
    |> Enum.map(fn
      {key, %DateTime{} = datetime} -> {key, DateTime.to_iso8601(datetime)}
      {key, value} when is_map(value) -> {key, convert_datetime_to_string(value)}
      {key, value} when is_list(value) -> {key, Enum.map(value, &convert_datetime_to_string/1)}
      {key, value} -> {key, value}
    end)
    |> Enum.into(%{})
  end

  defp convert_datetime_to_string(data) when is_list(data) do
    Enum.map(data, &convert_datetime_to_string/1)
  end

  defp convert_datetime_to_string(data), do: data
end