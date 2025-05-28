// Chart rendering logic for device detail page
// Assumes Chart.js is available globally as Chart

let currentChart = null;

window.addEventListener('phx:hide_all_charts', () => {
  document.querySelectorAll('[id$="-chart"]').forEach(chart => {
    chart.classList.add('hidden');
  });
  if (currentChart) {
    currentChart.destroy();
    currentChart = null;
  }
});

window.addEventListener('phx:show_chart', (e) => {
  const { type, data } = e.detail;
  const chartId = `${type}-chart`;
  const chartElement = document.getElementById(chartId);

  if (chartElement) {
    chartElement.classList.remove('hidden');

    // Clear any existing chart
    if (currentChart) {
      currentChart.destroy();
    }

    // Setup chart configuration based on metric type
    const labels = data.timestamps.map(ts => {
      const date = new Date(ts);
      return date.toLocaleTimeString();
    });

    const datasets = [{
      label: getChartLabel(type),
      data: data[type],
      borderColor: getChartColor(type),
      backgroundColor: getChartColor(type, 0.2),
      tension: 0.4,
      fill: true
    }];

    // Create new chart
    currentChart = new Chart(chartElement, {
      type: 'line',
      data: {
        labels: labels,
        datasets: datasets
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true,
            position: 'top'
          }
        },
        scales: {
          x: {
            display: true,
            title: {
              display: true,
              text: 'Time'
            }
          },
          y: {
            display: true,
            title: {
              display: true,
              text: getYAxisLabel(type)
            }
          }
        },
        animation: {
          duration: 750,
          easing: 'easeInOutQuart'
        }
      }
    });
  }
});

window.addEventListener('phx:update_charts', (e) => {
  const { metrics, selected_type } = e.detail;
  if (currentChart && selected_type) {
    const labels = metrics.timestamps.map(ts => {
      const date = new Date(ts);
      return date.toLocaleTimeString();
    });

    currentChart.data.labels = labels;
    currentChart.data.datasets[0].data = metrics[selected_type];
    currentChart.update('none'); // Update without animation for smoother real-time updates
  }
});

function getChartColor(type, alpha = 1) {
  const colors = {
    speed: `rgba(34, 197, 94, ${alpha})`,
    elevation: `rgba(168, 85, 247, ${alpha})`,
    voltage: `rgba(234, 179, 8, ${alpha})`,
    rssi: `rgba(239, 68, 68, ${alpha})`,
    snr: `rgba(99, 102, 241, ${alpha})`
  };
  return colors[type] || `rgba(59, 130, 246, ${alpha})`;
}

function getChartLabel(type) {
  const labels = {
    speed: 'Speed (m/s)',
    elevation: 'Elevation (m)',
    voltage: 'Battery Level (V)',
    rssi: 'Signal Strength (dBm)',
    snr: 'Signal Quality (dB)'
  };
  return labels[type] || type;
}

function getYAxisLabel(type) {
  const labels = {
    speed: 'Meters per Second (m/s)',
    elevation: 'Meters (m)',
    voltage: 'Volts (V)',
    rssi: 'Decibel-milliwatts (dBm)',
    snr: 'Decibels (dB)'
  };
  return labels[type] || '';
}

// Chart visibility handling for device detail page

window.addEventListener('phx:hide_all_charts', () => {
  document.querySelectorAll('[id$="-chart"]').forEach(chart => {
    chart.classList.add('hidden');
  });
});

window.addEventListener('phx:show_chart', (e) => {
  const { type } = e.detail;
  const chartId = `${type}-chart`;
  const chartElement = document.getElementById(chartId);

  if (chartElement) {
    // Show this chart
    chartElement.classList.remove('hidden');
  }
}); 