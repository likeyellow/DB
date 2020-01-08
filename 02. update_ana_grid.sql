/*
Create by Bea Eun Mi(likeyellowand@gmail.com)
2019.12.19
*/

-- ==================================================================================
-- 최종 데이터 셋 산출 스크립트
-- ==================================================================================

-- ==================================================================================
-- (1) 인구 (전체인구, 고령인구, 65세이하인구)
-- ==================================================================================

--1km 격자내 고령 인구로 ana_grid 테이블 만듦
CREATE TABLE ana_grid
AS
SELECT * FROM grid_1km_65_;



-- 전체인구(남녀통합) 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD age0_200 numeric(10, 3);
-- 고령인구 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD age65_ numeric(10, 3) ;
-- 65세 이하 인구 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD age_65 numeric(10, 3);



-- 65세 이상 인구 산출 후 데이터 셋에 업데이트
BEGIN;
UPDATE ana_grid AS grid
SET age65_ = ROUND(CAST(age.val AS numeric), 2)
FROM grid_1km_65_ AS age
WHERE grid.__gid = age.__gid;
COMMIT;



-- 결측값 처리
BEGIN;
UPDATE ana_grid
SET age65_ = 0
WHERE age65_ IS NULL;
COMMIT;



-- 전체인구(남녀통합) 산출 후 데이터 셋에 업데이트
BEGIN;
UPDATE ana_grid AS grid
SET age0_200 = ROUND(age.val, 2)
FROM grid_pp_1km AS age
WHERE grid.__gid = age.__gid;
COMMIT;



-- 결측값 처리
BEGIN;
UPDATE ana_grid
SET age0_200 = 0
WHERE age0_200 IS NULL;
COMMIT;



-- 65세 이하 인구 산출 후 데이터 셋에 업데이트
BEGIN;
UPDATE ana_grid 
SET age_65 = ROUND(val - age65_, 2);
COMMIT;



-- 결측값 처리
BEGIN;
UPDATE ana_grid
SET age_65 = 0
WHERE age_65 IS NULL;
COMMIT;



-- 격자 중심점 변수를 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD grid_centroid geometry;



-- 격자 중심 좌표 산출 후 데이터 셋에 업데이트
BEGIN;
UPDATE ana_grid AS g
SET grid_centroid = cent.geom_cent
FROM (SELECT __gid, ST_CENTROID(geom)AS geom_cent FROM ana_grid) AS cent
WHERE g.__gid = cent.__gid;
COMMIT;



-- ==================================================================================
-- (2) 지적도
-- ==================================================================================

-- 지목 편집결과 저장용 변수를 지적도 테이블에 추가 
ALTER TABLE geo_nn_ldreg_5179 
ADD jimok character varying(1);



-- 지목 변수값 산출
BEGIN;
UPDATE geo_nn_ldreg_5179
SET jimok = b.value
FROM (SELECT right(jibun, 1) AS value, gid FROM geo_nn_ldreg_5179) AS b
WHERE geo_nn_ldreg_5179.gid = b.gid;
COMMIT;



-- 지적도에서 논, 밭, 묘만 추출
CREATE TABLE geo_nn_ldreg_weak
AS
SELECT * FROM geo_nn_ldreg_5179
WHERE jimok = '전' OR jimok = '답' OR jimok = '묘';



-- 논 데이터 테이블 생성 
BEGIN;
CREATE TABLE geo_nn_ldreg_non
AS
SELECT * FROM geo_nn_ldreg_weak WHERE jimok = '답';
COMMIT;



-- 논 데이터 테이블 centroid 구하기 (1)
ALTER TABLE geo_nn_ldreg_non 
ADD non_centroid geometry;



-- 논 데이터 테이블 centroid 구하기 (2)
BEGIN;
UPDATE geo_nn_ldreg_non AS non
SET non_centroid = ori.cent
FROM (SELECT gid, ST_CENTROID(geom) AS cent FROM geo_nn_ldreg_non) AS ori
WHERE non.gid = ori.gid; 
COMMIT;



-- 밭 데이터 테이블 생성
CREATE TABLE geo_nn_ldreg_bat 
AS
SELECT * FROM geo_nn_ldreg_weak WHERE jimok = '전';



-- 밭 데이터 테이블 centroid 구하기 (1)
ALTER TABLE geo_nn_ldreg_bat 
ADD bat_centroid geometry;



-- 밭 데이터 테이블 centroid 구하기 (2)
BEGIN;
UPDATE geo_nn_ldreg_bat AS bat
SET bat_centroid = ori.cent
FROM (SELECT gid, ST_CENTROID(geom) AS cent FROM geo_nn_ldreg_bat) AS ori
WHERE bat.gid = ori.gid;
COMMIT; 



-- 묘지 데이터 테이블 생성
CREATE TABLE geo_nn_ldreg_myo 
AS
SELECT * FROM geo_nn_ldreg_weak WHERE jimok = '묘';



-- 묘지 데이터 테이블 centroid 구하기 (1)
ALTER TABLE geo_nn_ldreg_myo 
ADD myo_centroid geometry;



-- 밭 데이터 테이블 centroid 구하기 (2)
BEGIN;
UPDATE geo_nn_ldreg_myo AS myo
SET myo_centroid = ori.cent
FROM (SELECT gid, ST_CENTROID(geom) AS cent FROM geo_nn_ldreg_myo) AS ori
WHERE myo.gid = ori.gid;
COMMIT;
 


-- 결과 테이블(ana_grid)에 지적도 계산결과 컬럼 추가
ALTER TABLE ana_grid 
ADD myo_dist double precision;
ALTER TABLE ana_grid 
ADD non_dist double precision;
ALTER TABLE ana_grid 
ADD bat_dist double precision;



-- 묘지와의 거리 산출
BEGIN;
UPDATE ana_grid AS grid
SET myo_dist = myo.dist
FROM (
      WITH t1 AS (
            SELECT __gid, ST_DISTANCE(myo_centroid, grid_centroid) AS dist
            FROM ana_grid AS grid, geo_nn_ldreg_myo AS ldreg 
      )
      SELECT t.*
      FROM  (
            SELECT *, RANK() OVER(PARTITION BY __gid ORDER BY dist) AS rnk
            FROM t1
      ) t
      WHERE t.rnk = 1 
) myo
WHERE grid.__gid = myo.__gid;
COMMIT;



