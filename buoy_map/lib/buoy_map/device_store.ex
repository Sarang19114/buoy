defmodule BuoyMap.DeviceStore do
  use GenServer

  @max_trail_points 1000  # Maximum points to store in memory
  @history_limit 1000

  # API
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def get_device(device_id), do: GenServer.call(__MODULE__, {:get_device, device_id})
  def get_trail(device_id), do: GenServer.call(__MODULE__, {:get_trail, device_id})
  def get_history(device_id, points), do: GenServer.call(__MODULE__, {:get_history, device_id, points})
  def get_all_devices(), do: GenServer.call(__MODULE__, :get_all_devices)
  def set_devices(devices), do: GenServer.cast(__MODULE__, {:set_devices, devices})
  def update_device(device), do: GenServer.cast(__MODULE__, {:update_device, device})
  def update_trail(device_id, trail), do: GenServer.cast(__MODULE__, {:update_trail, device_id, trail})

  # Server
  def init(_), do: {:ok, %{devices: %{}, trails: %{}, history: %{}}}

  def handle_call({:get_device, id}, _from, state) do
    {:reply, Map.get(state.devices, id), state}
  end

  def handle_call({:get_trail, id}, _from, state) do
    {:reply, Map.get(state.trails, id, []), state}
  end

  def handle_call({:get_history, id, points}, _from, state) do
    device = Map.get(state.devices, id)
    if device do
      history = Map.get(state.history, id, [])
      limited_history = Enum.take(history, points)
      {:reply, limited_history, state}
    else
      {:reply, [], state}
    end
  end

  def handle_call(:get_all_devices, _from, state) do
    {:reply, Map.values(state.devices), state}
  end

  def handle_cast({:set_devices, devices}, state) do
    now = DateTime.utc_now()
    new_devices = for d <- devices, into: %{}, do: {d.device_id, d}
    new_trails = for d <- devices, into: %{}, do: {d.device_id, [[d.lon, d.lat]]}
    new_history = for d <- devices, into: %{} do
      {d.device_id, [%{
        timestamp: now,
        avg_speed: d.avg_speed,
        elevation: d.elevation,
        voltage: d.voltage,
        rssi: d.rssi,
        snr: d.snr
      }]}
    end
    {:noreply, %{state | devices: new_devices, trails: new_trails, history: new_history}}
  end

  def handle_cast({:update_device, device}, state) do
    device_id = device.device_id
    current_history = Map.get(state.history, device_id, [])

    # Create new history entry with timestamp
    new_entry = %{
      timestamp: DateTime.utc_now(),
      avg_speed: device.avg_speed,
      elevation: device.elevation,
      voltage: device.voltage,
      rssi: device.rssi,
      snr: device.snr
    }

    updated_history = [new_entry | current_history] |> Enum.take(@history_limit)

    {:noreply, %{state |
      devices: Map.put(state.devices, device_id, device),
      history: Map.put(state.history, device_id, updated_history)
    }}
  end

  def handle_cast({:update_trail, device_id, trail}, state) do
    {:noreply, %{state | trails: Map.put(state.trails, device_id, trail)}}
  end
end
