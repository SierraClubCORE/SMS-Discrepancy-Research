CREATE TEMPORARY TABLE step1 AS
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

CREATE TEMPORARY TABLE step2 AS
SELECT 
  phone, statecode, 
  sum(van_optinc4) AS van_optinc4, 
  sum(van_optinc3) AS van_optinc3, 
  sum(van_unknownc4) AS van_unknownc4, 
  sum(van_unknownc3) AS van_unknownc3, 
  sum(van_optoutc4) AS van_optoutc4, 
  sum(van_optoutc3) AS van_optoutc3, 
  sum(instance) AS total_instances
FROM step1
GROUP BY 1,2
ORDER BY 3 DESC;

SELECT *
FROM step2
WHERE (van_optinc4 > 0 
       OR van_optinc3 > 0) AND (
  van_unknownc3 > 0 OR 
  van_unknownc4 > 0 OR 
  van_optoutc4 > 0 OR 
  van_optoutc3 > 0)
