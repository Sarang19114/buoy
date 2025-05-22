import maplibregl from "maplibre-gl";

const MapHook = {
  mounted() {
    console.log("MapHook mounted");
    
    
    this.deviceMarkers = {};
    
    this.highlightedDeviceId = null;
    
    this.trailLayers = {};
    
    
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
    this.handleEvent("update_device_locations", (data) => {
      console.log("Updating device locations", data);
      if (!data.payloads || data.payloads.length === 0) return;
      
      data.payloads.forEach(device => {
        this.updateMarkerPosition(device);
      });
    });
    
    // Handle new device creation
    this.handleEvent("new_payload", (device) => {
      console.log("New device payload received", device);
      if (!device || !device.device_id) return;
      if (!this.deviceMarkers[device.device_id]) {
        this.addDeviceMarker(device);
      }
    });
    
    // Handle device selection with trail
    this.handleEvent("plot_marker", (payload) => {
      if (!payload || !payload.device || !payload.trail) return;
      
      const device = payload.device;
      const trail = payload.trail;
      
      // Clear existing trail
      this.clearTrail();
      
      // Draw trail for selected device
      this.drawTrail(device.device_id, trail);
      
      // Focus on the device
      const mapContainer = this.el.querySelector("#map");
      const { offsetWidth, offsetHeight } = mapContainer;
      const offset = [0.10 * -offsetWidth, -offsetHeight * 0.10];
      
      this.map.flyTo({
        center: [device.lon, device.lat],
        zoom: 12,
        speed: 1.5,
        offset: offset,
      });
    });
    
    
    this.handleEvent("update_trail", (data) => {
      if (!data || !data.device_id || !data.trail) return;
      
      
      if (this.highlightedDeviceId === data.device_id) {
        this.updateTrail(data.device_id, data.trail);
      }
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
    
    // Handle clearing trail
    this.handleEvent("clear_trail", () => {
      this.clearTrail();
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
    }, 2000); // Update every 2 seconds
  },
  
  // Initialize all device markers
  initializeDeviceMarkers(devices) {
    Object.values(this.deviceMarkers).forEach(marker => marker.remove());
    this.deviceMarkers = {};
    devices.forEach(device => {
      this.addDeviceMarker(device);
    });
  },
  
  // Add a single device marker
  addDeviceMarker(device) {
    const deviceColor = '#3b82f6';
    
    const el = document.createElement('div');
    el.className = 'device-marker';
    el.style.width = '20px';
    el.style.height = '20px';
    el.style.borderRadius = '50%';
    el.style.backgroundColor = deviceColor;
    el.style.border = '2px solid white';
    el.style.cursor = 'pointer';
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
  
  
  drawTrail(deviceId, trail) {
    if (!trail || trail.length < 2) return;
    
    const sourceId = `trail-${deviceId}`;
    const layerId = `trail-layer-${deviceId}`;
    
    
    const trailGeoJSON = {
      type: 'Feature',
      properties: {},
      geometry: {
        type: 'LineString',
        coordinates: trail
      }
    };
    
    // Add source
    if (this.map.getSource(sourceId)) {
      this.map.getSource(sourceId).setData(trailGeoJSON);
    } else {
      this.map.addSource(sourceId, {
        type: 'geojson',
        data: trailGeoJSON
      });
    }
    
    // Add layer if it doesn't exist
    if (!this.map.getLayer(layerId)) {
      this.map.addLayer({
        id: layerId,
        type: 'line',
        source: sourceId,
        layout: {
          'line-join': 'round',
          'line-cap': 'round'
        },
        paint: {
          'line-color': '#ff6b6b',
          'line-width': 3,
          'line-opacity': 0.8
        }
      });
    }
    
    
    this.trailLayers[deviceId] = { sourceId, layerId };
    
    // Add trail point markers
    this.addTrailPointMarkers(deviceId, trail);
  },
  
  
  updateTrail(deviceId, trail) {
    if (!trail || trail.length < 2) return;
    
    const sourceId = `trail-${deviceId}`;
    
    if (this.map.getSource(sourceId)) {
      const trailGeoJSON = {
        type: 'Feature',
        properties: {},
        geometry: {
          type: 'LineString',
          coordinates: trail
        }
      };
      
      this.map.getSource(sourceId).setData(trailGeoJSON);
      this.updateTrailPointMarkers(deviceId, trail);
    } else {
      // If source doesn't exist, create the trail
      this.drawTrail(deviceId, trail);
    }
  },
  
  
  addTrailPointMarkers(deviceId, trail) {
    
    this.removeTrailPointMarkers(deviceId);
    
    const trailMarkers = [];
    
    trail.forEach((point, index) => {
      if (index === 0) return; 
      
      const el = document.createElement('div');
      el.className = 'trail-point-marker';
      el.style.width = '8px';
      el.style.height = '8px';
      el.style.borderRadius = '50%';
      el.style.backgroundColor = '#ff6b6b';
      el.style.border = '1px solid white';
      el.style.opacity = Math.max(0.3, 1 - (index * 0.02)); 
      
      const marker = new maplibregl.Marker(el)
        .setLngLat(point)
        .addTo(this.map);
      
      trailMarkers.push(marker);
    });
    
    this.trailPointMarkers = this.trailPointMarkers || {};
    this.trailPointMarkers[deviceId] = trailMarkers;
  },
  
  // Update trail point markers
  updateTrailPointMarkers(deviceId, trail) {
    this.addTrailPointMarkers(deviceId, trail);
  },
  
  // Remove trail point markers for a device
  removeTrailPointMarkers(deviceId) {
    if (this.trailPointMarkers && this.trailPointMarkers[deviceId]) {
      this.trailPointMarkers[deviceId].forEach(marker => marker.remove());
      delete this.trailPointMarkers[deviceId];
    }
  },
  
  // Clear all trails
  clearTrail() {
    Object.keys(this.trailLayers).forEach(deviceId => {
      const { sourceId, layerId } = this.trailLayers[deviceId];
      
      if (this.map.getLayer(layerId)) {
        this.map.removeLayer(layerId);
      }
      if (this.map.getSource(sourceId)) {
        this.map.removeSource(sourceId);
      }
      
      this.removeTrailPointMarkers(deviceId);
    });
    
    this.trailLayers = {};
  },
  
  // Update all device positions with random movements
  updateDevicePositionsWithJitter() {
    Object.values(this.deviceMarkers).forEach(marker => {
      if (marker._basePosition) {
        const jitterAmount = 0.001;
        const newPos = [
          marker._basePosition.lng + (Math.random() * 2 - 1) * jitterAmount,
          marker._basePosition.lat + (Math.random() * 2 - 1) * jitterAmount
        ];
        
        marker.setLngLat(newPos);
      }
    });
  },
  
  // Simply update marker position
  updateMarkerPosition(device) {
    const marker = this.deviceMarkers[device.device_id];
    if (!marker) return;
    
    // Update the base position
    marker._basePosition = {
      lng: device.lon,
      lat: device.lat
    };
    
    // Update marker position
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
    const allMarkers = devices
      ? devices.map(device => this.deviceMarkers[device.device_id])
      : Object.values(this.deviceMarkers);

    if (allMarkers.length === 0) return;

    const bounds = new maplibregl.LngLatBounds();
    allMarkers.forEach(marker => bounds.extend(marker.getLngLat()));

    this.map.fitBounds(bounds, {
      padding: 50,
      maxZoom: 12
    });
  },
  
  destroyed() {
    if (this.movementInterval) {
      clearInterval(this.movementInterval);
    }
    
    // Clean up trails
    this.clearTrail();
    
    if (this.map) {
      this.map.remove();
    }
    this.deviceMarkers = {};
    this.trailPointMarkers = {};
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
    height: 25px !important;
    z-index: 100;
    animation: pulse 1s infinite;
    border-radius: 50%;
  }
  
  .trail-point-marker {
    transition: opacity 0.3s ease;
  }
  
  .maplibregl-popup-content {
    border-radius: 8px;
    padding: 0;
    overflow: hidden;
  }
  
  .maplibregl-popup {
    z-index: 200;
  }
  </style>
`);

export default MapHook;
