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

--Salesforce
CREATE TEMPORARY TABLE sfstep1 AS
SELECT 
  REPLACE(REPLACE(REPLACE(REPLACE(phone, '(', ''),')',''), ' ',''),'-','') AS phone, 
  mobile_commons_outreach_preference__c, 
  lastmodifieddate
FROM sc_analytics.salescloud_contact_w_source
WHERE phone IS NOT NULL;

CREATE TEMPORARY TABLE sfstep2 AS
SELECT 
  phone, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-In' THEN '1' ELSE '0' END AS mcop_OptIn, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-In Failed' THEN '1' ELSE '0' END AS mcop_OptIn_Failed, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-In Requested' THEN '1' ELSE '0' END AS mcop_OptIn_Requested, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-Out' THEN '1' ELSE '0' END AS mcop_OptOut, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-Out Requested' THEN '1' ELSE '0' END AS mcop_OptOut_Requested,
  CASE WHEN mobile_commons_outreach_preference__c IS NULL THEN '1' ELSE '0' END AS mcop_null
FROM sfstep1
;

CREATE TEMPORARY TABLE sfstep3 AS
SELECT 
  phone, 
  sum(mcop_OptIn) AS mcop_optin, 
  (sum(mcop_OptIn_Failed) +
  sum(mcop_OptIn_Requested) +
  sum(mcop_OptOut) +
  sum(mcop_OptOut_Requested) +
  sum(mcop_null)) AS mcop_optout,
  count(*) AS total_instances
FROM sfstep2
GROUP BY 1;

CREATE TEMPORARY TABLE sfstep4 AS
SELECT 
  phone, 
  CASE WHEN mcop_optout > 0 THEN 'Opt-Out' ELSE 'Opt-In' END AS sf_sms_status
FROM sfstep3;


-- JOIN
SELECT a.phone, a.van_sms_status, b.sf_sms_status
FROM vanstep4 a
JOIN sfstep4 b
ON a.phone = b.phone
WHERE a.van_sms_status <> b.sf_sms_status;
