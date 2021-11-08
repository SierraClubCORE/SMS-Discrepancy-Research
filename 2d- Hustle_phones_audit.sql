CREATE TEMPORARY TABLE step1 AS
SELECT 
  	right(phone_number, 10) as phone, 
  	global_opted_out, 
  	updated_at,
  	COUNT(*)
FROM sc_analytics.hustle_leads
WHERE phone_number IS NOT NULL
GROUP BY 1,2,3;

CREATE TEMPORARY TABLE step2 AS
SELECT 
    phone, 
    updated_at,
    CASE WHEN global_opted_out = 't' THEN '1' ELSE '0' END AS opted_out,
    CASE WHEN global_opted_out = 'f' THEN '1' ELSE '0' END AS opted_in,
    CASE WHEN global_opted_out = 't' THEN 'Opt-Out' ELSE 'Opt-In' END AS global_opted_out
FROM step1
;

CREATE TEMPORARY TABLE step3 AS
SELECT 
  phone, 
  sum(opted_out) AS opted_out, 
  sum(opted_in) AS opted_in,
  count(*) AS total_instances
  FROM step2
GROUP BY 1
ORDER BY 4 DESC;

CREATE TEMPORARY TABLE step4 AS
SELECT 
  phone,
  MAX(updated_at) AS latest_update
FROM step2
GROUP BY 1;

CREATE TEMPORARY TABLE step5 AS
SELECT a.phone, a.latest_update, b.global_opted_out AS latest_status
FROM step4 a
LEFT JOIN step2 b
	ON a.phone = b.phone
  AND a.latest_update = b.updated_at;

CREATE TEMPORARY TABLE step6 AS
SELECT a.phone, b.latest_status, b.latest_update, a.opted_out, a.opted_in, a.total_instances
FROM step3 a
LEFT JOIN step5 b
  ON a.phone = b.phone
ORDER BY 6 DESC;

SELECT phone, opted_out, opted_in, total_instances, latest_update, latest_status
FROM step6
WHERE opted_out > 0 AND opted_in > 0
GROUP BY 1,2,3,4,5,6
ORDER BY 4 DESC;
