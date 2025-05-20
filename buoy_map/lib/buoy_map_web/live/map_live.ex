defmodule BuoyMapWeb.MapLive do
  use BuoyMapWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    devices = mock_devices()
    selected = Enum.at(devices, 0)

    socket =
      socket
      |> assign(:devices, devices)
      |> assign(:selected_device, selected)

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_event("select_device", %{"name" => name}, socket) do
    selected = Enum.find(socket.assigns.devices, fn d -> d.name == name end)

    socket = assign(socket, :selected_device, selected)

    if selected.lat && selected.lng do
      push_event(socket, "plot_marker", %{coordinates: [[selected.lat, selected.lng]]})
    else
      socket
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("map_loaded", _params, socket) do
    if selected = socket.assigns.selected_device do
      if selected.lat && selected.lng do
        push_event(socket, "plot_marker", %{coordinates: [[selected.lat, selected.lng]]})
      end
    end

    {:noreply, socket}
  end

  defp mock_devices do
    [
      %{name: "Mapper 1", location: "San Francisco", lat: 37.7749, lng: -122.4194},
      %{name: "Mapper 2", location: "New York", lat: 40.7128, lng: -74.0060},
      %{name: "Mapper 3", location: "London", lat: 51.5074, lng: -0.1278},
      %{name: "Mapper 4", location: "Tokyo", lat: 35.6895, lng: 139.6917},
      %{name: "Mapper 5", location: "Sydney", lat: -33.8688, lng: 151.2093}
    ]
  end
end
