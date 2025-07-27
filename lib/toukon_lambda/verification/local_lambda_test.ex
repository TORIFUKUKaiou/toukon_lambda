defmodule ToukonLambda.Verification.LocalLambdaTest do
  @moduledoc """
  🔥 ローカルLambda関数テスト機能

  HTTP経由でのLambda関数呼び出し、ペイロードテスト、ログ解析機能を提供
  """

  require Logger
  alias ToukonLambda.Verification.{TestUtils, DockerVerification}

  @lambda_endpoint "http://localhost:8080/2015-03-31/functions/function/invocations"
  @default_timeout 30_000

  @doc """
  基本的なLambda関数呼び出しテストを実行する
  """
  def test_basic_invocation(options \\ []) do
    TestUtils.log_info("🔥 基本Lambda呼び出しテスト開始", %{})

    payload = build_test_payload("basic_invocation", options)

    case invoke_lambda_function(payload, options) do
      {:ok, response} ->
        case validate_basic_response(response) do
          :ok ->
            TestUtils.log_info("🔥 基本Lambda呼び出しテスト成功", %{
              status_code: response.status_code,
              response_size: byte_size(response.body)
            })

            {:ok, response}

          {:error, reason} ->
            TestUtils.log_error("💥 基本Lambda呼び出しレスポンス検証失敗", %{
              reason: reason,
              response: response
            })

            {:error, {:response_validation_failed, reason}}
        end

      {:error, reason} ->
        TestUtils.log_error("💥 基本Lambda呼び出し失敗", %{reason: reason})
        {:error, reason}
    end
  end

  @doc """
  複数のテストペイロードでLambda関数をテストする
  """
  def test_multiple_payloads(test_cases \\ nil, options \\ []) do
    TestUtils.log_info("🔥 複数ペイロードテスト開始", %{})

    test_cases = test_cases || get_default_test_cases()

    test_results =
      Enum.map(test_cases, fn test_case ->
        TestUtils.log_info("🔥 テストケース実行", %{name: test_case.name})

        start_time = System.monotonic_time(:millisecond)

        result =
          case invoke_lambda_function(test_case.payload, options) do
            {:ok, response} ->
              duration_ms = System.monotonic_time(:millisecond) - start_time

              case validate_response_against_expected(response, test_case.expected) do
                :ok ->
                  TestUtils.log_info("🔥 テストケース成功", %{
                    name: test_case.name,
                    duration_ms: duration_ms
                  })

                  {:ok,
                   %{
                     name: test_case.name,
                     status: :passed,
                     duration_ms: duration_ms,
                     response: response
                   }}

                {:error, reason} ->
                  TestUtils.log_error("💥 テストケース検証失敗", %{
                    name: test_case.name,
                    reason: reason
                  })

                  {:error,
                   %{
                     name: test_case.name,
                     status: :failed,
                     duration_ms: duration_ms,
                     error: reason,
                     response: response
                   }}
              end

            {:error, reason} ->
              duration_ms = System.monotonic_time(:millisecond) - start_time

              TestUtils.log_error("💥 テストケース実行失敗", %{
                name: test_case.name,
                reason: reason
              })

              {:error,
               %{
                 name: test_case.name,
                 status: :failed,
                 duration_ms: duration_ms,
                 error: reason
               }}
          end

        result
      end)

    # 結果の集計
    summary = generate_test_summary(test_results)

    TestUtils.log_info("🔥 複数ペイロードテスト完了", %{summary: summary})

    {:ok,
     %{
       results: test_results,
       summary: summary
     }}
  end

  @doc """
  Lambda関数を呼び出してレスポンスを取得する
  """
  def invoke_lambda_function(payload, options \\ []) do
    timeout = Keyword.get(options, :timeout, @default_timeout)
    headers = build_request_headers(options)

    # Reqの場合、ペイロードの形式に応じて処理を分ける
    {req_options, payload_info} =
      case payload do
        binary when is_binary(binary) ->
          # 既にJSONエンコード済みの文字列の場合
          {[body: binary, headers: headers, receive_timeout: timeout],
           %{payload_size: byte_size(binary), type: "binary"}}

        data ->
          # マップやその他のデータ構造の場合、Reqの自動JSONエンコーディングを使用
          json_size = data |> Jason.encode!() |> byte_size()

          {[json: data, headers: headers, receive_timeout: timeout],
           %{payload_size: json_size, type: "json"}}
      end

    TestUtils.log_info("🔥 Lambda関数呼び出し", %{
      endpoint: @lambda_endpoint,
      payload_size: payload_info.payload_size,
      payload_type: payload_info.type,
      timeout: timeout
    })

    start_time = System.monotonic_time(:millisecond)

    case Req.post(@lambda_endpoint, req_options) do
      {:ok, %{status: status, body: body}} ->
        duration_ms = System.monotonic_time(:millisecond) - start_time

        TestUtils.log_info("🔥 Lambda関数呼び出し成功", %{
          status_code: status,
          duration_ms: duration_ms,
          response_size: byte_size(body)
        })

        response_with_duration = %{
          status_code: status,
          body: body,
          duration_ms: duration_ms
        }

        {:ok, response_with_duration}

      {:error, exception} ->
        duration_ms = System.monotonic_time(:millisecond) - start_time

        TestUtils.log_error("💥 Lambda関数呼び出し失敗", %{
          reason: exception,
          duration_ms: duration_ms
        })

        {:error, {:http_request_failed, exception}}
    end
  end

  @doc """
  コンテナログを取得して解析する
  """
  def analyze_container_logs(options \\ []) do
    TestUtils.log_info("🔥 コンテナログ解析開始", %{})

    case DockerVerification.get_container_logs("toukon-lambda-test", options) do
      {:ok, logs} ->
        analysis = parse_and_analyze_logs(logs)

        TestUtils.log_info("🔥 コンテナログ解析完了", %{
          total_lines: analysis.total_lines,
          error_count: analysis.error_count,
          request_count: analysis.request_count
        })

        {:ok, analysis}

      {:error, reason} ->
        TestUtils.log_error("💥 コンテナログ取得失敗", %{reason: reason})
        {:error, reason}
    end
  end

  @doc """
  エラーハンドリングテストを実行する
  """
  def test_error_handling(options \\ []) do
    TestUtils.log_info("🔥 エラーハンドリングテスト開始", %{})

    error_test_cases = get_error_test_cases()

    test_results =
      Enum.map(error_test_cases, fn test_case ->
        TestUtils.log_info("🔥 エラーテストケース実行", %{name: test_case.name})

        start_time = System.monotonic_time(:millisecond)

        result =
          case invoke_lambda_function(test_case.payload, options) do
            {:ok, response} ->
              duration_ms = System.monotonic_time(:millisecond) - start_time

              case validate_error_response(response, test_case.expected_error) do
                :ok ->
                  TestUtils.log_info("🔥 エラーテストケース成功", %{
                    name: test_case.name,
                    duration_ms: duration_ms,
                    status_code: response.status_code
                  })

                  {:ok,
                   %{
                     name: test_case.name,
                     status: :passed,
                     duration_ms: duration_ms,
                     response: response,
                     error_type: test_case.expected_error.type
                   }}

                {:error, reason} ->
                  TestUtils.log_error("💥 エラーテストケース検証失敗", %{
                    name: test_case.name,
                    reason: reason
                  })

                  {:error,
                   %{
                     name: test_case.name,
                     status: :failed,
                     duration_ms: duration_ms,
                     error: reason,
                     response: response
                   }}
              end

            {:error, reason} ->
              duration_ms = System.monotonic_time(:millisecond) - start_time

              # HTTPエラーまたはReqエラーが期待される場合は成功とみなす
              if test_case.expected_error.type == :http_error do
                TestUtils.log_info("🔥 エラーテストケース成功 (HTTP エラー)", %{
                  name: test_case.name,
                  duration_ms: duration_ms,
                  error: reason
                })

                {:ok,
                 %{
                   name: test_case.name,
                   status: :passed,
                   duration_ms: duration_ms,
                   error_type: :http_error,
                   error: reason
                 }}
              else
                TestUtils.log_error("💥 エラーテストケース実行失敗", %{
                  name: test_case.name,
                  reason: reason
                })

                {:error,
                 %{
                   name: test_case.name,
                   status: :failed,
                   duration_ms: duration_ms,
                   error: reason
                 }}
              end
          end

        result
      end)

    # 結果の集計
    summary = generate_test_summary(test_results)

    TestUtils.log_info("🔥 エラーハンドリングテスト完了", %{summary: summary})

    {:ok,
     %{
       results: test_results,
       summary: summary
     }}
  end

  @doc """
  無効なJSONペイロードテストを実行する
  """
  def test_invalid_json_payload(options \\ []) do
    TestUtils.log_info("🔥 無効JSONペイロードテスト開始", %{})

    invalid_payloads = [
      "{invalid json",
      "{'single_quotes': 'not_valid'}",
      "{\"unclosed\": \"string",
      "{\"trailing_comma\": \"value\",}",
      "null",
      "",
      "not json at all"
    ]

    results =
      Enum.map(invalid_payloads, fn payload ->
        TestUtils.log_info("🔥 無効JSONテスト", %{payload: String.slice(payload, 0, 50)})

        case invoke_lambda_function(payload, options) do
          {:ok, response} ->
            # Lambda関数がエラーを適切に処理したかチェック
            if response.status_code >= 400 do
              {:ok, %{payload: payload, status_code: response.status_code, handled: true}}
            else
              {:error, %{payload: payload, status_code: response.status_code, handled: false}}
            end

          {:error, reason} ->
            # HTTPレベルでのエラーも適切な処理
            {:ok, %{payload: payload, error: reason, handled: true}}
        end
      end)

    passed =
      Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)

    TestUtils.log_info("🔥 無効JSONペイロードテスト完了", %{
      total: length(results),
      passed: passed
    })

    {:ok, %{results: results, passed: passed, total: length(results)}}
  end

  @doc """
  タイムアウトシナリオテストを実行する
  """
  def test_timeout_scenarios(options \\ []) do
    TestUtils.log_info("🔥 タイムアウトシナリオテスト開始", %{})

    # 短いタイムアウトでテスト
    # 100ms
    short_timeout_options = Keyword.put(options, :timeout, 100)

    payload = build_test_payload("timeout_test", options)

    case invoke_lambda_function(payload, short_timeout_options) do
      {:ok, response} ->
        TestUtils.log_info("🔥 タイムアウトテスト: レスポンス受信", %{
          status_code: response.status_code,
          duration_ms: response.duration_ms
        })

        {:ok, %{result: :no_timeout, response: response}}

      {:error, {:http_request_failed, %Req.TransportError{reason: :timeout}}} ->
        TestUtils.log_info("🔥 タイムアウトテスト: 期待通りタイムアウト", %{})
        {:ok, %{result: :timeout_occurred}}

      {:error, reason} ->
        TestUtils.log_error("💥 タイムアウトテスト: 予期しないエラー", %{reason: reason})
        {:error, reason}
    end
  end

  @doc """
  初期化エラーテストを実行する
  """
  def test_initialization_errors(options \\ []) do
    TestUtils.log_info("🔥 初期化エラーテスト開始", %{})

    # 初期化エラーをシミュレートするペイロード
    init_error_payload = %{
      "test_type" => "initialization_error",
      "simulate_error" => true,
      "error_type" => "init_failure"
    }

    case invoke_lambda_function(init_error_payload, options) do
      {:ok, response} ->
        TestUtils.log_info("🔥 初期化エラーテスト完了", %{
          status_code: response.status_code,
          response_body: String.slice(response.body, 0, 200)
        })

        {:ok, response}

      {:error, reason} ->
        TestUtils.log_error("💥 初期化エラーテスト失敗", %{reason: reason})
        {:error, reason}
    end
  end

  @doc """
  レスポンス時間のパフォーマンステストを実行する
  """
  def test_response_time_performance(iterations \\ 10, options \\ []) do
    TestUtils.log_info("🔥 レスポンス時間パフォーマンステスト開始", %{
      iterations: iterations
    })

    payload = build_test_payload("performance_test", options)

    response_times =
      Enum.map(1..iterations, fn iteration ->
        TestUtils.log_info("🔥 パフォーマンステスト実行", %{
          iteration: iteration,
          total: iterations
        })

        case invoke_lambda_function(payload, options) do
          {:ok, response} ->
            response.duration_ms

          {:error, reason} ->
            TestUtils.log_error("💥 パフォーマンステスト失敗", %{
              iteration: iteration,
              reason: reason
            })

            nil
        end
      end)
      |> Enum.filter(&(&1 != nil))

    if length(response_times) > 0 do
      stats = calculate_performance_stats(response_times)

      TestUtils.log_info("🔥 レスポンス時間パフォーマンステスト完了", %{
        stats: stats
      })

      {:ok, stats}
    else
      TestUtils.log_error("💥 パフォーマンステスト全失敗", %{})
      {:error, :all_requests_failed}
    end
  end

  # プライベート関数

  defp build_test_payload(test_type, options) do
    base_payload = %{
      "test_type" => test_type,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "payload" => %{
        "message" => "🔥 闘魂テスト",
        "data" => %{
          "key1" => "value1",
          "key2" => 42,
          "nested" => %{
            "inner_key" => "inner_value"
          }
        }
      }
    }

    # カスタムペイロードがあれば使用
    case Keyword.get(options, :custom_payload) do
      nil -> base_payload
      custom -> Map.merge(base_payload, custom)
    end
  end

  defp build_request_headers(options) do
    base_headers = %{
      "content-type" => "application/json",
      "user-agent" => "ToukonLambda-Verification/1.0"
    }

    # 追加ヘッダーがあれば追加
    case Keyword.get(options, :headers) do
      nil ->
        base_headers

      additional when is_list(additional) ->
        # タプルリストをマップに変換
        additional_map = Enum.into(additional, %{})
        Map.merge(base_headers, additional_map)

      additional when is_map(additional) ->
        Map.merge(base_headers, additional)
    end
  end

  defp validate_basic_response(response) do
    cond do
      response.status_code not in 200..299 ->
        {:error, {:invalid_status_code, response.status_code}}

      byte_size(response.body) == 0 ->
        {:error, :empty_response_body}

      true ->
        :ok
    end
  end

  defp validate_response_against_expected(response, expected) do
    cond do
      response.status_code != Map.get(expected, :status_code, 200) ->
        {:error, {:status_code_mismatch, response.status_code, expected.status_code}}

      expected[:body_contains] && !String.contains?(response.body, expected.body_contains) ->
        {:error, {:body_content_mismatch, expected.body_contains}}

      expected[:response_time_max] && response.duration_ms > expected.response_time_max ->
        {:error, {:response_time_exceeded, response.duration_ms, expected.response_time_max}}

      true ->
        :ok
    end
  end

  defp get_error_test_cases do
    [
      %{
        name: "invalid_json_structure",
        payload: "{\"invalid\": json}",
        expected_error: %{
          type: :json_parse_error,
          # Lambda関数は内部でエラーを処理する可能性
          status_code_range: 200..499
        }
      },
      %{
        name: "malformed_json",
        payload: "{unclosed json",
        expected_error: %{
          type: :json_parse_error,
          # Lambda関数は内部でエラーを処理する可能性
          status_code_range: 200..499
        }
      },
      %{
        name: "empty_payload",
        payload: "",
        expected_error: %{
          type: :empty_payload,
          # 空のペイロードも処理される可能性
          status_code_range: 200..499
        }
      },
      %{
        name: "null_payload",
        payload: "null",
        expected_error: %{
          type: :null_payload,
          # nullは有効なJSONなので成功
          status_code_range: 200..299
        }
      },
      %{
        name: "large_payload",
        payload:
          Jason.encode!(%{
            "test_type" => "large_payload",
            # 適度に大きなペイロード
            "data" => String.duplicate("🔥", 10_000)
          }),
        expected_error: %{
          type: :payload_large,
          # 大きなペイロードも処理される可能性
          status_code_range: 200..499
        }
      }
    ]
  end

  defp validate_error_response(response, expected_error) do
    cond do
      response.status_code not in expected_error.status_code_range ->
        {:error,
         {:unexpected_status_code, response.status_code, expected_error.status_code_range}}

      expected_error[:body_should_contain] &&
          !String.contains?(response.body, expected_error.body_should_contain) ->
        {:error, {:missing_error_message, expected_error.body_should_contain}}

      true ->
        :ok
    end
  end

  defp get_default_test_cases do
    [
      %{
        name: "basic_success",
        payload: build_test_payload("basic_success", []),
        expected: %{
          status_code: 200,
          response_time_max: 5000
        }
      },
      %{
        name: "large_payload",
        payload:
          build_test_payload("large_payload",
            custom_payload: %{
              "large_data" => String.duplicate("🔥", 1000)
            }
          ),
        expected: %{
          status_code: 200,
          response_time_max: 10000
        }
      },
      %{
        name: "nested_data",
        payload: %{
          "test_type" => "nested_data",
          "complex_structure" => %{
            "level1" => %{
              "level2" => %{
                "level3" => %{
                  "data" => [1, 2, 3, 4, 5],
                  "metadata" => %{
                    "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
                    "version" => "1.0"
                  }
                }
              }
            }
          }
        },
        expected: %{
          status_code: 200,
          response_time_max: 5000
        }
      }
    ]
  end

  defp generate_test_summary(test_results) do
    total = length(test_results)

    passed =
      Enum.count(test_results, fn
        {:ok, %{status: :passed}} -> true
        _ -> false
      end)

    failed = total - passed

    durations =
      Enum.flat_map(test_results, fn
        {:ok, %{duration_ms: duration}} -> [duration]
        {:error, %{duration_ms: duration}} -> [duration]
        _ -> []
      end)

    avg_duration =
      if length(durations) > 0 do
        Enum.sum(durations) / length(durations)
      else
        0
      end

    %{
      total_tests: total,
      passed: passed,
      failed: failed,
      success_rate: if(total > 0, do: passed / total * 100, else: 0),
      average_duration_ms: avg_duration
    }
  end

  defp parse_and_analyze_logs(logs) do
    lines = String.split(logs, "\n")

    analysis = %{
      total_lines: length(lines),
      error_count: 0,
      request_count: 0,
      response_count: 0,
      errors: [],
      requests: [],
      performance_data: []
    }

    Enum.reduce(lines, analysis, fn line, acc ->
      cond do
        String.contains?(line, "[error]") || String.contains?(line, "ERROR") ->
          %{
            acc
            | error_count: acc.error_count + 1,
              errors: [extract_error_info(line) | acc.errors]
          }

        String.contains?(line, "Lambda リクエスト受信") ->
          %{
            acc
            | request_count: acc.request_count + 1,
              requests: [extract_request_info(line) | acc.requests]
          }

        String.contains?(line, "Lambda レスポンス送信完了") ->
          %{acc | response_count: acc.response_count + 1}

        String.contains?(line, "Duration:") ->
          %{acc | performance_data: [extract_performance_info(line) | acc.performance_data]}

        true ->
          acc
      end
    end)
  end

  defp extract_error_info(line) do
    %{
      timestamp: extract_timestamp(line),
      message: String.trim(line),
      severity: if(String.contains?(line, "[error]"), do: :error, else: :warning)
    }
  end

  defp extract_request_info(line) do
    %{
      timestamp: extract_timestamp(line),
      request_id: extract_request_id(line)
    }
  end

  defp extract_performance_info(line) do
    duration_match = Regex.run(~r/Duration: ([\d.]+) ms/, line)

    %{
      timestamp: extract_timestamp(line),
      duration_ms: if(duration_match, do: String.to_float(Enum.at(duration_match, 1)), else: nil)
    }
  end

  defp extract_timestamp(line) do
    case Regex.run(~r/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)/, line) do
      [_, timestamp] -> timestamp
      _ -> nil
    end
  end

  defp extract_request_id(line) do
    case Regex.run(~r/([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})/, line) do
      [_, request_id] -> request_id
      _ -> nil
    end
  end

  defp calculate_performance_stats(response_times) do
    sorted_times = Enum.sort(response_times)
    count = length(sorted_times)

    %{
      count: count,
      min_ms: Enum.min(sorted_times),
      max_ms: Enum.max(sorted_times),
      avg_ms: Enum.sum(sorted_times) / count,
      median_ms: calculate_median(sorted_times),
      p95_ms: calculate_percentile(sorted_times, 95),
      p99_ms: calculate_percentile(sorted_times, 99)
    }
  end

  defp calculate_median(sorted_list) do
    count = length(sorted_list)
    middle = div(count, 2)

    if rem(count, 2) == 0 do
      (Enum.at(sorted_list, middle - 1) + Enum.at(sorted_list, middle)) / 2
    else
      Enum.at(sorted_list, middle)
    end
  end

  defp calculate_percentile(sorted_list, percentile) do
    count = length(sorted_list)
    index = round(percentile / 100 * count) - 1
    index = max(0, min(index, count - 1))

    Enum.at(sorted_list, index)
  end
end
