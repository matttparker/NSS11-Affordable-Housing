-- Correcting the dataset
--INSERT INTO property_updated
--DELETE FROM property
--WHERE assessdate >= DATE('2021-01-01')



-- Used to generate the file assessment.csv

WITH 
	sfh AS 
		(SELECT apn FROM property_updated WHERE ludesc = 'SINGLE FAMILY'),
	addr AS
		(SELECT apn, propaddr, propcity, propzip, council, taxdist
		FROM property_updated),
	appr AS 
			((SELECT apn, assessdate, landappr, imprappr, totlappr 
			FROM property_updated
			WHERE apn IN (SELECT * FROM sfh))
		UNION ALL
			(SELECT apn, assessdate, landappr, imprappr, totlappr
			FROM property
			WHERE apn IN (SELECT * FROM sfh))
		UNION ALL 
			(SELECT 
				apn,
				effectivedate AS assessdate,
				landapprvalue AS landappr,
				improveapprvalue AS imprapp,
				totalapprvalue AS totlappr
			FROM assessment 
			WHERE apn in (SELECT * FROM sfh)))
	SELECT *
	FROM appr
	NATURAL JOIN addr
ORDER BY apn ASC, assessdate DESC;

SELECT *
FROM assessment
LIMIT 20

SELECT permittype, permitsubtype, COUNT(*)
FROM permit
GROUP BY permittype, permitsubtype
ORDER BY COUNT DESC
LIMIT 100


-- Largest Landowners (by quantity)
SELECT ownername
	, COUNT(o.*) AS num_properties
	, ROUND(AVG(o.saleamount), 0) AS avg_purchase
	, ROUND(AVG(pu.totlappr), 0) AS avg_appraised
	, ROUND(AVG(a.year_built), 2) AS avg_year_built
	, ROUND(AVG(a.square_footage), 2) AS avg_sq_foot
	, ROUND (AVG(pu.totlappr) / NULLIF(AVG(a.square_footage), 0), 2) AS avg_price_per_sq_foot
FROM owner AS o
JOIN property_updated AS pu
USING (apn)
JOIN attributes AS a
USING (apn)
GROUP BY o.ownername
ORDER BY num_properties DESC
LIMIT 100

--Oners not in TN
SELECT COUNT(*)
FROM owner
WHERE owneraddress NOT LIKE '%TN%'

--Owned by MDHA
SELECT pu.featuretype
	, a.property_type
	, pu.owner
	, pu.owndate
	, pu.saleprice
	, pu.totlappr
	, pu.landappr
	, pu.totlappr
	, pu.propaddr
	, pu.legaldesc
	, pu.ludesc
	, pu.acres
	, a.square_footage
FROM owner AS o
JOIN property_updated AS pu
USING (apn)
JOIN attributes AS a
USING (apn)
WHERE ownername = 'M. D. H. A.'
ORDER BY pu.totlappr DESC
LIMIT 50



--2. Affordable housing can disappear in a number of ways. 
--It can occur from existing home prices increasing, but can also occur when older, affordable 
--housing is demolished and replaced with more expensive housing. 
--What areas have seen a large number of instances of this?

--Find homes with significant building permits
WITH residential_permits AS (
	SELECT p.apn, p.location, EXTRACT(YEAR FROM p.dateissued) AS permit_year
	FROM permit AS p
	INNER JOIN
		(SELECT apn, MAX(dateissued) AS recent_permit
		 FROM permit
		 GROUP BY apn
		 ) AS sub
		 USING (apn)
	WHERE p.apn = sub.apn
	AND p.permittype IN (--'BUILDING RESIDENTIAL - ADDITION', 
						 'BUILDING RESIDENTIAL - NEW'--, 
						 --'BUILDING RESIDENTIAL - REHAB'
						)
	AND p.status NOT IN ('EXPIRED'
					  , 'REJECTED'
					  , 'PENDING'
					  , 'WITHDRAWN'
					  , 'CNCL'
					  , 'REFUNDED'
					  , 'NOT GRANTD'
					  , 'REVOKED'
					  , 'CHANCERY'
					  , 'INREVIEW'
					  , 'REQUESTED'
					  , 'IGNORE')
	AND p.dateissued IS NOT NULL
), oldest_record AS (
	--Pull out oldest record for an apn
	SELECT a.apn
		, EXTRACT(YEAR FROM a.effectivedate) AS oldest_year
		, a.totalapprvalue AS original_appr
	FROM assessment AS a
	INNER JOIN
		(SELECT apn, MIN(effectivedate) AS first_assessment
		FROM assessment
		GROUP BY apn
		) AS sub
		USING (apn)
	WHERE a.apn = sub.apn
	AND a.effectivedate = sub.first_assessment
	AND class = 'R'
), cte AS (
SELECT rp.apn
	, o.oldest_year
	, rp.permit_year
	, rp.permit_year - o.oldest_year AS change_years
	, rp.location
	, o.original_appr
FROM residential_permits AS rp
INNER JOIN oldest_record AS o
USING (apn)
WHERE rp.permit_year > 2010
)
SELECT cte.*
	, pu.propzip
	, pu.ludesc
	, pu.totlappr AS current_appr
