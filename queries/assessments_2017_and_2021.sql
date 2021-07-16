WITH assessments AS (SELECT pu.apn
	, pu.ludesc AS prop_type
	, pu.propaddr AS prop_addr
	, pu.propcity AS prop_city
	, pu.propzip AS prop_zip
	, pu.council AS prop_council_dist
	, pu.taxdist AS prop_tax_dist
	, ROUND(AVG(p.totlappr),0) AS appraisal_2017
	, ROUND(AVG(pu.totlappr),0) AS appraisal_2021

FROM property_updated AS pu

JOIN property AS p
	ON p.apn = pu.apn
	AND p.assessdate = DATE('2017-01-01')

WHERE
	pu.assessdate = DATE('2021-01-01')
	AND p.ludesc IN (
	'SINGLE FAMILY'
	, 'RESIDENTIAL CONDO'
	, 'DUPLEX'
	, 'TRIPLEX'
	, 'QUADPLEX'
	, 'MOBILE HOME'
	)
	AND pu.ludesc IN (
	'SINGLE FAMILY'
	, 'RESIDENTIAL CONDO'
	, 'DUPLEX'
	, 'TRIPLEX'
	, 'QUADPLEX'
	, 'MOBILE HOME'
	)
GROUP BY 1,2,3,4,5,6,7
)

SELECT a.*
	, p.permittype
	, p.permitsubtype
	, p.purpose
	--, p.contractor
	
FROM assessments AS a

LEFT JOIN permit AS p
	ON p.apn = a.apn
	AND p.dateissued BETWEEN DATE('2017-01-01') AND DATE('2020-12-31')
;