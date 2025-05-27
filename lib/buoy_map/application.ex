defmodule BuoyMap.Application do
  use Application

  def start(_type, _args) do
    children = [
      {BuoyMap.DeviceStore, []},
    ]

    opts = [strategy: :one_for_one, name: BuoyMap.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    BuoyMapWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