-- 논과의 거리 산출 
BEGIN;
UPDATE ana_grid AS grid
SET non_dist = non.dist
FROM (
      WITH t1 AS (
            SELECT __gid, ST_DISTANCE(non_centroid, grid_centroid) AS dist
            FROM ana_grid AS grid, geo_nn_ldreg_non AS ldreg 
      )
      SELECT t.*
      FROM  (
            SELECT *, RANK() OVER(PARTITION BY __gid ORDER BY dist) AS rnk
            FROM t1
      ) t
      WHERE t.rnk = 1 
) non
WHERE grid.__gid = non.__gid ;
COMMIT;



-- 밭과의 거리 산출
BEGIN;
UPDATE ana_grid AS grid
SET bat_dist = bat.dist
FROM (
      WITH t1 AS (
            SELECT __gid, ST_DISTANCE(bat_centroid, grid_centroid) AS dist
            FROM ana_grid AS grid, geo_nn_ldreg_bat AS ldreg 
      )
      SELECT t.*
      FROM  (
            SELECT *, RANK() OVER(PARTITION BY __gid ORDER BY dist) AS rnk
            FROM t1
      ) t
      WHERE t.rnk = 1 
)bat
WHERE grid.__gid = bat.__gid;
COMMIT;



-- ==================================================================================
-- (3) 감시자원(CCTV, 감시초소,탑)
-- ==================================================================================

-- CCTV 시컨스 생성
CREATE SEQUENCE ff_cctv_gid INCREMENT 1 START 1;



-- 4326 좌표계 CCTV 테이블 생성
CREATE TABLE geo_ff_cctv AS (
	SELECT 
	NEXTVAL('ff_cctv_gid') gid,
	first_mnagn_nm,
	second_mnagn_nm,
	install_location,
	location_juso,
	install_year,
	model_nm,
	produce_nm,
	resolution,
	night_shoot,
	alarm,
	motion_sensor,
	hear_sensor,
	etc,
	ST_SetSRID(ST_POINT(xcrd, ycrd), 4326) geom
	FROM raw_ff_cctv
);



-- CCTV 테이블 5179 좌표로 변경
ALTER TABLE geo_ff_cctv
	ALTER COLUMN geom TYPE geometry(point, 5179)
	USING ST_Transform(ST_SetSRID(geom, 4326), 5179);
	
	
	
-- 감시초소, 탑 시컨스 생성
CREATE SEQUENCE ff_choso_tower_gid INCREMENT 1 START 1;



-- 4326 좌표계 감시초소, 탑 테이블 생성 
CREATE TABLE geo_ff_choso_tower AS (
	SELECT NEXTVAL('ff_choso_tower_gid') gid,
	sigun,
	site,
	manage_site,
	setup_year,
	repair_date,
	repair_cont,
	repair_cost,
	build_condt,
	note,
	ST_SetSRID(ST_POINT(x, y), 4326) geom
	FROM raw_ff_choso_tower
);



-- 감시초소, 탑 테이블 5179 좌표로 변경
ALTER TABLE geo_ff_choso_tower
	ALTER COLUMN geom TYPE geometry(point, 5179)
	USING ST_Transform(ST_SetSRID(geom, 4326), 5179);



-- 조망형 cctv 최단거리 산출(1-1)
CREATE TABLE IF NOT EXISTS temp1 AS
SELECT gr.*, ST_DISTANCE(grid_centroid, ST_CENTROID(jc.geom)) AS cctv_view_dist
FROM ana_grid AS gr
LEFT JOIN geo_ff_cctv as jc
ON (gr.gid <> jc.gid OR gr.gid = jc.gid) and etc like '%조망%'; 



-- 조망형 cctv 최단거리 산출(1-2)
CREATE TABLE IF NOT EXISTS temp2 AS
SELECT *,RANK() OVER(PARTITION BY __gid ORDER BY cctv_view_dist) as rnk
FROM temp1;



-- 조망형 cctv 최단거리 산출(1-3)
CREATE TABLE IF NOT EXISTS temp_view_cctv_result AS
SELECT DISTINCT a.*, cctv_view_dist
FROM ana_grid AS a
LEFT JOIN (SELECT __gid, rnk, cctv_view_dist FROM temp2) as b
ON a.__gid = b.__gid
WHERE rnk = 1;



-- 밀착형 cctv 최단거리 산출(2-1)
CREATE TABLE IF NOT EXISTS temp3 AS
SELECT gr.*, ST_DISTANCE(grid_centroid, ST_CENTROID(jc.geom)) AS cctv_close_dist
FROM ana_grid AS gr
LEFT JOIN geo_ff_cctv as jc
ON (gr.gid <> jc.gid OR gr.gid = jc.gid) and etc like '%밀착%'; 



-- 밀착형 cctv 최단거리 산출(2-2)
CREATE TABLE IF NOT EXISTS temp4 AS
SELECT *,RANK() OVER(PARTITION BY __gid ORDER BY cctv_close_dist) as rnk
FROM temp3;



-- 밀착형 cctv 최단거리 산출(2-3)
CREATE TABLE IF NOT EXISTS temp_close_cctv_result AS
SELECT DISTINCT a.*, cctv_close_dist
FROM ana_grid AS a
LEFT JOIN (SELECT __gid, rnk, cctv_close_dist FROM temp4) as b
ON a.__gid = b.__gid
WHERE rnk = 1;



-- 탑 최단거리 산출(3-1)
CREATE TABLE IF NOT EXISTS temp5 AS
SELECT gr.*, ST_DISTANCE(grid_centroid, ST_CENTROID(gp.geom)) AS tower_dist
FROM ana_grid AS gr
LEFT JOIN geo_ff_choso_tower as gp
ON (gr.gid <> gp.gid OR gr.gid = gp.gid) and note like '%탑%';



-- 탑 최단거리 산출(3-2) 
CREATE TABLE IF NOT EXISTS temp6 AS
SELECT *,RANK() OVER(PARTITION BY __gid ORDER BY tower_dist) as rnk
FROM temp5;



-- 탑 최단거리 산출(3-3)
CREATE TABLE IF NOT EXISTS temp_tower_result AS
SELECT DISTINCT a.*, tower_dist
FROM temp_close_cctv_result AS a
LEFT JOIN (SELECT __gid, rnk, tower_dist FROM temp6) as b
ON a.__gid = b.__gid
WHERE rnk = 1;



-- 초소 최단거리 산출(4-1)
CREATE TABLE IF NOT EXISTS temp7 AS
SELECT gr.*, ST_DISTANCE(grid_centroid, ST_CENTROID(gp.geom)) AS choso_dist
FROM ana_grid AS gr
LEFT JOIN geo_ff_choso_tower as gp
ON (gr.gid <> gp.gid OR gr.gid = gp.gid) and note like '%초소%';



