import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'https://scalerank.example.com';
const errorRate = new Rate('error_rate');
const topDuration = new Trend('top_rankings_duration');
const userDuration = new Trend('user_rank_duration');

export const options = {
  stages: [
    { duration: '30s', target: 500 },
    { duration: '1m',  target: 3000 },
    { duration: '3m',  target: 3000 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(99)<200'],
    error_rate: ['rate<0.01'],
  },
};

export default function () {
  // 70% top rankings, 30% user rank lookup
  if (Math.random() < 0.7) {
    const limit = [10, 50, 100][Math.floor(Math.random() * 3)];
    const res = http.get(`${BASE_URL}/api/rankings/top?limit=${limit}`);
    topDuration.add(res.timings.duration);
    errorRate.add(res.status !== 200);
    check(res, { 'top rankings 200': (r) => r.status === 200 });
  } else {
    const userId = `user:${Math.floor(Math.random() * 100000) + 1}`;
    const res = http.get(`${BASE_URL}/api/rankings/${encodeURIComponent(userId)}`);
    userDuration.add(res.timings.duration);
    errorRate.add(res.status !== 200 && res.status !== 404);
    check(res, { 'user rank 200/404': (r) => r.status === 200 || r.status === 404 });
  }
  sleep(0.05);
}
