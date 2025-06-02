defmodule BuoyMap.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BuoyMap.Repo,

      BuoyMapWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:buoy_map, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BuoyMap.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: BuoyMap.Finch},
      {BuoyMap.DeviceStore, []},
      # Start a worker by calling: BuoyMap.Worker.start_link(arg)
      # {BuoyMap.Worker, arg},
      # Start to serve requests, typically the last entry
      BuoyMapWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BuoyMap.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BuoyMapWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
