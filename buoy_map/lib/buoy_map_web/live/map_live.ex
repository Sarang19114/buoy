defmodule BuoyMapWeb.MapLive do
  use BuoyMapWeb, :live_view

  @update_interval 2000
  @new_device_interval 15000
  @max_mock_devices 20

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BuoyMap.PubSub, "payload_created")
      # timer to update existing device data
      :timer.send_interval(@update_interval, :update_device_data)
      # timer to create new mock devices
      :timer.send_interval(@new_device_interval, :create_new_device)
    end

    # Initial mock devices
    initial_payloads = initial_mock_devices()

    socket =
      assign(socket,
        payloads: initial_payloads,
        filtered_payloads: initial_payloads,
        filter_query: "",
        selected_device: nil,
        packets: generate_dummy_data(),
        transmitting_devices: %{},
        next_device_id: length(initial_payloads) + 1
      )

    {:ok, socket, layout: false}
  end

  def handle_event("filter_devices", %{"query" => query}, socket) do
    filtered = filter_payloads(socket.assigns.payloads, query)
    socket =
      socket
      |> assign(filter_query: query, filtered_payloads: filtered)

    # If the currently selected device is not in the filtered list, deselect it
    socket =
      if socket.assigns.selected_device &&
           not Enum.any?(filtered, fn d -> d.device_id == socket.assigns.selected_device.device_id end) do
        socket
        |> assign(:selected_device, nil)
        |> push_event("highlight_device", %{
          device_id: nil  # Clear any highlighted device
        })
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("device_clicked", %{"id" => device_id}, socket) do
    device = Enum.find(socket.assigns.payloads, fn d -> d.device_id == device_id end)

    socket =
      if device do
        latest_location = [[device.lon, device.lat]]

        socket
        |> push_event("plot_marker", %{history: latest_location})
        |> assign(:selected_device, device)
        |> push_event("highlight_device", %{
          device_id: device.device_id,
        })
      else
        IO.inspect("Error: device not found for device_id: #{device_id}")
        socket
      end

    {:noreply, socket}
  end

  def handle_event("show_all", _params, socket) do
    socket =
      socket
      |> assign(:selected_device, nil)
      |> assign(:filter_query, "")
      |> push_event("highlight_device", %{
        device_id: nil  # Clear any highlighted device
      })
      |> push_event("fit_all_markers", %{})

    filtered = filter_payloads(socket.assigns.payloads, "")
    socket = assign(socket, :filtered_payloads, filtered)

    {:noreply, socket}
  end

  # Map initialization handler
  def handle_event("map_loaded", _params, socket) do
    {:noreply, push_event(socket, "init_device", %{payloads: socket.assigns.filtered_payloads})}
  end

  # Handler for requesting initial devices
  def handle_event("request_initial_devices", _params, socket) do
    {:noreply, push_event(socket, "init_device", %{payloads: socket.assigns.filtered_payloads})}
  end

  # Handler for updating existing device data
  def handle_info(:update_device_data, socket) do
    updated_payloads =
      socket.assigns.payloads
      |> Enum.map(fn device ->
        {new_lon, new_lat} = significant_movement(device.lon, device.lat)

        # Update device metrics
        device
        |> Map.put(:lon, new_lon)
        |> Map.put(:lat, new_lat)
        |> Map.put(:sequence_no, get_random_sequence_no())
        |> Map.put(:avg_speed, :rand.uniform() * 12)
        |> Map.put(:elevation, 10 + :rand.uniform() * 120)
        |> Map.put(:voltage, 3.8 + :rand.uniform())
        |> Map.put(:rssi, -100 + :rand.uniform() * 30)
        |> Map.put(:snr, :rand.uniform() * 12)
        |> Map.put(:updated_at, DateTime.utc_now())
      end)

    socket =
      socket
      |> assign(:payloads, updated_payloads)
      |> assign(:filtered_payloads, filter_payloads(updated_payloads, socket.assigns.filter_query))
      |> push_event("update_device_locations", %{payloads: filter_payloads(updated_payloads, socket.assigns.filter_query)})

    # Update selected device if one is selected
    socket =
      if socket.assigns.selected_device do
        updated_device = Enum.find(updated_payloads, fn d ->
          d.device_id == socket.assigns.selected_device.device_id
        end)

        assign(socket, :selected_device, updated_device)
      else
        socket
      end

    {:noreply, socket}
  end

  # Handler for creating new mock devices
  def handle_info(:create_new_device, socket) do
    if length(socket.assigns.payloads) < @max_mock_devices do
      new_device = create_random_mock_device(socket.assigns.next_device_id)
      updated_payloads = [new_device | socket.assigns.payloads]
      socket =
        socket
        |> assign(:payloads, updated_payloads)
        |> assign(:filtered_payloads, filter_payloads(updated_payloads, socket.assigns.filter_query))
        |> assign(:next_device_id, socket.assigns.next_device_id + 1)
      # Broadcast
      Phoenix.PubSub.broadcast(
        BuoyMap.PubSub,
        "payload_created",
        %{topic: "payload_created", payload: %{data: new_device}}
      )
      # Also push directly to this client
      {:noreply, push_event(socket, "new_payload", new_device)}
    else
      {:noreply, socket}
    end
  end

  # Subscription handler
  def handle_info(%{topic: "payload_created", payload: payload}, socket) do
    payload_data =
      case payload do
        %{data: data} when is_map(data) -> data
        %{payload: %{data: data}} when is_map(data) -> data
        _ -> %{}
      end

    if payload_data != %{} do
      # Check if this device is already in our payloads list (to avoid duplicates)
      device_exists = Enum.any?(socket.assigns.payloads, fn device -> 
        device.device_id == payload_data.device_id 
      end)

      if device_exists do
        # Device already exists in our list, just update the UI
        {:noreply, push_event(socket, "new_payload", payload_data)}
      else
        # Add the new device to this client's list of payloads
        updated_payloads = [payload_data | socket.assigns.payloads]
        
        socket = 
          socket
          |> assign(:payloads, updated_payloads)
          |> assign(:filtered_payloads, filter_payloads(updated_payloads, socket.assigns.filter_query))
          |> assign(:next_device_id, max(socket.assigns.next_device_id, String.to_integer(payload_data.device_id) + 1))
          |> push_event("new_payload", payload_data)
          
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Initial set of mock devices
  defp initial_mock_devices do
    [
      %{
        device_id: "1",
        name: "Buoy Alpha - USA (San Francisco)",
        lon: -122.4194,
        lat: 37.7749,
        sequence_no: get_random_sequence_no(),
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
        sequence_no: get_random_sequence_no(),
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
        sequence_no: get_random_sequence_no(),
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
        sequence_no: get_random_sequence_no(),
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
        sequence_no: get_random_sequence_no(),
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

  # Create a new random mock device
  defp create_random_mock_device(id) do
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

    lon = lon + (:rand.uniform() - 0.5) * 0.2
    lat = lat + (:rand.uniform() - 0.5) * 0.2

    greek_letters = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta",
                     "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi", "Omicron", "Pi",
                     "Rho", "Sigma", "Tau", "Upsilon", "Phi", "Chi", "Psi", "Omega"]

    buoy_name = "Buoy #{Enum.random(greek_letters)} - #{location}"

    # Create the device map
    %{
      device_id: "#{id}",
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

  defp significant_movement(lon, lat) do
    angle = :rand.uniform() * 2 * :math.pi()
    distance = 0.002 + :rand.uniform() * 0.008  # Between 0.002-0.01 degrees movement
    new_lon = lon + distance * :math.cos(angle)
    new_lat = lat + distance * :math.sin(angle)
    {new_lon, new_lat}
  end

  # Filter payloads based on search query
  defp filter_payloads(payloads, query) do
    if query == "" do
      payloads
    else
      query = String.trim(String.downcase(query))
      query_parts = String.split(query, " ", trim: true)

      payloads
      |> Enum.filter(fn payload ->
        name = String.downcase(payload.name)
        Enum.all?(query_parts, fn part ->
          String.contains?(name, part)
        end)
      end)
    end
  end

  defp get_random_sequence_no do
    5000 + :rand.uniform(1000)
  end

  defp generate_random_hotspot_name do
    adjectives = ["swift", "bold", "bright", "calm", "dazzling", "eager", "fierce", "gentle", "happy", "kind", "loud", "mighty", "noble", "proud", "quiet", "rapid", "silent", "tall", "wise", "zealous"]
    animals = ["fox", "wolf", "bear", "eagle", "hawk", "tiger", "lion", "panther", "dolphin", "whale", "shark", "falcon", "osprey", "otter", "lynx", "leopard", "jaguar", "raven", "cobra", "viper"]
    colors = ["amber", "azure", "bronze", "coral", "crimson", "cyan", "emerald", "gold", "indigo", "jade", "obsidian", "ruby", "sapphire", "scarlet", "silver", "teal", "topaz", "turquoise", "violet"]

    "#{Enum.random(adjectives)}-#{Enum.random(colors)}-#{Enum.random(animals)}"
  end

  defp generate_dummy_data do
    now = DateTime.utc_now()

    data =
      Enum.map(0..20, fn i ->
        timestamp = DateTime.add(now, -i * 60, :second)

        {timestamp,
         %{
           sequence: 5462 - i,
           speed: :rand.uniform() * 10,
           elevation: :rand.uniform() * 100,
           rssi: :rand.uniform() * -120,
           battery: 4.5 + :rand.uniform(),
           snr: :rand.uniform() * 10
         }}
      end)

    %{data: Enum.reverse(data)}
  end

  def render(assigns) do
~H"""
<div class="flex flex-col md:flex-row w-screen h-screen">
  <!-- Sidebar for desktop -->
  <div class="hidden md:flex md:flex-col md:w-1/4 bg-gray-100 rounded-lg shadow-lg p-4 overflow-y-auto">
    <div class="flex justify-between items-center mb-4">
      <h2 class="text-2xl font-bold text-gray-800">Buoy Map</h2>
      <button
        phx-click="show_all"
        class="bg-blue-500 hover:bg-blue-600 text-white px-3 py-1 rounded-md text-sm font-medium transition-colors duration-150"
      >
        See All
      </button>
    </div>

    <form phx-submit="filter_devices" class="w-full mb-4">
      <div class="flex">
        <input
          type="text"
          placeholder="Filter devices..."
          value={@filter_query}
          phx-change="filter_devices"
          phx-debounce="300"
          name="query"
          class="w-full p-2 rounded-l border border-gray-300"
        />
      </div>
    </form>

    <ul class="space-y-3">
      <%= for payload <- @filtered_payloads do %>
        <li
          class={"bg-white rounded-lg shadow p-4 flex items-center justify-between cursor-pointer transition duration-150 ease-in-out hover:bg-blue-50 hover:shadow-md active:bg-gray-100 active:shadow-inner " <> if @selected_device && @selected_device.device_id == payload.device_id, do: "bg-blue-200 border-2 border-blue-500", else: ""}
          phx-click="device_clicked"
          phx-value-id={payload.device_id}
        >
          <div class="flex items-center space-x-3">
            <div class={"w-3 h-3 rounded-full " <> if @selected_device && @selected_device.device_id == payload.device_id, do: "bg-blue-600", else: "bg-green-500"}></div>
            <span class="font-medium text-gray-800"><%= payload.name %></span>
          </div>
          <div class="text-xs text-gray-500">
            <%= if Map.has_key?(payload, :updated_at) do %>
              Updated: <%= Calendar.strftime(payload.updated_at, "%H:%M:%S") %>
            <% end %>
          </div>
        </li>
      <% end %>
    </ul>
  </div>

  <!-- Main content area with map and overlays stacked using z-index -->
  <div class="relative flex-1 h-full">
    <div id="map-container" class="absolute inset-0 z-10" phx-update="ignore" phx-hook="MapHook">
      <div id="map" class="h-full w-full"></div>
    </div>

    <%= if @selected_device do %>
      <div class="hidden md:block absolute top-4 right-4 z-30 bg-white rounded-lg shadow-lg p-4 ml- w-64">
        <h2 class="text-xl font-semibold mb-2">Last Packet Stats</h2>
        <div><strong>Name:</strong> <%= @selected_device.name %></div>
        <div><strong>Hotspot:</strong> <%= @selected_device[:hotspot] || "N/A" %></div>
        <div class="grid grid-cols-2 gap-2 mt-2 text-sm">
          <div>Seq #: <strong><%= @selected_device[:sequence_no] || "N/A" %></strong></div>
          <div>Speed: <strong><%= Float.round(@selected_device[:avg_speed] || 0, 2) %> m/s</strong></div>
          <div>Elevation: <strong><%= Float.round(@selected_device[:elevation] || 0, 1) %> m</strong></div>
          <div>Voltage: <strong><%= Float.round(@selected_device[:voltage] || 0, 2) %> V</strong></div>
          <div>RSSI: <strong><%= round(@selected_device[:rssi] || 0) %> dBm</strong></div>
          <div>SNR: <strong><%= Float.round(@selected_device[:snr] || 0, 1) %> dB</strong></div>
          <%= if Map.has_key?(@selected_device, :updated_at) do %>
            <div class="col-span-2 text-xs text-gray-500 mt-2">
              Last update: <%= Calendar.strftime(@selected_device.updated_at, "%H:%M:%S") %>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>

  <!-- Mobile top navbar with higher z-index -->
  <div class="md:hidden fixed top-0 left-0 right-0 bg-white shadow p-2 flex flex-col space-y-2 z-40">
    <form phx-submit="filter_devices" class="flex justify-between items-center">
      <div class="flex-1 flex mr-2">
        <input
          type="text"
          placeholder="Filter devices..."
          value={@filter_query}
          phx-change="filter_devices"
          phx-debounce="300"
          name="query"
          class="flex-1 p-2 rounded-l border border-gray-300"
        />

      </div>
      <button
        phx-click="show_all"
        class="bg-blue-500 hover:bg-blue-600 text-white px-3 py-2 rounded-md text-sm font-medium transition-colors duration-150 flex-shrink-0"
      >
        See All
      </button>
    </form>

    <!-- Status box for mobile with guaranteed z-index -->
    <%= if @selected_device do %>
      <div class="bg-white rounded-lg shadow-lg p-4 w-full max-w-xs mx-auto">
        <h2 class="text-xl font-semibold mb-2">Last Packet Stats</h2>
        <div><strong>Name:</strong> <%= @selected_device.name %></div>
        <div><strong>Hotspot:</strong> <%= @selected_device[:hotspot] || "N/A" %></div>
        <div class="grid grid-cols-2 gap-2 mt-2 text-sm">
          <div>Seq #: <strong><%= @selected_device[:sequence_no] || "N/A" %></strong></div>
          <div>Speed: <strong><%= Float.round(@selected_device[:avg_speed] || 0, 2) %> m/s</strong></div>
          <div>Elevation: <strong><%= Float.round(@selected_device[:elevation] || 0, 1) %> m</strong></div>
          <div>Voltage: <strong><%= Float.round(@selected_device[:voltage] || 0, 2) %> V</strong></div>
          <div>RSSI: <strong><%= round(@selected_device[:rssi] || 0) %> dBm</strong></div>
          <div>SNR: <strong><%= Float.round(@selected_device[:snr] || 0, 1) %> dB</strong></div>
          <%= if Map.has_key?(@selected_device, :updated_at) do %>
            <div class="col-span-2 text-xs text-gray-500 mt-2">
              Last update: <%= Calendar.strftime(@selected_device.updated_at, "%H:%M:%S") %>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>

  <!-- Mobile bottom bar with higher z-index -->
  <div class="md:hidden fixed bottom-0 left-0 right-0 bg-gray-100 p-2 flex space-x-3 overflow-x-auto shadow-inner z-40">
    <%= for payload <- @filtered_payloads do %>
      <button
        class={"bg-white rounded-lg shadow px-3 py-2 whitespace-nowrap text-sm font-medium text-gray-700 hover:bg-blue-50 active:bg-gray-100 " <> if @selected_device && @selected_device.device_id == payload.device_id, do: "bg-blue-200 border-2 border-blue-500", else: ""}
        phx-click="device_clicked"
        phx-value-id={payload.device_id}
        aria-label={"Select device #{payload.name}"}
      >
        <div class="flex items-center gap-1">
          <div class={"w-2 h-2 rounded-full " <> if @selected_device && @selected_device.device_id == payload.device_id, do: "bg-blue-600", else: "bg-green-500"}></div>
          <%= payload.name %>
        </div>
      </button>
    <% end %>
  </div>

  <!-- Global styles for proper z-index stacking -->
  <style>
    /* Set explicit stacking context */
    #map-container {
      z-index: 10;
      position: absolute;
    }

    /* Add padding on mobile to account for fixed elements */
    @media (max-width: 767px) {
      .relative.flex-1.h-full {
        padding-top: 12rem;
        padding-bottom: 3.5rem;
      }
    }
  </style>
</div>
"""
  end
end
