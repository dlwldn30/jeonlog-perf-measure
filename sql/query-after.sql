SELECT t.id FROM (
  SELECT e.id,
    (SELECT COUNT(*) FROM exhibition_click_logs ecl WHERE ecl.exhibition_id = e.id AND ecl.clicked_date BETWEEN '2026-09-13' AND '2026-10-13') AS c,
    (SELECT COUNT(*) FROM bookmarks b WHERE b.exhibition_id = e.id AND b.created_at BETWEEN '2026-09-13 12:00:00' AND '2026-10-13 12:00:00') AS b
  FROM exhibitions e WHERE e.end_date >= '2026-10-13'
) t
ORDER BY (t.c * 1.0 + t.b * 1.0) DESC, t.b DESC, t.c DESC, t.id DESC
LIMIT 10;
