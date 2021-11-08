--VAN
CREATE TEMPORARY TABLE vanstep1 AS
SELECT 
  phone, statecode,
  CASE WHEN (phoneoptinstatusid = '1' AND committeeid = '56610') THEN '1' ELSE '0' END AS van_optinc4, 
  CASE WHEN (phoneoptinstatusid = '1' AND committeeid = '57277') THEN '1' ELSE '0' END AS van_optinc3, 
  CASE WHEN (phoneoptinstatusid = '2' AND committeeid = '56610') THEN '1' ELSE '0' END AS van_unknownc4, 
  CASE WHEN (phoneoptinstatusid = '2' AND committeeid = '57277') THEN '1' ELSE '0' END AS van_unknownc3, 
  CASE WHEN (phoneoptinstatusid = '3' AND committeeid = '56610') THEN '1' ELSE '0' END AS van_optoutc4,
  CASE WHEN (phoneoptinstatusid = '3' AND committeeid = '57277') THEN '1' ELSE '0' END AS van_optoutc3,
  CASE WHEN phone IS NOT NULL THEN '1' ELSE '0' END AS instance
FROM sc_van_staging.tsm_sc_phonesoptins
;

CREATE TEMPORARY TABLE vanstep2 AS
SELECT 
  phone, statecode, 
  sum(van_optinc4) AS van_optinc4, 
  sum(van_optinc3) AS van_optinc3, 
  sum(van_unknownc4) AS van_unknownc4, 
  sum(van_unknownc3) AS van_unknownc3, 
  sum(van_optoutc4) AS van_optoutc4, 
  sum(van_optoutc3) AS van_optoutc3, 
  sum(instance) AS total_instances
FROM vanstep1
GROUP BY 1,2
ORDER BY 3 DESC;

CREATE TEMPORARY TABLE vanstep3 AS
SELECT 
  phone, 
  (sum(van_optinc4) + sum(van_optinc3)) as van_optin,
  (sum(van_unknownc4) +
  sum(van_unknownc3) +
  sum(van_optoutc4) +
  sum(van_optoutc3)) AS van_optout,
  sum(total_instances) AS total_instances
FROM vanstep2
GROUP BY 1;

CREATE TEMPORARY TABLE vanstep4 AS
SELECT 
  phone, 
  CASE WHEN van_optout > 0 THEN 'Opt-Out' ELSE 'Opt-In' END AS van_sms_status
FROM vanstep3;



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
SELECT a.phone, a.van_sms_status, b.hustle_sms_status
FROM vanstep4 a
JOIN hstep4 b
ON a.phone = b.phone
WHERE a.van_sms_status <> b.hustle_sms_status;
