-- 실제 엔티티 스키마(pop_measure)에 합성 데이터 적재: 전시 1만, 클릭 로그 약 40만 시도, 북마크 약 8만 시도, 사용자 3만
SET SESSION cte_max_recursion_depth = 1000000;
SET @today = '2026-10-13';
INSERT INTO venues (id, name, type) VALUES (1, 'venue-1', 'GALLERY');
INSERT INTO users (id, name, oauth_id, oauth_provider, role, moderation_strike, permanently_banned)
WITH RECURSIVE s(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM s WHERE n<30000)
SELECT n, CONCAT('u', n), CONCAT('oid', n), 'GOOGLE', 'USER', 0, b'0' FROM s;
INSERT INTO exhibitions (id, venue_id, title, description, location, poster_url, start_date, end_date, price, is_free,
                         exhibition_theme, genre, contact, website, viewing_time, personalized_poster_url, general_recommendations_poster_url)
WITH RECURSIVE s(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM s WHERE n<10000)
SELECT n, 1, CONCAT('ex-', n), 'd', 'loc', 'p',
       DATE_SUB(@today, INTERVAL 30 DAY),
       IF(n % 3 = 0, DATE_ADD(@today, INTERVAL 1+(n%50) DAY), DATE_SUB(@today, INTERVAL 1+(n%200) DAY)),
       0, b'1', 'CASUAL_VISIT', 'PAINTING', 'c', 'w', 't', 'pp', 'gp'
FROM s;
INSERT IGNORE INTO exhibition_click_logs (user_id, exhibition_id, clicked_date)
WITH RECURSIVE s(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM s WHERE n<400000)
SELECT 1+FLOOR(RAND()*30000), 1+FLOOR(10000*POW(RAND(),2)), DATE_SUB(@today, INTERVAL FLOOR(RAND()*60) DAY) FROM s;
INSERT IGNORE INTO bookmarks (user_id, exhibition_id, created_at, notify_enabled)
WITH RECURSIVE s(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM s WHERE n<80000)
SELECT 1+FLOOR(RAND()*30000), 1+FLOOR(10000*POW(RAND(),2)), DATE_SUB(CONCAT(@today,' 12:00:00'), INTERVAL FLOOR(RAND()*60*86400) SECOND), b'0' FROM s;
ANALYZE TABLE exhibitions, exhibition_click_logs, bookmarks;
