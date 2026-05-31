************************
***Bond data cleaning***
************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"

**# Bookmark #1
***Start with original main dataset*** 
use "$MERGENT\Clean\MuniBond_20210716_v3.dta", clear

**Do base cleaning from other project**

*isolate 2011-2020
*JH Note: we may not need to or want to drop prior to 2011 for our project
keep  if year>=2011 & year<=2020

save "$MERGENT\Clean\MuniBond_20210716_v3_2011_2020.dta", replace

use "$MERGENT\Clean\MuniBond_20210716_v3_2011_2020.dta", clear	


* Create CUSIP6
gen cusip6 = substr(cusip,1,6)


// Step 3: Generate quarter indicator
gen qtr = yq(year(offering_date), quarter(offering_date))
	format qtr %tq
	sort qtr


rename *, lower

foreach v in amount maturity    {
	keep if `v' != .
}

merge m:1 cusip6 using  "$MERGENT\Clean\CUSIP_LOCATION_FIP_INDEX_Jan_05_2023.dta", keepusing(COUNTYFP_STATEFP timing)
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                        28,271
        from master                     5,473  (_merge==1)
        from using                     22,798  (_merge==2)

    Matched                         1,198,687  (_merge==3)
    -----------------------------------------
*/

*br cusip year issuer_long_name COUNTYFP_STATEFP timing _merge
*JH: after skimming through, doesn't seem like anything uniquely labels cities/counties. Plenty of non-city/county issusers get a fips code matched

drop if _merge !=3
drop _merge
gen  fips =  (COUNTYFP_STATEFP)

gen fips_real = real(fips)

drop fips
rename fips_real fips
	
drop if fips==.
*63,619 obs dropped
 	


********************************************************************************
**# Bookmark #2
**** Sample selection part 1 - drop state bonds.    1121492 
********************************************************************************
gen temp1 = (substr(issuer_long_name, strlen(issuer_long_name)-2, 3) == " ST")
keep if temp1 == 0 
*13,576 obs dropped
drop temp1
*unique cusip6 
gunique cusip6 
*1,121,492 obs; 28,274 unique cusip6
********************************************************************************
**** Table 1:     1121492 		28274
********************************************************************************

********************************************************************************
**** Sample selection part 2 - only keep city/county bonds    322,039 
********************************************************************************

*JH: have to use the names to filter down 
/*get list of unique cusip6 / issuer names to work through
preserve
duplicates drop issuer_long_name cusip6, force
count
*28,280 unique issuer_long_name-cusip6 dyads
duplicates report issuer_long_name
*lot of duplicates by name for some reason still
duplicates tag issuer_long_name, gen(dup_name)
duplicates report cusip6
*only a few dups by cusip6
duplicates tag cusip6, gen(dup_cusip)
rename issuer_type issuer_type_old
sort issuer_long_name cusip6
*br cusip year issuer_long_name COUNTYFP_STATEFP timing cusip6 if dup_name > 0
*There are some places where the cusip6 is slighlty different (typos in raw data?)
*Go by issuer_long_name instead
drop dup*
duplicates drop issuer_long_name, force
*27,972 unique issuer_long_name
keep issuer_long_name cusip6 fips county location issuer_type_old state
save "$MERGENT\Clean\240730_issuername_unique.dta", replace
restore
*/

**Work in list of unique issuer names**
/*
use "$MERGENT\Clean\240730_issuername_unique.dta", clear
*gen new issuer_id
gegen issuer_id_new = group(issuer_long_name)
sort state issuer_long_name

*Use strings in names to exclude: school districts, special districts
*Gen temp variable for what to keep
*Ignore issuer_type because it is often wrong

gen temp1 = 1 if strpos(issuer_long_name,"SCH DI") > 0
replace temp1 = 1 if strpos(issuer_long_name,"CMNTY") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"SWR REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"TAX REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"TAX") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"BLDG") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"CORP") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"DEV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"HOSP") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"WTR") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"HSG") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"HOSP") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REC") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"DRAIN") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"UNIV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"COLLEGE") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"UTIL") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"DIST") > 0 & strpos(issuer_long_name,"UTIL") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"WTR") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"SWR") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"UTIL") > 0 & strpos(issuer_long_name,"WTR") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"REFUSE") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"SWR") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"ARPT") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & state == "AK" & temp1 == . 
replace temp1 = 1 if strpos(issuer_long_name,"WASTE") > 0 & strpos(issuer_long_name,"WTR") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"HEALTH") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"HEALTH") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0 & strpos(issuer_long_name,"DEV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"SALES") > 0 & strpos(issuer_long_name,"TAX") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"ELEC") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"IMPT") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"WATER") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"WASTE") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"HWY") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0 & strpos(issuer_long_name,"TAX") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"DEV") > 0 & strpos(issuer_long_name,"TAX") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"DIST") > 0 & strpos(issuer_long_name,"IMPT") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"HSG") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"AGY") > 0 & strpos(issuer_long_name,"HSG") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"AGY") > 0 & strpos(issuer_long_name,"FIN") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"AGY") > 0 & strpos(issuer_long_name,"TAX") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"FIN") > 0 & strpos(issuer_long_name,"CORP") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"ST ") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"SPL") > 0 & strpos(issuer_long_name,"TAX") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"MET") > 0 & strpos(issuer_long_name,"DIST") > 0 & state == "CO" & temp1 == . 
replace temp1 = 1 if strpos(issuer_long_name,"LIB") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == . 
replace temp1 = 1 if strpos(issuer_long_name,"FIRE") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == . 
replace temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0 & strpos(issuer_long_name,"WTR") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"SPL") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"SYS") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"AGY") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"BRD") > 0 & strpos(issuer_long_name,"ED") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"POLLU") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"FAC") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"PORT") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"SPL") > 0 & strpos(issuer_long_name,"OBLI") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"BLDG") > 0 & strpos(issuer_long_name,"CORP") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"PK") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0 & strpos(issuer_long_name,"ARPT") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"DEV") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"PUB") > 0 & strpos(issuer_long_name,"SCH") > 0 & temp1 == .

count if temp1 == .
*7,965 out of 27,972

*Now, go through temp1 == . and clean manually
br state issuer_long_name issuer_id_new temp1 if temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"GAS") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"SOLID WASTE") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"COLLEGE") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"ZONE") > 0 & strpos(issuer_long_name,"OPPOR") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"HEALTH") > 0 & strpos(issuer_long_name,"SYS") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"PUB") > 0 & strpos(issuer_long_name,"FAC") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"FRANCHISE") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"RCPTS") > 0 & strpos(issuer_long_name,"TAX") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"PUB") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"COMM") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"TAX") > 0 | strpos(issuer_long_name,"REV") > 0  & state == "AR" & temp1 == .

replace temp1 = 1 if issuer_id_new == 204
replace temp1 = 1 if inlist(issuer_id_new,7960,7961,12228,14043,17011,745,747, ///
	1097,2834,3297,4279,5480,8078,9124,9129,14983,14987,15431,15719,17961,18986, ///
	19753,19797,22154,23164,24304,24453,24970,26972,308,814,1146,1167,1654,2376, ///
	2424,2425,2456,3137,3146,3179,3186,3478,3493,3564,5108,5729,7629,7688,7812, ///
	7813,8041,8241,8503,8729,8771,9236,9295,9910,10641,10687,11613,11630,11634, ///
	11733,12915,12916,12999,13110,13412,13452,14187,14188,14206,14207,14209, ///
	14283,14287,14298,14299,14301,14765,14812,15007,15222,15608,15645,15930)

replace temp1 = 1 if strpos(issuer_long_name,"PENSION OBLIG") > 0 & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"IMPT") > 0 & strpos(issuer_long_name,"BD") > 0  & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"FIN") > 0 & strpos(issuer_long_name,"AUTH") > 0  & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"AGY") > 0 & strpos(issuer_long_name,"DEV") > 0  & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"DIST") > 0 & strpos(issuer_long_name,"CALIF") > 0  & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"WASTEWATER") > 0 & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"CALIF") > 0  & temp1 == .
replace temp1 = 1 if inlist(issuer_id_new,18207,19086,21707,21914,21943,21947,  ///
	21973,21975,21990,23179,24326,24938,25266,26982,64,1018,1019,1307,2253, ///
	2257,2639,4956,4958,6271,6497,7322,7559,8743,9455,14241,16595,18828,25599, ///
	27651,5160,10085,10580,16215,12491,24467,27394,27396,179,390,994,1370, ///
	1563,2315,3399,4395,4398,4832,5953,6852,8153,8767,9964,9967,11903,11910, ///
	13027,13029,13124,13169,13174,13185,13612,13615,14505,14775,15783,15818, ///
	15826,15829,16701,18227,18391,18781,19016,19026,19030,19223,20088,22228, ///
	23552,24441,24574,24575,24594,24595,25378,27526,909,3006,3557,4136,4254,4391)	

replace temp1 = 1 if inlist(issuer_id_new,5523,9279,9883,16864,25666,26060,38,  ///
	5389,6171,11669,11689,11699,12433,21247,27458,27725,2146,2150,3457,17729, ///
	111,1025,2273,2336,2859,3017,3949,5238,5249,5701,6772,6775,6797,6798,7708, ///
	7869,9283,10685,11082,11765,11790,11803,12220,12308,12311,12448,13011,13049, ///
	13065,13066,13067,13126,14539,15389,16106,16495,16667,18059,18143,18144, ///
	18145,18146,18147,19803,20479,20746,21352,21486,21582,22954,23197,23390, ///
	23697,25807,27277,27481,27602)
	
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"IND") > 0  & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"SCH") > 0 & strpos(issuer_long_name,"IND") > 0  & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"PUB LIB") > 0 & strpos(issuer_long_name,"IND") > 0  & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"BLDG") > 0 & strpos(issuer_long_name,"IND") > 0  & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"DEPT") > 0 & strpos(issuer_long_name,"IND") > 0  & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"CORP") > 0 & strpos(issuer_long_name,"IND") > 0  & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"DEV") > 0 & strpos(issuer_long_name,"IND") > 0  & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"DIST") > 0 & strpos(issuer_long_name,"IND") > 0  & temp1 == .
	
replace temp1 = 1 if inlist(issuer_id_new,8197,8198,8799,11953,16800,23386,  ///
	26957,893,894,5041,18483,18885,22774,24162,24517,27741,855,1229,1231,2309, ///
	3538,7155,7663,12515,13474,13806,13808,14355,14357,14367,14368,14369, ///
	15124,16583,16898,17970,25126,25505,26166,27209,10,833,2846,3078,6238,9650, ///
	9651,11186,12536,12982,12991,14096,14351,14352,17225,17295,17297,17301,18731, ///
	19926,19927,23777,24169,24612,25449,26065,2571,3810,3998,8613,9643,14397,14784, ///
	15165,15746,16956,23275,25196,27675,1187,1189,1190,1191,8659,15192,15196, ///
	15197,15199,16404,16405,16406,16409,16410,16411,20424,20425,26265,27033,27034,27035)			
	
replace temp1 = 1 if strpos(issuer_long_name,"REG") > 0 & strpos(issuer_long_name,"SCH") > 0 & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"SCHOOL") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"SCHS") > 0 & temp1 == .	
	
replace temp1 = 1 if inlist(issuer_id_new,5738,410,413,587,1277,1473,1739,1807,1808, ///
	2354,3123,3648,3679,4018,4019,4093,4750,5362,5677,6108,6352,7194,7196,8113, ///
	9479,9481,9483,9499,9577,9693,9904,10020,10258,10642,10742,11625,11835,12281, ///
	12284,12494,12533,13022,13075,13133,13373,14089,14107,14400,14552,14558, ///
	15109,15136,15726,15912,16279,16919,17144,17388,17738,18065,18215,18219, ///
	18220,18783,18835,18851,19555,20243,20848,21609,21745,21754,21757,22474, ///
	23296,23298,23304,23491,23546,24095,24309,24655,25054,25125,25292,26360,26379, ///
	26991)			
	
replace temp1 = 1 if strpos(issuer_long_name,"MINN") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .		
replace temp1 = 1 if strpos(issuer_long_name,"MINN") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp1 == .		
replace temp1 = 1 if strpos(issuer_long_name,"MINN") > 0 & strpos(issuer_long_name,"HSG") > 0 & temp1 == .		
replace temp1 = 1 if strpos(issuer_long_name,"MINN") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .		
replace temp1 = 1 if strpos(issuer_long_name," MO") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .		
replace temp1 = 1 if strpos(issuer_long_name,"MO ") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp1 == .		
replace temp1 = 1 if strpos(issuer_long_name,"LTD") > 0 & strpos(issuer_long_name,"OBLIG") > 0 & temp1 == .		
replace temp1 = 1 if strpos(issuer_long_name,"N C") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .		
replace temp1 = 1 if strpos(issuer_long_name,"N D") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .		
	
replace temp1 = 1 if inlist(issuer_id_new,15748,24016,1295,6996,12076,14324,16525,  ///
	23936,23944,4250,4516,10551,11958,13563,14321,19325,19328,25264,27514,1916, ///
	8858,16168,16169,16343,16345,16346,22808,17630,17639,17645,17647,25538,7894, ///
	8011,1349,1386,2581,3658,3663,3839,3841,5050,5634,5832,5840,6452,6511,6512, ///
	6668,6698,7846,8234,8615,9875,11171,11206,11533,11534,12420,12469,12606,12921, ///
	13291,13937,13940,13943,13953,14370,14537,14538,14628,17033,17034,17807,18536, ///
	18541,19119,19123,19577,19955,20663,21814,22253,22367,22368,22404,23385, ///
	24291,24301,24540,24541,25532,26275,26550)		

replace temp1 = 1 if strpos(issuer_long_name,"N H") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .			
replace temp1 = 1 if strpos(issuer_long_name,"N J") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .			
replace temp1 = 1 if strpos(issuer_long_name,"N J") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp1 == .			
replace temp1 = 1 if strpos(issuer_long_name,"N MEX") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"N MEX") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"N MEX") > 0 & strpos(issuer_long_name,"FAC") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"NEW MEX") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"NEW MEX") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"OHIO") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"OHIO") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"OHIO") > 0 & strpos(issuer_long_name,"PUB LIB") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"ORE") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"PA") > 0 & strpos(issuer_long_name,"FAC REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"PA") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"S C") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"S C") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .
	
replace temp1 = 1 if inlist(issuer_id_new,17178,17183,17239,17244,17245,17246,17254,17255, ///
	17380,19250,17280,21993,4472,13431,17748,20942,20945,25930,2,3375,4087,7582, ///
	9413,12061,17345,17350,17363,17367,17469,17471,18570,21550,24338,24986,25365, ///
	25650,26954,478,1629,2288,4664,5997,6168,9029,9621,11102,13842,14714,14715, ///
	15813,15815,18351,18363,18365,18366,18373,18384,25289,25461,25483,25493,25551, ///
	27953,11372,15433,17520,18411,18415,18439,18463,18605,21633,25261,12039, ///
	20183,20285,20858,21452,22088,4193,6197,16436,19427,19429,19436,25478,25546, ///
	26902,20983,20986,20990,20999,1759,4889,9826,13311,17394,23243,6040,13560)		

replace temp1 = 1 if strpos(issuer_long_name,"TEX") > 0 & strpos(issuer_long_name,"COLLEGE DIST") > 0 & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"UTAH") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"UTAH") > 0 & strpos(issuer_long_name,"ASSMT") > 0 & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"WIS") > 0 & strpos(issuer_long_name,"REV") > 0 & temp1 == .	
replace temp1 = 1 if strpos(issuer_long_name,"WIS") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"WIS") > 0 & strpos(issuer_long_name,"ASSMT") > 0 & temp1 == .
	
replace temp1 = 1 if inlist(issuer_id_new,23261,24679,3545,4076,15734,15750,  ///
	15751,15752,15753,15754,15755,459,1054,1062,1077,1875,2128,3281,3282,3291, ///
	3292,5176,7866,8322,8407,8748,8887,8913,10533,10943,14195,14413,15281,15350, ///
	16484,18003,19335,20137,20171,20201,20723,21868,22942,23154,24759,24772, ///
	24788,24792,25549,25704,25732,25968,26515,26849,27564,27956,23267,25626, ///
	25630,25634,25636,25637,25638,2246,4174,10182,25938,25939,25553,1136,4479, ///
	4804,5533,7008,7089,8821,16579,16787,17674,20127,20549,22599,22899,23086, ///
	23413,23414,25547,25613,25705,25756,299,2587,26911,3307,4225)	
		
/*	
replace temp1 = 1 if inlist(issuer_id_new,,  ///
	, ///
	, ///
	, ///
	, ///
	, ///
	, ///
	)	
*/	
	
count if temp1 == .	
*6,374

*keep these and save list
keep if temp1 == .
drop temp1
save "$MERGENT\Clean\240730_issuername_unique_citycounty.dta", replace	
	
*/

*Bring in 7/30/24 list of city and county issuer names

mmerge issuer_long_name using "$MERGENT\Clean\240730_issuername_unique_citycounty.dta", ///
	type(n:1) missing(nomatch)
/*
                vars |    194  (including _merge)
         ------------+---------------------------------------------------------
              _merge | 799453  obs only in master data                (code==1)
                     | 322039  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*br cusip year state issuer_long_name issuer_id_new _merge
*seems like this works
keep if _merge == 3
drop _merge
sort state issuer_id_new offering_date

gunique cusip6 
*322,039 obs; 6,479 unique cusip6
gunique issuer_long_name
*6,374 issuer_long_name

*save file
save "$MERGENT\Clean\240801_munibond_citycounty_20112020.dta", replace

********************************************************************************
**** Table 1:     322,039 		6,479
********************************************************************************

********************************************************************************
**** Sample selection part 3 - only keep new money (non-refunding)    [147,113]
********************************************************************************

use "$MERGENT\Clean\240801_munibond_citycounty_20112020.dta", clear

*JH note to self: cusip is what uniquely identifies; a bundle of cusips have the same issue_id
*br cusip year issuer_long_name issuer_id_new issue_description new_money use_proceeds

*based on comparing "refund" in issue_description and new_money, seems new_money == 0 does a good job of capturing when "refund" is in description

drop if new_money == 0

gunique cusip6 
*147,113 obs; 4,098 unique cusip6
gunique issuer_long_name
*4,012 issuer_long_name

********************************************************************************
**** Table 1:     147,113 		4,098
********************************************************************************

********************************************************************************
**** Sample selection part 4 - only keep GO bonds    [144,214]
********************************************************************************
*br cusip year issuer_long_name issuer_id_new issue_description repayment_source source_of_repayment use_proceeds

*JH: doesn't seem like repayment_source == 1 captures all GO bonds
*E.g., cusip 033161A59 has repayment_source == 0 but description is "General Obligation General Purpose"
*what uniquely identifies GO bonds?
*For anchorage, alaska, use_proceeds can == PSED and issue_description can have "General Obligation"

tab use_proceeds
*GPPI is 76.5%, WTR is 5.6%, PSED is 3.0%, GVPB is 1.9%

*note that to some extent, we've dropped many revenue bonds in the manual city/county filtering process
*in issue_description, if "GENERAL OBLIGATION" is not there, still seems to be GO
*how many have "general" or "oblig"?
gen temp1 = strupper(issue_description)
gen temp2 = 1 if strpos(temp1,"GENERAL") > 0 | strpos(temp1,"OBLIG") > 0
count if temp2 == .
*19,828 out of 147,113 (13.5%) don't have it
*br cusip year issuer_long_name issuer_id_new issue_description use_proceeds repayment_source if temp2 == .
*from skimming through data, looks like some descriptions have "Revenue" in them or special districts
*ex: zionsville, indiana issues bonds for "special taxing district bonds" of the park district. It's really the park district issuing: https://www.zionsville-in.gov/AgendaCenter/ViewFile/Item/2169?fileID=2807

*gen temp var if description has district or revenue
gen temp3 = 1 if temp2 == . & strpos(temp1,"REVENUE") > 0
replace temp3 = 1 if temp2 == . & strpos(temp1,"DISTRICT") > 0
count if temp3 == 1
*1,271

*do we want to include limited tax GO bonds aka special assessment debt?
*in these cases, a new tax is being levied, so they're similar to revenue bonds: https://mrsc.org/explore-topics/finance/debt/types-of-municipal-debt
gen temp4 = 1 if temp2 == . & strpos(temp1,"SPECIAL") > 0 & strpos(temp1,"ASSESSMENT") > 0
replace temp4 = 1 if temp2 == . & strpos(temp1,"LIMITED") > 0 & strpos(temp1,"TAX") > 0
replace temp4 = 1 if temp2 == . & strpos(temp1,"SPECIAL") > 0 & strpos(temp1,"TAX") > 0
count if temp4 == 1
*2,809

*include tax anticipation because these are short-term debt
replace temp4 = 1 if temp2 == . & strpos(temp1,"ANTICIP") > 0 & strpos(temp1,"TAX") > 0
replace temp4 = 1 if temp2 == . & strpos(temp1,"ANTICIPATION") > 0 

*exclude "unlimited tax"
replace temp4 = . if temp4 == 1 & strpos(temp1,"UNLIMITED") > 0 & strpos(temp1,"TAX") > 0
*unlimited tax is a more common term for TX bonds

*drop if temp3 and temp4 == 1
keep if temp3 == . & temp4 == .
*2,899 obs dropped

drop temp*

gunique cusip6 
*144,214 obs; 4,021 unique cusip6
gunique issuer_long_name
*3,936 issuer_long_name

********************************************************************************
**** Table 1:     144,214 		4,021
********************************************************************************

********************************************************************************
**** Sample selection part 5 - keep only fixed coupon (as in Cuny) [144,145]   
********************************************************************************
tab coupon_code
/*
coupon_code |      Freq.     Percent        Cum.
------------+-----------------------------------
        FXD |     23,815       16.51       16.51
        IXL |          1        0.00       16.51
        OID |     18,452       12.79       29.31
        OIP |    101,878       70.64       99.95
        SPC |          7        0.00       99.96
        STP |          2        0.00       99.96
        VAR |          2        0.00       99.96
        ZER |         57        0.04      100.00
------------+-----------------------------------
      Total |    144,214      100.00
*/
keep if coupon_code == "FXD" |  coupon_code == "OID" |  coupon_code == "OIP"
*69 obs dropped

gunique cusip6	
*144,145 obs; 4,020 unique cusip6
gunique issuer_long_name
*3,935 issuer_long_name
********************************************************************************
**** Table 1:     144,145	3,935
********************************************************************************

********************************************************************************
**** Sample selection part 6 - keep only federal exempt [134,410]
********************************************************************************
tab taxexempt_federal
/*
taxexempt_f |
     ederal |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      9,735        6.75        6.75
          1 |    134,410       93.25      100.00
------------+-----------------------------------
      Total |    144,145      100.00
*/
keep if taxexempt_federal == 1

gunique cusip6	
*134,410 obs; 3,931 unique cusip6
gunique issuer_long_name
*3,847 issuer_long_name
********************************************************************************
**** Table 1:     134,410	3,931
********************************************************************************


**************************
**# Bookmark #3
*	CLEAN VARIABLES
**************************

replace agent_count = 0 if agent_count==.

*Variable - numerical values for categories of use_of_proceeds
local k = 0
capture drop use_proceeds
g use_proceeds = 0
levelsof use_of_proceeds, local(use_loc)	
foreach i of local use_loc {
	di "`k' 	`i'"
	quietly local k = `k' + 1
	quietly replace use_proceeds = `k' if use_of_proceeds == "`i'"
}
/* Note: To map this list to the later code that collapses to issuer-month level, add 1 (so that use_proceeds == 1 means AIR)
0         AIR
1         BRDG
2         CFCT
3         CIVC
4         CORR
5         CUTI
6         EDEV
7         ELEC
8         FISE
9         FLOD
10         GAS
11         GPPI
12         GVPB
13         HIED
14         HOSP
15         IDEV
16         IRRG
17         LIMU
18         MALL
19         MASS
20         MFHG
21         NURS
22         OHCA
23         OPUB
24         OREC
25         OTED
26         OTHS
27         OTRN
28         OUTI
29         PARK
30         PFR
31         PKG
32         POLE
33         POLL
34         PRES
35         PSED
36         REDV
37         RETR
38         SANI
39         SEAP
40         SFHG
41         SPOR
42         THTR
43         TOLL
44         WAST
45         WTR
*/

