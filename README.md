# jeonlog-perf-measure

전록(Jeonlog) 백엔드의 **인기 전시 집계 API**(`GET /api/recommendations/popular`) 성능 개선을 재현하는 측정 자료입니다.
포트폴리오에 적은 수치(1.3초 → 0.08초, p95 33초 → 2.6초 → 0.12초)의 원본 스크립트와 결과를 담았습니다.

- 대상 코드: [Team-Jeonlog/Jeonlog-Backend](https://github.com/Team-Jeonlog/Jeonlog-Backend)
- 서비스는 2026.09에 운영을 종료했습니다. 아래 측정은 모두 **로컬 환경**에서 한 것이며 운영 수치가 아닙니다.

## 무엇을 비교했나

| 단계 | 코드 | 설명 |
|---|---|---|
| 변경 전 | `1549f07` | 클릭 로그와 북마크를 한 번에 JOIN해 (클릭 수 × 북마크 수)개의 행이 만들어짐 |
| 쿼리·인덱스 개선 | 브랜치 `perf/popular-ranking-query` (`888fab1`) | 전시별 상관 서브쿼리로 JOIN 곱 제거 + `(exhibition_id, clicked_date)`, `(exhibition_id, created_at)` 복합 인덱스 |
| + 결과 캐시 | `patches/0002-popular-cache.patch` | Caffeine 캐시, TTL 60초, 같은 키가 동시에 만료돼도 집계는 한 번만 실행 |

`patches/0001-...patch`는 `888fab1` 커밋 하나의 변경입니다. 브랜치가 원격에 있으므로 패치 없이 체크아웃해도 됩니다.

> 참고: `888fab1`은 `1549f07`보다 뒤의 커밋 위에 만든 브랜치라, 인기 집계와 무관한 다른 변경(클릭 로그 인증 수정 등)도 함께 들어 있습니다. 인기 집계 API는 그 변경들과 관련이 없습니다.

## 결과

### 1. 쿼리 실행 시간 (합성 데이터: 전시 1만 · 클릭 로그 약 40만 · 북마크 약 8만)

| 단계 | 방식 | 시간 |
|---|---|---|
| 변경 전 | 실제 Hibernate 쿼리 5회 중앙값, N=3 | 1,314 / 1,295 / 1,299ms |
| 변경 후 | 같은 방식 | 79 / 73 / 90ms |
| 분해 (SQL 직접 실행) | 인덱스만 / 쿼리만 / 둘 다 | 745ms / 180ms / 63ms |

`EXPLAIN ANALYZE` (인덱스를 `INVISIBLE`로 바꿔 변경 전 상태를 재현):

| 단계 | 시간 | 핵심 |
|---|---|---|
| 변경 전 쿼리 | 1,509ms | Nested loop join 결과 **624,012행** |
| 쿼리만 변경 | 235ms | 서브쿼리 2개, 단일 컬럼 인덱스 조회 |
| 쿼리 + 복합 인덱스 | 93ms | 두 서브쿼리 모두 **Covering index lookup** |

복합 인덱스의 효과는 날짜 범위로 좁혀 읽는 것이 아니라, 테이블 행을 읽지 않고 인덱스만으로 세는 커버링 조회입니다.

### 2. 동시 부하 (k6, 가상 사용자 10 → 30명, 60초, 각 3회)

| 단계 | p95 (회차별) | 처리량 (회차별) | 오류 |
|---|---|---|---|
| 변경 전 | 33.11s / 30.16s / 33.48s | 0.93 / 1.14 / 0.83 req/s | 0건 |
| 쿼리·인덱스 개선 | 2.63s / 3.56s / 2.02s | 12.5 / 12.9 / 20.2 req/s | 0건 |
| + Caffeine 캐시 | 134ms / 78ms / 116ms | 397 / 617 / 493 req/s | 0건 |

요약(중앙값): p95 약 33초 → 약 2.6초 → 약 0.12초, 처리량 약 0.9 → 약 12.9 → 약 490 req/s.
캐시 단계의 수치는 DB가 아니라 앱 자체의 처리 한계에 가깝습니다. 회차별 원본은 [`results/k6-summary.md`](results/k6-summary.md)에 있습니다.

## 재현 방법

필요: Docker, JDK 21, [k6](https://k6.io), Python 3.

```bash
# 1. MySQL 8.0
docker run -d --name popular-db -e MYSQL_ROOT_PASSWORD=pw -e MYSQL_DATABASE=pop_measure -p 33307:3306 mysql:8.0

# 2. 대상 코드 체크아웃 (변경 전 / 변경 후)
git clone https://github.com/Team-Jeonlog/Jeonlog-Backend.git && cd Jeonlog-Backend
git checkout 1549f07                      # 변경 전
# git checkout perf/popular-ranking-query # 변경 후
# git apply ../jeonlog-perf-measure/patches/0002-popular-cache.patch   # 캐시 추가 시

# 3. 스키마 생성 후 합성 데이터 적재
#    (엔티티로 스키마만 만드는 측정 테스트: scripts/PopularQueryMeasureTest.java를
#     src/test/java/com/jeonlog/exhibition_recommender/measure/ 에 복사)
DDL=create MODE=schema ./gradlew test --tests '*PopularQueryMeasureTest*'
docker exec -i popular-db mysql -uroot -ppw pop_measure < ../jeonlog-perf-measure/sql/seed.sql

# 4. 앱 실행 (측정용 더미 환경변수)
source ../jeonlog-perf-measure/scripts/env.example
./gradlew bootJar -x test
SERVER_PORT=8081 java -jar build/libs/exhibition_recommender-0.0.1-SNAPSHOT.jar

# 5. k6 실행
TOKEN=$(python3 ../jeonlog-perf-measure/scripts/make-token.py)
BASE=http://localhost:8081 TOKEN=$TOKEN k6 run ../jeonlog-perf-measure/k6/popular.js
```

`sql/query-before.sql`, `sql/query-after.sql` 앞에 `EXPLAIN ANALYZE`를 붙여 실행 계획을 볼 수 있습니다.

### 참고
- `sql/seed.sql`은 기준 날짜를 `2026-10-13`으로 고정합니다. 앱은 현재 날짜 기준으로 조회하므로, 다른 날짜에 재현할 때는 `@today` 값을 오늘 날짜로 바꾸세요.
- 변경 전·후를 같은 DB에서 번갈아 측정할 때는 복합 인덱스를 `ALTER TABLE ... ALTER INDEX ... INVISIBLE`로 숨기고 단일 `exhibition_id` 인덱스를 임시로 추가해 변경 전 상태를 만들었습니다.
- 위 절차는 제 환경에서 측정한 순서를 정리한 것입니다. 처음부터 새 환경에서 다시 돌려 검증한 것은 아닙니다.

## 한계
- 한 대의 PC에서 k6, 앱, MySQL(Docker)을 함께 실행했습니다. 처리량은 회차 편차가 큽니다.
- 데이터는 합성입니다(전시 인기 분포는 `POW(RAND(), 2)`로 쏠리게 했습니다).
- 캐시는 인스턴스 로컬이라 서버마다 따로 유지되고, 최대 60초 지난 순위가 보일 수 있습니다. 서비스 종료로 운영에는 반영하지 않았습니다.

## 구성
```
patches/   변경 코드 (쿼리·인덱스 개선, 캐시)
sql/       합성 데이터 시드, 변경 전·후 쿼리
k6/        부하 테스트 스크립트
scripts/   JWT 생성, 더미 환경변수, 스키마 생성·측정용 테스트
results/   k6 회차별 결과
```
