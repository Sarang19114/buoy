defmodule BuoyMap.DeviceStore do
  use GenServer

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
    {:noreply, %{state | devices: Map.put(state.devices, device.device_id, device)}}
  end

  def handle_cast({:update_trail, device_id, trail}, state) do
    {:noreply, %{state | trails: Map.put(state.trails, device_id, trail)}}
  end
end
