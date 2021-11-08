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
SELECT a.phone, a.hustle_sms_status, b.sf_sms_status
FROM hstep4 a
JOIN sfstep4 b
ON a.phone = b.phone
WHERE b.sf_sms_status <> a.hustle_sms_status;
