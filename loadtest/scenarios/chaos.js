import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'https://scalerank.example.com';
const errorRate = new Rate('error_rate');

export const options = {
  stages: [
    { duration: '1m',  target: 1000 },  // ramp up
    { duration: '2m',  target: 1000 },  // steady — kill score-service pod here
    { duration: '2m',  target: 1000 },  // observe recovery
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    error_rate: ['rate<0.05'],  // allow up to 5% errors during chaos
    http_req_duration: ['p(99)<1000'],
  },
};

export function setup() {
  console.log('=== CHAOS TEST START ===');
  console.log('At ~90s mark, run:');
  console.log('  kubectl delete pod -l app=score-service -n scalerank --wait=false');
  console.log('Watch error_rate and pod recovery in Grafana.');
}

export default function () {
  if (Math.random() < 0.2) {
    const userId = `user:${Math.floor(Math.random() * 100000) + 1}`;
    const score = Math.floor(Math.random() * 1000000);
    const res = http.post(
      `${BASE_URL}/api/scores`,
      JSON.stringify({ userId, score }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    errorRate.add(res.status !== 201);
    check(res, { 'write ok': (r) => r.status === 201 });
  } else {
    const limit = 100;
    const res = http.get(`${BASE_URL}/api/rankings/top?limit=${limit}`);
    errorRate.add(res.status !== 200);
    check(res, { 'read ok': (r) => r.status === 200 });
  }
  sleep(0.1);
}
