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

CREATE TEMPORARY TABLE step3 AS
SELECT 
  phone, 
  sum(van_optinc4) AS van_optinc4, 
  sum(van_optinc3) AS van_optinc3, 
  sum(van_unknownc4) AS van_unknownc4, 
  sum(van_unknownc3) AS van_unknownc3, 
  sum(van_optoutc4) AS van_optoutc4, 
  sum(van_optoutc3) AS van_optoutc3, 
  count(statecode) AS total_states, 
  sum(total_instances) AS total_instances
FROM step2
GROUP BY 1
ORDER BY 8 DESC;

CREATE TEMPORARY TABLE step4 AS
SELECT *
FROM step3
WHERE (van_optinc4 > 0 
       OR van_optinc3 > 0) AND (
  van_unknownc3 > 0 OR 
  van_unknownc4 > 0 OR 
  van_optoutc4 > 0 OR 
  van_optoutc3 > 0)
  ORDER BY 9 DESC;

CREATE TEMPORARY TABLE step5 AS
  SELECT b.statecode, b.phone, b.committeeid, b.phoneoptinstatusid,  b.createdby, b.datecreated, b.modifiedby, b.datemodified, b.internaldatemodified, a.total_instances
  FROM step4 a
  JOIN sc_van_staging.tsm_sc_phonesoptins b
  	ON a.phone = b.phone
  ORDER BY a.phone, b.statecode;
 
SELECT a.statecode, a.phone, b.committeename, c.phoneoptinstatusname, d.username AS createdby, a.datecreated, e.username AS modifiedby, a.datemodified, a.internaldatemodified, a.total_instances
FROM step5 a
JOIN sc_van_staging.tsm_sc_committees b
	ON a.committeeid = b.committeeid
JOIN sc_van_staging.tsm_sc_phoneoptinstatuses c
	ON a.phoneoptinstatusid = c.phoneoptinstatusid
JOIN sc_van_staging.tsm_sc_users d
	ON a.createdby = d.userid
JOIN sc_van_staging.tsm_sc_users e
	ON a.modifiedby = e.userid
ORDER BY a.phone, a.statecode, a.committeeid