-- 초소 최단거리 산출(4-2)
CREATE TABLE IF NOT EXISTS temp8 AS
SELECT *,RANK() OVER(PARTITION BY __gid ORDER BY choso_dist) as rnk
FROM temp7;



-- 초소 최단거리 산출(4-3)
CREATE TABLE IF NOT EXISTS temp_choso_tower_result AS
SELECT DISTINCT a.*, choso_dist
FROM temp_tower_result AS a
LEFT JOIN (SELECT __gid, rnk, choso_dist FROM temp8) as b
ON a.__gid = b.__gid
WHERE rnk = 1;



-- 감시자원 최종 산출 결과 테이블 생성
CREATE TABLE IF NOT EXISTS temp_result AS
SELECT a.*, b.cctv_view_dist
FROM temp_choso_tower_result AS a
LEFT JOIN (SELECT __gid, cctv_view_dist FROM temp_view_cctv_result) AS b
ON a.__gid = b.__gid;



-- 감시자원과의 거리 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD cctv_view_dist double precision;
ALTER TABLE ana_grid 
ADD cctv_close_dist double precision;
ALTER TABLE ana_grid 
ADD tower_dist double precision;
ALTER TABLE ana_grid 
ADD choso_dist double precision;



-- 감시자원과의 거리 변수 업데이트
BEGIN;
UPDATE ana_grid AS ana
SET cctv_view_dist = view_cctv.cctv_view_dist
FROM temp_result AS view_cctv
WHERE ana.__gid = view_cctv.__gid;
COMMIT;



BEGIN;
UPDATE ana_grid AS ana
SET cctv_close_dist = close_cctv.cctv_close_dist
FROM temp_result AS close_cctv
WHERE ana.__gid = close_cctv.__gid;
COMMIT;



BEGIN;
UPDATE ana_grid AS ana
SET tower_dist = tower.tower_dist
FROM temp_result AS tower
WHERE ana.__gid = tower.__gid;
COMMIT;



BEGIN;
UPDATE ana_grid AS ana
SET choso_dist = choso.choso_dist
FROM temp_result AS choso
WHERE ana.__gid = choso.__gid;
COMMIT;



-- ==================================================================================
-- (4) 산불발생 현황
-- ==================================================================================

-- 산불발생 현황 시컨스 생성
CREATE SEQUENCE ff_damage_gid INCREMENT 1 START 1;



-- 4326 좌표계 산불발생 현황 테이블 생성 
CREATE TABLE geo_ff_damage AS (
	SELECT NEXTVAL('ff_damage_gid') gid,
	OB_YEAR,
	OB_MONTH,
	OB_DAY,
	OB_TIME,
	OB_WEEK,
	EX_YEAR,
	EX_MONTH,
	EX_DAY,
	EX_TIME,
	GS,
	SIDO,
	SIGUNGU,
	EM,
	DL,
	JIBUN,
	CAUSE_CD,
	CAUSE_DETAIL,
	CAUSE_ETC,
	DEMAGE_AREA,
	JUSO,
	ST_SetSRID(ST_POINT(X, Y), 4326) geom
	FROM raw_ff_damage
);



-- 산불발생 현황 테이블 5179 좌표로 변경
ALTER TABLE geo_ff_damage
	ALTER COLUMN geom TYPE geometry(point, 5179)
	USING ST_Transform(ST_SetSRID(geom, 4326), 5179);
	
	
	
-- 산불 진화 시간 산출변수 데이터 셋에 추가
ALTER TABLE geo_ff_damage 
ADD damage_inter_time interval;
ALTER TABLE geo_ff_damage 
ADD damage_inter_time_min integer;



-- 산불진화 시간 산출
BEGIN;
WITH time AS (
	SELECT tmp1.gid, tmp1.interval
	FROM(
		SELECT a."gid", a."ob_year", a."ob_month", a."ob_day", a."ob_time",
		a."ob_week", a."ex_year", a."ex_month", a."ex_day", a."ex_time", "gs",
		a."sido", a."sigungu", a."em", a."dl", a."jibun", a."cause_cd", a."cause_detail",
		a."cause_etc", a."demage_area", a."juso", a."geom", a."damage_inter_time", a."damage_inter_time_min", 
		((TO_TIMESTAMP(CONCAT(a.ex_year,'-', a.ex_month,'-', a.ex_day,' ', a.ex_time),
			'YYYY-MM-DD HH24:MI')) -
		(TO_TIMESTAMP(CONCAT(a.ob_year,'-', a.ob_month,'-', a.ob_day,' ', a.ob_time),
			'YYYY-MM-DD HH24:MI'))) AS interval
		FROM geo_ff_damage a
		)tmp1
	GROUP BY tmp1.gid, tmp1.interval
	ORDER BY tmp1.gid ASC
	)		
UPDATE geo_ff_damage AS damage
SET damage_inter_time = time.interval
FROM time
WHERE damage.gid = time.gid;
COMMIT; 



-- 산진화 시간 -> 분으로 환산
BEGIN;
WITH time_min AS(
	SELECT tmp1.gid, EXTRACT(hour FROM tmp1.damage_inter_time) * 60 + EXTRACT(minute FROM tmp1.damage_inter_time) AS mi
	FROM(	
		SELECT * 
		FROM geo_ff_damage 
		)tmp1
	ORDER BY gid ASC
)
UPDATE geo_ff_damage AS damage
SET damage_inter_time_min = time_min.mi
FROM time_min
WHERE damage.gid = time_min.gid;
COMMIT;



-- 산불 진화 시간 산출변수 데이터 셋에 추가 
ALTER TABLE ana_grid 
ADD inter_time character varying(100);
ALTER TABLE ana_grid 
ADD inter_time_min character varying(100);
ALTER TABLE ana_grid 
ADD inter_time_sum integer;



-- 산불진화 시간 산출 업데이트
BEGIN;
WITH time AS (
	SELECT tmp1.__gid, STRING_AGG(tmp1.damage_inter_time::character varying(100), ',') AS interval
	FROM(
		SELECT a.*, t.damage_inter_time
		FROM ana_grid a, geo_ff_damage t
		WHERE ST_INTERSECTS(a.geom, t.geom)
		)tmp1
	GROUP BY tmp1.__gid, tmp1.gid
	ORDER BY tmp1.__gid ASC
	)		
