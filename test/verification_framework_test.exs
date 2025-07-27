defmodule ToukonLambda.VerificationFrameworkTest do
  use ExUnit.Case
  doctest ToukonLambda.Verification

  alias ToukonLambda.Verification
  alias ToukonLambda.Verification.{TestResult, TestSuite, TestUtils}

  describe "検証フレームワーク基盤" do
    test "検証IDが正しく生成される" do
      id1 = TestUtils.generate_verification_id()
      id2 = TestUtils.generate_verification_id()
      
      assert is_binary(id1)
      assert is_binary(id2)
      assert id1 != id2
      assert String.length(id1) == 32
    end

    test "テストイベントが正しく作成される" do
      event = TestUtils.create_test_event("test", %{"key" => "value"})
      
      assert event["test_type"] == "test"
      assert event["payload"]["key"] == "value"
      assert Map.has_key?(event, "timestamp")
      assert Map.has_key?(event, "metadata")
    end

    test "成功したテスト結果が正しく作成される" do
      result = TestResult.create_success_result("test_case", %{"status" => "ok"}, 100)
      
      assert result.name == "test_case"
      assert result.status == :passed
      assert result.duration_ms == 100
      assert result.response["status"] == "ok"
      assert result.error == nil
    end

    test "失敗したテスト結果が正しく作成される" do
      error = %RuntimeError{message: "テストエラー"}
      result = TestResult.create_failure_result("test_case", error, 50)
      
      assert result.name == "test_case"
      assert result.status == :failed
      assert result.duration_ms == 50
      assert result.response == nil
      assert result.error == error
    end

    test "テスト結果のサマリーが正しく生成される" do
      results = [
        TestResult.create_success_result("test1", %{}, 100),
        TestResult.create_success_result("test2", %{}, 200),
        TestResult.create_failure_result("test3", %RuntimeError{}, 50)
      ]
      
      summary = TestResult.generate_summary(results)
      
      assert summary.total_tests == 3
      assert summary.passed == 2
      assert summary.failed == 1
      assert summary.skipped == 0
      assert summary.success_rate == 66.67
      assert summary.total_duration_ms == 350
      assert summary.average_duration_ms == 116.67
    end

    test "テストケースが正しく取得される" do
      test_cases = TestSuite.get_test_cases_for_environment(:all)
      
      assert is_list(test_cases)
      assert length(test_cases) > 0
      
      basic_test = Enum.find(test_cases, fn tc -> tc.name == "basic_runtime_api_test" end)
      assert basic_test != nil
      assert basic_test.environment == :all
      assert is_function(basic_test.execute_fn, 1)
    end

    test "特定のテストケースが名前で取得できる" do
      {:ok, test_case} = TestSuite.get_test_case("basic_runtime_api_test")
      
      assert test_case.name == "basic_runtime_api_test"
      assert test_case.description != nil
      assert is_list(test_case.requirements)
    end

    test "存在しないテストケースでエラーが返される" do
      {:error, message} = TestSuite.get_test_case("nonexistent_test")
      
      assert String.contains?(message, "見つかりません")
    end

    test "Lambdaレスポンスの検証が正しく動作する" do
      valid_response = %{
        "status" => "success",
        "processed_by" => "BEAM闘魂エンジン"
      }
      
      assert {:ok, ^valid_response} = TestUtils.validate_lambda_response(valid_response)
      
      invalid_response = %{"status" => "success"}
      assert {:error, message} = TestUtils.validate_lambda_response(invalid_response)
      assert String.contains?(message, "processed_by")
    end

    test "JSON検証が正しく動作する" do
      valid_json = ~s({"key": "value"})
      assert {:ok, %{"key" => "value"}} = TestUtils.validate_json(valid_json)
      
      invalid_json = "{invalid json"
      assert {:error, message} = TestUtils.validate_json(invalid_json)
      assert String.contains?(message, "JSON解析エラー")
    end

    test "パフォーマンス検証が正しく動作する" do
      assert {:ok, _message} = TestUtils.validate_performance(50, 100)
      assert {:error, message} = TestUtils.validate_performance(150, 100)
      assert String.contains?(message, "パフォーマンス要件を満たしていません")
    end

    test "レスポンス時間測定が正しく動作する" do
      {result, duration} = TestUtils.measure_response_time(fn ->
        Process.sleep(10)
        "test_result"
      end)
      
      assert result == "test_result"
      assert duration >= 10
      assert is_integer(duration)
    end

    test "環境情報が正しく取得される" do
      env_info = TestUtils.get_environment_info()
      
      assert Map.has_key?(env_info, "elixir_version")
      assert Map.has_key?(env_info, "otp_release")
      assert Map.has_key?(env_info, "system_architecture")
    end

    test "テストデータが正しく生成される" do
      basic_data = TestUtils.generate_test_data(:basic)
      assert Map.has_key?(basic_data, "message")
      assert basic_data["message"] == "闘魂テスト"
      
      complex_data = TestUtils.generate_test_data(:complex)
      assert Map.has_key?(complex_data, "nested")
      assert Map.has_key?(complex_data, "unicode")
    end
  end

  describe "統合テスト" do
    test "基本的な検証テストが実行できる" do
      {:ok, result} = Verification.run_test_case("basic_runtime_api_test")
      
      assert result.name == "basic_runtime_api_test"
      assert result.status == :passed
      assert result.response != nil
      assert result.duration_ms >= 0
    end

    test "JSON処理テストが実行できる" do
      {:ok, result} = Verification.run_test_case("json_processing_test")
      
      assert result.name == "json_processing_test"
      assert result.status == :passed
      assert result.response["json_valid"] == true
    end

    test "エラーハンドリングテストが実行できる" do
      {:ok, result} = Verification.run_test_case("error_handling_test")
      
      assert result.name == "error_handling_test"
      assert result.status == :passed
      assert result.response["handled_correctly"] == true
    end
  end
end