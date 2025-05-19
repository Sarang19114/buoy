defmodule BuoyMapWeb.MapLive do
  use BuoyMapWeb, :live_view

  def mount(_params, _session, socket) do
  mock_devices = [
    %{name: "Dragino soil moisture ...", location: "Wayzata, MN", gps_fix: true, lat: 44.974, lng: -93.506},
    %{name: "RAK - Device 21 - Paul ...", location: "Richmond, BC", gps_fix: true, lat: 49.166, lng: -123.133},
    %{name: "Fremont 2", location: "Fremont, CA", gps_fix: true, lat: 37.548, lng: -121.988},
    %{name: "disc01", location: "Unknown", gps_fix: false},
    %{name: "Mapper 4", location: "Unknown", gps_fix: false},
    %{name: "Mapper 2", location: "San Diego, CA", gps_fix: true, lat: 32.715, lng: -117.161,
      hotspot: "Flat Vanilla Crab", sequence_no: "4117", avg_speed: "0mph",
      elevation: "0m", voltage: "0.00v", rssi: "-101dBm", snr: "-11.00"},
    %{name: "rocket_launch_RK72", location: "Los Angeles, CA", gps_fix: true, lat: 34.052, lng: -118.244}
  ]

  socket =
    socket
    |> assign(:devices, mock_devices)
    |> assign(:selected_device, "Mapper 2")
    |> push_event("map:update_devices", %{devices: mock_devices})

  {:ok, socket, layout: false}
end


  def handle_event("select_device", %{"name" => name}, socket) do
  selected_device = Enum.find(socket.assigns.devices, fn d -> d.name == name end)

  socket =
    socket
    |> assign(:selected_device, selected_device)

  
  socket =
    if selected_device[:lat] && selected_device[:lng] do
      push_event(socket, "map:fly_to", %{lat: selected_device.lat, lng: selected_device.lng})
    else
      socket
    end

  {:noreply, socket}
end
end