UPDATE ana_grid AS grid
SET inter_time = time.interval
FROM time
WHERE grid.__gid = time.__gid;
COMMIT;



-- 산불진화 시간 분으로 환산 산출값 업데이트	
BEGIN;
WITH ff AS (
	SELECT tmp1.__gid, STRING_AGG(tmp1.damage_inter_time_min::character varying(100), ',') AS ff_min
	FROM (
		SELECT a.*, b.damage_inter_time_min
		FROM ana_grid a, geo_ff_damage b
		WHERE ST_INTERSECTS(a.geom, b.geom)
		) tmp1
	GROUP BY tmp1.__gid
)
UPDATE ana_grid AS grid
SET inter_time_min = ff.ff_min
FROM ff
WHERE grid.__gid = ff.__gid ;
COMMIT;



-- 산불진화 총시간 업데이트
BEGIN;
WITH damage AS (
	SELECT tmp1.__gid, SUM(tmp1.damage_inter_time_min) AS damage_time
	FROM (
		SELECT a.*, b.damage_inter_time_min
		FROM ana_grid a, geo_ff_damage b
		WHERE ST_INTERSECTS(a.geom, b.geom)
		) tmp1
	GROUP BY tmp1.__gid
	)
UPDATE ana_grid AS grid
SET inter_time_sum = damage.damage_time
FROM damage
WHERE grid.__gid = damage.__gid;
COMMIT;



-- 산불여부 및 피해면적 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD ff_cnt integer ;
ALTER TABLE ana_grid 
ADD ff_damage_area numeric(10,3) ;



-- 산불건수 변수 산출
BEGIN;
WITH count AS (
	SELECT tmp1.__gid, ROUND(SUM(tmp1.demage_area), 3) AS ff_damage_area, COUNT(*) AS ff_cnt
	FROM (
		SELECT a.*, b.demage_area
		FROM ana_grid a, geo_ff_damage b
		WHERE ST_INTERSECTS(a.geom, b.geom)
		) tmp1
	GROUP BY tmp1.__gid
	ORDER BY ff_cnt DESC
	)
UPDATE ana_grid AS grid
SET ff_cnt = count.ff_cnt
FROM count
WHERE grid.__gid = count.__gid;
COMMIT;



-- 산불건수 결측값 처리
BEGIN;
UPDATE ana_grid
SET ff_cnt = 0
WHERE ff_cnt IS NULL;
COMMIT;



-- 산불 피해면적 변수 산출
BEGIN;
WITH sum AS (
	SELECT tmp1.__gid, ROUND(SUM(tmp1.demage_area), 3) AS  ff_damage_area, COUNT(*) AS ff_cnt
	FROM (
		SELECT a.*, b.demage_area
		FROM ana_grid a, geo_ff_damage b
		WHERE ST_INTERSECTS(a.geom, b.geom)
		) tmp1
	GROUP BY tmp1.__gid
	ORDER BY ff_cnt DESC
	)
UPDATE ana_grid AS grid
SET ff_damage_area = sum.ff_damage_area
FROM sum
WHERE grid.__gid = sum.__gid ;
COMMIT;



-- 산불 피해면적 결측값 처리
BEGIN;
UPDATE ana_grid
SET ff_damage_area = 0
WHERE ff_damage_area IS NULL ;
COMMIT;



-- 산불 발생원인 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD ff_cause character varying(500);



-- 산불 발생원인 데이터 셋에 업데이트
BEGIN;
WITH cause AS (
	SELECT tmp1.__gid, STRING_AGG(DISTINCT tmp1.cause_detail, ',') AS cause_detail
	FROM (
		SELECT a.*, b.*
		FROM ana_grid a, geo_ff_damage b
		WHERE ST_INTERSECTS(a.geom, b.geom)
		) tmp1
	GROUP BY tmp1.__gid
)
UPDATE ana_grid AS grid
SET ff_cause = cause.cause_detail
FROM cause
WHERE grid.__gid = cause.__gid ;
COMMIT;



-- 산불 발생 달 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD ff_month character varying(20);



-- 산불 발생달 변수 산출
BEGIN;
WITH month AS (
	SELECT tmp1.__gid, STRING_AGG(tmp1.ob_month, ',') AS cause_month
	FROM (
		SELECT a.*, b.*
		FROM ana_grid a, geo_ff_damage b
		WHERE ST_INTERSECTS(a.geom, b.geom)
		) tmp1
	GROUP BY tmp1.__gid
)
UPDATE ana_grid AS grid
SET ff_month = month.cause_month
FROM month
WHERE grid.__gid = month.__gid ;
COMMIT;



-- ==================================================================================
-- (5) 임상도
-- ================================================================================== 

-- 산림(침엽수림, 활엽수림 등)종류별 면적 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD fr_etc_area double precision ;
ALTER TABLE ana_grid 
ADD fr_chim_area double precision ;
ALTER TABLE ana_grid 
ADD fr_whal_area double precision ;
ALTER TABLE ana_grid 
ADD fr_hon_area double precision ;
ALTER TABLE ana_grid 
ADD fr_juk_area double precision ;



-- 기타산림 면적 산출 테이블 생성
CREATE TABLE temp_etc_area
	AS
	SELECT tmp1.*, ST_AREA(tmp1.tmp_geom) AS area
	FROM (
		SELECT a.*, b.frtp_cd, ST_INTERSECTION(a.geom, b.geom) AS tmp_geom
		FROM ana_grid a, fs_im5000 b
		WHERE ST_INTERSECTS(a.geom, b.geom)
		) tmp1
	WHERE tmp1.frtp_cd = '0';
	

	
-- 기타산림 면적 산출값 업데이트
BEGIN;
WITH area AS (
	SELECT tmp2.__gid, sum(tmp2.area) AS area
	FROM temp_etc_area AS tmp2
	GROUP BY tmp2.__gid
	)
UPDATE ana_grid AS grid
SET fr_etc_area = area.area
FROM area
WHERE grid.__gid = area.__gid;
COMMIT;



-- 면적 폴리곤 오류 처리
BEGIN;
UPDATE fs_im5000 
SET geom = ST_MULTI(ST_BUFFER(geom, 0));
COMMIT;



-- 침엽수림 면적 산출 테이블 생성
CREATE TABLE temp_chim_area
	AS
	SELECT tmp1.*, ST_AREA(tmp1.tmp_geom) AS area
	FROM (
		SELECT a.*, b.frtp_cd, ST_INTERSECTION(a.geom, b.geom) AS tmp_geom
		FROM ana_grid a, fs_im5000 b
		WHERE ST_INTERSECTS(a.geom, b.geom)
		) tmp1
	WHERE tmp1.frtp_cd = '1';
	


