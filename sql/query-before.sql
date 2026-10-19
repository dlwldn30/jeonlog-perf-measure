SELECT e.id
FROM exhibitions e
LEFT JOIN exhibition_click_logs ecl ON ecl.exhibition_id = e.id AND ecl.clicked_date BETWEEN '2026-09-13' AND '2026-10-13'
LEFT JOIN bookmarks b ON b.exhibition_id = e.id AND b.created_at BETWEEN '2026-09-13 12:00:00' AND '2026-10-13 12:00:00'
WHERE e.end_date >= '2026-10-13'
GROUP BY e.id
ORDER BY (COUNT(DISTINCT ecl.id) * 1.0 + COUNT(DISTINCT b.id) * 1.0) DESC, COUNT(DISTINCT b.id) DESC, COUNT(DISTINCT ecl.id) DESC, e.id DESC
LIMIT 10;
