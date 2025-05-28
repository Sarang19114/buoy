defmodule BuoyMapWeb.DeviceDetailLive do
  use BuoyMapWeb, :live_view

  alias BuoyMap.DeviceStore

  @update_interval 2000
  @max_trail_points 50
  @default_history_points 100
  @max_history_points 1000

  def mount(%{"id" => device_id}, _session, socket) do

    if connected?(socket) do
      Phoenix.PubSub.subscribe(BuoyMap.PubSub, "payload_created")
      Phoenix.PubSub.subscribe(BuoyMap.PubSub, "device_movements")
      :timer.send_interval(@update_interval, :update_device_data)
      Process.send_after(self(), :check_loading_state, 5000)
    end

    # Get initial device data from DeviceStore
    device = DeviceStore.get_device(device_id)
    trail = DeviceStore.get_trail(device_id)

    socket =
      socket
      |> assign(:device, device)
      |> assign(:device_id, device_id)
      |> assign(:trail, trail || [])
      |> assign(:history_points, @default_history_points)
      |> assign(:max_history_points, @max_history_points)
      |> assign(:metrics_history, initialize_metrics_history(@default_history_points))
      |> assign(
        :page_title,
        if(device, do: "Device Detail: #{device.name}", else: "Device Detail")
      )
      |> assign(:map_loading, true)
      |> assign(:charts_loading, true)
      |> assign(:error, if(device, do: nil, else: "Device not found"))
      |> assign(:retry_count, 0)
      |> assign(:last_update, DateTime.utc_now())

    {:ok, socket, layout: false}
  end

  # All handle_event
  def handle_event("show_map_view", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("map_loaded", _params, socket) do
    if socket.assigns.device do
      {:noreply,
       push_event(socket, "init_device_detail", %{
         device: socket.assigns.device,
         trail: socket.assigns.trail
       })}
    else
      {:noreply, socket}
    end
  end

  def handle_event("map_loaded_success", _params, socket) do
    {:noreply, assign(socket, :map_loading, false)}
  end

  def handle_event("reload_page", _params, socket) do
    {:noreply, socket |> redirect(to: ~p"/device/#{socket.assigns.device_id}")}
  end

  def handle_event(
        "device_moved",
        %{"device_id" => device_id, "lon" => lon, "lat" => lat},
        socket
      ) do
    if device_id == socket.assigns.device_id do
      # Update the device with new coordinates but preserve other attributes
      current_device = socket.assigns.device
      updated_device = %{current_device | lon: lon, lat: lat}

      current_trail = socket.assigns.trail
      new_point = [lon, lat]
      updated_trail = [new_point | current_trail] |> Enum.take(socket.assigns.history_points)

      DeviceStore.update_device(updated_device)
      DeviceStore.update_trail(device_id, updated_trail)

      # Broadcast
      Phoenix.PubSub.broadcast(
        BuoyMap.PubSub,
        "device_movements",
        %{
          topic: "device_movements",
          device_id: device_id,
          device: updated_device,
          trail: updated_trail,
          metrics: socket.assigns.metrics_history
        }
      )

      socket =
        socket
        |> assign(:device, updated_device)
        |> assign(:trail, updated_trail)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_history_points", %{"points" => value} = params, socket) do
    points = String.to_integer(value)

    # Update metrics history with new size
    metrics_history = resize_metrics_history(socket.assigns.metrics_history, points)

    # Get fresh trail data and limit it to points
    trail = DeviceStore.get_trail(socket.assigns.device_id) || []
    limited_trail = Enum.take(trail, points)


    socket =
      socket
      |> assign(:history_points, points)
      |> assign(:metrics_history, metrics_history)
      |> assign(:trail, limited_trail)
      |> push_event("update_charts", %{metrics: metrics_history})

    {:noreply, socket}
  end

  # All handle_info
  def handle_info(:update_device_data, socket) do
    device = DeviceStore.get_device(socket.assigns.device_id)
    trail = DeviceStore.get_trail(socket.assigns.device_id)

    if device do
      metrics_history = update_metrics_history(socket.assigns.metrics_history, device)

      current_trail = if trail, do: Enum.take(trail, socket.assigns.history_points), else: []

      socket =
        socket
        |> assign(:device, device)
        |> assign(:trail, current_trail)
        |> assign(:metrics_history, metrics_history)
        |> assign(:error, nil)
        |> assign(:last_update, DateTime.utc_now())
        |> push_event("update_device_detail", %{device: device, trail: current_trail})
        |> push_event("update_charts", %{metrics: metrics_history})

      {:noreply, socket}
    else
      if socket.assigns.retry_count < @max_retries do
        {:noreply, assign(socket, :retry_count, socket.assigns.retry_count + 1)}
      else
        {:noreply,
         assign(socket, :error, "Unable to load device data. The device may no longer exist.")}
      end
    end
  end

  def handle_info(%{topic: "device_movements", device_id: device_id} = payload, socket) do
    # Only care about our specific device
    if device_id == socket.assigns.device_id do
      socket =
        socket
        |> assign(:device, payload.device)
        |> assign(:trail, payload.trail)
        |> push_event("external_device_update", %{
          device: payload.device,
          trail: payload.trail,
          metrics: payload.metrics
        })

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{topic: "payload_created", payload: payload}, socket) do
    payload_data =
      case payload do
        %{data: data} when is_map(data) -> data
        %{payload: %{data: data}} when is_map(data) -> data
        _ -> %{}
      end

    # Specific device
    if payload_data != %{} && payload_data.device_id == socket.assigns.device_id do
      device = DeviceStore.get_device(socket.assigns.device_id)
      trail = DeviceStore.get_trail(socket.assigns.device_id)

      if device do
        metrics_history = update_metrics_history(socket.assigns.metrics_history, device)

        socket =
          socket
          |> assign(:device, device)
          |> assign(:trail, trail)
          |> assign(:metrics_history, metrics_history)
          |> push_event("update_device_detail", %{
            device: device,
            trail: trail
          })
          |> push_event("update_charts", %{
            metrics: metrics_history
          })

        {:noreply, socket}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Add timeout handler
  def handle_info(:check_loading_state, socket) do
    socket =
      if socket.assigns.charts_loading do
        assign(socket, :charts_loading, false)
      else
        socket
      end

    {:noreply, socket}
  end

  # Private functions
  defp initialize_metrics_history(points) do
    now = DateTime.utc_now()

    # Create a list of timestamps
    timestamps =
      Enum.map(0..points, fn i ->
        DateTime.add(now, -i * @update_interval, :millisecond)
      end)

    %{
      timestamps: timestamps,
      rssi: List.duplicate(nil, points + 1),
      snr: List.duplicate(nil, points + 1),
      speed: List.duplicate(nil, points + 1),
      voltage: List.duplicate(nil, points + 1),
      elevation: List.duplicate(nil, points + 1)
    }
  end

  defp update_metrics_history(history, device) do
    now = DateTime.utc_now()
    points = length(history.timestamps) - 1

    # Shift all values and add new one at the beginning
    %{
      timestamps: [now | history.timestamps] |> Enum.take(points + 1),
      rssi: [device[:rssi] | history.rssi] |> Enum.take(points + 1),
      snr: [device[:snr] | history.snr] |> Enum.take(points + 1),
      speed: [device[:avg_speed] | history.speed] |> Enum.take(points + 1),
      voltage: [device[:voltage] | history.voltage] |> Enum.take(points + 1),
      elevation: [device[:elevation] | history.elevation] |> Enum.take(points + 1)
    }
  end

  defp resize_metrics_history(history, new_size) do
    # Trim or pad the history to match the new size
    %{
      timestamps: Enum.take(history.timestamps, new_size + 1),
      rssi: Enum.take(history.rssi, new_size + 1),
      snr: Enum.take(history.snr, new_size + 1),
      speed: Enum.take(history.speed, new_size + 1),
      voltage: Enum.take(history.voltage, new_size + 1),
      elevation: Enum.take(history.elevation, new_size + 1)
    }
  end

  defp get_timestamps(count) do
    now = DateTime.utc_now()

    Enum.map(0..(count - 1), fn i ->
      DateTime.add(now, -i * @update_interval, :millisecond)
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen w-screen bg-gray-50">
      <!-- Header/Navigation -->
      <div class="bg-white shadow-md p-4 border-b border-gray-200 flex items-center justify-between">
        <h1 class="text-xl font-bold text-gray-800"><%= if @device, do: @device.name, else: "Loading..." %></h1>
        <button
          phx-click="show_map_view"
          class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors duration-150"
        >
          Back to Map
        </button>
      </div>

      <%= if @error do %>
        <div class="flex-1 flex items-center justify-center">
          <div class="text-center">
            <div class="text-red-500 mb-4"><%= @error %></div>
            <button
              phx-click="show_map_view"
              class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium"
            >
              Return to Map
            </button>
          </div>
        </div>
      <% else %>
        <%= if @device do %>
      <!-- Main content area -->
      <div class="flex flex-col md:flex-row flex-1 overflow-hidden">
        <!-- Left panel with map -->
        <div class="w-full md:w-1/2 h-full md:h-auto">
          <div id="device-map-container" class="relative h-[60vh] md:h-full" phx-update="ignore" phx-hook="DeviceMapHook" data-device-id={@device_id}>
            <div id="device-map" class="h-full w-full"></div>
          </div>

          <%= if @map_loading do %>
            <div class="absolute inset-0 bg-gray-100 flex flex-col items-center justify-center z-50">
              <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mb-4"></div>
              <p class="text-gray-600">Loading map...</p>
              <button
                class="mt-4 bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-md text-sm"
                phx-click="reload_page"
              >
                Reload if map doesn't appear
              </button>
            </div>
          <% end %>
        </div>

        <!-- Right panel with metrics -->
        <div class="w-full md:w-1/2 p-4 overflow-y-auto">
          <!-- Device Status Card -->
          <div class="bg-white rounded-lg shadow-lg p-4 mb-6">
            <h2 class="text-lg font-semibold mb-3">Device Status</h2>
            <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
              <div class="bg-gray-50 p-3 rounded-md">
                <div class="text-sm text-gray-500">Sequence #</div>
                <div class="text-lg font-medium"><%= @device[:sequence_no] || "N/A" %></div>
              </div>
              <div class="bg-gray-50 p-3 rounded-md">
                <div class="text-sm text-gray-500">Speed</div>
                <div class="text-lg font-medium"><%= Float.round(@device[:avg_speed] || 0, 2) %> m/s</div>
              </div>
              <div class="bg-gray-50 p-3 rounded-md">
                <div class="text-sm text-gray-500">Elevation</div>
                <div class="text-lg font-medium"><%= Float.round(@device[:elevation] || 0, 1) %> m</div>
              </div>
              <div class="bg-gray-50 p-3 rounded-md">
                <div class="text-sm text-gray-500">Battery</div>
                <div class="text-lg font-medium"><%= Float.round(@device[:voltage] || 0, 2) %> V</div>
              </div>
              <div class="bg-gray-50 p-3 rounded-md">
                <div class="text-sm text-gray-500">RSSI</div>
                <div class="text-lg font-medium"><%= round(@device[:rssi] || 0) %> dBm</div>
              </div>
              <div class="bg-gray-50 p-3 rounded-md">
                <div class="text-sm text-gray-500">SNR</div>
                <div class="text-lg font-medium"><%= Float.round(@device[:snr] || 0, 1) %> dB</div>
              </div>
              <div class="bg-gray-50 p-3 rounded-md col-span-2 md:col-span-3">
                <div class="text-sm text-gray-500">Last Connected Hotspot</div>
                <div class="text-lg font-medium truncate"><%= @device[:hotspot] || "N/A" %></div>
              </div>
            </div>

            <%= if Map.has_key?(@device, :updated_at) do %>
              <div class="text-xs text-gray-500 mt-3 text-right">
                Last update: <%= Calendar.strftime(@device.updated_at, "%H:%M:%S") %>
              </div>
            <% end %>
          </div>

          <!-- Charts section -->
          <div class="space-y-6 relative">
            <%= if @charts_loading do %>
              <div class="absolute inset-0 bg-gray-100 flex flex-col items-center justify-center z-50 rounded-lg">
                <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mb-4"></div>
                <p class="text-gray-600">Loading charts...</p>
              </div>
            <% end %>

            <!-- History Points Control -->
    <div class="bg-white rounded-xl shadow-lg p-6">
    <div class="flex items-center justify-between mb-3">
    <h3 class="text-md font-semibold text-gray-800">History Points</h3>
    </div>
    <form phx-change="update_history_points">
    <div class="flex items-center space-x-3">
      <span class="text-sm text-gray-500 font-medium">50</span>
      <input
        type="range"
        name="points"
        min="50"
        max={@max_history_points}
        value={@history_points}
        class="flex-1 h-2 bg-gradient-to-r from-blue-400 to-blue-600 rounded-lg appearance-none cursor-pointer transition duration-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
      <span class="text-sm text-gray-500 font-medium"><%= @max_history_points %></span>
    </div>
    </form>

              <!-- Coordinate History Table -->
              <div class="mt-4 border-t border-gray-200 pt-4">
                <div class="flex items-center justify-between mb-2">
                  <h3 class="text-md font-semibold">Coordinate History</h3>
                  <div class="text-sm text-gray-500">
                    <span class="font-medium text-blue-600"><%= @history_points %></span> points selected
                    <%= if length(@trail) < @history_points do %>
                      <span class="text-gray-400 ml-1">(<%= length(@trail) %> available)</span>
                    <% end %>
                  </div>
                </div>
                <div class="max-h-[500px] overflow-y-auto">
                  <table class="min-w-full">
                    <thead class="bg-gray-50 sticky top-0">
                      <tr>
                        <th class="py-2 px-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">#</th>
                        <th class="py-2 px-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Longitude</th>
                        <th class="py-2 px-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Latitude</th>
                        <th class="py-2 px-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Timestamp</th>
                      </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
                      <%= for {{[lon, lat], timestamp}, index} <- Enum.zip(Enum.take(@trail, @history_points), get_timestamps(@history_points)) |> Enum.with_index() do %>
                        <tr class="hover:bg-gray-50">
                          <td class="py-2 px-3 text-sm text-gray-500"><%= index + 1 %></td>
                          <td class="py-2 px-3 text-sm font-mono"><%= Float.round(lon, 6) %></td>
                          <td class="py-2 px-3 text-sm font-mono"><%= Float.round(lat, 6) %></td>
                          <td class="py-2 px-3 text-sm text-gray-500">
                            <%= Calendar.strftime(timestamp, "%H:%M:%S") %>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>

            <div class="bg-white rounded-lg shadow-lg p-4">
              <h3 class="text-md font-semibold mb-2">Signal Strength (RSSI)</h3>
              <div class="h-48" id="rssi-chart" phx-update="ignore"></div>
            </div>

            <div class="bg-white rounded-lg shadow-lg p-4">
              <h3 class="text-md font-semibold mb-2">Signal-to-Noise Ratio (SNR)</h3>
              <div class="h-48" id="snr-chart" phx-update="ignore"></div>
            </div>

            <div class="bg-white rounded-lg shadow-lg p-4">
              <h3 class="text-md font-semibold mb-2">Speed</h3>
              <div class="h-48" id="speed-chart" phx-update="ignore"></div>
            </div>

            <div class="bg-white rounded-lg shadow-lg p-4">
              <h3 class="text-md font-semibial mb-2">Battery Voltage</h3>
              <div class="h-48" id="voltage-chart" phx-update="ignore"></div>
            </div>

            <div class="bg-white rounded-lg shadow-lg p-4">
              <h3 class="text-md font-semibold mb-2">Elevation</h3>
              <div class="h-48" id="elevation-chart" phx-update="ignore"></div>
            </div>
          </div>
        </div>
      </div>
        <% else %>
          <div class="flex-1 flex items-center justify-center">
            <div class="text-center">
              <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mb-4 mx-auto"></div>
              <p class="text-gray-600">Loading device data...</p>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
