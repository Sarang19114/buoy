defmodule BuoyMapWeb.DeviceDetailLive do
  use BuoyMapWeb, :live_view

  @update_interval 2000
  @max_trail_points 50
  @max_graph_points 100

  def mount(%{"id" => device_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BuoyMap.PubSub, "payload_created")
      Phoenix.PubSub.subscribe(BuoyMap.PubSub, "device_movements")
      :timer.send_interval(@update_interval, :update_device_data)
    end

    # Get the device data from BuoyMapWeb.MapLive
    device = find_device(device_id)

    socket =
      socket
      |> assign(:device, device)
      |> assign(:device_id, device_id)
      |> assign(:trail, initialize_device_trail(device))
      |> assign(:metrics_history, initialize_metrics_history())
      |> assign(:page_title, "Device Detail: #{device.name}")
      |> assign(:map_loading, true)
      |> assign(:charts_loading, true)

    {:ok, socket, layout: false}
  end

  def handle_event("show_map_view", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("map_loaded", _params, socket) do
    {:noreply, push_event(socket, "init_device_detail", %{device: socket.assigns.device, trail: socket.assigns.trail})}
  end

  def handle_info(:update_device_data, socket) do
    device_id = socket.assigns.device_id
    current_device = socket.assigns.device

    # If device can't be found anymore, return to the map
    if !current_device do
      {:noreply, push_navigate(socket, to: ~p"/")}
    else
      # Update device position using significant_movement
      {new_lon, new_lat} = significant_movement(current_device.lon, current_device.lat)
      updated_device = %{current_device |
        lon: new_lon,
        lat: new_lat,
        sequence_no: get_random_sequence_no(),
        avg_speed: :rand.uniform() * 12,
        elevation: 10 + :rand.uniform() * 120,
        voltage: 3.8 + :rand.uniform(),
        rssi: -100 + :rand.uniform() * 30,
        snr: :rand.uniform() * 12,
        updated_at: DateTime.utc_now()
      }

      # Update trail
      current_trail = socket.assigns.trail
      new_point = [updated_device.lon, updated_device.lat]
      updated_trail = [new_point | current_trail] |> Enum.take(@max_trail_points)

      # Update metrics history
      metrics_history = update_metrics_history(socket.assigns.metrics_history, updated_device)

      socket =
        socket
        |> assign(:device, updated_device)
        |> assign(:trail, updated_trail)
        |> assign(:metrics_history, metrics_history)
        |> push_event("update_device_detail", %{
          device: updated_device,
          trail: updated_trail
        })
        |> push_event("update_charts", %{
          metrics: metrics_history
        })

      {:noreply, socket}
    end
  end

  # Handles payload creation/updates from PubSub
  def handle_info(%{topic: "payload_created", payload: payload}, socket) do
    payload_data =
      case payload do
        %{data: data} when is_map(data) -> data
        %{payload: %{data: data}} when is_map(data) -> data
        _ -> %{}
      end

    # Only care about our specific device
    if payload_data != %{} && payload_data.device_id == socket.assigns.device_id do
      # Update device data but preserve original location and name
      current_device = socket.assigns.device
      updated_device = %{current_device |
        sequence_no: payload_data.sequence_no,
        avg_speed: payload_data.avg_speed,
        elevation: payload_data.elevation,
        voltage: payload_data.voltage,
        rssi: payload_data.rssi,
        snr: payload_data.snr,
        updated_at: payload_data.updated_at,
        hotspot: payload_data.hotspot
      }

      # Update trail with current location
      current_trail = socket.assigns.trail
      new_point = [current_device.lon, current_device.lat]
      updated_trail = [new_point | current_trail] |> Enum.take(@max_trail_points)

      metrics_history = update_metrics_history(socket.assigns.metrics_history, updated_device)

      socket =
        socket
        |> assign(:device, updated_device)
        |> assign(:trail, updated_trail)
        |> assign(:metrics_history, metrics_history)
        |> push_event("update_device_detail", %{
          device: updated_device,
          trail: updated_trail
        })
        |> push_event("update_charts", %{
          metrics: metrics_history
        })

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("map_loaded_success", _params, socket) do
    {:noreply, assign(socket, :map_loading, false)}
  end

  def handle_event("charts_loaded_success", _params, socket) do
    {:noreply, assign(socket, :charts_loading, false)}
  end

  def handle_event("reload_page", _params, socket) do
    {:noreply, socket |> redirect(to: ~p"/device/#{socket.assigns.device_id}")}
  end

  # Handle device movement events from the JS hook
  def handle_event("device_moved", %{"device_id" => device_id, "lon" => lon, "lat" => lat}, socket) do
    if device_id == socket.assigns.device_id do
      # Update the device with new coordinates but preserve other attributes
      current_device = socket.assigns.device
      updated_device = %{current_device | lon: lon, lat: lat}

      # Update trail with new position
      current_trail = socket.assigns.trail
      new_point = [lon, lat]
      updated_trail = [new_point | current_trail] |> Enum.take(@max_trail_points)

      # Broadcast to all clients
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

  # Handle device movement broadcasts from other clients
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

  # Catch-all handler for unmatched messages
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  # Initialize empty metrics history
  defp initialize_metrics_history do
    now = DateTime.utc_now()

    # Create a list of timestamps for the last X minutes
    timestamps =
      Enum.map(0..@max_graph_points, fn i ->
        DateTime.add(now, -i * @update_interval, :millisecond)
      end)

    %{
      timestamps: timestamps,
      rssi: List.duplicate(nil, @max_graph_points + 1),
      snr: List.duplicate(nil, @max_graph_points + 1),
      speed: List.duplicate(nil, @max_graph_points + 1),
      voltage: List.duplicate(nil, @max_graph_points + 1),
      elevation: List.duplicate(nil, @max_graph_points + 1)
    }
  end

  # Update metrics history with new data
  defp update_metrics_history(history, device) do
    now = DateTime.utc_now()

    # Shift all values and add new one at the beginning
    %{
      timestamps: [now | history.timestamps] |> Enum.take(@max_graph_points + 1),
      rssi: [device[:rssi] | history.rssi] |> Enum.take(@max_graph_points + 1),
      snr: [device[:snr] | history.snr] |> Enum.take(@max_graph_points + 1),
      speed: [device[:avg_speed] | history.speed] |> Enum.take(@max_graph_points + 1),
      voltage: [device[:voltage] | history.voltage] |> Enum.take(@max_graph_points + 1),
      elevation: [device[:elevation] | history.elevation] |> Enum.take(@max_graph_points + 1)
    }
  end

  # Helper to find a device by ID
  defp find_device(device_id) do
    # For now, this is a mock function that would normally query a database
    # In reality we'd have a context module for this
    initial_mock_devices()
    |> Enum.find(fn device -> device.device_id == device_id end)
    |> case do
      nil ->
        # Create a mock device for missing IDs (just for demo purposes)
        create_mock_device(device_id)
      device ->
        # Return found device but preserve its original location and name
        device
    end
  end

  # Copy of the mock devices function to avoid dependency on private function
  defp initial_mock_devices do
    [
      %{
        device_id: "1",
        name: "Buoy Alpha - USA (San Francisco)",
        lon: -122.4194,
        lat: 37.7749,
        sequence_no: 5000 + :rand.uniform(1000),
        avg_speed: :rand.uniform() * 10,
        elevation: 42.0,
        voltage: 4.8,
        rssi: -85,
        snr: 7.3,
        updated_at: DateTime.utc_now(),
        hotspot: generate_random_hotspot_name()
      },
      %{
        device_id: "2",
        name: "Buoy Beta - Germany (Berlin)",
        lon: 13.4050,
        lat: 52.5200,
        sequence_no: 5000 + :rand.uniform(1000),
        avg_speed: :rand.uniform() * 10,
        elevation: 35.8,
        voltage: 4.5,
        rssi: -92,
        snr: 6.8,
        updated_at: DateTime.utc_now(),
        hotspot: generate_random_hotspot_name()
      },
      %{
        device_id: "3",
        name: "Buoy Gamma - Japan (Tokyo)",
        lon: 139.6917,
        lat: 35.6895,
        sequence_no: 5000 + :rand.uniform(1000),
        avg_speed: :rand.uniform() * 10,
        elevation: 28.2,
        voltage: 4.2,
        rssi: -78,
        snr: 8.5,
        updated_at: DateTime.utc_now(),
        hotspot: generate_random_hotspot_name()
      },
      %{
        device_id: "4",
        name: "Buoy Delta - Australia (Sydney)",
        lon: 151.2093,
        lat: -33.8688,
        sequence_no: 5000 + :rand.uniform(1000),
        avg_speed: :rand.uniform() * 10,
        elevation: 15.7,
        voltage: 4.1,
        rssi: -95,
        snr: 5.9,
        updated_at: DateTime.utc_now(),
        hotspot: generate_random_hotspot_name()
      },
      %{
        device_id: "5",
        name: "Buoy Epsilon - Brazil (Rio)",
        lon: -43.1729,
        lat: -22.9068,
        sequence_no: 5000 + :rand.uniform(1000),
        avg_speed: :rand.uniform() * 10,
        elevation: 22.3,
        voltage: 4.6,
        rssi: -88,
        snr: 7.1,
        updated_at: DateTime.utc_now(),
        hotspot: generate_random_hotspot_name()
      }
    ]
  end

  # Create a mock device if not found
  defp create_mock_device(id) do
    locations = [
      {-122.4194, 37.7749, "USA (San Francisco)"},
      {-74.0060, 40.7128, "USA (New York)"},
      {-87.6298, 41.8781, "USA (Chicago)"},
      {-79.3832, 43.6532, "Canada (Toronto)"},
      {-99.1332, 19.4326, "Mexico (Mexico City)"},
      {13.4050, 52.5200, "Germany (Berlin)"},
      {2.3522, 48.8566, "France (Paris)"},
      {-0.1278, 51.5074, "UK (London)"},
      {12.4964, 41.9028, "Italy (Rome)"},
      {4.9041, 52.3676, "Netherlands (Amsterdam)"},
      {139.6917, 35.6895, "Japan (Tokyo)"},
      {116.4074, 39.9042, "China (Beijing)"},
      {77.2090, 28.6139, "India (New Delhi)"},
      {103.8198, 1.3521, "Singapore"},
      {126.9780, 37.5665, "South Korea (Seoul)"},
      {151.2093, -33.8688, "Australia (Sydney)"},
      {174.7633, -36.8485, "New Zealand (Auckland)"},
      {-43.1729, -22.9068, "Brazil (Rio)"},
      {-58.3816, -34.6037, "Argentina (Buenos Aires)"},
      {18.4241, -33.9249, "South Africa (Cape Town)"},
      {31.2357, 30.0444, "Egypt (Cairo)"}
    ]

    {lon, lat, location} = Enum.random(locations)

    # Add small random offset to prevent devices stacking
    lon = lon + (:rand.uniform() - 0.5) * 0.2
    lat = lat + (:rand.uniform() - 0.5) * 0.2

    greek_letters = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta",
                     "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi", "Omicron", "Pi",
                     "Rho", "Sigma", "Tau", "Upsilon", "Phi", "Chi", "Psi", "Omega"]

    buoy_name = "Buoy #{Enum.random(greek_letters)} - #{location}"

    %{
      device_id: id,
      name: buoy_name,
      lon: lon,
      lat: lat,
      sequence_no: get_random_sequence_no(),
      avg_speed: :rand.uniform() * 10,
      elevation: 10 + :rand.uniform() * 100,
      voltage: 3.8 + :rand.uniform(),
      rssi: -100 + :rand.uniform() * 30,
      snr: :rand.uniform() * 10,
      updated_at: DateTime.utc_now(),
      hotspot: generate_random_hotspot_name()
    }
  end

  # Initialize device trail
  defp initialize_device_trail(device) do
    [[device.lon, device.lat]]
  end

  # Helper function for random hotspot name
  defp generate_random_hotspot_name do
    adjectives = ["swift", "bold", "bright", "calm", "dazzling", "eager", "fierce", "gentle", "happy", "kind"]
    animals = ["fox", "wolf", "bear", "eagle", "hawk", "tiger", "lion", "panther", "dolphin", "whale"]
    colors = ["amber", "azure", "bronze", "coral", "crimson", "cyan", "emerald", "gold", "indigo", "jade"]

    "#{Enum.random(adjectives)}-#{Enum.random(colors)}-#{Enum.random(animals)}"
  end

  # Add helper functions at the bottom of the module
  defp get_random_sequence_no do
    5000 + :rand.uniform(1000)
  end

  defp significant_movement(lon, lat) do
    angle = :rand.uniform() * 2 * :math.pi()
    distance = 0.002 + :rand.uniform() * 0.008
    new_lon = lon + distance * :math.cos(angle)
    new_lat = lat + distance * :math.sin(angle)
    {new_lon, new_lat}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen w-screen bg-gray-50">
      <!-- Header/Navigation -->
      <div class="bg-white shadow-md p-4 border-b border-gray-200 flex items-center justify-between">
        <h1 class="text-xl font-bold text-gray-800"><%= @device.name %></h1>
        <button
          phx-click="show_map_view"
          class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors duration-150"
        >
          Back to Map
        </button>
      </div>

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

          <div class="mt-6 bg-white rounded-lg shadow-lg p-4">
            <h3 class="text-md font-semibold mb-3">Coordinate History</h3>
            <div class="max-h-64 overflow-y-auto">
              <table class="min-w-full">
                <thead>
                  <tr>
                    <th class="py-2 px-3 text-left text-xs font-medium text-gray-500 uppercase">#</th>
                    <th class="py-2 px-3 text-left text-xs font-medium text-gray-500 uppercase">Longitude</th>
                    <th class="py-2 px-3 text-left text-xs font-medium text-gray-500 uppercase">Latitude</th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for {[lon, lat], index} <- Enum.with_index(@trail) do %>
                    <tr class="hover:bg-gray-50">
                      <td class="py-2 px-3 text-sm text-gray-500"><%= index + 1 %></td>
                      <td class="py-2 px-3 text-sm"><%= Float.round(lon, 6) %></td>
                      <td class="py-2 px-3 text-sm"><%= Float.round(lat, 6) %></td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Charts section -->
          <div class="space-y-6 relative">
            <%= if @charts_loading do %>
              <div class="absolute inset-0 bg-gray-100 flex flex-col items-center justify-center z-50 rounded-lg">
                <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mb-4"></div>
                <p class="text-gray-600">Loading charts...</p>
              </div>
            <% end %>

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
    </div>
    """
  end
end
