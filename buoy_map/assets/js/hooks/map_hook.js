import maplibregl from "maplibre-gl";

const MapHook = {
  mounted() {
    console.log("MapHook mounted");
    
    // Store device markers in an object for easy reference by device_id
    this.deviceMarkers = {};
    // Store currently highlighted device ID
    this.highlightedDeviceId = null;
    
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

    this.map.on("load", () => {
      console.log("Map loaded, requesting initial devices");
      this.pushEvent("map_loaded", {});
      this.pushEvent("request_initial_devices", {});
    });
    
    this.handleEvent("init_device", (data) => {
      console.log("Initializing devices", data);
      if (!data.payloads || data.payloads.length === 0) return;
      
      this.initializeDeviceMarkers(data.payloads);
      this.fitMapToMarkers();
    });
    
    // Handle device updates
    this.handleEvent("update_device", (data) => {
      console.log("Updating device locations", data);
      if (!data.payloads || data.payloads.length === 0) return;
      
      data.payloads.forEach(device => {
        this.updateMarkerPosition(device);
      });
    });
    
    // Handle filtered devices updates
    this.handleEvent("update_filtered_devices", (data) => {
      console.log("Updating filtered devices", data);
      if (!data.payloads) return;
      Object.values(this.deviceMarkers).forEach(marker => {
        marker.getElement().style.display = 'none';
      });
      data.payloads.forEach(device => {
        const marker = this.deviceMarkers[device.device_id];
        if (marker) {
          marker.getElement().style.display = 'block';
          if (data.highlight_only && data.payloads.length === 1) {
            marker.getElement().classList.add('highlighted-marker');
          } else {
            marker.getElement().classList.remove('highlighted-marker');
          }
        }
      });
      // Fit the map to the visible markers
      if (data.show_all) {
        this.fitMapToMarkers(Object.values(this.deviceMarkers));
      } else if (data.payloads.length > 0) {
        this.fitMapToMarkers(data.payloads);
      }
    });
    
    // Handle new device creation
    this.handleEvent("new_payload", (device) => {
      console.log("New device payload received", device);
      if (!device || !device.device_id) return;
      if (!this.deviceMarkers[device.device_id]) {
        this.addDeviceMarker(device);
      }
    });
    
    // Handle device selection
    this.handleEvent("plot_marker", (payload) => {
      if (!payload || !payload.history || !payload.history.length) return;
      const [lon, lat] = payload.history[0];
      this.map.flyTo({
        center: [lon, lat],
        zoom: 12,
        speed: 1.5
      });
    });
    
    // Handle device highlighting
    this.handleEvent("highlight_device", (data) => {
      const deviceId = data.device_id;      

      if (this.highlightedDeviceId && this.deviceMarkers[this.highlightedDeviceId]) {
        this.deviceMarkers[this.highlightedDeviceId].getElement().classList.remove('highlighted-marker');
      }
      if (deviceId && this.deviceMarkers[deviceId]) {
        this.deviceMarkers[deviceId].getElement().classList.add('highlighted-marker');
        this.highlightedDeviceId = deviceId;
      } else {
        this.highlightedDeviceId = null;
      }
    });
    
    // Handle fitting all markers on the map
    this.handleEvent("fit_all_markers", () => {
      Object.values(this.deviceMarkers).forEach(marker => {
        marker.getElement().style.display = 'block';
      });
    
      this.fitMapToMarkers();
    });
    
    this.movementInterval = setInterval(() => {
      this.updateDevicePositionsWithJitter();
    }, 2000); // Update every 2
  },
  
  // Initialize all device markers
  initializeDeviceMarkers(devices) {
    Object.values(this.deviceMarkers).forEach(marker => marker.remove());
    this.deviceMarkers = {};
    devices.forEach(device => {
      this.addDeviceMarker(device);
    });
  },
  

  getDeviceColor(deviceId) {
  if (!deviceId) return 'hsl(0, 0%, 70%)';
  let hash = 0;
  for (let i = 0; i < deviceId.length; i++) {
    hash = deviceId.charCodeAt(i) + ((hash << 5) - hash);
  }
  const hue = Math.abs(hash) % 360;
  return `hsl(${hue}, 70%, 60%)`;
},
  
  // Add a single device marker
  addDeviceMarker(device) {
    const deviceColor = this.getDeviceColor(device.device_id);
    
    const el = document.createElement('div');
    el.className = 'device-marker';
    el.style.width = '20px';
    el.style.height = '20px';
    el.style.borderRadius = '50%';
    el.style.backgroundColor = deviceColor;
    el.style.border = '2px solid white';
    el.style.cursor = 'pointer';
    el.style.boxShadow = `0 0 0 rgba(${deviceColor}, 0.6)`;
    el.style.animation = 'pulse 1.5s infinite';
    
    const popup = new maplibregl.Popup({ offset: 25, closeButton: false })
      .setHTML(`
        <div class="p-3 max-w-xs">
          <div class="font-bold text-lg mb-2">${device.name || device.device_id}</div>
          <div class="grid grid-cols-2 gap-2 text-sm">
            <div>Speed: <span class="font-medium">${device.avg_speed ? device.avg_speed.toFixed(2) : '0'} m/s</span></div>
            <div>Elevation: <span class="font-medium">${device.elevation ? device.elevation.toFixed(1) : '0'} m</span></div>
            <div>Battery: <span class="font-medium">${device.voltage ? device.voltage.toFixed(2) : '0'} V</span></div>
            <div>RSSI: <span class="font-medium">${device.rssi ? Math.round(device.rssi) : '0'} dBm</span></div>
            <div>SNR: <span class="font-medium">${device.snr ? device.snr.toFixed(1) : '0'} dB</span></div>
            ${device.hotspot ? `<div class="col-span-2">Hotspot: <span class="font-medium">${device.hotspot}</span></div>` : ''}
          </div>
        </div>
      `);
    
    const marker = new maplibregl.Marker(el)
      .setLngLat([device.lon, device.lat])
      .addTo(this.map);
    marker._popup = popup;
    el.addEventListener('mouseenter', () => popup.addTo(this.map));
    el.addEventListener('mouseleave', () => popup.remove());
    el.addEventListener('click', () => {
      this.pushEvent("device_clicked", { id: device.device_id });
    });
    this.deviceMarkers[device.device_id] = marker;
    marker._basePosition = {
      lng: device.lon,
      lat: device.lat
    };
    return marker;
  },
  
  // Update all device positions with small random movements
  updateDevicePositionsWithJitter() {
    Object.values(this.deviceMarkers).forEach(marker => {
      if (marker._basePosition) {
        const jitterAmount = 0.001;
        const newPos = [
          marker._basePosition.lng + (Math.random() * 2 - 1) * jitterAmount,
          marker._basePosition.lat + (Math.random() * 2 - 1) * jitterAmount
        ];
        
        // Update marker position immediately - no animation
        marker.setLngLat(newPos);
      }
    });
  },
  
  // Simply update marker position - no animation or trails
  updateMarkerPosition(device) {
    const marker = this.deviceMarkers[device.device_id];
    if (!marker) return;
    
    // Update the base position
    marker._basePosition = {
      lng: device.lon,
      lat: device.lat
    };
    
    // Update marker position immediately - no animation
    marker.setLngLat([device.lon, device.lat]);
    if (marker._popup) {
      marker._popup.setHTML(`
        <div class="p-3 max-w-xs">
          <div class="font-bold text-lg mb-2">${device.name || device.device_id}</div>
          <div class="grid grid-cols-2 gap-2 text-sm">
            <div>Speed: <span class="font-medium">${device.avg_speed ? device.avg_speed.toFixed(2) : '0'} m/s</span></div>
            <div>Elevation: <span class="font-medium">${device.elevation ? device.elevation.toFixed(1) : '0'} m</span></div>
            <div>Battery: <span class="font-medium">${device.voltage ? device.voltage.toFixed(2) : '0'} V</span></div>
            <div>RSSI: <span class="font-medium">${device.rssi ? Math.round(device.rssi) : '0'} dBm</span></div>
            <div>SNR: <span class="font-medium">${device.snr ? device.snr.toFixed(1) : '0'} dB</span></div>
            ${device.hotspot ? `<div class="col-span-2">Hotspot: <span class="font-medium">${device.hotspot}</span></div>` : ''}
          </div>
        </div>
      `);
    }
  },
  
  // Fit map to show all visible markers
  fitMapToMarkers(devices = null) {
    let visibleMarkers = [];
    if (devices) {
      if (devices.length > 0 && devices[0] instanceof maplibregl.Marker) {
        visibleMarkers = devices.filter(marker => 
          marker && marker.getElement().style.display !== 'none'
        );
      } else {
        visibleMarkers = devices
          .map(device => this.deviceMarkers[device.device_id])
          .filter(marker => marker && marker.getElement().style.display !== 'none');
      }
    } else {
      visibleMarkers = Object.values(this.deviceMarkers)
        .filter(marker => marker.getElement().style.display !== 'none');
    }
    
    if (visibleMarkers.length === 0) return;
    const bounds = new maplibregl.LngLatBounds();
    visibleMarkers.forEach(marker => {
      bounds.extend(marker.getLngLat());
    });
    this.map.fitBounds(bounds, {
      padding: 50,
      maxZoom: 12
    });
  },
  
  destroyed() {
    if (this.movementInterval) {
      clearInterval(this.movementInterval);
    }
    if (this.map) {
      this.map.remove();
    }
    this.deviceMarkers = {};
  }
};

document.head.insertAdjacentHTML('beforeend', `
  <style>
    @keyframes pulse {
      0% {
        box-shadow: 0 0 0 0 rgba(59, 130, 246, 0.6);
      }
      70% {
        box-shadow: 0 0 0 10px rgba(59, 130, 246, 0);
      }
      100% {
        box-shadow: 0 0 0 0 rgba(59, 130, 246, 0);
      }
    }
    
  .highlighted-marker {
    width: 25px !important;
    height: 30px !important;
    z-index: 100 !important;
    animation: pulse 1s infinite !important;
    border-radius: 50% !important;
  }
  
  .maplibregl-popup-content {
    border-radius: 8px !important;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15) !important;
    padding: 0 !important;
    overflow: hidden !important;
  }
  
  .maplibregl-popup {
    z-index: 200 !important;
  }
  </style>
`);

export default MapHook;