-- STARTING A CHOROPLETH ANALYSIS 
-- 1. ALTER the table eds polygon
-- add a new column called StopDensity
ALTER TABLE eds ADD COLUMN StopDensity numeric DEFAULT 0;
ALTER TABLE eds ADD COLUMN StopCount numeric DEFAULT 0;

-- 2. Write a SELECT statement (JOIN) to find the density of 
-- stops in EACH division. 
SELECT d.ogc_fid,count(*)/(ST_Area(ST_Transform(d.egeom,3857))/1000000) 
as DensityStopsInDivision
FROM stops as s, eds as d
where ST_CONTAINS(d.egeom, s.ptgeom)
GROUP BY d.ogc_fid;

-- 3 Use a Table Sub Query to do an update 
-- of the eds polygon and the new column
-- StopDensity. 

With PolygonQuery as (
    SELECT d.ogc_fid,count(*) as StopsCountInDivision 
    FROM stops as s, eds as d
    where ST_CONTAINS(d.egeom, s.ptgeom)
    GROUP BY d.ogc_fid)
UPDATE eds
SET StopCount = Round(CAST(PolygonQuery.StopsCountInDivision AS numeric),3)
FROM PolygonQuery 
WHERE eds.ogc_fid = PolygonQuery.ogc_fid;

With PolygonQuery as (
    SELECT d.ogc_fid,count(*)/(ST_Area(ST_Transform(d.egeom,3857))/1000000) as DensityStopsInDivision 
    FROM stops as s, eds as d
    where ST_CONTAINS(d.egeom, s.ptgeom)
    GROUP BY d.ogc_fid)
UPDATE eds
SET StopDensity = Round(CAST(PolygonQuery.DensityStopsInDivision AS numeric),3)
FROM PolygonQuery 
WHERE eds.ogc_fid = PolygonQuery.ogc_fid;

-- Let's look at the first few rows of eds 
SELECT ogc_fid,name_tag,stopdensity from eds order by stopdensity desc LIMIT 10;
SELECT ogc_fid,name_tag,stopcount from eds order by stopcount desc LIMIT 10;

--Considering only dublin county
delete from stops where ogc_fid not in (
select s.ogc_fid 
from stops as s, eds as d
where ST_Contains(d.egeom,s.ptgeom)

--bus stop count
SELECT 
    s.stop_name, 
    COUNT(*) AS stop_count,
    d.name_en AS county_name
FROM 
    stop_times st
JOIN 
    stops s ON st.stop_id = s.stop_id
JOIN 
    counties d ON ST_Contains(d.cgeom, s.ptgeom)
GROUP BY 
    s.stop_name, d.name_en
ORDER BY 
    stop_count DESC;
	
--vector grid analysis
ALTER TABLE irelandgrid DROP COLUMN IF EXISTS NumberStopsInGridCell;
ALTER TABLE irelandgrid ADD COLUMN NumberStopsInGridCell INTEGER DEFAULT 0.0;
	
With PolygonQuery as (
    SELECT grid.id,count(*) as NumberBusStops
    FROM stops as s, irelandgrid as grid
    where ST_CONTAINS(grid.wkb_geom,s.ptgeom)
    GROUP BY grid.id
)
UPDATE irelandgrid 
SET NumberStopsInGridCell = (PolygonQuery.NumberBusStops)
FROM PolygonQuery 
WHERE irelandgrid.id = PolygonQuery.id;

--bus stop distances
SELECT s1.stop_id as stopID1, 
	s1.stop_name,
	s2.stop_id as stopID2,
	s2.stop_name,
	ST_Transform(s1.ptgeom,32630)<->ST_Transform(s2.ptgeom,32630) as Distance
	FROM stops as s1, stops as s2, eds as d
	WHERE (s1.stop_id != s2.stop_id) 
	AND (s1.stop_id < s2.stop_id) 
	ORDER BY Distance DESC;
	LIMIT 10;

--bus departure patterns
WITH TripRouteAssociation AS (
    SELECT
        t.trip_id,
        st.departure_time AS departure_timestamp,
        ROW_NUMBER() OVER (PARTITION BY t.trip_id, s.stop_name ORDER BY st.departure_time) AS trip_rank
    FROM trips t
    JOIN stop_times st
    ON t.trip_id = st.trip_id
    JOIN stops s
    ON s.stop_id = st.stop_id 
    JOIN eds d
    ON ST_CONTAINS(d.egeom, s.ptgeom) 
)
SELECT
    tra.trip_id,
    tra.departure_timestamp,
    COUNT(*) AS num_buses
FROM TripRouteAssociation tra
WHERE tra.trip_rank = 1
GROUP BY tra.departure_timestamp,tra.trip_id
ORDER BY num_buses DESC
LIMIT 10;
