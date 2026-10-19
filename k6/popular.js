// 인기 전시 API 부하 테스트: VU를 단계적으로 올려 처리량과 지연을 본다.
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    ramp: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: '10s', target: 10 },
        { duration: '20s', target: 10 },
        { duration: '10s', target: 30 },
        { duration: '20s', target: 30 },
      ],
    },
  },
  summaryTrendStats: ['avg', 'med', 'p(95)', 'max'],
};

export default function () {
  const res = http.get(`${__ENV.BASE}/api/recommendations/popular`, { headers: { Authorization: `Bearer ${__ENV.TOKEN}` } });
  check(res, { '200': (r) => r.status === 200 });
}
