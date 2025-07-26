defmodule ToukonLambda.Application do
  @moduledoc """
  🔥 闘魂Lambda OTPアプリケーション
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Lambda Runtime API処理をバックグラウンドで開始
      {Task, fn -> ToukonLambda.Handler.handle_lambda_request() end}
    ]

    opts = [strategy: :one_for_one, name: ToukonLambda.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
