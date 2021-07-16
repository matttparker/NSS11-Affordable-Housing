-- query to get all historical assessments for residences in Davidson county since 1993
WITH historicals AS (-- get historical assessment data for each property when it was residential 
	SELECT a.apn
		, a.effectivedate AS date
		, a.totalapprvalue AS prop_value
	-- also pull in the earliest address data we have for the apn
		, COALESCE(p.ludesc, pu.ludesc) AS prop_type
		, COALESCE(p.propaddr, pu.propaddr) AS prop_addr
		, COALESCE(p.propcity, pu.propcity) AS prop_city
		, COALESCE(p.propzip, pu.propzip) AS prop_zip
		--, COALESCE(p.council, pu.council) AS prop_council
		--, COALESCE(p.taxdist, pu.taxdist) AS prop_taxdist

	FROM assessment AS a
	LEFT JOIN property AS p
		ON p.apn = a.apn
	LEFT JOIN property_updated AS pu
		ON pu.apn = a.apn
	
	WHERE a.classdesc = 'RESIDENTIAL' -- only get assessment data for properties when they were classified as residential
		AND a.effectivedate >= DATE('1993-01-01') -- only get data starting in 1993, when assessments regularized to every 4 years
		AND (-- only get apns that were counted as some form of residential property in 2017 or 2020;
			-- there are no apns that had more than one ludesc in either table, but a handful do change between tables
			p.ludesc IN (
				'SINGLE FAMILY'
				, 'RESIDENTIAL CONDO'
				, 'DUPLEX'
				, 'TRIPLEX'
				, 'QUADPLEX'
				, 'MOBILE HOME'
				)
			OR pu.ludesc IN (
				'SINGLE FAMILY'
				, 'RESIDENTIAL CONDO'
				, 'DUPLEX'
				, 'TRIPLEX'
				, 'QUADPLEX'
				, 'MOBILE HOME'
				)
			)
),

recents AS (-- get address and property type info for 2021 and any non-overlapping 2017 apns
	SELECT pu.apn
		, pu.assessdate AS date
		, pu.totlappr AS prop_value
		, pu.ludesc AS prop_type
		, pu.propaddr AS prop_addr
		, pu.propcity AS prop_city
		, pu.propzip AS prop_zip
		--, pu.council AS prop_council
		--, pu.taxdist AS prop_taxdist
	
	FROM property_updated AS pu
	
	WHERE pu.ludesc IN (
		'SINGLE FAMILY'
		, 'RESIDENTIAL CONDO'
		, 'DUPLEX'
		, 'TRIPLEX'
		, 'QUADPLEX'
		, 'MOBILE HOME'
		)
	
	UNION -- drop duplicate rows, just in case they sneak in
	
	SELECT p.apn
		, p.assessdate AS date
		, p.totlappr AS prop_value
		, p.ludesc AS prop_type
		, p.propaddr AS prop_addr
		, p.propcity AS prop_city
		, p.propzip AS prop_zip
		--, p.council AS prop_council
		--, p.taxdist AS prop_taxdist
	
	FROM property AS p
	
	WHERE p.ludesc IN (
		'SINGLE FAMILY'
		, 'RESIDENTIAL CONDO'
		, 'DUPLEX'
		, 'TRIPLEX'
		, 'QUADPLEX'
		, 'MOBILE HOME'
		)
)

SELECT *
FROM recents

UNION -- drop duplicates, in case there are any

SELECT *
FROM historicals

ORDER BY 1, 2 DESC
;