// Use a reliable open source map style and provider
import maplibregl from "maplibre-gl";

const MapLibreHook = {
  customLayers: [],
  customSources: [],
  deviceCache: new Map(),

  mounted() {
    console.log("MapLibreHook mounted");
    // Ensure the map container has visible dimensions
    if (!this.el.offsetWidth || !this.el.offsetHeight) {
      console.error("Map container has no size. Setting fallback height.");
      this.el.style.height = "500px"; 
    }
    
    this.initializeMap();
    this.setupEventHandlers();
  },

  initializeMap() {
    console.log("Initializing map");
    try {
      // Create map with a reliable open source map style
      this.map = new maplibregl.Map({
        container: this.el,
        style: this.getMapStyle(),
        center: [-122.41919, 37.77115],
        zoom: 11,
        minZoom: 2,
        maxZoom: 19,
        attributionControl: true
      });

      // Add event listeners
      this.map.on("load", this.onMapLoad.bind(this));
      this.map.on("error", this.onMapError.bind(this));
      
      console.log("Map initialized");
    } catch (error) {
      console.error("Error initializing map:", error);
    }
  },

getMapStyle() {
  return {
    version: 8,
    sources: {
      darkMap: {
        type: "raster",
        tiles: [
          "https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png"
        ],
        tileSize: 256,
        maxzoom: 19
      }
    },
    layers: [
      {
        id: "background",
        type: "background",
        paint: {
          "background-color": "#000000"  // black background
        }
      },
      {
        id: "darkMap",
        type: "raster",
        source: "darkMap",
        minzoom: 0,
        maxzoom: 19
      }
    ]
  };
},


  onMapLoad() {
    console.log("Map loaded");
    this.pushEvent("map_loaded", {});
  },

  onMapError(e) {
    console.error("MapLibre GL error:", e);
  },

  setupEventHandlers() {
    this.handleEvent("plot_marker", this.plotMarker.bind(this));
    this.handleEvent("plot_latest_payloads", this.plotLatestPayloads.bind(this));
  },

  plotMarker(coords) {
  console.log("Plotting marker:", coords);

  if (!coords || !coords.history || !coords.history.length) {
    console.error("Invalid coordinates data:", coords);
    return;
  }

  const [lng, lat] = coords.history[0].slice().reverse(); // Ensure [lng, lat] order

  // Animate map to the new device location
  this.map.flyTo({
    center: [lng, lat],
    zoom: 14,
    speed: 1.5,
    curve: 1.42,
    easing(t) {
      return t;
    }
  });

  // Add marker on the map
  const geojson = this.createGeoJSON(coords);
  this.updateMapLayers(geojson, "marker-layer");
},

  createGeoJSON(coords) {
    try {
      const pointFeatures = coords.history.map((latlon, index) => ({
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [parseFloat(latlon[1]), parseFloat(latlon[0])],
        },
        properties: { index, isLast: index === coords.history.length - 1 },
      }));

      const lineFeature = {
        type: "Feature",
        geometry: {
          type: "LineString",
          coordinates: coords.history.map((latlon) => [
            parseFloat(latlon[1]),
            parseFloat(latlon[0]),
          ]),
        },
      };

      return {
        type: "FeatureCollection",
        features: [...pointFeatures, lineFeature],
      };
    } catch (error) {
      console.error("Error creating GeoJSON:", error);
      return { type: "FeatureCollection", features: [] };
    }
  },

  updateMapLayers(geojson, sourceType = "marker") {
    console.log(`Updating map layers for ${sourceType}`);
    if (!this.map) {
      console.error("Map not initialized");
      return;
    }
    
    // Wait until the map is fully loaded
    if (!this.map.loaded()) {
      console.log("Map not loaded yet, waiting...");
      this.map.once('load', () => {
        this._updateMapLayersInternal(geojson, sourceType);
      });
      return;
    }
    
    this._updateMapLayersInternal(geojson, sourceType);
  },
  
  _updateMapLayersInternal(geojson, sourceType) {
    const sourceId = `${sourceType}-source`;
    const layerPrefix = sourceType;

    this.removeCustomLayers();
    this.removeCustomSources();
    this.addNewSource(geojson, sourceId);

    if (sourceType === "marker") {
      this.addLineLayers(sourceId, layerPrefix);
      this.addDotLayers(sourceId, layerPrefix);
    } else if (sourceType === "device") {
      this.addDeviceLayers(sourceId, layerPrefix);
    }
  },

  removeCustomLayers() {
    if (!this.map) return;
    
    console.log("Removing custom layers");
    this.customLayers.forEach((layerId) => {
      if (this.map.getLayer(layerId)) {
        console.log(`Removing layer: ${layerId}`);
        this.map.removeLayer(layerId);
      }
    });
    this.customLayers = [];
  },

  removeCustomSources() {
    if (!this.map) return;
    
    console.log("Removing custom sources");
    this.customSources.forEach((sourceId) => {
      if (this.map.getSource(sourceId)) {
        console.log(`Removing source: ${sourceId}`);
        this.map.removeSource(sourceId);
      }
    });
    this.customSources = [];
  },

  addNewSource(geojson, sourceId) {
    console.log(`Adding new source: ${sourceId}`);
    try {
      this.map.addSource(sourceId, {
        type: "geojson",
        data: geojson,
      });
      this.customSources.push(sourceId);
    } catch (error) {
      console.error(`Error adding source ${sourceId}:`, error);
    }
  },

  addLineLayers(sourceId, prefix) {
    const layerId = `${prefix}-line-layer`;
    console.log(`Adding line layer: ${layerId}`);
    try {
      this.map.addLayer({
        id: layerId,
        type: "line",
        source: sourceId,
        layout: { "line-join": "round", "line-cap": "round" },
        paint: { "line-color": "#007cbf", "line-width": 1 },
        filter: ["==", "$type", "LineString"],
      });
      this.customLayers.push(layerId);
    } catch (error) {
      console.error(`Error adding line layer ${layerId}:`, error);
    }
  },

  addDotLayers(sourceId, prefix) {
    const layerId = `${prefix}-dot-layer`;
    console.log(`Adding dot layer: ${layerId}`);
    try {
      this.map.addLayer({
        id: layerId,
        type: "circle",
        source: sourceId,
        paint: {
          "circle-radius": ["case", ["==", ["get", "isLast"], true], 6, 3],
          "circle-color": "#007cbf",
        },
        filter: ["==", "$type", "Point"],
      });
      this.customLayers.push(layerId);
    } catch (error) {
      console.error(`Error adding dot layer ${layerId}:`, error);
    }
  },

  flyToCoordinates(coords) {
    if (!coords.history || coords.history.length === 0) return;

    try {
      const bounds = new maplibregl.LngLatBounds();
      coords.history.forEach((latlon) => {
        bounds.extend([parseFloat(latlon[1]), parseFloat(latlon[0])]);
      });

      this.map.fitBounds(bounds, { padding: 100, maxZoom: 13, duration: 1000 });
    } catch (error) {
      console.error("Error flying to coordinates:", error);
    }
  },

  addDeviceLayers(sourceId, prefix) {
    const layerId = `${prefix}-layer`;
    console.log(`Adding device layer: ${layerId}`);
    try {
      this.map.addLayer({
        id: layerId,
        type: "circle",
        source: sourceId,
        paint: { "circle-radius": 6, "circle-color": "#007cbf" },
      });
      this.customLayers.push(layerId);

      this.map.on("mouseenter", layerId, () => {
        this.map.getCanvas().style.cursor = "pointer";
      });

      this.map.on("mouseleave", layerId, () => {
        this.map.getCanvas().style.cursor = "";
      });
    } catch (error) {
      console.error(`Error adding device layer ${layerId}:`, error);
    }
  },

  plotLatestPayloads(data) {
    console.log("Plotting latest payloads:", data);
    const payloads = data.payloads;
    if (!payloads || payloads.length === 0) return;

    try {
      payloads.forEach((payload) => {
        const deviceId = payload.device_id;
        if (!this.deviceCache.has(deviceId)) {
          this.deviceCache.set(deviceId, []);
        }
        this.deviceCache.get(deviceId).push(payload);
        this.updateDeviceOnMap(deviceId);
      });

      this.flyToAllDevices();
    } catch (error) {
      console.error("Error plotting latest payloads:", error);
    }
  },

  updateDeviceOnMap(deviceId) {
    try {
      const deviceHistory = this.deviceCache.get(deviceId);
      if (!deviceHistory || deviceHistory.length === 0) return;

      const geojson = this.createGeoJSONFromPayloads(deviceHistory);
      const sourceId = `device-${deviceId}-source`;
      const layerPrefix = `device-${deviceId}`;

      if (!this.map.getSource(sourceId)) {
        this.addNewSource(geojson, sourceId);
        this.addDeviceLayers(sourceId, layerPrefix);
      } else {
        this.updateSource(sourceId, geojson);
      }

      const latestPayload = deviceHistory[deviceHistory.length - 1];
      this.map.flyTo({
        center: [parseFloat(latestPayload.lon), parseFloat(latestPayload.lat)],
        zoom: 12,
        duration: 1000,
      });
    } catch (error) {
      console.error(`Error updating device ${deviceId} on map:`, error);
    }
  },

  updateSource(sourceId, geojson) {
    const source = this.map.getSource(sourceId);
    if (source) {
      source.setData(geojson);
    }
  },

  createGeoJSONFromPayloads(payloads) {
    try {
      const features = payloads.map((payload) => ({
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [parseFloat(payload.lon), parseFloat(payload.lat)],
        },
        properties: payload,
      }));

      return { type: "FeatureCollection", features };
    } catch (error) {
      console.error("Error creating GeoJSON from payloads:", error);
      return { type: "FeatureCollection", features: [] };
    }
  },

  flyToAllDevices() {
    try {
      const bounds = new maplibregl.LngLatBounds();
      let hasDevices = false;
      
      this.deviceCache.forEach((deviceHistory) => {
        if(deviceHistory.length > 0) {
          const latestPayload = deviceHistory[deviceHistory.length - 1];
          bounds.extend([
            parseFloat(latestPayload.lon),
            parseFloat(latestPayload.lat),
          ]);
          hasDevices = true;
        }
      });

      if (hasDevices) {
        this.map.fitBounds(bounds, { padding: 50, maxZoom: 15, duration: 2000 });
      }
    } catch (error) {
      console.error("Error flying to all devices:", error);
    }
  },

  destroyed() {
    if (this.map) {
      this.map.remove();
    }
    this.deviceCache.clear();
  },
};

export default MapLibreHook;