*Logs
foreach v in /*maturity*/ agent_count  {
	g ln_`v' = log(`v')
}


*Variable - Tax Exempt - state tax
	g taxexempt_state = 1
	replace taxexempt_state=0 if state_tax==""
	
*Variable - long-term
	/* g maturity_years = maturity/12 */
	g long_term = cond(maturity_years >= 25, 1, 0, 0)
	
*Variable - yield_avg
	winsor2 yield ,  cuts(2 98) suffix(_w)

**************************************************************************
**# Bookmark #4
***Calculate issue/series-level variables that aggregate cusip-level vars
**************************************************************************
sort state year issue_id cusip

br issue_id cusip year offering_date maturity_date settlement_date issuer_long_name yield amount maturity num_cusip yield_w

*Amount: Calc total amount raised in a series
gegen total_amount = sum(amount), by(issue_id)

*Yield: Calc largest yield and weighted average
*Version 1: Base wavg calcs off the raw yield and winsorize or trim at the end
gen temp1 = yield * amount
gegen temp2 = sum(temp1), by(issue_id)
gen yield_wavg = temp2 / total_amount
drop temp*
*Version 2: Base wavg calcs off of winsorized yield (yield_w)
gen temp1 = yield_w * amount
gegen temp2 = sum(temp1), by(issue_id)
gen yield_w_wavg = temp2 / total_amount
drop temp*
*Version 3: Base yield of largest bond off of raw yield
gegen temp1 = max(amount), by(issue_id)
gen temp2 = 1 if amount == temp1
gen temp3 = yield if temp2 == 1
gegen yield_bigamt = max(temp3), by(issue_id)
drop temp*
*Version 4: Base yield of largest bond off of winsor yield
gegen temp1 = max(amount), by(issue_id)
gen temp2 = 1 if amount == temp1
gen temp3 = yield_w if temp2 == 1
gegen yield_w_bigamt = max(temp3), by(issue_id)
drop temp*

