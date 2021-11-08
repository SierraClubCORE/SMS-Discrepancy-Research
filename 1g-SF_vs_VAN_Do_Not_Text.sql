-- VAN pt 1
CREATE LOCAL TEMPORARY TABLE step1 AS
SELECT 
statecode, myc_vanid, result_name, datetimecreated
FROM sc_analytics.van_contact_history_myc
WHERE result_name = 'Do Not Text';

CREATE LOCAL TEMPORARY TABLE step2 AS
SELECT p.statecode,
	p.contactsphoneid,
	p.vanid,
	p.phone,
	p.datesuppressed,
	DATEDIFF ( minute, p.datecreated, s.datetimecreated) AS minute_difference,
	p.datecreated,
	p.createdby,
	p.sourcename,
	p.datemodified,
	p.phonetypeid,
	p.iscellstatusid,
	p.countrycode,
	p.internationaldialingprefix,
	p.createdbycommitteeid
FROM step1 s
LEFT JOIN sc_van_staging.tsm_sc_phonesdelta_myc p ON
	s.statecode = p.statecode and
	s.myc_vanid = p.vanid;

	
CREATE LOCAL TEMPORARY TABLE step3 AS	
SELECT statecode,
	vanid,
	MIN(minute_difference) AS min_minute_difference
FROM step2
GROUP BY 1,2
ORDER BY vanid;

CREATE LOCAL TEMPORARY TABLE step4 AS
SELECT
	a.statecode,
	a.vanid,
	a.phone,
	a.datesuppressed,
	a.minute_difference,
	sign(minute_difference) AS sign_minute_difference,
	a.datecreated,
	a.createdby,
	a.sourcename,
	a.datemodified,
	a.phonetypeid,
	a.iscellstatusid,
	a.countrycode,
	a.internationaldialingprefix,
	a.createdbycommitteeid
FROM step2 a
JOIN step3 b ON
	a.statecode = b.statecode AND
	a.vanid = b.vanid AND
	a.minute_difference = b.min_minute_difference;

CREATE LOCAL TEMPORARY TABLE step5 AS
SELECT 
	a.statecode,
	a.myc_vanid,
	a.result_name,
	b.phone,
	count(*)
FROM step1 a
LEFT JOIN step4 b ON
	a.myc_vanid = b.vanid AND
	a.statecode = b.statecode
  WHERE b.sign_minute_difference = '1'
GROUP BY 1,2,3,4;

CREATE LOCAL TEMPORARY TABLE step6 AS
SELECT
	statecode,
	myc_vanid,
	result_name,
	phone
FROM step5;

--VAN pt2
CREATE TEMPORARY TABLE vanstep1 AS
SELECT 
  phone, statecode,
  CASE WHEN result_name = 'Do Not Text' THEN '1' ELSE '0' END AS van_optout
FROM step6
;

CREATE TEMPORARY TABLE vanstep2 AS
SELECT 
  phone, statecode, 
  sum(van_optout) AS van_optout
FROM vanstep1
GROUP BY 1,2
ORDER BY 3 DESC;

CREATE TEMPORARY TABLE vanstep3 AS
SELECT 
  phone, 
  sum(van_optout) AS van_optout,
  count(statecode) AS total_states
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
