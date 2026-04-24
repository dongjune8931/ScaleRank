import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'https://scalerank.example.com';
const errorRate = new Rate('error_rate');
const scoreDuration = new Trend('score_submit_duration');

export const options = {
  stages: [
    { duration: '30s', target: 200 },
    { duration: '1m',  target: 1000 },
    { duration: '3m',  target: 1000 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(99)<500'],
    error_rate: ['rate<0.01'],
  },
};

export default function () {
  const userId = `user:${Math.floor(Math.random() * 100000) + 1}`;
  const score = Math.floor(Math.random() * 1000000);

  const res = http.post(
    `${BASE_URL}/api/scores`,
    JSON.stringify({ userId, score }),
    { headers: { 'Content-Type': 'application/json' } }
  );

  errorRate.add(res.status !== 201);
  scoreDuration.add(res.timings.duration);
  check(res, { 'status 201': (r) => r.status === 201 });
  sleep(0.1);
}
