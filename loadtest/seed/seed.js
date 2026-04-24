import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'https://scalerank.example.com';
const TOTAL_USERS = 100000;
const BATCH_SIZE = 500;

export const options = {
  vus: 50,
  iterations: TOTAL_USERS,
};

export default function () {
  const userId = `user:${__ITER + 1}`;
  const score = Math.floor(Math.random() * 1000000);

  const res = http.post(
    `${BASE_URL}/api/scores`,
    JSON.stringify({ userId, score }),
    { headers: { 'Content-Type': 'application/json' } }
  );

  check(res, { 'seed success': (r) => r.status === 201 });
}
