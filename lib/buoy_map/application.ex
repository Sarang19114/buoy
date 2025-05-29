defmodule BuoyMap.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      BuoyMapWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: BuoyMap.PubSub},
      # Start the Endpoint (http/https)
      BuoyMapWeb.Endpoint,
      # Start the DeviceStore
      BuoyMap.DeviceStore,
      # Start the StatsStore
      BuoyMap.StatsStore
      # Start a worker by calling: BuoyMap.Worker.start_link(arg)
      # {BuoyMap.Worker, arg}
    ]

    opts = [strategy: :one_for_one, name: BuoyMap.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    BuoyMapWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