*Maturity: note current maturity var seems to capture # of months from offering date to longest maturity
rename maturity maturity_mths_longest
*gen maturity in duration for each bond in a series
gen maturity_mths = (maturity_date - offering_date) / (365/12)
*round down
replace maturity_mths = floor(maturity_mths)
*Calc a few versions of maturity: V1 (longest, already calc), V2 (biggest amt), V3 (weighted avg) 
*Version 2: biggest amount
gegen temp1 = max(amount), by(issue_id)
gen temp2 = 1 if amount == temp1
gen temp3 = maturity_mths if temp2 == 1
*spread this out
gegen maturity_bigamt = max(temp3), by(issue_id)
drop temp*
*Verion 3: weighted avg
gen temp1 = maturity_mths * amount
gegen temp2 = sum(temp1), by(issue_id)
gen temp3 = temp2 / total_amount
*round down
gen maturity_wavg = floor(temp3)
drop temp*

*Indicators: rated, callable, insured, sinkable, offer_type taxexempt_federal taxexempt_state green
*Note taxexempt_federal is always 1 by sample selection

*Look into offer_type
*Note offer_type = 1 if competitive, negotiated, or private placement

tab offer_type
tab offering_type
*Make a version of offer_type that just distinguishes between competitive vs. not
gen comp_offering = 1 if offering_type == "COMP"
replace comp_offering = 0 if comp_offering == .

