// Use a reliable open source map style and provider
import maplibregl from "maplibre-gl";

const MapHook = {
  mounted() {
    console.log("MapHook mounted");
    
    // Create map with a reliable open source map style
    this.map = new maplibregl.Map({
      container: this.el.querySelector("#map"),
      style: {
        version: 8,
        sources: {
          darkMap: {
            type: "raster",
            tiles: ["https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png"],
            tileSize: 256,
            maxzoom: 19
          }
        },
        layers: [
          {
            id: "background",
            type: "background",
            paint: { "background-color": "#000000" }
          },
          {
            id: "darkMap",
            type: "raster",
            source: "darkMap",
            minzoom: 0,
            maxzoom: 19
          }
        ]
      },
      center: [-122.41919, 37.77115],
      zoom: 2,
      minZoom: 2,
      maxZoom: 19
    });

    // Wait for map to load, then add markers
    this.map.on("load", () => {
      // Get initial data from Phoenix
      this.pushEvent("request_initial_devices", {});
    });
    
    // Setup event handlers
    this.handleEvent("plot_latest_payloads", (data) => {
      if (!data.payloads || data.payloads.length === 0) return;
      
      // Remove any existing markers
      if (this.markers) {
        this.markers.forEach(marker => marker.remove());
      }
      
      // Create new markers
      this.markers = [];
      
      data.payloads.forEach(device => {
        // Create marker element
        const el = document.createElement('div');
        el.className = 'device-marker';
        el.style.width = '20px';
        el.style.height = '20px';
        el.style.borderRadius = '50%';
        el.style.backgroundColor = '#3b82f6';
        el.style.border = '2px solid white';
        el.style.cursor = 'pointer';
        
        // Add marker to map
        const marker = new maplibregl.Marker(el)
          .setLngLat([device.lon, device.lat])
          .addTo(this.map);
          
        // Add click handler
        el.addEventListener('click', () => {
          this.pushEvent("device_clicked", { id: device.device_id });
        });
        
        this.markers.push(marker);
      });
      
      // Fit map to show all markers
    });
    
    this.handleEvent("plot_marker", (payload) => {
      if (!payload || !payload.history || !payload.history.length) return;
      
      const [lon, lat] = payload.history[0];
      
      // Center map on selected marker
      this.map.flyTo({
        center: [lon, lat],
        zoom: 12,
        speed: 1.5
      });
    });
  },
  
  destroyed() {
    if (this.map) {
      this.map.remove();
    }
    if (this.markers) {
      this.markers.forEach(marker => marker.remove());
    }
  }
};

export default MapHook;