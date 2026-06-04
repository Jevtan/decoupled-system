/**
 * ============================================================
 *  FLASH CROWD LOAD TEST — ADVANCED WITH HTML DASHBOARD
 *  Queue-Based vs CPU-Based Auto Scaling — Skripsi
 * ============================================================
 *
 *  CARA JALANKAN (dengan grafik HTML otomatis):
 *
 *  Queue-Based Run 3:
 *    k6 run \
 *      --env RUN_NUMBER=3 \
 *      --env EXPERIMENT=queue-based \
 *      --out json=run3_queue_raw.json \
 *      flashcrowd_advanced.js 2>&1 | tee run3_queue_output.txt
 *
 *  CPU-Based Run 1:
 *    k6 run \
 *      --env RUN_NUMBER=1 \
 *      --env EXPERIMENT=cpu-based \
 *      --out json=run1_cpu_raw.json \
 *      flashcrowd_advanced.js 2>&1 | tee run1_cpu_output.txt
 *
 *  Setelah test selesai, buka file HTML grafik yang otomatis dibuat:
 *    run3_queue_dashboard.html  ← buka di browser
 *
 *  WINDOWS (PowerShell):
 *    k6 run --env RUN_NUMBER=3 --env EXPERIMENT=queue-based `
 *      --out json=run3_queue_raw.json `
 *      flashcrowd_advanced.js 2>&1 | Tee-Object run3_queue_output.txt
 * ============================================================
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend, Gauge } from 'k6/metrics';

// ============================================================
//  CONFIG
// ============================================================

const BASE_URL   = __ENV.TARGET_URL   || 'http://webinar-alb-1099377454.us-east-1.elb.amazonaws.com';
const EXPERIMENT = __ENV.EXPERIMENT   || 'queue-based';
const RUN_NUMBER = __ENV.RUN_NUMBER   || '3';

// ============================================================
//  CUSTOM METRICS
// ============================================================

const registrationErrors = new Counter('registration_errors');
const successRate        = new Rate('success_rate');
const responseTime       = new Trend('response_time_ms', true);

// ============================================================
//  SKENARIO — sama persis dengan Run 1 & 2
// ============================================================

export const options = {
  scenarios: {
    flash_crowd: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '5m',  target: 10  },
        { duration: '2m',  target: 50  },
        { duration: '10m', target: 50  },
        { duration: '3m',  target: 100 },
        { duration: '15m', target: 100 },
        { duration: '5m',  target: 10  },
        { duration: '20m', target: 10  },
      ],
    },
  },
  thresholds: {
    'http_req_duration': ['p(95)<3000'],
    'success_rate':      ['rate>0.95'],
  },
};

// ============================================================
//  SETUP
// ============================================================

export function setup() {
  const startTime = new Date().toISOString();
  console.log('='.repeat(60));
  console.log(`  SKRIPSI LOAD TEST — ${EXPERIMENT.toUpperCase()} | Run ${RUN_NUMBER}`);
  console.log(`  Start Time (UTC) : ${startTime}`);
  console.log(`  Start Time (WIB) : ${wibTime(new Date())}`);
  console.log(`  Target URL       : ${BASE_URL}`);
  console.log('='.repeat(60));
  console.log('  ⚠️  CATAT WAKTU START DI EXCEL RUN TRACKER SEKARANG!');
  console.log('='.repeat(60));
  return { startTime, experiment: EXPERIMENT, run: RUN_NUMBER };
}

// ============================================================
//  MAIN VU
// ============================================================

export default function () {
  const userId  = `user_${Math.floor(Math.random() * 100000)}`;
  const payload = JSON.stringify({
    user_id:   userId,
    webinar_id: 'webinar_1',
    name:      `Test User ${userId}`,
    email:     `${userId}@test.com`,
  });

  const params = { headers: { 'Content-Type': 'application/json' } };
  const res    = http.post(`${BASE_URL}/register`, payload, params);

  const ok = res.status >= 200 && res.status < 300;
  successRate.add(ok);
  responseTime.add(res.timings.duration);
  check(res, { 'status 2xx': (r) => r.status >= 200 && r.status < 300 });
  if (!ok) registrationErrors.add(1);

  sleep(Math.random() * 2 + 1);
}

// ============================================================
//  TEARDOWN
// ============================================================

export function teardown(data) {
  const endTime = new Date().toISOString();
  console.log('\n' + '='.repeat(60));
  console.log(`  TEST SELESAI — ${data.experiment.toUpperCase()} | Run ${data.run}`);
  console.log(`  Start (UTC) : ${data.startTime}  |  WIB: ${wibFromISO(data.startTime)}`);
  console.log(`  End   (UTC) : ${endTime}  |  WIB: ${wibTime(new Date())}`);
  console.log('='.repeat(60));
  console.log('  CHECKLIST SETELAH TEST:');
  console.log('  [ ] Catat waktu END di Excel Run Tracker');
  console.log('  [ ] Copy latency avg, p95, throughput, success rate ke Excel');
  console.log('  [ ] Buka file dashboard HTML di browser untuk lihat grafik');
  console.log('  [ ] Jalankan 3 command CloudWatch (lihat sheet CMD di Excel)');
  console.log('  [ ] Screenshot alarm history di CloudWatch Console');
  console.log('  [ ] Tunggu minimal 30 menit sebelum run berikutnya');
  console.log('='.repeat(60));
}

// ============================================================
//  HANDLE SUMMARY — Generate grafik HTML otomatis
// ============================================================

// ============================================================
//  HTML DASHBOARD BUILDER
// ============================================================

function buildDashboard(data, experiment, runNumber) {
  const metrics = data.metrics;

  // Safely extract metric values
  function val(path, fallback = 0) {
    try {
      const parts = path.split('.');
      let obj = metrics;
      for (const p of parts) obj = obj[p];
      return typeof obj === 'number' ? obj.toFixed(2) : (obj ?? fallback);
    } catch { return fallback; }
  }

  const avgLatency   = val('http_req_duration.values.avg');
  const p95Latency   = val('http_req_duration.values.p(95)');
  const p99Latency   = val('http_req_duration.values.p(99)');
  const minLatency   = val('http_req_duration.values.min');
  const maxLatency   = val('http_req_duration.values.max');
  const medLatency   = val('http_req_duration.values.med');
  const throughput   = val('http_reqs.values.rate');
  const totalReqs    = val('http_reqs.values.count');
  const failRate     = val('http_req_failed.values.rate');
  const successRateV = ((1 - parseFloat(failRate)) * 100).toFixed(2);
  const errorRateV   = (parseFloat(failRate) * 100).toFixed(2);

  const passP95    = parseFloat(p95Latency) < 3000;
  const passSuccess = parseFloat(successRateV) >= 95;

  const expColor = experiment === 'queue-based' ? '#1a5276' : '#4a235a';
  const expLabel = experiment === 'queue-based' ? 'Queue-Based Auto Scaling' : 'CPU-Based Auto Scaling';

  return `<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Run ${runNumber} — ${expLabel} | Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: Arial, sans-serif; background: #f0f4f8; color: #1a1a2e; }

  .header {
    background: ${expColor};
    color: white;
    padding: 24px 32px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .header h1 { font-size: 22px; }
  .header .sub { font-size: 13px; opacity: 0.8; margin-top: 4px; }
  .badge {
    background: rgba(255,255,255,0.2);
    border-radius: 20px;
    padding: 6px 16px;
    font-size: 13px;
    font-weight: bold;
  }

  .container { max-width: 1100px; margin: 0 auto; padding: 24px 16px; }

  /* Status bar */
  .status-bar {
    display: flex;
    gap: 12px;
    margin-bottom: 24px;
  }
  .status-card {
    flex: 1;
    border-radius: 10px;
    padding: 16px 20px;
    display: flex;
    align-items: center;
    gap: 12px;
    font-weight: bold;
    font-size: 14px;
  }
  .status-pass { background: #d4edda; color: #155724; border-left: 5px solid #28a745; }
  .status-fail { background: #f8d7da; color: #721c24; border-left: 5px solid #dc3545; }
  .status-icon { font-size: 22px; }

  /* Metric cards */
  .cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
    gap: 14px;
    margin-bottom: 28px;
  }
  .card {
    background: white;
    border-radius: 10px;
    padding: 18px 16px;
    text-align: center;
    box-shadow: 0 2px 8px rgba(0,0,0,0.07);
    border-top: 4px solid ${expColor};
  }
  .card .label { font-size: 11px; color: #666; text-transform: uppercase; letter-spacing: 0.5px; }
  .card .value { font-size: 26px; font-weight: bold; color: ${expColor}; margin: 6px 0 2px; }
  .card .unit  { font-size: 11px; color: #999; }

  /* Charts */
  .charts { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 28px; }
  .chart-box {
    background: white;
    border-radius: 10px;
    padding: 20px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.07);
  }
  .chart-box h3 { font-size: 13px; color: #555; margin-bottom: 14px; text-transform: uppercase; letter-spacing: 0.5px; }
  .chart-box canvas { max-height: 220px; }

  /* Table */
  .table-box {
    background: white;
    border-radius: 10px;
    padding: 20px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.07);
    margin-bottom: 28px;
  }
  .table-box h3 { font-size: 13px; color: #555; margin-bottom: 14px; text-transform: uppercase; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th { background: ${expColor}; color: white; padding: 10px 14px; text-align: left; }
  td { padding: 9px 14px; border-bottom: 1px solid #eee; }
  tr:nth-child(even) td { background: #f7fafd; }
  .pass { color: #28a745; font-weight: bold; }
  .fail { color: #dc3545; font-weight: bold; }

  .footer { text-align: center; font-size: 11px; color: #aaa; padding: 16px 0 32px; }
</style>
</head>
<body>

<div class="header">
  <div>
    <h1>📊 Load Test Dashboard — Run ${runNumber}</h1>
    <div class="sub">${expLabel} | Skripsi Auto Scaling AWS</div>
  </div>
  <div class="badge">Run ${runNumber} / 5</div>
</div>

<div class="container">

  <!-- Status -->
  <div class="status-bar">
    <div class="status-card ${passP95 ? 'status-pass' : 'status-fail'}">
      <span class="status-icon">${passP95 ? '✅' : '❌'}</span>
      <span>p95 Latency ${passP95 ? 'PASS' : 'FAIL'} — ${p95Latency}ms (threshold &lt; 3000ms)</span>
    </div>
    <div class="status-card ${passSuccess ? 'status-pass' : 'status-fail'}">
      <span class="status-icon">${passSuccess ? '✅' : '❌'}</span>
      <span>Success Rate ${passSuccess ? 'PASS' : 'FAIL'} — ${successRateV}% (threshold &gt; 95%)</span>
    </div>
  </div>

  <!-- Metric Cards -->
  <div class="cards">
    <div class="card">
      <div class="label">Latency Avg</div>
      <div class="value">${avgLatency}</div>
      <div class="unit">ms</div>
    </div>
    <div class="card">
      <div class="label">Latency p95</div>
      <div class="value">${p95Latency}</div>
      <div class="unit">ms</div>
    </div>
    <div class="card">
      <div class="label">Latency p99</div>
      <div class="value">${p99Latency}</div>
      <div class="unit">ms</div>
    </div>
    <div class="card">
      <div class="label">Throughput</div>
      <div class="value">${throughput}</div>
      <div class="unit">req/s</div>
    </div>
    <div class="card">
      <div class="label">Total Request</div>
      <div class="value">${Number(totalReqs).toLocaleString()}</div>
      <div class="unit">requests</div>
    </div>
    <div class="card">
      <div class="label">Success Rate</div>
      <div class="value">${successRateV}</div>
      <div class="unit">%</div>
    </div>
    <div class="card">
      <div class="label">Error Rate</div>
      <div class="value">${errorRateV}</div>
      <div class="unit">%</div>
    </div>
  </div>

  <!-- Charts -->
  <div class="charts">
    <!-- Latency breakdown chart -->
    <div class="chart-box">
      <h3>Latency Breakdown (ms)</h3>
      <canvas id="latencyChart"></canvas>
    </div>

    <!-- Success vs Error pie -->
    <div class="chart-box">
      <h3>Success vs Error Rate</h3>
      <canvas id="pieChart"></canvas>
    </div>
  </div>

  <!-- VU Stages Chart -->
  <div class="table-box">
    <h3>Skenario Beban (VU Stages)</h3>
    <canvas id="stagesChart" style="max-height:180px"></canvas>
  </div>

  <!-- Detail Table -->
  <div class="table-box">
    <h3>Detail Metrics — Untuk Dimasukkan ke Tabel Skripsi</h3>
    <table>
      <thead><tr><th>Metrik</th><th>Nilai</th><th>Threshold</th><th>Status</th></tr></thead>
      <tbody>
        <tr>
          <td>Latency Average</td>
          <td>${avgLatency} ms</td>
          <td>—</td>
          <td>—</td>
        </tr>
        <tr>
          <td>Latency Median</td>
          <td>${medLatency} ms</td>
          <td>—</td>
          <td>—</td>
        </tr>
        <tr>
          <td>Latency p95</td>
          <td>${p95Latency} ms</td>
          <td>&lt; 3000 ms</td>
          <td class="${passP95 ? 'pass' : 'fail'}">${passP95 ? '✅ PASS' : '❌ FAIL'}</td>
        </tr>
        <tr>
          <td>Latency p99</td>
          <td>${p99Latency} ms</td>
          <td>—</td>
          <td>—</td>
        </tr>
        <tr>
          <td>Latency Max</td>
          <td>${maxLatency} ms</td>
          <td>—</td>
          <td>—</td>
        </tr>
        <tr>
          <td>Throughput</td>
          <td>${throughput} req/s</td>
          <td>—</td>
          <td>—</td>
        </tr>
        <tr>
          <td>Total Requests</td>
          <td>${Number(totalReqs).toLocaleString()}</td>
          <td>—</td>
          <td>—</td>
        </tr>
        <tr>
          <td>Success Rate</td>
          <td>${successRateV}%</td>
          <td>&gt; 95%</td>
          <td class="${passSuccess ? 'pass' : 'fail'}">${passSuccess ? '✅ PASS' : '❌ FAIL'}</td>
        </tr>
        <tr>
          <td>Error Rate</td>
          <td>${errorRateV}%</td>
          <td>&lt; 5%</td>
          <td class="${parseFloat(errorRateV) < 5 ? 'pass' : 'fail'}">${parseFloat(errorRateV) < 5 ? '✅ PASS' : '❌ FAIL'}</td>
        </tr>
      </tbody>
    </table>
  </div>

</div>

<div class="footer">
  Generated by k6 handleSummary | ${expLabel} | Run ${runNumber} | Skripsi Auto Scaling AWS
</div>

<script>
// Latency Bar Chart
new Chart(document.getElementById('latencyChart'), {
  type: 'bar',
  data: {
    labels: ['Min', 'Avg', 'Median', 'p95', 'p99', 'Max'],
    datasets: [{
      label: 'Latency (ms)',
      data: [${minLatency}, ${avgLatency}, ${medLatency}, ${p95Latency}, ${p99Latency}, ${maxLatency}],
      backgroundColor: [
        'rgba(46,117,182,0.3)','rgba(46,117,182,0.6)','rgba(46,117,182,0.5)',
        'rgba(255,165,0,0.7)','rgba(220,53,69,0.6)','rgba(220,53,69,0.8)'
      ],
      borderColor: ['#2E75B6','#2E75B6','#2E75B6','#FFA500','#dc3545','#dc3545'],
      borderWidth: 2,
      borderRadius: 6,
    }]
  },
  options: {
    responsive: true,
    plugins: { legend: { display: false } },
    scales: {
      y: { beginAtZero: true, title: { display: true, text: 'ms' } }
    }
  }
});

// Pie Chart
new Chart(document.getElementById('pieChart'), {
  type: 'doughnut',
  data: {
    labels: ['Success', 'Error'],
    datasets: [{
      data: [${successRateV}, ${errorRateV}],
      backgroundColor: ['rgba(40,167,69,0.8)', 'rgba(220,53,69,0.8)'],
      borderColor: ['#28a745', '#dc3545'],
      borderWidth: 2,
    }]
  },
  options: {
    responsive: true,
    plugins: {
      legend: { position: 'bottom' },
      tooltip: {
        callbacks: { label: (ctx) => ctx.label + ': ' + ctx.parsed.toFixed(2) + '%' }
      }
    }
  }
});

// VU Stages Line Chart
new Chart(document.getElementById('stagesChart'), {
  type: 'line',
  data: {
    labels: ['0m','5m','7m','17m','20m','35m','40m','60m'],
    datasets: [{
      label: 'Virtual Users (VU)',
      data: [0, 10, 50, 50, 100, 100, 10, 10],
      borderColor: '${expColor}',
      backgroundColor: '${expColor}22',
      fill: true,
      tension: 0.3,
      pointRadius: 5,
      pointBackgroundColor: '${expColor}',
    }]
  },
  options: {
    responsive: true,
    plugins: { legend: { display: false } },
    scales: {
      y: { beginAtZero: true, title: { display: true, text: 'VU Count' } },
      x: { title: { display: true, text: 'Waktu' } }
    }
  }
});
</script>
</body>
</html>`;
}

// ============================================================
//  HELPERS
// ============================================================

function wibTime(date) {
  const wib = new Date(date.getTime() + 7 * 60 * 60 * 1000);
  return wib.toISOString().replace('T', ' ').substring(0, 19) + ' WIB';
}

function wibFromISO(isoStr) {
  return wibTime(new Date(isoStr));
}