-- 침엽수림 면적 산출값 데이터 셋에 업데이트
BEGIN;
WITH area AS (
	SELECT tmp2.__gid, sum(tmp2.area) AS area
	FROM temp_chim_area AS tmp2
	GROUP BY tmp2.__gid
	)
UPDATE ana_grid AS grid
SET fr_chim_area = area.area
FROM area
WHERE grid.__gid = area.__gid;
COMMIT;



-- 활엽수림 면적 산출 테이블 생성
CREATE TABLE temp_whal_area
	AS
	SELECT tmp1.*, ST_AREA(tmp1.tmp_geom) AS area
	FROM (
		SELECT a.*, b.frtp_cd, ST_INTERSECTION(a.geom, b.geom) AS tmp_geom
		FROM ana_grid a, fs_im5000 b
		WHERE ST_INTERSECTS(a.geom, b.geom)
		) tmp1
	WHERE tmp1.frtp_cd = '2';



-- 활엽수림 면적 산출값 데이터 셋에 업데이트
BEGIN;
WITH area AS (
	SELECT tmp2.__gid, sum(tmp2.area) AS area
	FROM temp_whal_area AS tmp2
	GROUP BY tmp2.__gid
	)
UPDATE ana_grid AS grid
SET fr_whal_area = area.area
FROM area
WHERE grid.__gid = area.__gid;
COMMIT;



-- 혼효림 면적 산출 테이블 생성
CREATE TABLE temp_hon_area
	AS
	SELECT tmp1.*, ST_AREA(tmp1.tmp_geom) AS area
	FROM (
		SELECT a.*, b.frtp_cd, ST_INTERSECTION(a.geom, b.geom) AS tmp_geom
		FROM ana_grid a, fs_im5000 b
		WHERE ST_INTERSECTS(a.geom, b.geom)
		) tmp1
	WHERE tmp1.frtp_cd = '3';
	


-- 혼효림 면적 산출값 데이터 셋에 업데이트
BEGIN;
WITH area AS (
	SELECT tmp2.__gid, sum(tmp2.area) AS area
	FROM temp_hon_area AS tmp2
	GROUP BY tmp2.__gid
	)
UPDATE ana_grid AS grid
SET fr_hon_area = area.area
FROM area
WHERE grid.__gid = area.__gid;
COMMIT;



-- 죽림 면적 산출 테이블 생성
CREATE TABLE temp_juk_area
	AS
	SELECT tmp1.*, ST_AREA(tmp1.tmp_geom) AS area
	FROM (
		SELECT a.*, b.frtp_cd, ST_INTERSECTION(a.geom, b.geom) AS tmp_geom
		FROM ana_grid a, fs_im5000 b
		WHERE ST_INTERSECTS(a.geom, b.geom)
		) tmp1
	WHERE tmp1.frtp_cd = '4';



-- 죽림 면적 산출값 데이터 셋에 업데이트
BEGIN;
WITH area AS (
	SELECT tmp2.__gid, sum(tmp2.area) AS area
	FROM temp_juk_area AS tmp2
	GROUP BY tmp2.__gid
	)
UPDATE ana_grid AS grid
SET fr_juk_area = area.area
FROM area
WHERE grid.__gid = area.__gid;
COMMIT;



-- ==================================================================================
-- (6) 등산로
-- ==================================================================================

-- 격자내 등산로 수 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD trail_cnt integer;



-- 등산로 trail 테이블 좌표변경(5186 -> 5179) 
ALTER TABLE trail
	ALTER COLUMN geom TYPE geometry(MultiLineString, 5179)
	USING ST_TRANSFORM(ST_SETSRID(geom, 5186), 5179);
	
	
	
-- 격자내 등산로 수 산출값 데이터 셋에 업데이트
BEGIN;
WITH count AS (
	SELECT tmp1.__gid, count(*) AS trail_cnt
	FROM (
		SELECT a.*
		FROM ana_grid a, trail b
		WHERE ST_INTERSECTS(a.geom, b.geom)
		) tmp1
	GROUP BY tmp1.__gid
	)
UPDATE ana_grid AS grid
SET trail_cnt = count.trail_cnt
FROM count
WHERE grid.__gid = count.__gid;
COMMIT;



-- 격자내 등산로 거리합(단위 : m) 산출 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD trail_length double precision;



-- 등산로 폐쇄여부 결측값 처리 (null -> N) 
BEGIN;
UPDATE trail 
SET pmntn_cls_ = 'N'
WHERE pmntn_cls_ IS NULL;
COMMIT;



-- 격자내 등산로 길이합 산출값 데이터 셋에 업데이트
BEGIN;
WITH dist AS (
	SELECT tmp1.__gid, SUM(ST_LENGTH(tmp1.tmp_geom)) AS trail_dist
	FROM(
		SELECT a.*, b.mntn_nm, b.pmntn_cls_, b.pmntn_lt, ST_INTERSECTION(a.geom, b.geom) AS tmp_geom 
		FROM ana_grid a, trail b
		WHERE ST_INTERSECTS(a.geom, b.geom) AND b.pmntn_cls_ = 'N'
		) tmp1
	GROUP BY tmp1.__gid
)
UPDATE ana_grid AS grid
SET trail_length = dist.trail_dist
FROM dist
WHERE grid.__gid = dist.__gid;
COMMIT;



-- 격자내 산 이름 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD trail_name character varying(100);

 
 
-- 격자내 등산로가 위치하는 산의 이름 데이터 셋에 업데이트
BEGIN;
WITH name AS (
	SELECT tmp2.__gid, STRING_AGG(DISTINCT tmp2.mntn_nm, ',') as m_name
	FROM(
		SELECT a.*, b.mntn_nm, b.pmntn_cls_, b.pmntn_lt 
		FROM ana_grid a, trail b
		WHERE ST_INTERSECTS(a.geom, b.geom) AND b.pmntn_cls_ = 'N'
		) tmp2
	GROUP BY tmp2.__gid
)
UPDATE ana_grid AS grid
SET trail_name = name.m_name
FROM name
WHERE grid.__gid = name.__gid;
COMMIT;



-- 격자내 등산로 폐쇄여부 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD trail_close character varying(3);



