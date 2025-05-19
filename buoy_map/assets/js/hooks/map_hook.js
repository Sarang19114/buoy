import maplibregl from "maplibre-gl";

let MapHook = {
  mounted() {
    const map = new maplibregl.Map({
      container: this.el,
      style: "https://demotiles.maplibre.org/style.json",
      center: [-117.1611, 32.7157],
      zoom: 1.2
    });

    map.on('load', () => {
      const style = map.getStyle();
      const layers = style.layers;

      if (map.getLayer('background')) {
        map.setPaintProperty('background', 'background-color', '#0a0a0a'); // very dark zinc black
      }

      layers.forEach(layer => {
        if (layer.id.includes('water')) {
          map.setPaintProperty(layer.id, 'fill-color', '#050505'); // darker than terrain
        }

        if (layer.type === 'fill' && !layer.id.includes('water')) {
          map.setPaintProperty(layer.id, 'fill-color', '#1a1a1a'); // zinc-like gray-black for countries
        }


        // Boundaries (white lines)
        if (layer.type === 'line' || layer.id.includes('boundary') || layer.id.includes('admin')) {
          map.setPaintProperty(layer.id, 'line-color', '#ffffff');
          map.setPaintProperty(layer.id, 'line-opacity', 0.6);
          map.setPaintProperty(layer.id, 'line-width', 1);
        }

        // Hide symbols unless they're labels
        if (layer.type === 'symbol' && !layer.id.includes('label')) {
          map.setLayoutProperty(layer.id, 'visibility', 'none');
        }
      });

      map.once('idle', () => {
        map.triggerRepaint();
      });
    });

    const markers = [
      { lng: -117.1611, lat: 32.7157, name: "Mapper 2" },
      { lng: -117.173, lat: 32.719, name: "Mapper 4" },
      { lng: -121.9886, lat: 37.5483, name: "Fremont 2" },
      { lng: -123.1336, lat: 49.1666, name: "RAK - Device 21" },
      { lng: -118.2437, lat: 34.0522, name: "rocket_launch_RK72" }
    ];

    markers.forEach((m) => {
      const el = document.createElement("div");
      el.className = "marker";
      el.style.backgroundColor = "blue";
      el.style.width = "10px";
      el.style.height = "10px";
      el.style.borderRadius = "50%";

      const popup = new maplibregl.Popup({ offset: 25 }).setText(m.name);

      new maplibregl.Marker(el)
        .setLngLat([m.lng, m.lat])
        .setPopup(popup)
        .addTo(map);
    });
  }
};

export default MapHook;
