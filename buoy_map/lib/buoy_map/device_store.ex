defmodule BuoyMap.DeviceStore do
  use GenServer

  @max_trail_points 1000  # Maximum points to store in memory

  # API
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def get_device(device_id), do: GenServer.call(__MODULE__, {:get_device, device_id})
  def get_trail(device_id), do: GenServer.call(__MODULE__, {:get_trail, device_id})
  def get_all_devices(), do: GenServer.call(__MODULE__, :get_all_devices)
  def set_devices(devices), do: GenServer.cast(__MODULE__, {:set_devices, devices})
  def update_device(device), do: GenServer.cast(__MODULE__, {:update_device, device})
  def update_trail(device_id, trail), do: GenServer.cast(__MODULE__, {:update_trail, device_id, trail})

  # Server
  def init(_), do: {:ok, %{devices: %{}, trails: %{}}}

  def handle_call({:get_device, id}, _from, state) do
    {:reply, Map.get(state.devices, id), state}
  end

  def handle_call({:get_trail, id}, _from, state) do
    {:reply, Map.get(state.trails, id, []), state}
  end

  def handle_call(:get_all_devices, _from, state) do
    {:reply, Map.values(state.devices), state}
  end

  def handle_cast({:set_devices, devices}, state) do
    new_devices = for d <- devices, into: %{}, do: {d.device_id, d}
    new_trails = for d <- devices, into: %{}, do: {d.device_id, [[d.lon, d.lat]]}
    {:noreply, %{state | devices: new_devices, trails: new_trails}}
  end

  def handle_cast({:update_device, device}, state) do
    # When updating a device, also update its trail
    current_trail = Map.get(state.trails, device.device_id, [])
    new_point = [device.lon, device.lat]

    # Only add point if it's different from the last one
    updated_trail = if List.first(current_trail) != new_point do
      [new_point | current_trail] |> Enum.take(@max_trail_points)
    else
      current_trail
    end

    new_state = state
    |> put_in([:devices, device.device_id], device)
    |> put_in([:trails, device.device_id], updated_trail)

    {:noreply, new_state}
  end

  def handle_cast({:update_trail, device_id, trail}, state) do
    # Ensure we don't exceed maximum trail points
    updated_trail = Enum.take(trail, @max_trail_points)
    {:noreply, %{state | trails: Map.put(state.trails, device_id, updated_trail)}}
  end
end