FROM cte
JOIN property_updated AS pu
USING (apn)
WHERE change_years >= 10
AND ludesc IN ('SINGLE FAMILY'
			  , 'RESIDENTIAL CONDO'
			  , 'DUPLEX'
			  , 'APARTMENT: LOW RISE (BUILT SINCE 1960)'
			  , 'MOBILE HOME PARK'
			  , 'MOBILE HOME'
			  , 'APARTMENT: HIGH RISE (3 STORIES OR GREATER)'
			  , 'RESIDENTIAL COMBO/MISC')
ORDER BY change_years DESC


--5. Can you predict when the value of a home will increase based on the 
--text of the permits associated with a house 
--(along with any other factors that you think might be important)? 
--What words tend to be associated with an increase in home price?
WITH permit_reduced AS (
	SELECT p.apn
		, p.permitnumber
		, EXTRACT(YEAR FROM p.dateissued) AS permit_year
	FROM permit AS p
	JOIN property_updated AS pu
	USING (apn)
	WHERE p.dateissued >= '2008-01-01'
	AND pu.ludesc IN ('SINGLE FAMILY'
    , 'RESIDENTIAL CONDO'
    , 'APARTMENT: HIGH RISE (3 STORIES OR GREATER)'
    , 'APARTMENT: LOW RISE (BUILT SINCE 1960)'
    , 'APARTMENT: WALK UP (BUILT PRIOR TO 1960)'
    , 'DUPLEX'
    , 'TRIPLEX'
    , 'QUADPLEX'
    , 'ZERO LOT LINE'
    , 'VACANT RESIDENTIAL LAND'
    , 'MOBILE HOME PARK')
), assessment_reduced AS (
	SELECT apn
		, EXTRACT(YEAR FROM effectivedate) AS assessment_year
		, totalapprvalue
	FROM assessment
), time_diff AS (
	SELECT pr.apn
		, pr.permitnumber
		, pr.permit_year
		, ar.assessment_year
		, pr.permit_year - ar.assessment_year AS preceding_delta
		, ar.assessment_year - pr.permit_year AS following_delta
		, ar.totalapprvalue
	FROM permit_reduced AS pr
	JOIN assessment_reduced AS ar
	USING (apn)
), preceding_assessments AS (
	SELECT td.apn, td.permitnumber, td.permit_year
		, td.assessment_year, td.preceding_delta, td.totalapprvalue AS preceding_value
	FROM time_diff AS td
		INNER JOIN
		(
			SELECT permitnumber, MIN(preceding_delta) AS prec_delta_min
			FROM time_diff
			GROUP BY permitnumber
		) AS prec
		USING (permitnumber)
	WHERE td.preceding_delta = prec.prec_delta_min
	AND td.preceding_delta >=0
), following_assessments AS (
	SELECT td.apn, td.permitnumber, td.permit_year
		, td.assessment_year, td.following_delta, td.totalapprvalue AS following_value
	FROM time_diff AS td
		INNER JOIN
		(
			SELECT permitnumber, MIN(following_delta) AS foll_delta_min
			FROM time_diff
			GROUP BY permitnumber
		) AS foll
		USING (permitnumber)
	WHERE td.following_delta = foll.foll_delta_min
	AND td.following_delta >=0
)
SELECT pa.apn, pa.permitnumber, pa.permit_year
	, pa.assessment_year AS preceding_assessment_year
	, pa.preceding_delta
	, pa.preceding_value
	, fa.assessment_year AS following_assessment_year
	, fa.following_delta
	, fa.following_value
	, fa.permitnumber AS following_permitnumber
FROM preceding_assessments AS pa
FULL JOIN following_assessments AS fa
USING (permitnumber)
--WHERE pa.permit_year = '2008'
ORDER BY pa.permit_year DESC, pa.permitnumber





--Count of total land use descriptions from property_updated
SELECT ludesc, COUNT(*)
FROM property_updated
GROUP BY ludesc
ORDER BY count DESC

--Glance at groups of permittype/subtype by land use description
--Option to to look at only short term rentals, and to order by permit type
SELECT p.permittype, p.permitsubtype, pu.ludesc, COUNT(*)
FROM permit AS p
JOIN property_updated AS pu
USING (apn)
--WHERE p.permittype = 'RESIDENTIAL SHORT TERM RENTAL'
GROUP BY p.permittype, p.permitsubtype, pu.ludesc
--ORDER BY p.permittype, p.permitsubtype, pu.ludesc
ORDER BY COUNT DESC



