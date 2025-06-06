defmodule BuoyMapWeb.DeviceDetailLive do
  use BuoyMapWeb, :live_view

  alias BuoyMap.DeviceStore

  @update_interval 2000
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
      |> assign(:active_chart, nil)

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

  def handle_event("update_history_points", %{"points" => value} = _params, socket) do
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

  # Add new event handler for showing charts
  def handle_event("show_chart", %{"type" => chart_type}, socket) do
    socket =
      socket
      |> assign(:active_chart, chart_type)
      |> assign(:charts_loading, false)
      |> push_event("toggle_view", %{
        show_stats: false,
        chart_type: chart_type
      })
      |> push_event("show_chart", %{
        chart_type: chart_type,
        metrics: socket.assigns.metrics_history
      })

    {:noreply, socket}
  end

  def handle_event("show_stats", _params, socket) do
    socket =
      socket
      |> assign(:active_chart, nil)
      |> push_event("toggle_view", %{
        show_stats: true,
        chart_type: nil
      })

    {:noreply, socket}
  end

  # Add new event handler for highlighting coordinates
  def handle_event(
        "highlight_coordinate",
        %{"coordinate" => coordinate, "index" => index},
        socket
      ) do
    socket =
      socket
      |> push_event("highlight_coordinate", %{
        coordinate: coordinate,
        index: index
      })

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
        |> push_event("update_device_detail", %{
          device: device,
          trail: current_trail
        })
        |> push_event("update_charts", %{metrics: metrics_history})

      {:noreply, socket}
    else
      {:noreply, socket}
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
        <div class="flex items-center space-x-4">
    <button
    phx-click="show_map_view"
    class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors duration-150 flex items-center"
    >
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 sm:mr-2" viewBox="0 0 20 20" fill="currentColor">
    <path fill-rule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clip-rule="evenodd" />
    </svg>
    <span class="hidden sm:inline">Back to Map</span>
    </button>
          <h1 class="text-xl font-bold text-gray-800"><%= if @device, do: @device.name, else: "Loading..." %></h1>
        </div>
        <div class="text-sm text-gray-500">
          <%= if @device && Map.has_key?(@device, :updated_at) do %>
            Last Update: <span class="font-medium"><%= Calendar.strftime(@device.updated_at, "%H:%M:%S") %></span>
          <% end %>
        </div>
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
          <div class="flex flex-col md:flex-row flex-1 min-h-0">
            <!-- Map container - top on mobile, right side on desktop -->
            <div class="w-full md:w-1/2 h-[35vh] md:h-auto relative md:order-2 flex-shrink-0 z-10">
              <div id="device-map-container" class="absolute inset-0" phx-update="ignore" phx-hook="DeviceMapHook" data-device-id={@device_id}>
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

            <!-- Content panel - below map on mobile, left on desktop -->
            <div class="w-full md:w-1/2 md:order-1 flex-1 min-h-0 overflow-hidden">
              <div class="h-full overflow-y-auto p-4">
                <!-- Device Status Card -->
                <div class="bg-white rounded-lg shadow-lg p-4 mb-2 mt-24 md:mt-0" id="device-status-card" phx-hook="DeviceStatusHook">
                  <h2 class="text-lg font-semibold mb-3 flex items-center">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                        d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z" />
                    </svg>
                    Current Status
                    <%= if @active_chart == nil do %>
                      <span class="ml-2 text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded-full">Click cards to view charts</span>
                    <% end %>
                  </h2>

                  <!-- Stats Grid -->
                  <div id="stats-grid" class={if @active_chart, do: "hidden", else: "grid grid-cols-2 md:grid-cols-3 gap-3"}>
                    <div class="bg-blue-50 p-3 rounded-lg">
                      <div class="text-xs text-blue-600 font-medium mb-1">Sequence #</div>
                      <div class="text-base font-semibold text-gray-800"><%= @device[:sequence_no] || "N/A" %></div>
                    </div>

                    <%= for {type, label, value, color} <- [
                      {"speed", "Speed", Float.round(@device[:avg_speed] || 0, 2), "green"},
                      {"elevation", "Elevation", Float.round(@device[:elevation] || 0, 1), "purple"},
                      {"voltage", "Battery", Float.round(@device[:voltage] || 0, 2), "yellow"},
                      {"rssi", "Signal Strength", round(@device[:rssi] || 0), "red"},
                      {"snr", "Signal Quality", Float.round(@device[:snr] || 0, 1), "indigo"}
                    ] do %>
                      <button phx-click="show_chart" phx-value-type={type}
                        class={"group bg-#{color}-50 p-3 rounded-lg text-left hover:bg-#{color}-100 transition-all duration-150 relative overflow-hidden hover:shadow-md transform hover:scale-105"}>
                        <!-- Chart Icon -->
                        <div class="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity duration-150">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                          </svg>
                        </div>
                        <div class={"text-xs text-#{color}-600 font-medium mb-1"}><%= label %></div>
                        <div class="text-base font-semibold text-gray-800">
                          <%= value %> <%= case type do
                            "speed" -> "m/s"
                            "elevation" -> "m"
                            "voltage" -> "V"
                            "rssi" -> "dBm"
                            "snr" -> "dB"
                          end %>
                        </div>
                      </button>
                    <% end %>

                    <div class="bg-gray-50 p-3 rounded-lg col-span-2 md:col-span-3">
                      <div class="text-xs text-gray-600 font-medium mb-1">Connected To</div>
                      <div class="text-base font-semibold text-gray-800 truncate"><%= @device[:hotspot] || "N/A" %></div>
                    </div>
                  </div>

                  <!-- Chart Containers -->
                  <div id="charts-container" phx-hook="ChartHook" phx-update="ignore" class={if @active_chart, do: "", else: "hidden"}>
                    <%= for {type, title} <- [
                      {"speed", "Speed Over Time"},
                      {"elevation", "Elevation Over Time"},
                      {"voltage", "Battery Level Over Time"},
                      {"rssi", "Signal Strength Over Time"},
                      {"snr", "Signal Quality Over Time"}
                    ] do %>
                      <div id={"#{type}-chart"} class={if @active_chart == type, do: "mt-4", else: "hidden mt-4"}>
                        <div class="flex items-center justify-between mb-4">
                          <h3 class="text-lg font-semibold"><%= title %></h3>
                          <button phx-click="show_stats" class="text-gray-600 hover:text-gray-800 p-2 rounded-lg hover:bg-gray-100 transition-colors duration-150">
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                            </svg>
                          </button>
                        </div>
                        <div class="h-64 bg-white rounded-lg border border-gray-200 p-4">
                          <canvas id={"#{type}-chart-canvas"} class="w-full h-full"></canvas>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>

                <!-- History Points Control -->
                <div class="bg-white rounded-xl shadow-lg p-6">
                  <div class="flex items-center justify-between mb-4">
                    <h3 class="text-lg font-semibold flex items-center">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mr-2 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      History Points
                    </h3>
                    <div class="text-sm text-gray-500">
                      Showing <span class="font-medium text-blue-600"><%= @history_points %></span> points
                    </div>
                  </div>
                  <div class="bg-gray-50 p-4 rounded-lg mb-4">
                    <p class="text-sm text-gray-600 mb-3">
                      Adjust the slider to see more or fewer location points. More points show a longer history but may load slower.
                    </p>
                    <form phx-change="update_history_points" class="space-y-2">
                      <div class="flex items-center space-x-3">
                        <span class="text-sm font-medium text-gray-500">50</span>
                        <input
                          type="range"
                          name="points"
                          min="50"
                          max={@max_history_points}
                          value={@history_points}
                          class="flex-1 h-2 bg-gradient-to-r from-blue-400 to-blue-600 rounded-lg appearance-none cursor-pointer transition duration-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
                        />
                        <span class="text-sm font-medium text-gray-500"><%= @max_history_points %></span>
                      </div>
                    </form>
                  </div>

                  <!-- Coordinate History Table -->
                  <div class="overflow-hidden">
                    <div class="flex items-center justify-between mb-2">
                      <h3 class="text-md font-semibold flex items-center">
                        Location History
                        <span class="ml-2 text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded-full">Click rows to highlight on map</span>
                      </h3>
                      <div class="text-sm text-gray-500">
                        <%= if length(@trail) < @history_points do %>
                          <span class="text-gray-400">(<%= length(@trail) %> points available)</span>
                        <% end %>
                      </div>
                    </div>

                    <!-- Make table wrapper responsive -->
                    <div class="max-h-[420px] overflow-y-auto border border-gray-200 rounded-lg w-full overflow-x-auto">
                      <table class="w-full table-auto divide-y divide-gray-200 text-sm">
                        <thead class="bg-gray-50 sticky top-0">
                          <tr>
                            <th class="py-2 px-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">#</th>
                            <th class="py-2 px-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Longitude</th>
                            <th class="py-2 px-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Latitude</th>
                            <th class="py-2 px-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap">Time</th>
                          </tr>
                        </thead>
                        <tbody class="bg-white divide-y divide-gray-200">
                          <%= for {{[lon, lat], timestamp}, index} <- Enum.zip(Enum.take(@trail, @history_points), get_timestamps(@history_points)) |> Enum.with_index() do %>
                            <tr class="hover:bg-blue-50 cursor-pointer transition-colors duration-150 group"
                                phx-click="highlight_coordinate"
                                phx-value-coordinate={Jason.encode!([lon, lat])}
                                phx-value-index={index}>
                              <td class="py-1.5 px-2 text-gray-500 group-hover:text-blue-600"><%= index + 1 %></td>
                              <td class="py-1.5 px-2 font-mono group-hover:text-blue-700"><%= Float.round(lon, 6) %></td>
                              <td class="py-1.5 px-2 font-mono group-hover:text-blue-700"><%= Float.round(lat, 6) %></td>
                              <td class="py-1.5 px-2 text-gray-500 whitespace-nowrap group-hover:text-blue-600">
                                <%= Calendar.strftime(timestamp, "%H:%M:%S") %>
                              </td>
                              <!-- Location Icon -->
                              <td class="py-1.5 px-2 opacity-0 group-hover:opacity-100 transition-opacity duration-150">
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                                </svg>
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>

                <!-- Selected Chart Section -->
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
