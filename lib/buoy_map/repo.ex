defmodule BuoyMap.Repo do
  use Ecto.Repo,
    otp_app: :buoy_map,
    adapter: Ecto.Adapters.Postgres
end
