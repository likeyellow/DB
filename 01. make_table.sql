/*
Create by Bea Eun Mi(likeyellowand@gmail.com)
2019.12.18
*/

-- ==================================================================================
-- 엑셀 파일 업로드용 테이블 생성 스크립트
-- ==================================================================================

--------- 감시자원
-- 감시자원(CCTV) 테이블 생성 
CREATE TABLE IF NOT EXISTS raw_ff_cctv
(
	first_mnagn_nm character varying(4),	-- 1차관리주체
	second_mnagn_nm character varying(30),	-- 2차관리주체
	install_location character varying(50),	-- 설치장소
	location_juso character varying(50),	-- 세부주소
	install_year character varying(10),		-- 설치년도
	model_nm character varying(10),			-- 모델명
	produce_nm character varying(10),		-- 제조사명
	resolution character varying(10),		-- 해상도
	night_shoot character varying(1),		-- 야간촬영기능
	alarm character varying(1),				-- 알람기능
	motion_sensor character varying(1),		-- 동작감지기능
	hear_sensor character varying(1),		-- 열감지기능
	etc character varying(100),				-- 기타특화기능
	xcrd numeric(100, 10),					-- 위도
	ycrd numeric(100, 10)					-- 경도
);



-- 감시자원(초소, 탑) 테이블 생성 
CREATE TABLE IF NOT EXISTS raw_ff_choso_tower
(
	sigun character varying(3),				-- 시군구
	site character varying(30),				-- 설치장소
	manage_site character varying(30),		-- 관리주체
	setup_year character varying(5),		-- 최초개설년도
	repair_date character varying(10),		-- 보수시기
	repair_cont character varying(20),		-- 보수내용
	repair_cost int,						-- 보수비용
	build_condt character varying(10),		-- 건물상태
	note character varying(10),				-- 감시자원 분류
	x numeric(100,10),						-- 위도
	y numeric(100,10)						-- 경도
);


--------- 산불 발생 현황
-- 산불 피해대장 테이블 생성
CREATE TABLE raw_ff_damage (
	OB_YEAR character varying(4),			-- 발생일시_년
	OB_MONTH character varying(2),			-- 발생일시_월
	OB_DAY character varying(2),			-- 발생일시_일
	OB_TIME character varying(5),			-- 발생일시_시간
	OB_WEEK character varying(1),			-- 발생일시_요일
	EX_YEAR character varying(4),			-- 진화일시_년
	EX_MONTH character varying(2),			-- 진화일시_월
	EX_DAY character varying(2),			-- 진화일시_일
	EX_TIME character varying(5),			-- 진화일시_시간
	GS character varying(2),				-- 발생장소_관서
	SIDO character varying(3),				-- 발생장소_시도
	SIGUNGU character varying(3),			-- 발생장소_시군구
	EM character varying(15),				-- 발생장소_읍면
	DL character varying(15),				-- 발생장소_동리
	JIBUN character varying(10),			-- 발생장소_지번
	CAUSE_CD character varying(2),			-- 발생원인_구분
	CAUSE_DETAIL character varying(50),		-- 발생원인_세부원인
	CAUSE_ETC character varying(100),		-- 발생원인_기타	
	DEMAGE_AREA numeric(6, 3),				-- 피해면적
	JUSO character varying(100),			-- 발생장소_주소
	X numeric(100,10),						-- 위도
	Y numeric(100,10)						-- 경도
);



--------- 문화재
-- 문화재 테이블 생성 
CREATE TABLE public.raw_cultural_assets
(
	sigun character varying(4),			-- 1월 평균실효습도
    name character varying(60),			-- 1월 평균실효습도
    mnagn_nm character varying(60),		-- 1월 평균실효습도
    designate_yr character varying(12),	-- 1월 평균실효습도
    assets_gd character varying(10),	-- 1월 평균실효습도
    add character varying(60),			-- 1월 평균실효습도
    x numeric,							-- 1월 평균실효습도
    y numeric							-- 1월 평균실효습도
);



--------- 기상
-- 기상관측 데이터 테이블 생성
CREATE TABLE raw_wthr_sttn (
	wthr_sttn_no integer, 	            -- 관측소 표준지점변호
	wthr_sttn_nm character varying(40),	-- 관측소명 
	x numeric(100, 10),	                -- 관측소 위도
	y numeric(100, 10),	                -- 관측소 경도
	temp_jan numeric(10,2),				-- 1월 평균기온
	temp_feb numeric(10,2),				-- 2월 평균기온
	temp_mar numeric(10,2),				-- 3월 평균기온
	temp_apr numeric(10,2),				-- 4월 평균기온
	temp_may numeric(10,2),				-- 5월 평균기온
	temp_jun numeric(10,2),				-- 6월 평균기온
	temp_jul numeric(10,2),				-- 7월 평균기온
	temp_aug numeric(10,2),				-- 8월 평균기온
	temp_sep numeric(10,2),				-- 9월 평균기온
	temp_oct numeric(10,2),				-- 10월 평균기온
	temp_nov numeric(10,2),				-- 11월 평균기온
	temp_dec numeric(10,2),				-- 12월 평균기온
	humi_jan numeric(10,2),				-- 1월 평균습도
	humi_feb numeric(10,2),				-- 2월 평균습도
	humi_mar numeric(10,2),				-- 3월 평균습도
	humi_apr numeric(10,2),				-- 4월 평균습도
	humi_may numeric(10,2),				-- 5월 평균습도
	humi_jun numeric(10,2),				-- 6월 평균습도
	humi_jul numeric(10,2),				-- 7월 평균습도
	humi_aug numeric(10,2),				-- 8월 평균습도
	humi_sep numeric(10,2),				-- 9월 평균습도
	humi_oct numeric(10,2),				-- 10월 평균습도
	humi_nov numeric(10,2),				-- 11월 평균습도
	humi_dec numeric(10,2),				-- 12월 평균습도
	wind_jan numeric(10,2),				-- 1월 평균풍속
	wind_feb numeric(10,2),				-- 2월 평균풍속
	wind_mar numeric(10,2),				-- 3월 평균풍속
	wind_apr numeric(10,2),				-- 4월 평균풍속
	wind_may numeric(10,2),				-- 5월 평균풍속
	wind_jun numeric(10,2),				-- 6월 평균풍속
	wind_jul numeric(10,2),				-- 7월 평균풍속
	wind_aug numeric(10,2),				-- 8월 평균풍속
	wind_sep numeric(10,2),				-- 9월 평균풍속
	wind_oct numeric(10,2),				-- 10월 평균풍속
	wind_nov numeric(10,2),				-- 11월 평균풍속
	wind_dec numeric(10,2),				-- 12월 평균풍속
	efhumi_jan numeric(10,2), 			-- 1월 평균실효습도
	efhumi_feb numeric(10,2),			-- 2월 평균실효습도
	efhumi_mar numeric(10,2),			-- 3월 평균실효습도
	efhumi_apr numeric(10,2),			-- 4월 평균실효습도
	efhumi_may numeric(10,2),			-- 5월 평균실효습도
	efhumi_jun numeric(10,2),			-- 6월 평균실효습도
	efhumi_jul numeric(10,2),			-- 7월 평균실효습도
	efhumi_aug numeric(10,2),			-- 8월 평균실효습도
	efhumi_sep numeric(10,2),			-- 9월 평균실효습도
	efhumi_oct numeric(10,2),			-- 10월 평균실효습도
	efhumi_nov numeric(10,2),			-- 11월 평균실효습도
	efhumi_dec numeric(10,2)			-- 12월 평균실효습도
);


