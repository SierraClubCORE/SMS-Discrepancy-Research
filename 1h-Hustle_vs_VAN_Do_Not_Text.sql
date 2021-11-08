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
