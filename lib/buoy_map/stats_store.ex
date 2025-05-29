defmodule BuoyMap.StatsStore do
  use GenServer
  require Logger

  @update_interval 2000

  # Client API
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def get_device_stats(device_id), do: GenServer.call(__MODULE__, {:get_device_stats, device_id})
  def update_device_stats(device_id, stats), do: GenServer.cast(__MODULE__, {:update_device_stats, device_id, stats})

  # Server Callbacks
  def init(_) do
    if Process.whereis(BuoyMap.DeviceStore) do
      schedule_stats_update()
    end
    {:ok, %{stats: %{}}}
  end

  def handle_call({:get_device_stats, device_id}, _from, state) do
    {:reply, get_in(state, [:stats, device_id]), state}
  end

  def handle_cast({:update_device_stats, device_id, stats}, state) do
    new_state = put_in(state, [:stats, device_id], stats)
    broadcast_stats_update(device_id, stats)
    {:noreply, new_state}
  end

  def handle_info(:update_stats, state) do
    schedule_stats_update()

    # Get all devices and update their stats
    devices = BuoyMap.DeviceStore.get_all_devices()

    new_state = Enum.reduce(devices, state, fn device, acc ->
      stats = generate_device_stats()
      broadcast_stats_update(device.device_id, stats)
      put_in(acc, [:stats, device.device_id], stats)
    end)

    {:noreply, new_state}
  end

  # Private Functions
  defp schedule_stats_update do
    Process.send_after(self(), :update_stats, @update_interval)
  end

  defp broadcast_stats_update(device_id, stats) do
    Phoenix.PubSub.broadcast(
      BuoyMap.PubSub,
      "device_stats",
      {:device_stats_updated, device_id, stats}
    )
  end

  defp generate_device_stats do
    %{
      avg_speed: :rand.uniform() * 12,
      elevation: 10 + :rand.uniform() * 120,
      voltage: 3.8 + :rand.uniform(),
      rssi: -100 + :rand.uniform() * 30,
      snr: :rand.uniform() * 12
    }
  end
end
