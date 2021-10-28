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
    global_opted_out
FROM sc_analytics.hustle_leads
WHERE phone_number IS NOT NULL;

CREATE TEMPORARY TABLE hstep2 AS 
SELECT 
    phone, 
    CASE WHEN global_opted_out = 't' THEN '1' ELSE '0' END AS opted_out,
    CASE WHEN global_opted_out = 'f' THEN '1' ELSE '0' END AS opted_in
FROM hstep1;

CREATE TEMPORARY TABLE hstep3 AS 
SELECT 
  phone, 
  sum(opted_out) AS opted_out, 
  sum(opted_in) AS opted_in,
  count(*) AS total_instances
FROM hstep2
GROUP BY 1
ORDER BY 4 DESC;

CREATE TEMPORARY TABLE hstep4 AS 
SELECT 
  phone, 
  CASE WHEN opted_out > 0 THEN 'Opt-Out' ELSE 'Opt-In' END AS hustle_sms_status
FROM hstep3;

-- JOIN
SELECT a.phone, a.mc_sms_status, b.hustle_sms_status
FROM mcstep4 a
LEFT JOIN hstep4 b
ON a.phone = b.phone
WHERE a.mc_sms_status <> b.hustle_sms_status;