-- 격자내 등산로 폐쇄여부 데이터 셋에 업데이트
BEGIN;
WITH close AS (
	SELECT tmp1.__gid, STRING_AGG(DISTINCT tmp1.pmntn_cls_, ',') AS load_close
	FROM(
		SELECT a.*, b.mntn_nm, b.pmntn_cls_, b.pmntn_lt 
		FROM ana_grid a, trail b
		WHERE ST_INTERSECTS(a.geom, b.geom)
		) tmp1
	GROUP BY tmp1.__gid
)
UPDATE ana_grid AS grid
SET trail_close = close.load_close
FROM close
WHERE grid.__gid = close.__gid;
COMMIT;



-- ==================================================================================
-- (7) 수치표고모델(DEM) 데이터 정제 
-- ==================================================================================

-- 평균고도 산출값 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD avg_altitude double precision;



-- 평균고도 산출 테이블 생성
CREATE TABLE ana_grid_avg AS (
	SELECT a.__gid, AVG(b.field_3) avg_altitude
	FROM ana_grid a, altitude b
	WHERE ST_Intersects(a.geom, b.geom)
	GROUP BY a.__gid
);



-- 평균고도 산출값 데이터 셋에 업데이트
BEGIN;
UPDATE ana_grid AS grid
SET avg_altitude = ROUND(avg.avg_altitude, 3)
FROM ana_grid_avg AS avg
WHERE grid.__gid = avg.__gid;
COMMIT;



-- 평균고도 결측값 처리 
BEGIN;
UPDATE ana_grid AS grid
SET avg_altitude = 0
WHERE grid.avg_altitude IS NULL;
COMMIT;



-- ==================================================================================
-- (8) 문화재
-- ==================================================================================

-- 문화재 시컨스 생성
CREATE SEQUENCE cultural_assets_gid INCREMENT 1 START 1;



-- 4326 좌표계 문화재 현황 테이블 생성 
CREATE TABLE geo_cultural_assets AS (
	SELECT 
	NEXTVAL('cultural_assets_gid') gid,
	sigun,
    name,
  	mnagn_nm,
  	designate_yr,
  	assets_gd,
  	add,
	x,
	y,
	ST_SETSRID(ST_POINT(x, y), 4326) geom
	FROM raw_cultural_assets
);



-- 문화재 현황 테이블 5179 좌표로 변경
ALTER TABLE geo_cultural_assets
	ALTER COLUMN geom TYPE geometry(point, 5179)
	USING ST_TRANSFORM(ST_SETSRID(geom, 4326), 5179);
	


-- 산림인접 100m 이내 문화재 선별
CREATE TABLE geo_cultural_assets_100 AS(
	SELECT DISTINCT ON (b.gid) b.gid, b.gid AS asset_gid, b.sigun, 
			b.name, b.mnagn_nm, b.designate_yr, b.assets_gd, b.add, b.x, b.y, b.geom
		FROM fs_im5000 AS g
	LEFT JOIN geo_cultural_assets AS b ON st_dwithin(g.geom, b.geom, 100)
	WHERE b.geom IS NOT NULL);



-- 격자 중심-문화재 최단거리 산출(1)
CREATE TABLE temp_assets1 AS
	SELECT gr.*, ST_DISTANCE(grid_centroid, ST_CENTROID(ca.geom)) AS assets_dt
		FROM ana_grid AS gr
	LEFT JOIN geo_cultural_assets_100 AS ca
	ON gr.gid <> ca.gid OR gr.gid = ca.gid;



-- 격자 중심-문화재 최단거리 산출(2)
CREATE TABLE temp_assets2 AS
	SELECT *,RANK() OVER(PARTITION BY __gid ORDER BY assets_dt) AS rnk
	FROM temp_assets1;



-- 격자 중심-문화재 최단거리 산출(3)
CREATE TABLE temp_cul_assets_result AS
	SELECT DISTINCT a.*, assets_dt
		FROM ana_grid AS a
	LEFT JOIN (SELECT __gid, rnk, assets_dt FROM temp_assets2) AS b
	ON a.__gid = b.__gid
	WHERE rnk = 1;



-- 격자중심-문화재 최단거리 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD mun_dist double precision ;



-- 격자중심-문화재 최단거리 산출값 데이터 셋에 업데이트
BEGIN;
UPDATE ana_grid AS ana
SET mun_dist = cul.assets_dt
FROM temp_cul_assets_result AS cul
WHERE ana.__gid = cul.__gid ;
COMMIT;



-- 문화재 카운트 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD mun_cnt integer ;



-- 격자 내 문화재 수 산출
BEGIN;
WITH count AS (
	SELECT tmp1.__gid, COUNT(*) AS mun_cnt
	FROM (
		SELECT a.*
		FROM ana_grid a, geo_cultural_assets_100 b
		WHERE ST_INTERSECTS(a.geom, b.geom)
		) tmp1
	GROUP BY tmp1.__gid
	)
UPDATE ana_grid AS grid
SET mun_cnt = COUNT.mun_cnt
FROM COUNT
WHERE grid.__gid = COUNT.__gid;
COMMIT;



-- 문화재 수 결측값 처리
BEGIN;
UPDATE ana_grid 
SET mun_cnt = '0'
WHERE mun_cnt is null;
COMMIT;



-- 격자중심-문화재(국보 등급) 최단거리 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD mun_kuk_dist double precision ;



-- 격자중심-문화재(국보 등급) 최단거리 산출값 데이터 셋에 업데이트
BEGIN;
UPDATE ana_grid AS grid
SET mun_kuk_dist = kuk.dist 
FROM (
	WITH t1 AS (
		SELECT __gid, ST_DISTANCE(grid_centroid, ST_CENTROID(b.geom)) AS dist
		FROM ana_grid AS a, geo_cultural_assets_100 AS b WHERE b.assets_gd LIKE '%국%보%'
	)
	SELECT t.*
	FROM (
		SELECT *, RANK() OVER(PARTITION BY __gid ORDER BY dist) AS rnk
		FROM t1
	) t
	WHERE t.rnk = 1
) kuk 
WHERE grid.__gid = kuk.__gid;
COMMIT;



-- 격자중심-문화재(보물 등급) 최단거리 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD mun_bo_dist double precision ;



-- 격자중심-문화재(보물 등급) 최단거리 산출값 데이터 셋에 업데이트 
BEGIN;
UPDATE ana_grid AS grid
SET mun_bo_dist = bo.dist 
FROM (
	WITH t1 AS (
		SELECT __gid, ST_DISTANCE(grid_centroid, ST_CENTROID(b.geom)) AS dist
		FROM ana_grid AS a, geo_cultural_assets_100 AS b WHERE b.assets_gd = '보물'
	)
	SELECT t.*
	FROM (
		SELECT *, RANK() OVER(PARTITION BY __gid ORDER BY dist) AS rnk
		FROM t1
	) t
	WHERE t.rnk = 1
) bo 
WHERE grid.__gid = bo.__gid;
COMMIT;



