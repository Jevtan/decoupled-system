import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const BASE_URL = __ENV.TARGET_URL || 'http://webinar-alb-773308983.us-east-1.elb.amazonaws.com';

const registrationErrors = new Counter('registration_errors');
const successRate = new Rate('success_rate');
const responseTime = new Trend('response_time_ms', true);

export const options = {
  scenarios: {
    flash_crowd: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '5m', target: 10 },
        { duration: '2m', target: 50 },
        { duration: '10m', target: 50 },
        { duration: '3m', target: 100 },
        { duration: '15m', target: 100 },
        { duration: '5m', target: 10 },
        { duration: '20m', target: 10 },
      ],
    },
  },
  thresholds: {
    'http_req_duration': ['p(95)<3000'],
    'success_rate': ['rate>0.95'],
  },
};

export default function () {
  const userId = `user_${Math.floor(Math.random() * 100000)}`;
  const payload = JSON.stringify({
    user_id: userId,
    webinar_id: 'webinar_1',
    name: `Test User ${userId}`,
    email: `${userId}@test.com`,
  });

  const params = { headers: { 'Content-Type': 'application/json' } };
  const res = http.post(`${BASE_URL}/register`, payload, params);

  successRate.add(res.status >= 200 && res.status < 300);
  check(res, { 'status 2xx': (r) => r.status >= 200 && r.status < 300 });

  sleep(Math.random() * 2 + 1);
}
