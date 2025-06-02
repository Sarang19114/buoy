import Chart from 'chart.js/auto';

const ChartHook = {
  mounted() {
    this.charts = {};

    // Handle showing specific charts
    this.handleEvent("show_chart", ({ chart_type, metrics }) => {
      if (!metrics) return;
      
      setTimeout(() => {
        this.createChart(chart_type, metrics);
      }, 100); // Small delay to ensure DOM is ready
    });

    // Handle chart updates
    this.handleEvent("update_charts", ({ metrics }) => {
      if (!metrics) return;

      // Update all existing charts
      Object.keys(this.charts).forEach(type => {
        if (this.charts[type] && !this.charts[type].destroyed) {
          this.updateChart(type, metrics);
        }
      });
    });

    // Handle toggling between stats and charts
    this.handleEvent("toggle_view", ({ show_stats, chart_type }) => {
      const statsGrid = document.getElementById('stats-grid');
      const chartsContainer = document.getElementById('charts-container');
      
      if (show_stats) {
        statsGrid.classList.remove('hidden');
        chartsContainer.classList.add('hidden');
        // Destroy all charts to free up memory
        Object.keys(this.charts).forEach(type => {
          if (this.charts[type] && !this.charts[type].destroyed) {
            this.charts[type].destroy();
          }
        });
        this.charts = {};
      } else {
        statsGrid.classList.add('hidden');
        chartsContainer.classList.remove('hidden');
      }
    });
  },

  createChart(type, metrics) {
    const canvas = document.getElementById(`${type}-chart-canvas`);
    if (!canvas) return;

    // Destroy existing chart if it exists
    if (this.charts[type]) {
      this.charts[type].destroy();
    }

    const labels = metrics.timestamps.map(ts => {
      if (!ts) return '';
      const date = new Date(ts);
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    });

    const data = metrics[type] || [];
    
    // Filter out null/undefined values for better display
    const processedData = data.map(value => value === null || value === undefined ? null : value);

    this.charts[type] = new Chart(canvas, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [{
          label: this.getChartLabel(type),
          data: processedData,
          borderColor: this.getChartColor(type),
          backgroundColor: this.getChartBackgroundColor(type),
          tension: 0.4,
          fill: false,
          pointRadius: 3,
          pointHoverRadius: 5,
          pointBackgroundColor: this.getChartColor(type),
          pointBorderColor: '#ffffff',
          pointBorderWidth: 2,
          spanGaps: true // Connect line even if there are null values
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: {
          duration: 300
        },
        interaction: {
          intersect: false,
          mode: 'index'
        },
        scales: {
          y: {
            beginAtZero: this.shouldBeginAtZero(type),
            grid: {
              color: 'rgba(0,0,0,0.1)'
            },
            ticks: {
              callback: function(value) {
                return value + ' ' + this.getUnit(type);
              }.bind(this)
            }
          },
          x: {
            grid: {
              display: false
            },
            ticks: {
              maxTicksLimit: 8
            }
          }
        },
        plugins: {
          legend: {
            display: true,
            position: 'top',
            labels: {
              usePointStyle: true,
              padding: 20
            }
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                const value = context.parsed.y;
                const unit = this.getUnit(type);
                return `${context.dataset.label}: ${value}${unit}`;
              }.bind(this)
            }
          }
        }
      }
    });
  },

  updateChart(type, metrics) {
    const chart = this.charts[type];
    if (!chart || chart.destroyed) return;

    const labels = metrics.timestamps.map(ts => {
      if (!ts) return '';
      const date = new Date(ts);
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    });

    const data = metrics[type] || [];
    const processedData = data.map(value => value === null || value === undefined ? null : value);

    chart.data.labels = labels;
    chart.data.datasets[0].data = processedData;
    chart.update('none'); // Update without animation for real-time feel
  },

  getChartLabel(type) {
    const labels = {
      speed: 'Speed',
      elevation: 'Elevation',
      voltage: 'Battery Voltage',
      rssi: 'Signal Strength',
      snr: 'Signal Quality'
    };
    return labels[type] || type.charAt(0).toUpperCase() + type.slice(1);
  },

  getChartColor(type) {
    const colors = {
      speed: '#22c55e',      // green-500
      elevation: '#a855f7',  // purple-500
      voltage: '#eab308',    // yellow-500
      rssi: '#ef4444',       // red-500
      snr: '#6366f1'         // indigo-500
    };
    return colors[type] || '#3b82f6';  // default to blue-500
  },

  getChartBackgroundColor(type) {
    const colors = {
      speed: 'rgba(34, 197, 94, 0.1)',      // green with opacity
      elevation: 'rgba(168, 85, 247, 0.1)',  // purple with opacity
      voltage: 'rgba(234, 179, 8, 0.1)',     // yellow with opacity
      rssi: 'rgba(239, 68, 68, 0.1)',        // red with opacity
      snr: 'rgba(99, 102, 241, 0.1)'         // indigo with opacity
    };
    return colors[type] || 'rgba(59, 130, 246, 0.1)';  // default to blue with opacity
  },

  getUnit(type) {
    const units = {
      speed: ' m/s',
      elevation: ' m',
      voltage: ' V',
      rssi: ' dBm',
      snr: ' dB'
    };
    return units[type] || '';
  },

  shouldBeginAtZero(type) {
    // Some metrics like RSSI can be negative, so don't force zero
    return !['rssi', 'snr'].includes(type);
  },

  destroyed() {
    // Cleanup all charts when hook is destroyed
    Object.values(this.charts).forEach(chart => {
      if (chart && !chart.destroyed) {
        chart.destroy();
      }
    });
    this.charts = {};
  }
};

export default ChartHook;