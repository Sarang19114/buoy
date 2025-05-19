import maplibregl from "maplibre-gl";

let MapHook = {
  mounted() {
    this.map = new maplibregl.Map({
      container: this.el,
      style: "https://demotiles.maplibre.org/style.json",
      center: [-117.1611, 32.7157],
      zoom: 1.2
    });

    this.markers = [];

    this.map.on("load", () => {
      const style = this.map.getStyle();
      const layers = style.layers;

      if (this.map.getLayer("background")) {
        this.map.setPaintProperty("background", "background-color", "#0a0a0a");
      }

      layers.forEach((layer) => {
        if (layer.id.includes("water")) {
          this.map.setPaintProperty(layer.id, "fill-color", "#050505");
        }

        if (layer.type === "fill" && !layer.id.includes("water")) {
          this.map.setPaintProperty(layer.id, "fill-color", "#1a1a1a");
        }

        if (
          layer.type === "line" ||
          layer.id.includes("boundary") ||
          layer.id.includes("admin")
        ) {
          this.map.setPaintProperty(layer.id, "line-color", "#ffffff");
          this.map.setPaintProperty(layer.id, "line-opacity", 0.6);
          this.map.setPaintProperty(layer.id, "line-width", 1);
        }

        if (layer.type === "symbol" && !layer.id.includes("label")) {
          this.map.setLayoutProperty(layer.id, "visibility", "none");
        }
      });

      this.map.once("idle", () => {
        this.map.triggerRepaint();
      });
    });

    this.handleEvent("map:fly_to", ({ lat, lng }) => {
  this.map.flyTo({
    center: [lng, lat],
    zoom: 12,
    essential: true
  });
});


    // Listen for LiveView push event
    this.handleEvent("map:update_devices", ({ devices }) => {
      this.clearMarkers();

      devices.forEach((device) => {
        if (device.lat && device.lng) {
          const el = document.createElement("div");
          el.className = "marker";
          el.style.backgroundColor = "blue";
          el.style.width = "10px";
          el.style.height = "10px";
          el.style.borderRadius = "50%";

          const popup = new maplibregl.Popup({ offset: 25 }).setText(device.name);

          const marker = new maplibregl.Marker(el)
            .setLngLat([device.lng, device.lat])
            .setPopup(popup)
            .addTo(this.map);

          this.markers.push(marker);
        }
      });
    });
  },

  clearMarkers() {
    this.markers.forEach((m) => m.remove());
    this.markers = [];
  }
};

export default MapHook;
