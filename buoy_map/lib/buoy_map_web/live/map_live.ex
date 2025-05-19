defmodule BuoyMapWeb.MapLive do
  use BuoyMapWeb, :live_view

  def mount(_params, _session, socket) do
    mock_devices = [
      %{name: "Dragino soil moisture ...", location: "Wayzata, MN", status: nil, gps_fix: false},
      %{name: "RAK - Device 21 - Paul ...", location: "Richmond, BC", status: nil, gps_fix: false},
      %{name: "Fremont 2", location: "Fremont, CA", status: nil, gps_fix: false},
      %{name: "disc01", location: "Unknown", status: nil, gps_fix: false},
      %{name: "Mapper 4", location: "Unknown", status: "now", gps_fix: false},
      %{name: "Mapper 2", location: "San Diego, CA", status: "now", gps_fix: false,
        hotspot: "Flat Vanilla Crab", sequence_no: "4117", avg_speed: "0mph",
        elevation: "0m", voltage: "0.00v", rssi: "-101dBm", snr: "-11.00"},
      %{name: "rocket_launch_RK72", location: "Los Angeles, CA", status: nil, gps_fix: false}
    ]

    socket =
      socket
      |> assign(:devices, mock_devices)
      |> assign(:selected_device, "Mapper 2")

    {:ok, socket, layout: false}
  end

  def handle_event("select_device", %{"name" => name}, socket) do
    # Find the selected device
    selected_device = Enum.find(socket.assigns.devices, fn d -> d.name == name end)
    {:noreply, assign(socket, :selected_device, selected_device)}
  end
end
