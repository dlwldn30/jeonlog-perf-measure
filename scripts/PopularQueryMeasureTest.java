package com.jeonlog.exhibition_recommender.measure;

import com.jeonlog.exhibition_recommender.recommendation.repository.PopularRecommendationRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * 인기 추천 쿼리 전/후 측정용 (전/후 worktree에 동일 파일 배치, 판정 없이 측정값만 출력).
 * - 외부 MySQL(localhost:33307/pop_measure)에 붙고, DDL 환경변수로 스키마 모드를 정한다.
 *   MODE=schema DDL=create  : 엔티티로 스키마만 생성
 *   MODE=measure DDL=none   : 이미 적재된 데이터로 측정 (후 측정은 DDL=update로 운영과 같은 방식)
 */
@SpringBootTest
class PopularQueryMeasureTest {

  @DynamicPropertySource
  static void registerProps(DynamicPropertyRegistry registry) {
    registry.add("spring.datasource.url", () ->
        "jdbc:mysql://localhost:33307/pop_measure?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Seoul");
    registry.add("spring.datasource.username", () -> "root");
    registry.add("spring.datasource.password", () -> "pw");
    registry.add("spring.datasource.driver-class-name", () -> "com.mysql.cj.jdbc.Driver");
    registry.add("spring.jpa.hibernate.ddl-auto", () -> System.getenv().getOrDefault("DDL", "none"));
    registry.add("spring.jpa.database-platform", () -> "org.hibernate.dialect.MySQLDialect");
    registry.add("spring.jpa.show-sql", () -> "true");
  }

  @Autowired private PopularRecommendationRepository popularRepo;

  @Test
  void measure() {
    if (!"measure".equals(System.getenv().getOrDefault("MODE", "measure"))) return;

    LocalDate today = LocalDate.of(2026, 10, 13);
    LocalDate fromDate = today.minusDays(30);
    LocalDateTime toDt = LocalDateTime.of(2026, 10, 13, 12, 0);
    LocalDateTime fromDt = toDt.minusDays(30);

    List<Long> ids = null;
    for (int i = 0; i < 3; i++) { // 워밍업
      ids = popularRepo.findTopPopularExhibitionIds(today, fromDate, today, fromDt, toDt, 1.0, 1.0, PageRequest.of(0, 10));
    }
    List<Double> ms = new ArrayList<>();
    for (int i = 0; i < 5; i++) {
      long t0 = System.nanoTime();
      ids = popularRepo.findTopPopularExhibitionIds(today, fromDate, today, fromDt, toDt, 1.0, 1.0, PageRequest.of(0, 10));
      ms.add((System.nanoTime() - t0) / 1_000_000.0);
    }
    List<Double> sorted = new ArrayList<>(ms);
    Collections.sort(sorted);
    System.out.println("[MEASURE] runs(ms)=" + ms);
    System.out.println("[MEASURE] median(ms)=" + sorted.get(2));
    System.out.println("[MEASURE] top10=" + ids);
  }
}