--격자 중심-문화재(기타 등급) 최단거리 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD mun_etc_dist double precision;



-- 격자중심-문화재(기타 등급) 최단거리 산출값 데이터 셋에 업데이트
BEGIN;
UPDATE ana_grid AS grid
SET mun_etc_dist = etc.dist
FROM (
	WITH t1 AS(
		SELECT __gid, ST_DISTANCE(grid_centroid, ST_CENTROID(b.geom)) AS dist
		from ana_grid AS a, geo_cultural_assets_100 AS b WHERE b.assets_gd <> '국보' AND b.assets_gd <> '보물' and assets_gd <>'국가보물'
	)
	SELECT t.*
	FROM (
		SELECT *, RANK() OVER(PARTITION BY __gid ORDER BY dist) AS rnk
		FROM t1
	)t
	WHERE t.rnk = 1
)etc
WHERE grid.__gid = etc.__gid;
COMMIT;



-- ==================================================================================
-- (9) 기상관측 데이터
-- ==================================================================================

-- 기상관측 데이터 시컨스 생성
CREATE SEQUENCE wthr_sttn_gid INCREMENT 1 START 1;



-- 4326 좌표계 기상관측 데이터 테이블 생성 
CREATE TABLE geo_wthr_sttn AS (
	SELECT 
	NEXTVAL('wthr_sttn_gid') gid, wthr_sttn_no,
    wthr_sttn_nm, x, y, temp_jan,
  	temp_feb, temp_mar, temp_apr, temp_may, temp_jun,
	temp_jul, temp_aug, temp_sep, temp_oct, temp_nov, temp_dec,
	humi_jan, humi_feb, humi_mar, humi_apr, humi_may, humi_jun,
	humi_jul, humi_aug, humi_sep, humi_oct, humi_nov, humi_dec,
	wind_jan, wind_feb, wind_mar, wind_apr, wind_may, wind_jun,
	wind_jul, wind_aug, wind_sep, wind_oct, wind_nov, wind_dec,
	efhumi_jan, efhumi_feb, efhumi_mar, efhumi_apr, efhumi_may, efhumi_jun,
	efhumi_jul, efhumi_aug, efhumi_sep, efhumi_oct, efhumi_nov, efhumi_dec,
	ST_SETSRID(ST_POINT(x, y), 4326) geom
	FROM raw_wthr_sttn
);



--  기상관측 데이터 테이블 5179 좌표로 변경
ALTER TABLE geo_wthr_sttn
	ALTER COLUMN geom TYPE geometry(point, 5179)
	USING ST_Transform(ST_SetSRID(geom, 4326), 5179);
	
	
	
-- 격자중심-기상관측소 데이터 정제 : 가장 가까운 기상관측소 데이터 조인
CREATE TABLE temp_ana_grid
	AS
	SELECT t2.*
	FROM (
		SELECT t1.*, rank() OVER(PARTITION BY __gid ORDER BY wthr_sttn_dist) AS rnk
		FROM (
			SELECT a.gid, a.__gid, a.lbl, a.val, a.geom, a.age0_200, a.age_65, a.age65_, a.grid_centroid,
					a.fr_etc_area, a.fr_chim_area, a.fr_whal_area, a.fr_hon_area, a.fr_juk_area, 
					a.trail_cnt, a.trail_length, a.trail_name, a.trail_close,
					a.myo_dist, a.non_dist, a.bat_dist, 
					a.avg_altitude, a.ff_cnt, a.ff_damage_area, a.ff_cause, a.ff_month, a.inter_time, a.inter_time_min,
					a.mun_cnt, a.mun_kuk_dist, a.mun_bo_dist, a.mun_etc_dist, a.mun_dist, 
					a.cctv_view_dist, a.cctv_close_dist, a.tower_dist, a.choso_dist, 
					b.gid AS wthr_index, b.wthr_sttn_no, b.wthr_sttn_nm, b.temp_jan, b.temp_feb,
					b.temp_mar, b.temp_apr, b.temp_may, b.temp_jun, b.temp_jul, b.temp_aug, b.temp_sep, b.temp_oct, b.temp_nov,
					b.temp_dec, b.humi_jan, b.humi_feb, b.humi_mar, b.humi_apr, b.humi_may, b.humi_jun, b.humi_jul, b.humi_aug,
					b.humi_sep, b.humi_oct, b.humi_nov, b.humi_dec, b.wind_jan, b.wind_feb, b.wind_mar, b.wind_apr, b.wind_may,
					b.wind_jun, b.wind_jul, b.wind_aug, b.wind_sep, b.wind_oct, b.wind_nov, b.wind_dec,
					b.efhumi_jan, b.efhumi_feb, b.efhumi_mar, b.efhumi_apr, b.efhumi_may, b.efhumi_jun,
					b.efhumi_jul, b.efhumi_aug, b.efhumi_sep, b.efhumi_oct, b.efhumi_nov, b.efhumi_dec,
					ST_DISTANCE(grid_centroid, ST_CENTROID(b.geom)) AS wthr_sttn_dist
			FROM ana_grid a, geo_wthr_sttn b
		) t1 
	) t2
	WHERE t2.rnk = 1;



-- 기상데이터 변수 데이터 셋에 추가
ALTER TABLE ana_grid 
ADD wthr_index integer ;
ALTER TABLE ana_grid 
ADD wthr_sttn_no integer ;
ALTER TABLE ana_grid 
ADD wthr_sttn_nm character varying(10) ;
ALTER TABLE ana_grid 
ADD wthr_sttn_dist double precision ;


ALTER TABLE ana_grid 
ADD temp_jan numeric(10,2) ;
ALTER TABLE ana_grid 
ADD temp_feb numeric(10,2) ;
ALTER TABLE ana_grid 
ADD temp_mar numeric(10,2) ;
ALTER TABLE ana_grid 
ADD temp_apr numeric(10,2) ;
ALTER TABLE ana_grid 
ADD temp_may numeric(10,2) ;
ALTER TABLE ana_grid 
ADD temp_jun numeric(10,2) ;
ALTER TABLE ana_grid 
ADD temp_jul numeric(10,2) ;
ALTER TABLE ana_grid 
ADD temp_aug numeric(10,2) ;
ALTER TABLE ana_grid 
ADD temp_sep numeric(10,2) ;
ALTER TABLE ana_grid 
ADD temp_oct numeric(10,2) ;
ALTER TABLE ana_grid 
ADD temp_nov numeric(10,2) ;
ALTER TABLE ana_grid 
ADD temp_dec numeric(10,2) ;


