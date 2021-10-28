CREATE TEMPORARY TABLE step1 AS
SELECT 
  REPLACE(REPLACE(REPLACE(REPLACE(phone, '(', ''),')',''), ' ',''),'-','') AS phone, 
  mobile_commons_outreach_preference__c, 
  lastmodifieddate
FROM sc_analytics.salescloud_contact_w_source
WHERE phone IS NOT NULL
;

CREATE TEMPORARY TABLE step2 AS
SELECT 
  phone, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-In' THEN '1' ELSE '0' END AS mcop_OptIn, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-In Failed' THEN '1' ELSE '0' END AS mcop_OptIn_Failed, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-In Requested' THEN '1' ELSE '0' END AS mcop_OptIn_Requested, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-Out' THEN '1' ELSE '0' END AS mcop_OptOut, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-Out Requested' THEN '1' ELSE '0' END AS mcop_OptOut_Requested,
  CASE WHEN mobile_commons_outreach_preference__c IS NULL THEN '1' ELSE '0' END AS mcop_null
FROM step1
;

CREATE TEMPORARY TABLE step3 AS
SELECT 
  phone, 
  sum(mcop_OptIn) AS mcop_optin, 
  (sum(mcop_OptIn_Failed) +
  sum(mcop_OptIn_Requested) +
  sum(mcop_OptOut) +
  sum(mcop_OptOut_Requested) +
  sum(mcop_null)) AS mcop_optout,
  count(*) AS total_instances
FROM step2
GROUP BY 1;

CREATE TEMPORARY TABLE step4 AS
SELECT 
  phone, 
  CASE WHEN mcop_optout > 0 THEN 'Opt-Out' ELSE 'Opt-In' END AS true_sms_status
FROM step3;

CREATE TEMPORARY TABLE step5 AS
SELECT 
  a.id,
  REPLACE(REPLACE(REPLACE(REPLACE(a.phone, '(', ''),')',''), ' ',''),'-','') AS phone_clean,
  CASE WHEN a.mobile_commons_outreach_preference__c = 'Opt-In' THEN 'Opt-In' ELSE 'Opt-Out' END AS sf_mobile_commons_outreach_preference__c, 
  b.true_sms_status
FROM sc_analytics.salescloud_contact_w_source a
JOIN step4 b
	ON REPLACE(REPLACE(REPLACE(REPLACE(a.phone, '(', ''),')',''), ' ',''),'-','') = b.phone
WHERE recordtypeid = '012i0000000xb3DAAQ';
    
SELECT a.id, a.accountid, a.recordtypeid, REPLACE(REPLACE(REPLACE(REPLACE(a.phone, '(', ''),')',''), ' ',''),'-','') AS phone_clean, a.mobile_commons_outreach_preference__c, b.true_sms_status, a.lastname, a.firstname, a.mailingstreet, a.mailingcity, a.mailingstate, a.mailingpostalcode, a.email, a.donotcall
FROM sc_analytics.salescloud_contact_w_source a
JOIN step5 b
	ON a.id = b.id
WHERE b.sf_mobile_commons_outreach_preference__c <> b.true_sms_status
ORDER BY phone
