import Chart from 'chart.js/auto';

const ChartHook = {
  mounted() {
    this.charts = {};
    
    // Listen for chart data updates
    this.handleEvent("show_chart", ({ type, data }) => {
      this.showChart(type, data);
    });
    
    this.handleEvent("update_charts", ({ metrics }) => {
      if (this.currentChart) {
        this.updateChart(this.currentChart.type, metrics);
      }
    });
  },
  
  showChart(type, data) {
    // Destroy existing chart if any
    if (this.currentChart) {
      this.currentChart.chart.destroy();
    }
    
    const ctx = document.getElementById(`${type}-chart`);
    if (!ctx) return;
    
    const chartData = this.prepareChartData(type, data);
    
    this.currentChart = {
      type,
      chart: new Chart(ctx, {
        type: 'line',
        data: chartData,
        options: {
          responsive: true,
          maintainAspectRatio: false,
          animation: {
            duration: 0 // Disable animation for real-time updates
          },
          plugins: {
            legend: {
              display: false
            },
            title: {
              display: true,
              text: this.getChartTitle(type),
              font: {
                size: 16,
                weight: 'bold'
              },
              padding: {
                top: 10,
                bottom: 20
              }
            }
          },
          scales: {
            x: {
              type: 'time',
              time: {
                unit: 'second',
                displayFormats: {
                  second: 'HH:mm:ss'
                }
              },
              title: {
                display: true,
                text: 'Time',
                font: {
                  size: 12,
                  weight: 'bold'
                }
              },
              grid: {
                display: true,
                color: 'rgba(0,0,0,0.1)'
              }
            },
            y: {
              beginAtZero: false,
              title: {
                display: true,
                text: this.getYAxisLabel(type),
                font: {
                  size: 12,
                  weight: 'bold'
                }
              },
              grid: {
                display: true,
                color: 'rgba(0,0,0,0.1)'
              }
            }
          }
        }
      })
    };
  },
  
  updateChart(type, data) {
    if (!this.currentChart || !this.currentChart.chart) return;
    
    const chartData = this.prepareChartData(type, data);
    if (chartData) {
      this.currentChart.chart.data = chartData;
      this.currentChart.chart.update('none'); // Update without animation
    }
  },
  
  prepareChartData(type, data) {
    if (!data || !data.timestamps || !data[type]) return null;
    
    const timestamps = data.timestamps;
    const values = data[type];
    
    return {
      labels: timestamps,
      datasets: [{
        data: values.map((value, index) => ({
          x: new Date(timestamps[index]),
          y: value
        })),
        borderColor: this.getChartColor(type),
        backgroundColor: this.getChartColor(type, 0.2),
        borderWidth: 2,
        fill: true,
        tension: 0.4,
        pointRadius: 3,
        pointHoverRadius: 5,
        pointBackgroundColor: this.getChartColor(type),
        pointBorderColor: '#fff',
        pointBorderWidth: 1
      }]
    };
  },
  
  getChartTitle(type) {
    const titles = {
      avg_speed: 'Speed History',
      elevation: 'Elevation History',
      voltage: 'Battery Level History',
      rssi: 'Signal Strength History',
      snr: 'Signal Quality History'
    };
    return titles[type] || type;
  },
  
  getYAxisLabel(type) {
    const labels = {
      avg_speed: 'Speed (m/s)',
      elevation: 'Elevation (m)',
      voltage: 'Voltage (V)',
      rssi: 'RSSI (dBm)',
      snr: 'SNR (dB)'
    };
    return labels[type] || '';
  },
  
  getChartColor(type, alpha = 1) {
    const colors = {
      avg_speed: `rgba(34, 197, 94, ${alpha})`,
      elevation: `rgba(168, 85, 247, ${alpha})`,
      voltage: `rgba(234, 179, 8, ${alpha})`,
      rssi: `rgba(239, 68, 68, ${alpha})`,
      snr: `rgba(99, 102, 241, ${alpha})`
    };
    return colors[type] || `rgba(107, 114, 128, ${alpha})`;
  },
  
  destroyed() {
    // Clean up charts
    if (this.currentChart && this.currentChart.chart) {
      this.currentChart.chart.destroy();
    }
  }
};

export default ChartHook; 