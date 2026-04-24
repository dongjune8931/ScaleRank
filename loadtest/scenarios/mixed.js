import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'https://scalerank.example.com';
const errorRate = new Rate('error_rate');
const writeDuration = new Trend('write_duration');
const readDuration = new Trend('read_duration');
const writeCount = new Counter('write_requests');
const readCount = new Counter('read_requests');

export const options = {
  stages: [
    { duration: '1m',  target: 1000 },
    { duration: '2m',  target: 3000 },
    { duration: '3m',  target: 5000 },
    { duration: '3m',  target: 5000 },
    { duration: '1m',  target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<300', 'p(99)<500'],
    error_rate: ['rate<0.01'],
  },
};

export default function () {
  if (Math.random() < 0.2) {
    // Write: 20%
    const userId = `user:${Math.floor(Math.random() * 100000) + 1}`;
    const score = Math.floor(Math.random() * 1000000);
    const res = http.post(
      `${BASE_URL}/api/scores`,
      JSON.stringify({ userId, score }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    writeDuration.add(res.timings.duration);
    writeCount.add(1);
    errorRate.add(res.status !== 201);
    check(res, { 'write 201': (r) => r.status === 201 });
  } else {
    // Read: 80%
    if (Math.random() < 0.6) {
      const limit = [10, 50, 100][Math.floor(Math.random() * 3)];
      const res = http.get(`${BASE_URL}/api/rankings/top?limit=${limit}`);
      readDuration.add(res.timings.duration);
      readCount.add(1);
      errorRate.add(res.status !== 200);
      check(res, { 'read top 200': (r) => r.status === 200 });
    } else {
      const userId = `user:${Math.floor(Math.random() * 100000) + 1}`;
      const res = http.get(`${BASE_URL}/api/rankings/${encodeURIComponent(userId)}`);
      readDuration.add(res.timings.duration);
      readCount.add(1);
      errorRate.add(res.status !== 200 && res.status !== 404);
      check(res, { 'read user 200/404': (r) => r.status === 200 || r.status === 404 });
    }
  }
  sleep(0.05);
}
