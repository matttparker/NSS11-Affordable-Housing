-- query to get a lifetime history for each house since 1993
WITH historicals AS (-- get historical assessment data for each property when it was residential 
	SELECT a.apn
		, a.effectivedate AS date
		, 'assessment' AS permit_num

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
		, 'assessment' AS permit_num
	
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
		, 'assessment' AS permit_num
	
	FROM property AS p
	
	WHERE p.ludesc IN (
		'SINGLE FAMILY'
		, 'RESIDENTIAL CONDO'
		, 'DUPLEX'
		, 'TRIPLEX'
		, 'QUADPLEX'
		, 'MOBILE HOME'
		)
),

assessments AS (
	SELECT *
	FROM recents

	UNION -- drop duplicates, in case there are any

	SELECT *
	FROM historicals
),

permits AS (
	WITH first_assessment AS (-- get historical assessment data for each property when it was residential 
		SELECT a.apn
			, MIN(a.effectivedate) AS date

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

		GROUP BY 1
	)

	SELECT p.apn
		, p.dateissued AS date
		, p.permitnumber AS permit_num

	FROM permit AS p

	JOIN first_assessment AS fa
		ON p.apn = fa.apn
		AND p.dateissued >= fa.date -- only get permits from on or after the first assessment date or 1993-01-01
)

SELECT *
FROM assessments

UNION ALL -- ever so slightly faster than UNION and no need to dedupe

SELECT *
FROM permits

ORDER BY 1,2 DESC
;