ALTER TABLE ana_grid 
ADD humi_jan numeric(10,2) ;
ALTER TABLE ana_grid 
ADD humi_feb numeric(10,2) ;
ALTER TABLE ana_grid 
ADD humi_mar numeric(10,2) ;
ALTER TABLE ana_grid 
ADD humi_apr numeric(10,2) ;
ALTER TABLE ana_grid 
ADD humi_may numeric(10,2) ;
ALTER TABLE ana_grid 
ADD humi_jun numeric(10,2) ;
ALTER TABLE ana_grid 
ADD humi_jul numeric(10,2) ;
ALTER TABLE ana_grid 
ADD humi_aug numeric(10,2) ;
ALTER TABLE ana_grid 
ADD humi_sep numeric(10,2) ;
ALTER TABLE ana_grid 
ADD humi_oct numeric(10,2) ;
ALTER TABLE ana_grid 
ADD humi_nov numeric(10,2) ;
ALTER TABLE ana_grid 
ADD humi_dec numeric(10,2) ;


ALTER TABLE ana_grid 
ADD wind_jan numeric(10,2) ;
ALTER TABLE ana_grid 
ADD wind_feb numeric(10,2) ;
ALTER TABLE ana_grid 
ADD wind_mar numeric(10,2) ;
ALTER TABLE ana_grid 
ADD wind_apr numeric(10,2) ;
ALTER TABLE ana_grid 
ADD wind_may numeric(10,2) ;
ALTER TABLE ana_grid 
ADD wind_jun numeric(10,2) ;
ALTER TABLE ana_grid 
ADD wind_jul numeric(10,2) ;
ALTER TABLE ana_grid 
ADD wind_aug numeric(10,2) ;
ALTER TABLE ana_grid 
ADD wind_sep numeric(10,2) ;
ALTER TABLE ana_grid 
ADD wind_oct numeric(10,2) ;
ALTER TABLE ana_grid 
ADD wind_nov numeric(10,2) ;
ALTER TABLE ana_grid 
ADD wind_dec numeric(10,2) ;


ALTER TABLE ana_grid 
ADD efhumi_jan numeric(10,2) ;
ALTER TABLE ana_grid 
ADD efhumi_feb numeric(10,2) ;
ALTER TABLE ana_grid 
ADD efhumi_mar numeric(10,2) ;
ALTER TABLE ana_grid 
ADD efhumi_apr numeric(10,2) ;
ALTER TABLE ana_grid 
ADD efhumi_may numeric(10,2) ;
ALTER TABLE ana_grid 
ADD efhumi_jun numeric(10,2) ;
ALTER TABLE ana_grid 
ADD efhumi_jul numeric(10,2) ;
ALTER TABLE ana_grid 
ADD efhumi_aug numeric(10,2) ;
ALTER TABLE ana_grid 
ADD efhumi_sep numeric(10,2) ;
ALTER TABLE ana_grid 
ADD efhumi_oct numeric(10,2) ;
ALTER TABLE ana_grid 
ADD efhumi_nov numeric(10,2) ;
ALTER TABLE ana_grid 
ADD efhumi_dec numeric(10,2) ;



-- 통합기상데이터 산출값 데이터 셋에 업데이트
BEGIN;
UPDATE ana_grid AS ana
SET wthr_index = wt.wthr_index
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wthr_sttn_no = wt.wthr_sttn_no
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wthr_sttn_nm = wt.wthr_sttn_nm
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wthr_sttn_dist = wt.wthr_sttn_dist
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET temp_jan = wt.temp_jan
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET temp_feb = wt.temp_feb
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET temp_mar = wt.temp_mar
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET temp_apr = wt.temp_apr
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET temp_may = wt.temp_may
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET temp_jun = wt.temp_jun
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET temp_jul = wt.temp_jul
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET temp_aug = wt.temp_aug
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET temp_sep = wt.temp_sep
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET temp_oct = wt.temp_oct
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET temp_nov = wt.temp_nov
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET temp_dec = wt.temp_dec
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET humi_jan = wt.humi_jan
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET humi_feb = wt.humi_feb
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET humi_mar = wt.humi_mar
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET humi_apr = wt.humi_apr
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET humi_may = wt.humi_may
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET humi_jun = wt.humi_jun
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET humi_jul = wt.humi_jul
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET humi_aug = wt.humi_aug
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET humi_sep = wt.humi_sep
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET humi_oct = wt.humi_oct
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET humi_nov = wt.humi_nov
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET humi_dec = wt.humi_dec
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wind_jan = wt.wind_jan
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wind_feb = wt.wind_feb
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wind_mar = wt.wind_mar
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wind_apr = wt.wind_apr
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wind_may = wt.wind_may
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wind_jun = wt.wind_jun
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wind_jul = wt.wind_jul
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wind_aug = wt.wind_aug
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wind_sep = wt.wind_sep
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wind_oct = wt.wind_oct
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wind_nov = wt.wind_nov
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET wind_dec = wt.wind_dec
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET efhumi_jan = wt.efhumi_jan
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET efhumi_feb = wt.efhumi_feb
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET efhumi_mar = wt.efhumi_mar
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET efhumi_apr = wt.efhumi_apr
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET efhumi_may = wt.efhumi_may
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET efhumi_jun = wt.efhumi_jun
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET efhumi_jul = wt.efhumi_jul
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET efhumi_aug = wt.efhumi_aug
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET efhumi_sep = wt.efhumi_sep
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET efhumi_oct = wt.efhumi_oct
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET efhumi_nov = wt.efhumi_nov
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;


BEGIN;
UPDATE ana_grid AS ana
SET efhumi_dec = wt.efhumi_dec
FROM temp_ana_grid AS wt
WHERE ana.__gid = wt.__gid ;
COMMIT;



-- ==================================================================================
-- (10) 최종 데이터 셋 결과 확인
-- ==================================================================================

-- 최종 데이터 셋(ana_grid) 결과 확인
BEGIN;
SELECT * FROM ana_grid;
COMMIT;