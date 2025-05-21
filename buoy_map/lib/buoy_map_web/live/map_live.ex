defmodule BuoyMapWeb.MapLive do
  use BuoyMapWeb, :live_view

  alias BuoyMapWeb.Components.DeviceInfo

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BuoyMap.PubSub, "payload_created")
    end

    payloads = latest_payload_records()

    socket =
      assign(socket,
        payloads: payloads,
        filtered_payloads: payloads,
        filter_query: "",
        selected_device: nil,
        packets: generate_dummy_data(),
        last_packet: dummy_last_packet(),
        map_center: [-122.41919, 37.77115],
        show_mappers: false,
        transmitting_devices: %{}
      )

    {:ok, socket, layout: false}
  end

  def handle_event("filter_devices", %{"query" => query}, socket) do
    filtered =
      if query == "" do
        socket.assigns.payloads
      else
        socket.assigns.payloads
        |> Enum.filter(fn p ->
          String.contains?(String.downcase(p.name), String.downcase(query))
        end)
      end

    # Update the map to show only filtered devices
    socket =
      socket
      |> assign(filter_query: query, filtered_payloads: filtered)
      |> push_event("update_filtered_devices", %{payloads: filtered})

    {:noreply, socket}
  end

  def handle_event("device_clicked", %{"id" => device_id}, socket) do
    device = Enum.find(socket.assigns.filtered_payloads, fn d -> d.device_id == device_id end)

    socket =
      if device do
        latest_location = [[device.lon, device.lat]]

        socket
        |> push_event("plot_marker", %{history: latest_location})
        |> assign(:selected_device, device)
      else
        IO.inspect("Error: device not found for device_id: #{device_id}")
        socket
      end

    {:noreply, socket}
  end

  # Map initialization handler
  def handle_event("map_loaded", _params, socket) do
    # Send initial device data to the map
    {:noreply, push_event(socket, "init_device_locations", %{payloads: socket.assigns.filtered_payloads})}
  end

  # Handler for requesting initial devices
  def handle_event("request_initial_devices", _params, socket) do
    # Send all known device payloads to the map
    {:noreply, push_event(socket, "plot_latest_payloads", %{payloads: socket.assigns.filtered_payloads})}
  end

  def handle_info(:update_data, socket) do
    {:noreply, assign(socket, packets: generate_dummy_data())}
  end

  def handle_info(%{topic: "payload_created", payload: payload}, socket) do
    payload_data =
      case payload do
        %{payload: %{data: data}} when is_map(data) -> data
        _ -> %{}
      end

    {:noreply, push_event(socket, "new_payload", payload_data)}
  end

  defp latest_payload_records do
    [
      %{device_id: "1", name: "Buoy Alpha - USA (San Francisco)", lon: -122.4194, lat: 37.7749},
      %{device_id: "2", name: "Buoy Beta - Germany (Berlin)", lon: 13.4050, lat: 52.5200},
      %{device_id: "3", name: "Buoy Gamma - Japan (Tokyo)", lon: 139.6917, lat: 35.6895},
      %{device_id: "4", name: "Buoy Delta - Australia (Sydney)", lon: 151.2093, lat: -33.8688},
      %{device_id: "5", name: "Buoy Epsilon - Brazil (Rio)", lon: -43.1729, lat: -22.9068}
    ]
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

  defp dummy_last_packet do
    %{
      sequence_number: 5462,
      avg_speed: 5.4,
      elevation: 42.0,
      battery: 4.8,
      rssi: -85,
      snr: 7.3
    }
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col md:flex-row w-screen h-screen">
      <!-- Sidebar for desktop -->
      <div class="hidden md:flex md:flex-col md:w-1/4 bg-gray-100 rounded-lg shadow-lg p-4 overflow-y-auto">
        <h2 class="text-2xl font-bold mb-4 text-gray-800">Devices</h2>

        <input
          type="text"
          placeholder="Filter devices..."
          value={@filter_query}
          phx-debounce="300"
          phx-change="filter_devices"
          name="query"
          class="w-full p-2 mb-4 rounded border border-gray-300"
        />

        <ul class="space-y-3">
          <%= for payload <- @filtered_payloads do %>
            <li
              class={"bg-white rounded-lg shadow p-4 flex items-center justify-between cursor-pointer transition duration-150 ease-in-out hover:bg-blue-50 hover:shadow-md active:bg-gray-100 active:shadow-inner " <> if @selected_device && @selected_device.device_id == payload.device_id, do: "bg-blue-100", else: ""}
              phx-click="device_clicked"
              phx-value-id={payload.device_id}
            >
              <div class="flex items-center space-x-3">
                <div class="w-3 h-3 rounded-full bg-green-500"></div>
                <span class="font-medium text-gray-800"><%= payload.name %></span>
              </div>
            </li>
          <% end %>
        </ul>
      </div>

      <!-- Main map area -->
      <div class="relative flex-1" id="map-container" phx-update="ignore" phx-hook="MapHook">
        <div id="map" class="h-full w-full"></div>

        <%= if @selected_device do %>
          <div class="md:block absolute z-50 top-4 right-4 bg-white rounded-lg shadow-lg p-4 w-64">
            <h2 class="text-xl font-semibold mb-2">Last Packet Stats</h2>
            <div><strong>Name:</strong> <%= @selected_device.name %></div>
            <div><strong>Hotspot:</strong> <%= @selected_device[:hotspot] || "N/A" %></div>
            <div class="grid grid-cols-2 gap-2 mt-2 text-sm">
              <div>Seq #: <strong><%= @selected_device[:sequence_no] || "N/A" %></strong></div>
              <div>Speed: <strong><%= @selected_device[:avg_speed] || "N/A" %></strong></div>
              <div>Elevation: <strong><%= @selected_device[:elevation] || "N/A" %></strong></div>
              <div>Voltage: <strong><%= @selected_device[:voltage] || "N/A" %></strong></div>
              <div>RSSI: <strong><%= @selected_device[:rssi] || "N/A" %></strong></div>
              <div>SNR: <strong><%= @selected_device[:snr] || "N/A" %></strong></div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Mobile top navbar -->
      <div class="md:hidden fixed top-0 left-0 right-0 bg-white shadow p-2 flex flex-col space-y-2 z-30">
        <input
          type="text"
          placeholder="Filter devices..."
          value={@filter_query}
          phx-debounce="300"
          phx-change="filter_devices"
          name="query"
          class="flex-1 p-2 rounded border border-gray-300"
        />

        <%= if @selected_device do %>
          <div class="block md:hidden bg-white rounded-lg shadow-lg p-4 w-full max-w-xs mx-auto">
            <h2 class="text-xl font-semibold mb-2">Last Packet Stats</h2>
            <div><strong>Name:</strong> <%= @selected_device.name %></div>
            <div><strong>Hotspot:</strong> <%= @selected_device[:hotspot] || "N/A" %></div>
            <div class="grid grid-cols-2 gap-2 mt-2 text-sm">
              <div>Seq #: <strong><%= @selected_device[:sequence_no] || "N/A" %></strong></div>
              <div>Speed: <strong><%= @selected_device[:avg_speed] || "N/A" %></strong></div>
              <div>Elevation: <strong><%= @selected_device[:elevation] || "N/A" %></strong></div>
              <div>Voltage: <strong><%= @selected_device[:voltage] || "N/A" %></strong></div>
              <div>RSSI: <strong><%= @selected_device[:rssi] || "N/A" %></strong></div>
              <div>SNR: <strong><%= @selected_device[:snr] || "N/A" %></strong></div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Mobile bottom bar -->
      <div class="md:hidden fixed bottom-0 left-0 right-0 bg-gray-100 p-2 flex space-x-3 overflow-x-auto shadow-inner z-30">
        <%= for payload <- @filtered_payloads do %>
          <button
            class={"bg-white rounded-lg shadow px-3 py-2 whitespace-nowrap text-sm font-medium text-gray-700 hover:bg-blue-50 active:bg-gray-100 " <> if @selected_device && @selected_device.device_id == payload.device_id, do: "bg-blue-100", else: ""}
            phx-click="device_clicked"
            phx-value-id={payload.device_id}
            aria-label={"Select device #{payload.name}"}
          >
            <div class="flex items-center gap-1">
              <div class="w-2 h-2 rounded-full bg-green-500"></div>
              <%= payload.name %>
            </div>
          </button>
        <% end %>
      </div>

      <!-- Spacer for fixed bars -->
      <style>
        @media (max-width: 767px) {
          #map-container {
            padding-top: 12rem;
            padding-bottom: 3.5rem;
          }
        }
      </style>
    </div>
    """
  end
end
