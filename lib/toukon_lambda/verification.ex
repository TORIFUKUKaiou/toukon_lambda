defmodule ToukonLambda.Verification do
  @moduledoc """
  🔥 闘魂Lambda 検証テストフレームワーク
  
  Lambda Runtime APIの実装とAWS Lambda互換環境での動作を検証するためのフレームワーク
  """

  alias ToukonLambda.Verification.{TestSuite, TestResult, TestUtils}

  @doc """
  検証テストを実行する
  """
  def run_verification(environment \\ :local, options \\ []) do
    verification_id = TestUtils.generate_verification_id()
    
    TestUtils.log_info("🔥 Lambda検証開始", %{
      verification_id: verification_id,
      environment: environment,
      timestamp: DateTime.utc_now()
    })

    try do
      test_cases = build_test_cases(environment, options)
      results = execute_test_cases(test_cases, verification_id)
      
      summary = TestResult.generate_summary(results)
      
      TestUtils.log_info("🔥 Lambda検証完了", %{
        verification_id: verification_id,
        summary: summary
      })
      
      {:ok, %{
        verification_id: verification_id,
        environment: environment,
        results: results,
        summary: summary
      }}
      
    rescue
      error ->
        TestUtils.log_error("💥 検証エラー", %{
          verification_id: verification_id,
          error: Exception.message(error),
          stacktrace: __STACKTRACE__
        })
        
        {:error, error}
    end
  end

  @doc """
  特定のテストケースを実行する
  """
  def run_test_case(test_name, environment \\ :local, options \\ []) do
    verification_id = TestUtils.generate_verification_id()
    
    case TestSuite.get_test_case(test_name, environment) do
      {:ok, test_case} ->
        result = execute_single_test(test_case, verification_id, options)
        {:ok, result}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  # プライベート関数

  defp build_test_cases(environment, options) do
    TestSuite.get_test_cases_for_environment(environment, options)
  end

  defp execute_test_cases(test_cases, verification_id) do
    test_cases
    |> Enum.map(fn test_case ->
      execute_single_test(test_case, verification_id)
    end)
  end

  defp execute_single_test(test_case, verification_id, options \\ []) do
    start_time = System.monotonic_time(:millisecond)
    
    TestUtils.log_info("🔥 テストケース実行開始", %{
      test_name: test_case.name,
      verification_id: verification_id
    })

    try do
      result = test_case.execute_fn.(options)
      duration_ms = System.monotonic_time(:millisecond) - start_time
      
      TestResult.create_success_result(test_case.name, result, duration_ms)
      
    rescue
      error ->
        duration_ms = System.monotonic_time(:millisecond) - start_time
        
        TestUtils.log_error("💥 テストケース失敗", %{
          test_name: test_case.name,
          error: Exception.message(error),
          verification_id: verification_id
        })
        
        TestResult.create_failure_result(test_case.name, error, duration_ms)
    end
  end
end