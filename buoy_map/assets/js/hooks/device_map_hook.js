import maplibregl from "maplibre-gl";

const DeviceMapHook = {
  mounted() {
    console.log("DeviceMapHook mounted");
    
    try {
      // Initialize map
      this.initMap();
      
      // Event listeners for device data
      this.handleEvent("init_device_detail", (data) => {
        console.log("Received init_device_detail event", data);
        if (data && data.device) {
          this.initializeDevice(data.device, data.trail);
        }
      });
      
      this.handleEvent("update_device_detail", (data) => {
        if (data && data.device) {
          this.updateDevice(data.device, data.trail);
        }
      });
      
      // Handle refresh components event
      this.handleEvent("refresh_components", () => {
        console.log("Refreshing components");
        if (!this.mapLoaded && this.map) {
          this.pushEvent("map_loaded", {});
        }
      });
      
      // Add jitter movement similar to home page
      this.movementInterval = setInterval(() => {
        if (this.deviceMarker && this._basePosition) {
          this.updateDevicePositionWithJitter();
        }
      }, 2000); // Update every 2 seconds

      // Handle external device updates (from other browsers/connections)
      this.handleEvent("external_device_update", (data) => {
        console.log("Received external device update", data);
        if (data && data.device && data.device.device_id === this.el.dataset.deviceId) {
          this.updateDevice(data.device, data.trail);
        }
      });
    } catch (error) {
      console.error("Error in DeviceMapHook initialization:", error);
      // Notify the server of the error
      this.pushEvent("hook_error", { error: error.toString() });
    }
  },
  
  // Initialize map
  initMap() {
    console.log("Initializing map...");
    try {
      // Ensure the map container exists
      const mapContainer = this.el.querySelector("#device-map");
      if (!mapContainer) {
        throw new Error("Map container not found!");
      }
      
      console.log("Map container found, initializing map");
      
      // Create map with a reliable open source map style - matching main map style
      this.map = new maplibregl.Map({
        container: mapContainer,
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
        center: [0, 0],
        minZoom: 2,
        maxZoom: 19
      });
      
      this.map.on("load", () => {
        console.log("Device map loaded");
        this.mapLoaded = true;
        this.pushEvent("map_loaded", {});
        this.pushEvent("map_loaded_success", {});
      });
      
      this.map.on("error", (e) => {
        console.error("Map error:", e);
        this.pushEvent("hook_error", { error: `Map error: ${e.toString()}` });
      });
    } catch (error) {
      console.error("Error initializing map:", error);
      this.pushEvent("hook_error", { error: `Map initialization error: ${error.toString()}` });
    }
  },
  
  // Initialize device marker and trail
  initializeDevice(device, trail) {
    console.log("Initializing device", device);
    try {
      if (!this.map) {
        console.error("Map not initialized!");
        return;
      }
      
      if (!this.map.loaded()) {
        console.log("Map not yet loaded, waiting...");
        this.map.once('load', () => {
          this._initializeDevice(device, trail);
        });
      } else {
        this._initializeDevice(device, trail);
      }
    } catch (error) {
      console.error("Error initializing device:", error);
    }
  },
  
  // Private method to initialize device after map is loaded
  _initializeDevice(device, trail) {
    try {
      // Store base position for jitter movement
      this._basePosition = {
        lng: device.lon,
        lat: device.lat
      };
      
      // Remove existing marker if it exists
      if (this.deviceMarker) {
        this.deviceMarker.remove();
      }
      
      // Create marker element with matching style from main map
      const el = document.createElement('div');
      el.className = 'device-marker highlighted-marker';
      
      // Create popup with device info
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
      
      // Create marker
      this.deviceMarker = new maplibregl.Marker(el)
        .setLngLat([device.lon, device.lat])
        .addTo(this.map);
      
      // Add popup behavior
      this.deviceMarker._popup = popup;
      el.addEventListener('mouseenter', () => popup.addTo(this.map));
      el.addEventListener('mouseleave', () => popup.remove());
      
      // Center map on device with offset for stats panel
      const mapContainer = this.el.querySelector("#device-map");
      const { offsetWidth, offsetHeight } = mapContainer;
      const offset = [0.10 * -offsetWidth, -offsetHeight * 0.10];
      
      this.map.flyTo({
        center: [device.lon, device.lat],
        zoom: 12,
        speed: 1.5,
        offset: offset
      });
      
      // Draw trail
      if (trail && trail.length > 0) {
        console.log("Drawing trail with", trail.length, "points");
        this.drawTrail(trail);
      } else {
        console.warn("No trail data provided");
      }
    } catch (error) {
      console.error("Error in _initializeDevice:", error);
    }
  },
  
  // Update device position with random jitter
  updateDevicePositionWithJitter() {
    try {
      if (this.deviceMarker && this._basePosition) {
        const jitterAmount = 0.002 + Math.random() * 0.008; // Match the significant_movement from map_live.ex
        const angle = Math.random() * 2 * Math.PI;
        const newPos = [
          this._basePosition.lng + jitterAmount * Math.cos(angle),
          this._basePosition.lat + jitterAmount * Math.sin(angle)
        ];
        
        // Update base position to prevent returning to origin
        this._basePosition = {
          lng: newPos[0],
          lat: newPos[1]
        };
        
        this.deviceMarker.setLngLat(newPos);
        
        // Update popup if it's showing
        if (this.deviceMarker._popup.isOpen()) {
          this.deviceMarker._popup.setLngLat(newPos);
        }
        
        // Broadcast this movement to other tabs/browsers
        const deviceId = this.el.dataset.deviceId;
        if (deviceId) {
          this.pushEvent("device_moved", {
            device_id: deviceId,
            lon: newPos[0],
            lat: newPos[1]
          });
        }
      }
    } catch (error) {
      console.error("Error updating device position with jitter:", error);
    }
  },
  
  // Draw trail
  drawTrail(trail) {
    try {
      if (!this.map || !this.map.loaded()) {
        console.error("Map not loaded, can't draw trail");
        return;
      }
      
      if (!trail || trail.length < 2) {
        console.warn("Not enough trail points to draw line", trail);
        return;
      }
      
      // Create GeoJSON for the trail
      const trailGeoJSON = {
        type: 'Feature',
        properties: {},
        geometry: {
          type: 'LineString',
          coordinates: trail
        }
      };
      
      // Add source if it doesn't exist
      if (this.map.getSource('trail')) {
        this.map.getSource('trail').setData(trailGeoJSON);
      } else {
        this.map.addSource('trail', {
          type: 'geojson',
          data: trailGeoJSON
        });
        
        // Add trail glow layer first (for a halo effect)
        this.map.addLayer({
          id: 'trail-glow',
          type: 'line',
          source: 'trail',
          layout: {
            'line-join': 'round',
            'line-cap': 'round',
            'visibility': 'visible'
          },
          paint: {
            'line-color': '#ff9999',
            'line-width': 8,
            'line-opacity': 0.4,
            'line-blur': 3
          }
        });
        
        // Add trail line layer on top
        this.map.addLayer({
          id: 'trail-line',
          type: 'line',
          source: 'trail',
          layout: {
            'line-join': 'round',
            'line-cap': 'round',
            'visibility': 'visible'
          },
          paint: {
            'line-color': '#ff6b6b',
            'line-width': 4,
            'line-opacity': 0.9
          }
        });
        
        // Add trail points layer
        this.map.addLayer({
          id: 'trail-points',
          type: 'circle',
          source: 'trail',
          paint: {
            'circle-radius': 4,
            'circle-color': '#ff6b6b',
            'circle-stroke-width': 1.5,
            'circle-stroke-color': '#ffffff'
          }
        });
        
        console.log("Trail layers added to map");
      }
      
      // Add trail point markers
      this.addTrailPointMarkers(trail);
    } catch (error) {
      console.error("Error drawing trail:", error);
    }
  },
  
  // Update trail
  updateTrail(trail) {
    try {
      if (!this.map || !this.map.loaded()) {
        console.error("Map not loaded, can't update trail");
        return;
      }
      
      if (!trail || trail.length < 2) return;
      
      // Update the trail GeoJSON
      if (this.map.getSource('trail')) {
        const trailGeoJSON = {
          type: 'Feature',
          properties: {},
          geometry: {
            type: 'LineString',
            coordinates: trail
          }
        };
        
        this.map.getSource('trail').setData(trailGeoJSON);
      } else {
        this.drawTrail(trail);
      }
      
      // Update trail point markers
      this.updateTrailPointMarkers(trail);
    } catch (error) {
      console.error("Error updating trail:", error);
    }
  },
  
  // Add small markers for trail points
  addTrailPointMarkers(trail) {
    // Remove existing trail point markers
    this.removeTrailPointMarkers();
    
    // Create array to store markers
    this.trailPointMarkers = [];
    
    // Add markers for each point except the current position
    trail.forEach((point, index) => {
      if (index === 0) return; // Skip the current position
      
      const el = document.createElement('div');
      el.className = 'trail-point-marker';
      
      // Make more recent points larger and more opaque
      const size = Math.max(3, 7 - (index * 0.15)); // Size decreases with age
      const opacity = Math.max(0.3, 1 - (index * 0.03)); // Opacity decreases with age
      
      el.style.width = `${size}px`;
      el.style.height = `${size}px`;
      el.style.borderRadius = '50%';
      el.style.backgroundColor = '#ff6b6b';
      el.style.border = '1px solid white';
      el.style.opacity = opacity;
      el.style.boxShadow = '0 0 3px rgba(0, 0, 0, 0.3)';
      
      const marker = new maplibregl.Marker({
        element: el,
        anchor: 'center',
        offset: [0, 0],
        draggable: false,
        clickTolerance: 0,
        rotation: 0
      })
      .setLngLat(point)
      .addTo(this.map);
      
      this.trailPointMarkers.push(marker);
    });
  },
  
  // Update trail point markers
  updateTrailPointMarkers(trail) {
    this.addTrailPointMarkers(trail);
  },
  
  // Remove trail point markers
  removeTrailPointMarkers() {
    if (this.trailPointMarkers) {
      this.trailPointMarkers.forEach(marker => marker.remove());
      this.trailPointMarkers = [];
    }
  },
  
  // Update device position and trail
  updateDevice(device, trail) {
    try {
      // Update base position for jitter
      this._basePosition = {
        lng: device.lon,
        lat: device.lat
      };
      
      // Update marker position
      if (this.deviceMarker) {
        this.deviceMarker.setLngLat([device.lon, device.lat]);
        
        // Update popup content
        if (this.deviceMarker._popup) {
          this.deviceMarker._popup.setHTML(`
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
      } else if (this.map && this.map.loaded()) {
        this._initializeDevice(device, trail);
        return;
      }
      
      // Update trail
      if (trail && trail.length > 0) {
        this.updateTrail(trail);
      }
    } catch (error) {
      console.error("Error updating device:", error);
    }
  },
  
  destroyed() {
    try {
      // Clean up movement interval
      if (this.movementInterval) {
        clearInterval(this.movementInterval);
      }
      
      // Clean up map
      if (this.map) {
        this.map.remove();
      }
      
      // Clean up markers
      if (this.deviceMarker) {
        this.deviceMarker.remove();
      }
      
      if (this.trailPointMarkers) {
        this.trailPointMarkers.forEach(marker => marker.remove());
      }
      
      console.log("DeviceMapHook destroyed, resources cleaned up");
    } catch (error) {
      console.error("Error cleaning up DeviceMapHook:", error);
    }
  }
};

// Add styles to match main map
document.head.insertAdjacentHTML('beforeend', `
  <style>
      .highlighted-marker {
    width: 25px !important;
    height: 25px !important;
    z-index: 100;
    animation: pulse 1s infinite;
    border-radius: 50%;
  }
    
    .trail-point-marker {
      transition: opacity 0.3s ease;
      pointer-events: none;
    }
    
    .maplibregl-popup-content {
      border-radius: 8px;
      padding: 0;
      overflow: hidden;
    }
    
    .maplibregl-popup {
      z-index: 200;
    }
    
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
    
    /* Make sure map container is visible */
    #device-map-container, #device-map {
      width: 100%;
      height: 100%;
      min-height: 400px;
    }
    
    /* Enhance trail line style */
    .maplibregl-canvas {
      outline: none;
    }
  </style>
`);

export default DeviceMapHook;