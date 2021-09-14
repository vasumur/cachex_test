defmodule CachexTest.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  import Supervisor.Spec
  import Cachex.Spec

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      # CachexTest.Repo,
      # Start the Telemetry supervisor
      CachexTestWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: CachexTest.PubSub},
      # Start the Endpoint (http/https)
      CachexTestWeb.Endpoint,
      # Start a worker by calling: CachexTest.Worker.start_link(arg)
      # {CachexTest.Worker, arg},

      worker(
        Cachex,
        [
          :common,
          [
            limit: 9999,
            warmers: [
              warmer(module: CachexTest.Warmers.PbdWarmer, state: nil),
              warmer(module: CachexTest.Warmers.DataWarmer, state: nil)
            ]
          ]
        ],
        id: :cache1
      ),
      worker(
        Cachex,
        [
          :security,
          [
            warmers: []
          ]
        ],
        id: :cache2
      ),
      :hackney_pool.child_spec(:cachextest_pool, timeout: 15000, max_connections: 150)
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CachexTest.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    CachexTestWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
