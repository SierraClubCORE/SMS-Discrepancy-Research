--Mobile Commons
CREATE TEMPORARY TABLE mcstep1 AS 
SELECT
  right(phone_number, 10) as phone, 
    opted_out_at
FROM sc_mobilecommons_staging.profiles
WHERE phone_number IS NOT NULL;

CREATE TEMPORARY TABLE mcstep2 AS 
SELECT 
    phone, 
    CASE WHEN opted_out_at IS NOT NULL THEN '1' ELSE '0' END AS opted_out,
    CASE WHEN opted_out_at IS NULL THEN '1' ELSE '0' END AS opted_in
FROM mcstep1;

CREATE TEMPORARY TABLE mcstep3 AS 
SELECT 
  phone, 
  sum(opted_out) AS opted_out, 
  sum(opted_in) AS opted_in,
  count(*) AS total_instances
FROM mcstep2
GROUP BY 1
ORDER BY 4 DESC;

CREATE TEMPORARY TABLE mcstep4 AS 
SELECT 
  phone, 
  CASE WHEN opted_out > 0 THEN 'Opt-Out' ELSE 'Opt-In' END AS mc_sms_status
FROM mcstep3;

--Hustle
CREATE TEMPORARY TABLE hstep1 AS 
SELECT
    right(phone_number, 10) as phone, 
    global_opted_out, 
    updated_at,
    COUNT(*)
FROM sc_analytics.hustle_leads
WHERE phone_number IS NOT NULL
GROUP BY 1,2,3;

CREATE TEMPORARY TABLE hstep2 AS 
SELECT 
    phone, updated_at,
    CASE WHEN global_opted_out = 't' THEN 'Opt-Out' ELSE 'Opt-In' END AS hustle_sms_status
FROM hstep1
;

CREATE TEMPORARY TABLE hstep3 AS
SELECT 
  phone,
  MAX(updated_at) AS latest_update
FROM hstep1
GROUP BY 1;

CREATE TEMPORARY TABLE hstep4 AS
SELECT a.phone, a.latest_update, b.hustle_sms_status
FROM hstep3 a
LEFT JOIN hstep2 b
  ON a.phone = b.phone
  AND a.latest_update = b.updated_at;


-- JOIN
SELECT a.phone, a.mc_sms_status, b.hustle_sms_status
FROM mcstep4 a
JOIN hstep4 b
ON a.phone = b.phone
WHERE a.mc_sms_status <> b.hustle_sms_status;
