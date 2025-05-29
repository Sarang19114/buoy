defmodule BuoyMapWeb.DeviceDetailLive do
  use BuoyMapWeb, :live_view

  alias BuoyMap.{DeviceStore, StatsStore}

  @update_interval 2000
  @default_history_points 100
  @max_history_points 1000

  def mount(%{"id" => device_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BuoyMap.PubSub, "payload_created")
      Phoenix.PubSub.subscribe(BuoyMap.PubSub, "device_movements")
      Phoenix.PubSub.subscribe(BuoyMap.PubSub, "device_stats")
      :timer.send_interval(@update_interval, :update_device_data)
    end

    device = DeviceStore.get_device(device_id)
    trail = DeviceStore.get_trail(device_id)
    stats = StatsStore.get_device_stats(device_id)

    socket =
      socket
      |> assign(:device, device)
      |> assign(:device_id, device_id)
      |> assign(:trail, trail || [])
      |> assign(:active_chart, nil)
      |> assign(:selected_coordinate, nil)
      |> assign(:error, if(device, do: nil, else: "Device not found"))

    {:ok, socket}
  end

  def handle_event("select_coordinate", %{"index" => index}, socket) do
    index = String.to_integer(index)
    trail = socket.assigns.trail

    if index >= 0 and index < length(trail) do
      coordinate = Enum.at(trail, index)
      socket =
        socket
        |> assign(:selected_coordinate, index)
        |> push_event("highlight_coordinate", %{
          coordinate: coordinate,
          index: index
        })
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("show_chart", %{"type" => type}, socket) do
    {:noreply, assign(socket, :active_chart, type)}
  end

  def handle_event("show_stats", _params, socket) do
    {:noreply, assign(socket, :active_chart, nil)}
  end

  def handle_info(:update_device_data, socket) do
    device_id = socket.assigns.device_id
    device = DeviceStore.get_device(device_id)
    trail = DeviceStore.get_trail(device_id)
    stats = StatsStore.get_device_stats(device_id)

    # Merge stats into device if they exist
    device = if stats, do: Map.merge(device || %{}, stats), else: device

    socket =
      socket
      |> assign(:device, device)
      |> assign(:trail, trail || [])
      |> push_event("update_charts", %{
        metrics: %{
          timestamps: Enum.map(trail || [], fn {_, ts} -> ts end),
          speed: Enum.map(trail || [], fn {_, speed} -> speed end),
          elevation: Enum.map(trail || [], fn {_, elevation} -> elevation end),
          voltage: Enum.map(trail || [], fn {_, voltage} -> voltage end),
          rssi: Enum.map(trail || [], fn {_, rssi} -> rssi end),
          snr: Enum.map(trail || [], fn {_, snr} -> snr end)
        }
      })

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen">
      <!-- Stats Grid -->
      <div id="stats-grid" class={if @active_chart, do: "hidden", else: "grid grid-cols-2 md:grid-cols-3 gap-3"}>
        <%= for {type, label, value, color} <- [
          {"speed", "Speed", Float.round(@device[:avg_speed] || 0, 2), "green"},
          {"elevation", "Elevation", Float.round(@device[:elevation] || 0, 1), "purple"},
          {"voltage", "Battery", Float.round(@device[:voltage] || 0, 2), "yellow"},
          {"rssi", "Signal Strength", round(@device[:rssi] || 0), "red"},
          {"snr", "Signal Quality", Float.round(@device[:snr] || 0, 1), "indigo"}
        ] do %>
          <button phx-click="show_chart" phx-value-type={type}
            class={"group relative bg-#{color}-50 p-3 rounded-lg text-left hover:bg-#{color}-100 transition-colors duration-150 cursor-pointer transform hover:scale-[1.02] hover:shadow-md"}>
            <div class={"text-xs text-#{color}-600 font-medium mb-1 flex items-center justify-between"}>
              <span><%= label %></span>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 opacity-0 group-hover:opacity-100 transition-opacity" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
            </div>
            <div class="text-base font-semibold text-gray-800">
              <%= value %> <%= case type do
                "speed" -> "m/s"
                "elevation" -> "m"
                "voltage" -> "V"
                "rssi" -> "dBm"
                "snr" -> "dB"
              end %>
            </div>
            <div class={"absolute inset-0 border-2 border-#{color}-300 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none"}></div>
            <div class="absolute -top-1 -right-1 bg-blue-500 text-white text-xs px-2 py-1 rounded-full opacity-0 group-hover:opacity-100 transition-opacity">
              Click for chart
            </div>
          </button>
        <% end %>
      </div>

      <!-- Chart Containers -->
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
            <button phx-click="show_stats" class="text-gray-600 hover:text-gray-800 p-2 rounded-lg hover:bg-gray-100 flex items-center">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
              <span>Back to Stats</span>
            </button>
          </div>
          <div class="h-64 bg-gray-50 rounded-lg p-4">
            <div class="w-full h-full" id={"#{type}-chart-container"} phx-update="ignore" phx-hook="ChartHook">
              <!-- Chart will be rendered here by JS -->
            </div>
          </div>
        </div>
      <% end %>

      <!-- Coordinate History Table -->
      <div class="overflow-hidden mt-4">
        <table class="w-full table-auto divide-y divide-gray-200 text-sm">
          <thead class="bg-gray-50">
            <tr>
              <th class="py-2 px-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">#</th>
              <th class="py-2 px-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Longitude</th>
              <th class="py-2 px-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Latitude</th>
              <th class="py-2 px-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Time</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for {{[lon, lat], timestamp}, index} <- Enum.zip(@trail, get_timestamps(@history_points)) |> Enum.with_index() do %>
              <tr class={"group hover:bg-blue-50 cursor-pointer transition-colors duration-150 " <> if @selected_coordinate == index, do: "bg-blue-100", else: ""}
                  phx-click="select_coordinate"
                  phx-value-index={index}>
                <td class="py-1.5 px-2 text-gray-500"><%= index + 1 %></td>
                <td class="py-1.5 px-2 font-mono"><%= Float.round(lon, 6) %></td>
                <td class="py-1.5 px-2 font-mono"><%= Float.round(lat, 6) %></td>
                <td class="py-1.5 px-2 text-gray-500 whitespace-nowrap">
                  <%= Calendar.strftime(timestamp, "%H:%M:%S") %>
                </td>
                <td class="py-1.5 px-2 opacity-0 group-hover:opacity-100 transition-opacity">
                  <span class="text-blue-500 text-xs">Click to highlight on map</span>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # ... rest of the existing code ...
end