*Next, check if these indicators vary within a series

local varlist rated callable insured sinkable taxexempt_state green comp_offering
foreach x of local varlist{
	gegen temp1 = max(`x'), by(issue_id)
	gegen temp2 = min(`x'), by(issue_id)
	count if temp1 != temp2
	drop temp*
}

/*Notes
- rated: 59,883
- callable: 124,589
- insured: 1,131
- sinkable: 40,793
- taxexempt_state: 24
- green: 0
- comp_offering: 0
*/

*for all except green and comp_offering (don't vary within series, so can collapse fine), make weighted average version and biggest version
local varlist rated callable insured sinkable taxexempt_state
foreach x of local varlist{
	*weighted avg version
	gen temp1 = `x' * amount
	gegen temp2 = sum(temp1), by(issue_id)
	gen `x'_wavg = temp2 / total_amount
	drop temp*
	
	*biggest amt version
	gegen temp1 = max(amount), by(issue_id)
	gen temp2 = 1 if amount == temp1
	gen temp3 = `x' if temp2 == 1
	*spread this out
	gegen `x'_bigamt = max(temp3), by(issue_id)
	drop temp*
}

*save file
save "$MERGENT\Clean\240801_munibond_citycounty_20112020_cusiplevel.dta", replace

*****************************************************************************
**# Bookmark #5
***Collapse to series level***
*****************************************************************************
use "$MERGENT\Clean\240801_munibond_citycounty_20112020_cusiplevel.dta", clear

*how many unique series?
gunique issue_id
*9,754 unique series 

*Collapse to series level. For each series, retain the largest amount and longest maturity
gcollapse (max) amount_big=amount ln_amount_big=ln_amount maturity_mths_longest ///
	ln_num_cusip num_cusip green agent_count ln_agent_count tax_amt ///
	long_term total_amount *_wavg *_bigamt comp_offering ///
	, by(issue_id year offering_date settlement_date diffd state issuer_long_name county cusip6 qtr fips issuer_id_new use_proceeds)

sort state cusip6 year issue_id 

*does issue_id uniquely identify?
/*
duplicates report issue_id
/*
--------------------------------------
   Copies | Observations       Surplus
----------+---------------------------
        1 |         9732             0
        2 |           38            19
        3 |            9             6
--------------------------------------
*/
duplicates tag issue_id, gen(dup)
*br if dup > 0
*looks like these are cases where one issue_id has different cusip6 (ex: bridgeport conn) and cusips changed over time
*leave this alone for now because not many observations and hard to figure out why cusip6 changed
*/
gunique cusip6
*9,779 obs (series); 3,931 unique cusip6
gunique issuer_long_name
*3,847 unique issuer_long_name

********************************************************************************
**** Table 1:     9,779		3,931 
********************************************************************************

**Additional cleaning**

*winsorize yield vars not previously winsorized
winsor2 yield_wavg, cuts(2 98) suffix(_w)
winsor2 yield_bigamt, cuts(2 98) suffix(_w)

tab year
/*
       year |      Freq.     Percent        Cum.
------------+-----------------------------------
       2011 |        917        9.38        9.38
       2012 |        905        9.25       18.63
       2013 |      1,023       10.46       29.09
       2014 |        964        9.86       38.95
       2015 |        958        9.80       48.75
       2016 |      1,012       10.35       59.10
       2017 |      1,066       10.90       70.00
       2018 |      1,184       12.11       82.10
       2019 |      1,063       10.87       92.97
       2020 |        687        7.03      100.00
------------+-----------------------------------
      Total |      9,779      100.00
*/

*label vars
label var diffd "Date Difference"						// = settlement_date - offering_date
label var issuer_id_new "Issuer ID"						// Issuer ID based on issuer_long_name
label var use_proceeds "Use of Proceeds"				//Takes values from one to ~50 for each of the use_of_proceeds categories from Mergent. See above commented-out block for mapping from number to category
label var amount_big "Amount (largest)"					// Amount of largest bond in a series
label var ln_amount_big "ln(Amount(largest))"			// Ln of amount of largest bond in a series
label var maturity_mths_longest "Maturity (longest)"	// Maturity in months of bond with the longest maturity in a series
label var ln_num_cusip "ln(Cusips in issue)"			// Ln of the number of CUSIPs in the issue
label var num_cusip "Num Cusips"						// Number of Cusips in an issue
label var green "Green Bond"							// Indicator = 1 if the series was a green bond
label var agent_count "Underwriter Deals"				// Number of deals that the bond's underwriter has issued in the sample
label var ln_agent_count "Ln(Underwriter Deals)"		// Ln of agent_count
label var tax_amt "AMT Taxable"							// Indicator = 1 if the series is subject to AMT tax
label var total_amount "Total Amount"					// Total amount across bonds within a series
label var yield_w_wavg "Yield"							// Individual bond yields are winsorized, then aggregated into weighted avg
label var yield_wavg_w "Yield"							// Individual bond yields are aggregated into weighted avg, then winsorized
label var yield_w_bigamt "Yield"						// Individual bond yields are winsorized, then yield for the biggest amount bond in the series is picked out
label var yield_bigamt_w "Yield"						// Yield for the biggest amount bond in the series is picked out, then winsorized
label var maturity_wavg "Maturity"						// Maturity in months as weighted average across series
label var maturity_bigamt "Maturity"					// Maturity of biggest amount bond in a series
label var rated_wavg "Rated"							// From 0 to 1. Weighted avg of rated indicator across series
label var callable_wavg "Callable"						// From 0 to 1. Weighted avg of callable indicator across series
label var sinkable_wavg "Sinkable"						// From 0 to 1. Weighted avg of sinkable indicator across series
label var insured_wavg "Insured"						// From 0 to 1. Weighted avg of insured indicator across series
label var taxexempt_state_wavg "State Tax-exempt"		// From 0 to 1. Weighted avg of state tax-exempt indicator across series
label var rated_bigamt "Rated"							// From 0 to 1. Whether biggest amount bond in a series is rated
label var callable_bigamt "Callable"					// From 0 to 1. Whether biggest amount bond in a series is callable
label var sinkable_bigamt "Sinkable"					// From 0 to 1. Whether biggest amount bond in a series is sinkable
label var insured_bigamt "Insured"						// From 0 to 1. Whether biggest amount bond in a series is insured
label var taxexempt_state_bigamt "State Tax-exempt"		// From 0 to 1. Whether biggest amount bond in a series is exempt from state tax
label var comp_offering "Competitive"					// Indicator = 1 if series offering is competitive

**Create numeric indicators / FEs 
gegen issuer_fe = group(issuer_long_name)
gegen state_fe = group(state)

*create year-month
gen ym = ym(year(offering_date), month(offering_date))
format ym %tm

*save file
save "$MERGENT\Clean\240801_munibond_citycounty_serieslevel.dta", replace



*****************************************************************************
**# Bookmark #6
***Get data to issuer (cusip6)-month level***
*****************************************************************************

use "$MERGENT\Clean\240801_munibond_citycounty_serieslevel.dta", clear

**Count the number of bonds (num_cusip) and series (issue_id) issued in a month for each issuer**
*Num of bonds
gegen n_cusip9_ym = sum(num_cusip), by(cusip6 ym)
*Num of series
gen temp1 = 1
gegen n_series_ym = sum(temp1), by(cusip6 ym)
tab n_series_ym
/*
n_series_ym |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      8,617       88.12       88.12
          2 |        992       10.14       98.26
          3 |        138        1.41       99.67
          4 |         24        0.25       99.92
          8 |          8        0.08      100.00
------------+-----------------------------------
      Total |      9,779      100.00
*/
*88% of obs have 1 series in an issuer-month
*browse for the ones with 3, 4, 8 series in a month
br if n_series_ym > 2

*Do the same for number of bonds and series issued in a year for each issuer
*Num of bonds
gegen n_cusip9_y = sum(num_cusip), by(cusip6 year)
*Num of series
gegen n_series_y = sum(temp1), by(cusip6 year)

*Do the same for number issued for each issuer over the whole sample period
*Num of bonds
gegen n_cusip9_issuer = sum(num_cusip), by(cusip6)
*Num of series
gegen n_series_issuer = sum(temp1), by(cusip6)
drop temp1

order ym, after(year)

**At the issuer-month level, aggregate the amount/agent/yield/rated etc variables**

*Use of proceeds: these are categorical numeric, so take mode
tab use_proceeds
*most common at 12 (78%) (GPPI), 36 (2.4%) (PSED), 46 (6%) (WTR)
*want to get mode, but if there are multiple modes, don't want the obs to drop out
*make command take lowest number if multiple modes; note that this adds noise
gegen use_proceeds_ym = mode(use_proceeds), by(cusip6 ym) minmode

*Amount:
*drop ln and re-gen later at ym level
drop ln_amount_big
*amount_big - at the ym level, take average
gegen amt_big_ym_avg = mean(amount_big), by(cusip6 ym) 
*rename total amount
rename total_amount amount_total
*amount_total - at the ym level, sum and avg
gegen amt_ttl_ym_avg = mean(amount_total), by(cusip6 ym) 
gegen amt_ttl_ym_sum = sum(amount_total), by(cusip6 ym) 
*note these are the same 88% of the time when an issuer-month only has 1 series

*Maturity:
*Want to get the longest in an issuer-month
gegen maturity_longest_ym = max(maturity_mths_longest), by(cusip6 ym) 
*Want to get the weighted avg in an issuer_month
*But weighted avg of what? Can either do wavg of wavg, wavg of longest, or wavg of biggest amount
*Even though it seems weird to do the wavg of wavg, I think that makes the most sense b/c wavg of biggest amount will look a lot like maturity_longest_ym. Want to recognize the variation in length within a series
*Get wavg of wavg
gen temp1 = maturity_wavg * amount_total
gegen temp2 = sum(temp1), by(cusip6 ym)
gen maturity_ym_wavg = temp2 / amt_ttl_ym_sum
drop temp*
*round maturity down
replace maturity_ym_wavg = floor(maturity_ym_wavg)

*Num cusip in a series:
*Sum these so we get total cusip9 issued in a month. Drop ln
drop ln_num_cusip
gegen n_cusip_ym = sum(num_cusip), by(cusip6 ym)

*Agent count becomes kind of meaningless as we keep aggregating without the underlying underwriter vars
drop agent_count ln_agent_count

*Drop taxable AMT because always zero
drop tax_amt

*Green and long-term
tab green
/*
 Green Bond |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      9,767       99.88       99.88
          1 |         12        0.12      100.00
------------+-----------------------------------
      Total |      9,779      100.00
*/
tab long_term
/*
  long_term |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      9,087       92.92       92.92
          1 |        692        7.08      100.00
------------+-----------------------------------
      Total |      9,779      100.00
*/
*Very little variation here
*Get max here
gegen green_ym = max(green), by(cusip6 ym)
gegen longterm_ym = max(long_term), by(cusip6 ym)

*Comp offering
tab comp_offering
*follow earlier logic where if any series was a competitive offering, bring that through
*similar to green and long-term
gegen comp_offering_ym = max(comp_offering), by(cusip6 ym)

*Yield:
*Have winsorized and non-winsorized versions
*Goes back to the question of philosophically, do you want to winsorize at the beg or end?
*Think I still prefer to winsorize at the end because I don't like changing data
*So, the input options to aggregate are yield_wavg and yield_bigamt
*Make yield versions for both of these at the issuer-month level

*Weighted avg of yield_wavg:
gen temp1 = yield_wavg * amount_total
gegen temp2 = sum(temp1), by(cusip6 ym)
gen yield_ym_wavg = temp2 / amt_ttl_ym_sum
drop temp*

*Max cusip9 yield in the series (i.e., max of yield_bigamt)
gegen yield_ym_max = max(yield_bigamt), by(cusip6 ym)

*Remember to winsorize these after collapsing to the issuer-month level

*Rated, callable, insured, sinkable
*Note these are already weighted averages of indicators 
*Also do a weighted avg of the weighted avgs
local varlist rated callable insured sinkable taxexempt_state
foreach x of local varlist{
	*weighted avg version
	gen temp1 = `x'_wavg * amount_total
	gegen temp2 = sum(temp1), by(cusip6 ym)
	gen `x'_ym_wavg = temp2 / amt_ttl_ym_sum
	drop temp*
}

**At the issuer-month level, get the issuance dates**
*How often do multiple series in a month have the same offering date and settlement date?
*Check offering date
gegen temp1 = min(offering_date), by(cusip6 ym)
gegen temp2 = max(offering_date), by(cusip6 ym)
count if temp1 != temp2
*54 times
*br if temp1 != temp2
*Check settlement date
gegen temp3 = min(settlement_date), by(cusip6 ym)
gegen temp4 = max(settlement_date), by(cusip6 ym)
count if temp3 != temp4
*87
*br if temp3 != temp4
*look at settlement date data errors:
count if diffd < 0
*4 obs, keep for now because don't think we'll use settlement date

*Think there are few enough times where offering or settlement dates are different within issuer-month, can do this manually

gen temp5 = 1 if temp1 != temp2
gen temp6 = 1 if temp3 != temp4
count if temp5 == 1 | temp6 == 1
*120

*Define date_issuance_1 = earliest offering date; date_issuance_2 = second offering date
*Define date_settlement_1 = earliest settlement date; date_settlement_2 = second settlement date

gen date_issuance_1 = offering_date if temp5 != 1
gen date_settlement_1 = settlement_date if temp6 != 1
format date_issuance_1 %td
format date_settlement_1 %td
format temp1 %td
format temp2 %td
format temp3 %td
format temp4 %td

*br if temp5 == 1
replace date_issuance_1 = temp1 if date_issuance_1 == . & temp5 == 1
gen date_issuance_2 = .
format date_issuance_2 %td

*fill in second issuance date
*check if there are only 2 options for issuance date
gegen temp7 = tag(cusip6 ym offering_date)
gegen temp8 = sum(temp7), by(cusip6 ym)
tab temp8
*54, yes, only 2 offering date options

*thus don't have to fill in date_issuance_2 manually
replace date_issuance_2 = temp2 if temp5 == 1 & temp1 != temp2
count if date_issuance_1 == .
*0, good
*drop a few temps
drop temp1 temp2 temp5 temp7 temp8

*Now do settlement date
*br if temp6 == 1
replace date_settlement_1 = temp3 if date_settlement_1 == . & temp6 == 1
gen date_settlement_2 = .
format date_settlement_2 %td

*check if there are only 2 options for settlement date
gegen temp7 = tag(cusip6 ym settlement_date)
gegen temp8 = sum(temp7), by(cusip6 ym)
tab temp8
*yup, only 2 settlement date options
replace date_settlement_2 = temp4 if temp6 == 1 & temp3 != temp4
*br if date_settlement_1 == .
*1 obs missing settlement date at all
drop temp*

*gen new diffd (difference between settlement date and issuance date)
gen diffd_1 = date_settlement_1 - date_issuance_1
gen diffd_2 = date_settlement_2 - date_issuance_2
drop diffd
     
**Collapse to issuer-month level**
gcollapse (max) n_cusip9_ym n_series_ym n_cusip9_y n_series_y n_cusip9_issuer ///
	n_series_issuer use_proceeds_ym amt_big_ym_avg amt_ttl* maturity_longest_ym ///
	maturity_ym_wavg n_cusip_ym green_ym longterm_ym yield_ym* comp_offering_ym ///
	rated_ym_wavg callable_ym_wavg insured_ym_wavg sinkable_ym_wavg ///
	sttaxexempt_ym_wavg=taxexempt_state_ym_wavg date_issuance_1 date_settlement_1 ///
	diffd_1 date_issuance_2 date_settlement_2 diffd_2 ///
	, by(cusip6 issuer_long_name state ym year qtr fips issuer_fe state_fe)
	 
*check whether cusip6-ym uniquely identifies
duplicates report cusip6 ym
/*
--------------------------------------
   Copies | Observations       Surplus
----------+---------------------------
        1 |         9166             0
--------------------------------------
*/
	 
gunique cusip6 
*3,931 issuers by cusip6
gunique issuer_long_name
*3,847 issuers by name

**Truncate yield at issuer-month level**
*Also prefer truncating to winsorizing because I'd rather drop obs than replace data
*Truncate yield 
local varlist yield_ym_wavg yield_ym_max 
foreach x of local varlist{
	winsor2 `x', trim cuts(1 99) suffix(_tr)
}

**Label variables**
label var yield_ym_wavg "Yield (WAvg)"
label var yield_ym_max "Yield (Max)"
label var use_proceeds_ym "Use of proceeds"
label var amt_ttl_ym_avg "Amount (Avg)"
label var maturity_ym_wavg "Maturity (WAvg)"
label var rated_ym_wavg "Rated"
label var callable_ym_wavg "Callable"
label var insured_ym_wavg "Insured"
label var sinkable_ym_wavg "Sinkable"
label var yield_ym_wavg_tr "Yield (WAvg)"
label var yield_ym_max_tr "Yield (Max)"

label var ym "Month"
label var cusip6 "Issuer Cusip"
label var issuer_long_name "Issuer Name"
label var n_cusip9_ym "N Securities in month"
label var n_series_ym "N Series in month"
label var n_cusip9_y "N Securities in year"
label var n_series_y "N Series in year"
label var n_cusip9_issuer "N Securities 2011-2020"
label var n_series_issuer "N Series 2011-2020"
label var amt_big_ym_avg "Amount of biggest sec in series (Avg across month)"
label var amt_ttl_ym_sum "Bond amount (Total across month)"
label var maturity_longest_ym "Maturity (Longest in month)"
label var date_issuance_1 "Issuance date of earlier series"
label var date_issuance_2 "Issuance date of later series"
label var issuer_fe "Issuer FE (based on issuer name)"
label var state_fe "State FE"

**Merge in demographics using county**
rename year year_actual
gen year = year_actual - 1

*merge in per capita income
mmerge fips year using "$BEA\percap_income_county.dta", ///
	type(n:1) missing(nomatch)
/*
                 obs |  42063
                vars |     47  (including _merge)
         ------------+---------------------------------------------------------
              _merge |    123  obs only in master data                (code==1)
                     |  32897  obs only in using data                 (code==2)
                     |   9043  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*br if _merge == 1
sort cusip6 ym
*These fips codes have leading 0's dropped, but even then, they seem wrong
*ignore for now because relatively few obs
gunique cusip6 if _merge == 1
*88 issuers only
drop if _merge == 2
drop _merge LineCode Description GeoName
rename percap_income_county percap_inc_cnty
destring percap_inc_cnty, replace
label var percap_inc_cnty "Per capita income (county)"

*merge in gdp
mmerge fips year using "$BEA\gdp.dta", ///
	type(n:1) missing(nomatch)
/*
                 obs |  33386
                vars |     48  (including _merge)
         ------------+---------------------------------------------------------
              _merge |   1815  obs only in master data                (code==1)
                     |  24220  obs only in using data                 (code==2)
                     |   7351  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
sort cusip6 ym
gunique cusip6 if _merge == 1
*1,463 cusips 
sum year if _merge == 3
*so many _merge == 1 because gdp data starts in 2012
drop if _merge == 2
rename gdp gdp_real2012thou
drop _merge LineCode Description GeoName
destring gdp_real2012thou, replace 
label var gdp_real2012thou "Real GDP (in thousands of 2012 $, county)"

*merge in population
mmerge fips year using "$BEA\population.dta", ///
	type(n:1) missing(nomatch)
/*
                obs |  42063
                vars |     49  (including _merge)
         ------------+---------------------------------------------------------
              _merge |    123  obs only in master data                (code==1)
                     |  32897  obs only in using data                 (code==2)
                     |   9043  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
sort cusip6 ym
drop if _merge == 2
drop _merge LineCode Description GeoName
rename population pop_cnty
destring pop_cnty, replace
label var pop_cnty "Population (county)" 

*merge in personal income
mmerge fips year using "$BEA\pincome_bea_gov.dta", ///
	type(n:1) missing(nomatch)
/*
                 obs |  42063
                vars |     50  (including _merge)
         ------------+---------------------------------------------------------
              _merge |    123  obs only in master data                (code==1)
                     |  32897  obs only in using data                 (code==2)
                     |   9043  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
sort cusip6 ym
drop if _merge == 2
drop _merge LineCode Description GeoName
rename personal_income_county pers_inc_cnty_thou
destring pers_inc_cnty_thou, replace 
label var pers_inc_cnty_thou "Personal income (in thousands, county)"

*fix year back
drop year
rename year_actual year

*clean demographics
gen ln_gdp_real2012thou = ln(gdp_real2012thou)
gen ln_pop_cnty = ln(pop_cnty)
gen ln_pers_inc_cnty_thou = ln(pers_inc_cnty_thou)
gen ln_percap_inc_cnty = ln(percap_inc_cnty)

label var ln_gdp_real2012thou "GDP"
label var ln_pop_cnty "Population"
label var ln_pers_inc_cnty_thou "Personal Inc"
label var ln_percap_inc_cnty "Per Capita Inc"
	 
*save
save "$MERGENT\Clean\240805_bond_issuermonth.dta", replace

*****************************************************************************
**# Bookmark #7
***Get list of unique cusip6 issuers***
*****************************************************************************	
	 
use "$MERGENT\Clean\240805_bond_issuermonth.dta", clear
keep cusip6 issuer_long_name state fips issuer_fe state_fe	 
duplicates drop cusip6, force
sort state cusip6

*save
save "$MERGENT\Clean\240805_bond_issuers.dta", replace


