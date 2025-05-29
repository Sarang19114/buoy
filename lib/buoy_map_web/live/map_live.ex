defmodule BuoyMapWeb.MapLive do
  use BuoyMapWeb, :live_view
  require Logger

  alias BuoyMap.{DeviceStore, StatsStore}

  @update_interval 2000
  @new_device_interval 15000
  @max_mock_devices 20
  @max_trail_points 50  # Maximum number of trail points to keep per device

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BuoyMap.PubSub, "payload_created")
      Phoenix.PubSub.subscribe(BuoyMap.PubSub, "device_movements")
      Phoenix.PubSub.subscribe(BuoyMap.PubSub, "device_stats")
      :timer.send_interval(@update_interval, :update_device_data)
      :timer.send_interval(@new_device_interval, :create_new_device)
    end

    # Initial mock devices
    initial_payloads = initial_mock_devices()
    DeviceStore.set_devices(initial_payloads)

    socket =
      assign(socket,
        payloads: initial_payloads,
        filtered_payloads: initial_payloads,
        filter_query: "",
        selected_device: nil,
        packets: generate_dummy_data(),
        transmitting_devices: %{},
        next_device_id: length(initial_payloads) + 1,
        device_trails: initialize_device_trails(initial_payloads),
        expanded_devices: %{}
      )

    {:ok, socket, layout: false}
  end

  # ... existing event handlers ...

  def handle_info(:update_device_data, socket) do
    updated_payloads =
      socket.assigns.payloads
      |> Enum.map(fn device ->
        {new_lon, new_lat} = significant_movement(device.lon, device.lat)
        updated_device =
          device
          |> Map.put(:lon, new_lon)
          |> Map.put(:lat, new_lat)
          |> Map.put(:sequence_no, get_random_sequence_no())
          |> Map.put(:updated_at, DateTime.utc_now())

        DeviceStore.update_device(updated_device)
        updated_device
      end)

    updated_trails = update_device_trails(socket.assigns.device_trails, updated_payloads)
    Enum.each(updated_payloads, fn device ->
      DeviceStore.update_trail(device.device_id, Map.get(updated_trails, device.device_id, []))
    end)

    socket =
      socket
      |> assign(:payloads, updated_payloads)
      |> assign(:device_trails, updated_trails)
      |> assign(:filtered_payloads, filter_payloads(updated_payloads, socket.assigns.filter_query))
      |> push_event("update_device_locations", %{payloads: filter_payloads(updated_payloads, socket.assigns.filter_query)})

    socket =
      if socket.assigns.selected_device do
        updated_device = Enum.find(updated_payloads, fn d ->
          d.device_id == socket.assigns.selected_device.device_id
        end)
        if updated_device do
          trail = Map.get(updated_trails, updated_device.device_id, [])
          socket
          |> assign(:selected_device, updated_device)
          |> push_event("update_trail", %{
            device_id: updated_device.device_id,
            trail: trail
          })
        else
          socket
        end
      else
        socket
      end

    {:noreply, socket}
  end

  # Handle stats updates from StatsStore
  def handle_info({:device_stats_updated, device_id, stats}, socket) do
    socket =
      if socket.assigns.selected_device && socket.assigns.selected_device.device_id == device_id do
        updated_device = Map.merge(socket.assigns.selected_device, stats)
        assign(socket, :selected_device, updated_device)
      else
        socket
      end

    updated_payloads = Enum.map(socket.assigns.payloads, fn device ->
      if device.device_id == device_id do
        Map.merge(device, stats)
      else
        device
      end
    end)

    socket =
      socket
      |> assign(:payloads, updated_payloads)
      |> assign(:filtered_payloads, filter_payloads(updated_payloads, socket.assigns.filter_query))

    {:noreply, socket}
  end

  # ... rest of existing code ...

  # Update initial_mock_devices to not include stats (they'll come from StatsStore)
  defp initial_mock_devices do
    [
      %{
        device_id: "1",
        name: "Buoy Alpha - USA (San Francisco)",
        lon: -122.4194,
        lat: 37.7749,
        sequence_no: get_random_sequence_no(),
        updated_at: DateTime.utc_now(),
        hotspot: generate_random_hotspot_name()
      },
      %{
        device_id: "2",
        name: "Buoy Beta - Germany (Berlin)",
        lon: 13.4050,
        lat: 52.5200,
        sequence_no: get_random_sequence_no(),
        updated_at: DateTime.utc_now(),
        hotspot: generate_random_hotspot_name()
      },
      %{
        device_id: "3",
        name: "Buoy Gamma - Japan (Tokyo)",
        lon: 139.6917,
        lat: 35.6895,
        sequence_no: get_random_sequence_no(),
        updated_at: DateTime.utc_now(),
        hotspot: generate_random_hotspot_name()
      },
      %{
        device_id: "4",
        name: "Buoy Delta - Australia (Sydney)",
        lon: 151.2093,
        lat: -33.8688,
        sequence_no: get_random_sequence_no(),
        updated_at: DateTime.utc_now(),
        hotspot: generate_random_hotspot_name()
      },
      %{
        device_id: "5",
        name: "Buoy Epsilon - Brazil (Rio)",
        lon: -43.1729,
        lat: -22.9068,
        sequence_no: get_random_sequence_no(),
        updated_at: DateTime.utc_now(),
        hotspot: generate_random_hotspot_name()
      }
    ]
  end

  # Update create_random_mock_device to not include stats
  defp create_random_mock_device(id) do
    locations = [
      # ... existing locations ...
    ]

    {lon, lat, location} = Enum.random(locations)

    lon = lon + (:rand.uniform() - 0.5) * 0.2
    lat = lat + (:rand.uniform() - 0.5) * 0.2

    greek_letters = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta",
                     "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi", "Omicron", "Pi",
                     "Rho", "Sigma", "Tau", "Upsilon", "Phi", "Chi", "Psi", "Omega"]

    buoy_name = "Buoy #{Enum.random(greek_letters)} - #{location}"

    # Create the device map without stats
    %{
      device_id: "#{id}",
      name: buoy_name,
      lon: lon,
      lat: lat,
      sequence_no: get_random_sequence_no(),
      updated_at: DateTime.utc_now(),
      hotspot: generate_random_hotspot_name()
    }
  end

  # ... rest of existing code ...
end
