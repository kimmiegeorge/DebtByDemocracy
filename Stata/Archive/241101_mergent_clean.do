************************
*Voting on bonds       *
*Bond data cleaning    *
*Last updated: 11/01/24*
************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"

**# Bookmark #1
***Start with original main dataset*** 
use "$MERGENT\Clean\MuniBond_20210716_v3.dta", clear

/*10/29 JH: Don't drop before 2011
**Do base cleaning from other project**

*isolate 2011-2020
*JH Note: we may not need to or want to drop prior to 2011 for our project
keep  if year>=2011 & year<=2020

save "$MERGENT\Clean\MuniBond_20210716_v3_2011_2020.dta", replace

use "$MERGENT\Clean\MuniBond_20210716_v3_2011_2020.dta", clear	
*/

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
    Not matched                        41,567
        from master                    32,360  (_merge==1)
        from using                      9,207  (_merge==2)

    Matched                         2,546,653  (_merge==3)
    -----------------------------------------
*/

*br cusip year issuer_long_name COUNTYFP_STATEFP timing _merge
*JH: after skimming through, doesn't seem like anything uniquely labels cities/counties. Plenty of non-city/county issusers get a fips code matched

drop if _merge !=3
drop _merge
*make version of fips code with leading zero
gen fips = string(real(COUNTYFP_STATEFP),"%05.0f")
	
drop if fips == "."
*140,176 obs dropped

*are use of proceeds vars redundant?
count if use_proceeds != use_of_proceeds
*0, yes redundant, drop one
drop use_of_proceeds
*drop some unhelpful vars
drop address___mitigation___taking_ac has_climate_sentence risk___uncertainty affect___is_affecting regulation county ///
	state_full state2 location coordinates state_geo zipcode issuer_type
 	
********************************************************************************
**# Bookmark #2
**** Sample selection part 1 - drop state bonds.  
********************************************************************************
gen temp1 = (substr(issuer_long_name, strlen(issuer_long_name)-2, 3) == " ST")
keep if temp1 == 0 
*33,246 obs dropped
drop temp1
gunique cusip6 
*2,373,231 obs; 41,014 unique cusip6

tab security_code
/*
security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |     67,690        2.85        2.85
          B |      2,687        0.11        2.97
          C |    147,047        6.20        9.16
          D |    224,464        9.46       18.62
          E |        285        0.01       18.63
          F |         80        0.00       18.64
          G |    424,628       17.89       36.53
          H |     44,972        1.89       38.42
          I |     44,174        1.86       40.28
          J |     21,242        0.90       41.18
          K |  1,191,929       50.22       91.40
          L |      2,759        0.12       91.52
          M |      5,302        0.22       91.74
          N |    109,105        4.60       96.34
          O |      1,229        0.05       96.39
          P |      1,804        0.08       96.47
          Q |     38,033        1.60       98.07
          R |     44,574        1.88       99.95
          S |      1,227        0.05      100.00
------------+-----------------------------------
      Total |  2,373,231      100.00
*/
*50% are unlimited tax GO, 18% are revenue, 9% are limited GO, 6% are lease/rent
********************************************************************************
**** Table 1:    
********************************************************************************

********************************************************************************
**** Sample selection part 2 - identify city, county, school bonds
********************************************************************************

*check whether use of proceeds var can help identify schools
*br cusip year issuer_long_name COUNTYFP_STATEFP cusip6 use_proceeds 
*browse issuers that have use_proceeds of PSED (education)
*br cusip year issuer_long_name state cusip6 if use_proceeds == "PSED"
*some nonprofits, some cities (e.g., Auburn, ME or Auburn, Mass or Fairfax, VA)

*in this case, still use names to filter down
 
/*get list of unique cusip6 / issuer names to work through
preserve
duplicates drop issuer_long_name cusip6, force
count
*41,048 unique issuer_long_name-cusip6 dyads
duplicates report issuer_long_name
*lot of duplicates by name for some reason still
duplicates tag issuer_long_name, gen(dup_name)
duplicates report cusip6
*only a few dups by cusip6
duplicates tag cusip6, gen(dup_cusip)
sort issuer_long_name cusip6
*br cusip year issuer_long_name COUNTYFP_STATEFP timing cusip6 if dup_name > 0
*There are some places where the cusip6 is slightly different (typos in raw data?)
*Go by issuer_long_name instead
drop dup*
duplicates drop issuer_long_name, force
count
*40,478 unique issuer_long_name
keep issuer_long_name cusip6 fips state
save "$MERGENT\Clean\241029_issuername_unique.dta", replace
restore
*/

/*
**Work in list of unique issuer names**

use "$MERGENT\Clean\241029_issuername_unique.dta", clear
*gen new issuer_id
gegen issuer_id_new = group(issuer_long_name)
sort state issuer_long_name

*Use strings in names to identify school districts and drop special districts

*School districts*
gen school = 1 if strpos(issuer_long_name,"SCH DI") > 0
replace school = 1 if strpos(issuer_long_name,"PUB") > 0 & strpos(issuer_long_name,"SCH") > 0 & school == .
replace school = 1 if strpos(issuer_long_name,"SCH") > 0 & strpos(issuer_long_name,"IND") > 0  & school == .
replace school = 1 if strpos(issuer_long_name,"REG") > 0 & strpos(issuer_long_name,"SCH") > 0 & school == .	
replace school = 1 if strpos(issuer_long_name,"SCHOOL") > 0 & strpos(issuer_long_name,"DIST") > 0 & school == .	
replace school = 1 if strpos(issuer_long_name,"SCHS") > 0 & school == .	

*Special districts*
*consider boards of education to be special districts, not school districts
gen temp1 = .
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

count if temp1 == .
*19,249 out of 40,478
*drop these
drop if temp1 == 1

*do more filters
replace temp1 = 1 if strpos(issuer_long_name,"BLDG") > 0 & strpos(issuer_long_name,"AUTH") > 0 
replace temp1 = 1 if strpos(issuer_long_name,"WASTE") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"ZONE") > 0 & strpos(issuer_long_name,"OPP") > 0  & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"GAS") > 0 & strpos(issuer_long_name,"REV") > 0  & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"BRD") > 0 & strpos(issuer_long_name,"REV") > 0  & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"GAS") > 0 & strpos(issuer_long_name,"TAX") > 0  & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0 & strpos(issuer_long_name,"PK") > 0  & temp1 == .
drop if temp1 == 1
*18,983

*gen var that combines if school is filled out or if temp1 is filled out
gen temp2 = 1 if school != . | temp1 != .
count if temp2 == 1
*8,441 are school, so 18,983 - 8,441 = 10,542 still to look through manually
rename issuer_id_new issuer_id
*br state issuer_long_name issuer_id school temp1 if temp2 == .
sort issuer_id

*gen indicator for county and city. do county first
gen county = .
gen city = .
replace county = 1 if strpos(issuer_long_name,"CNTY") > 0 & temp2 == .

*Check county by hand
br state issuer_long_name issuer_id school temp1 county if county == 1
*gen temp1 to exclude off of this list first
replace temp1 = 1 if county == 1 & strpos(issuer_long_name,"PUB LIB") > 0 
replace temp1 = 1 if county == 1 & strpos(issuer_long_name,"FACS") > 0 
replace temp1 = 1 if county == 1 & strpos(issuer_long_name,"TAX") > 0 
replace temp1 = 1 if county == 1 & strpos(issuer_long_name,"LTD") > 0 
replace temp1 = 1 if county == 1 & strpos(issuer_long_name,"AUTH") > 0 
replace temp1 = 1 if county == 1 & strpos(issuer_long_name,"FAMILY") > 0 
replace temp1 = 1 if county == 1 & strpos(issuer_long_name,"WTR") > 0 
replace temp1 = 1 if county == 1 & strpos(issuer_long_name,"HOSP") > 0 
replace temp1 = 1 if county == 1 & strpos(issuer_long_name,"FAC") > 0 & strpos(issuer_long_name,"REV") > 0 
replace temp1 = 1 if county == 1 & strpos(issuer_long_name,"COMMN") > 0 & strpos(issuer_long_name,"REV") > 0 
replace temp1 = 1 if inlist(issuer_id,765,872,911,921,926,1039,1040,1045, ///
	1295,1328,1362,1542,1549,1779,1911,1939,2605,3316,3328,3333,3334, ///
	3558,3563,3897,3899,3918,3941,4242,4340,4511,4557,4595,4625,4831, ///
	4857,5374,5377,5384,5801,6170,6247,6293,6449,6544,6568,6816,6891, ///
	7509,7623,7633,7634,7636,7705,7720,8016,8416,8503,8571,8597, ///
	8858,9027,9108,9175,9345,9441,9464,9487,9489,9544,9713,9852 ///
	)
replace temp1 = 1 if inrange(issuer_id,9881,9885)	
replace temp1 = 1 if inlist(issuer_id,9887,10184,10614,10663,10819,11019, ///
	11779,11887,11888,12044,12138,12620,12719,12756,12843,13103,13182, ///
	13743,13821,13852,13936,14017,14018,14550,14635,14873,14875,15080, ///
	15119,15147,15197,15373,15438,15555,15896,16092,16094,16153,16297, ///
	16305,16306,16318,16410,16653,16716,16802,16882,16949,17051,17133,17309, ///
	17439,17450,17639,17707,17745,17826,17839,18035,18099,18183,18277, ///
	18493,18640,18688,18885,18909,18928,18929,18930,18939,19252,19253)	
	
replace temp1 = 1 if inlist(issuer_id,19275,19498,19519,19554,19639,19706, ///
	19714,19984,20034,20124,20200,20715,20716,20791,20794,20796,20797,20811, ///
	20812,20814,20928,21133,21186,21301,21302,21388,21685,21788,21888,21996, ///
	22073,22117,22274,22306,22309,22336,22499,22543,22569,22735,22739,22756, ///
	22757,22758,22759,22760,22761,22762,22803,22813,22843,22853,22856,22857 ///
	23095,23506,23511,23524,23723,23724,23747,23760,23811,24462,24500,24501, ///
	24577,24585,24614,24743,25101,25102,25103,25104,25159,25267,25966,26073,26112)
	
replace temp1 = 1 if inlist(issuer_id,26344,26349,26350,26764,26826,26875,26957, ///
	26960,26975,27199,27201,27263,27295,27341,27471,27751,27786,27856,28231,28245, ///
	28346,28488,28563,28599,28791,29057,29581,29582,29610,29777,30109,30340,30390, ///
	30522,30782,30784,30933,31452,31627,31632,31635,31636,31696,31697,31701, ///
	31747,31772,31778,31782,31784,31786,31815,31843,31875,31958,31959,31960,31961, ///
	32059,32087,32091,32097,32100,32158,32195,32228,32354,32355,32356,32403, ///
	32640,32711,32718,33132,33405,33440,33461,33535,33536,33537,34073,34189,34374)	
	
replace temp1 = 1 if inlist(issuer_id,34442,34623,35089,35245,35602,35684,36222,36337, ///
	36574,36635,36638,36673,36677,36871,36913,37141,37147,37403,37489,37491,37770,37859, ///
	37925,38070,38084,38192,38200,38339,38429,38445,38521,39024,39055,39388, ///
	39462,39488,39504,39773,39819,39887,40047,40123,40144,40145,40147,40148,40298, ///
	40448)	

replace temp1 = 1 if inrange(issuer_id,36339,36343)		
	
replace school = 1 if inlist(issuer_id,6065,8116,14241)
replace school = 1 if inlist(issuer_id,12797,20114,20116,21690,23982,24284,27007, ///
	33776)
	
replace county = . if school == 1

*drop if temp1 == 1
drop if temp1 == 1

*there were some cities in the counties. this naming varied systematically by state. go through county == 1 again
*br state issuer_long_name issuer_id school temp1 county if county == 1
sort state issuer_long_name
replace city = 1 if inlist(issuer_id,12568,21051,8764,9079)
replace city = 1 if county == 1 & state == "IN" & strpos(issuer_long_name,"TWP") > 0 
replace city = 1 if county == 1 & state == "MI" & strpos(issuer_long_name,"TWP") > 0 
replace city = 1 if county == 1 & state == "MO" & strpos(issuer_long_name,"TWP") > 0 
replace city = 1 if county == 1 & state == "NC" & strpos(issuer_long_name,"TWP") > 0 
replace city = 1 if county == 1 & state == "NJ" & strpos(issuer_long_name,"TWP") > 0 
replace city = 1 if county == 1 & state == "OH" & strpos(issuer_long_name,"TWP") > 0 
replace city = 1 if county == 1 & state == "PA" & strpos(issuer_long_name,"TWP") > 0 
replace city = 1 if inlist(issuer_id,2264,16578,20091)
replace temp1 = 1 if inlist(issuer_id,22857,16143,23516,21999,23095,819)

replace county = . if city == 1
drop if temp1 == 1

*regen temp2
br state issuer_long_name issuer_id school temp1 county city
drop temp2
gen temp2 = 1 if school != . | temp1 != . | county != . | city != .

*manually comb through these to drop:
br state issuer_long_name issuer_id school temp1 county city if temp2 == .
*8,303 obs

replace temp1 = 1 if strpos(issuer_long_name,"HEALTH") > 0 & strpos(issuer_long_name,"SYS") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"ST") > 0 & strpos(issuer_long_name,"UNIV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"RCP") > 0 & strpos(issuer_long_name,"TAX") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"GROSS") > 0 & strpos(issuer_long_name,"RCP") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"FRANCHISE") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"IMPT") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"PKG") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"TAX") > 0 & strpos(issuer_long_name,"INCRE") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"HEALTH") > 0 & strpos(issuer_long_name,"FAC") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & strpos(issuer_long_name,"FAC") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"CORP") > 0 & strpos(issuer_long_name,"FAC") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"BRD") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"PPTY") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"HSG") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"PLEDGED") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SPL ASS") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"DIST") > 0 & strpos(issuer_long_name,"NO") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"CONSV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"PARTN") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"WTR") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"HWY") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"LLC") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"AGY") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"LTD") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"PENSION") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"TRANSIT") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"ASSN") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"LEASE") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0 & strpos(issuer_long_name,"INFRA") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0 & strpos(issuer_long_name,"FIN") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"DEV") > 0 & strpos(issuer_long_name,"INFRA") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"FAMILY") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"HEALTH") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"PK") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"CTR") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"DEPT") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"JUDGEMENT") > 0 & strpos(issuer_long_name,"OBLIG") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"JUDGMENT") > 0 & strpos(issuer_long_name,"OBLIG") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"TRAN") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"ENTERPRISE") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"GEN") > 0 & strpos(issuer_long_name,"FD") > 0 & state == "CO" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"CHARTER SC") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"POLLUTION") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"ENTITLEMENT") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"VALOREM") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"TAX") > 0 & strpos(issuer_long_name,"ALLOC") > 0 & state == "GA" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"ELEC") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"TRAN") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"URBAN") > 0 & strpos(issuer_long_name,"RENEW") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SAN DIST") > 0 & state == "IA" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SPL FD") > 0 & state == "IA" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SPL AREA") > 0 & state == "IL" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"GOLF COURSE") > 0 & state == "IL" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SVC AREA") > 0 & state == "IL" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SEW REV") > 0 & state == "IL" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"PROJ REV") > 0 & state == "IL" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"PRESERVE DIST") > 0 & state == "IL" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"RD DIST") > 0 & state == "IL" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"PARK DIST") > 0 & state == "IL" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"PORT DIST") > 0 & state == "IL" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SEW") > 0 & strpos(issuer_long_name,"WK") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"PUB") > 0 & strpos(issuer_long_name,"LIB") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"REDEV") > 0 & strpos(issuer_long_name,"COMM") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"CONSERV") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SAN") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"MTG") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"TRANS") > 0 & strpos(issuer_long_name,"CORP") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"TRANS") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SEW REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"INDL") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"ASSISTED") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"UTIL") > 0 & strpos(issuer_long_name,"SYS") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SAN") > 0 & strpos(issuer_long_name,"SWR") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"COMMN") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"GEN") > 0 & strpos(issuer_long_name,"RCPTS") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"DIST") > 0 & strpos(issuer_long_name,"SALES") > 0 & state == "LA" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"REC") > 0 & strpos(issuer_long_name,"PK") > 0 & state == "LA" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SVC") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"LEVEE") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"ENFORCE") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"ECON") > 0 & strpos(issuer_long_name,"DEV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"LEASE") > 0 & strpos(issuer_long_name,"AUTH") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"GEN HOSP") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SEW DISP") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0 & strpos(issuer_long_name,"UTIL") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"GROSS REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"STORE REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"LIQUOR REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"LIVING REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"NURSING HOME REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"PORT AUTH") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"BLDG") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"RD DIST") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"LEASE PUR") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"COLLEGE DIST") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"HSE") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"TEMP REV") > 0 & state == "ND" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"ANTIC REV") > 0 & state == "ND" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"ELEC PWR") > 0 & state == "ND" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"LANDFILL REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"IRR DIST") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"TAX ANTIC") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"COMB") > 0 & strpos(issuer_long_name,"REV") > 0 & state == "NE" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"FIRE PROTN") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"GOLF COURSE") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SVC UNIT") > 0 & state == "NE"  & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"BD BK") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"DIV REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SEW AUTH") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"PWR") > 0 & strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"LIBR") > 0 & state == "OH" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SVC") > 0 & strpos(issuer_long_name,"DIST") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"NAV DIST") > 0 & state == "TX" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"TOLL REV") > 0 & state == "TX" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0 &  strpos(issuer_long_name,"FEE") > 0 & state == "TX" & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"MGMT") > 0 &  strpos(issuer_long_name,"DIST") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"WATER") > 0 &  strpos(issuer_long_name,"DIST") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"FLOOD") > 0 &  strpos(issuer_long_name,"DIST") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"HOTEL") > 0 &  strpos(issuer_long_name,"REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"SVC") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"DRAIN REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"TOLL RD REV") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"FIRE") > 0 &  strpos(issuer_long_name,"RESCUE") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"PUB") > 0 &  strpos(issuer_long_name,"FACS") > 0 & temp2 == .
replace temp1 = 1 if strpos(issuer_long_name,"FAC AREA") > 0 & temp2 == .

replace temp1 = 1 if inlist(issuer_id,306,25992,22146,24606,12194,22334,25366,29872 ///
	203,474,4505,4671,4682,7041,9258,10593,11667,12677,13232,13424,14280,14466,15278, ///
	16795,16830,20571,20573,20579,20700,21346,22999,23633,27652,27654,28460,31423, ///
	31429,31724,31768,32150,33222,35233,36154,36969,1530,1953,3340,5416,7296,10979, ///
	12162,13637,20618,3762,7592,7593,23435,13106,13127,39644,7095,7896,9961,11815,12769, ///
	17233,17248,19083,24136,26362,35607,35636,35642,35643,63,25677,18555,6228,10369)

replace temp1 = 1 if inlist(issuer_id,16627,16628,16634,19007,20912,22766,24083, ///
	26300,28016,31525,33851,34279,40374,228,5691,6175,8437,11215,12987,17078, ///
	19664,33846,35838,39035,32950,40152,12345,14,1656,4187,4488,18805, ///
	25030,28877,3312,5602,13903,13909,21952,22750,24515,33683,36534,40053, ///
	1788,21997,22185,39143,8332,14772,16450,17167,19019,21066,24471,25533,25654, ///
	26120,32504,34879,36330,36332,36437,5057,15338,22752,22753,23210,23246,24917, ///
	29675,33034,33879,36019,39290,10166,15176,20749,30128,34274,34662,2825)	
	
replace temp1 = 1 if inlist(issuer_id,23627,506,11450,25578,2013,7434,20182, ///
	20816,24648,25198,26822,26823,27701,33184,37103,24945,24950,24951,24954,24964, ///
	25151,27893,389,392,6738,17573,18839,25004,25022,37580,5996,11682,23577,24379, ///
	24380,25106,25110,25130,25134,30386,30982,31211,35251,36780,36783,39032, ///
	237,719,13874,26545,26551,26560,26566,26567,6248,26628,26632,36628,8109,11161, ///
	25986,27062,29244,30233,31074,47,5567,6153,7327,7328,8157,20186,22905,28127, ///
	36936,37034,30429,30443,7198,14162,14778,19279,25167,27013,30529,36535,20859,26517,26518,33663,33667)	
	
replace temp1 = 1 if inlist(issuer_id,11575,1594,3569,4847,12874,19946,20554,30040, ///
	33863,35881,35902,35903,35924,35933,37040,33671,14671,2562,20436,29163, ///
	33884,33885,37331,1698,11925,15448,18727,18728,23167,26857)	
	
*fix some schools
replace school = 1 if strpos(issuer_long_name,"SCH SYS") > 0 & state == "GA" & temp2 == .
replace school = 1 if strpos(issuer_long_name,"SCH SYS") > 0 & state == "MI" & temp2 == .
replace school = 1 if strpos(issuer_long_name,"AREA SCH") > 0 & state == "MI" & temp2 == .
replace school = 1 if inlist(issuer_id,5092,24283,2192,3786,22722,27176)
	
*adjust county for parishes in LA
replace county = 1 if strpos(issuer_long_name,"PARISH") > 0 & state == "LA" & temp2 == .

*fix cities
replace temp1 = . if issuer_id == 38715
replace temp1 = . if issuer_id == 10683
replace temp1 = . if issuer_id == 15864

/*
replace temp1 = 1 if inlist(issuer_id,, ///
	, ///
	, ///
	, ///
	, ///
	, ///
	)
*/	

*drop temp's
drop if temp1 == 1
drop temp*
gen temp1 = 1 if school == 1 | county == 1
replace city = 1 if city == . & temp1 == .
drop temp1
*check whether anything is still not filled out
gen temp2 = 1 if school == 1 | county == 1 | city == 1
count if temp2 == .
*0, good
drop temp2

*fill in zeroes
local varlist school county city
foreach x of local varlist{
	replace `x' = 0 if `x' == .
	count if `x' == 1
}
/*Notes on obs:
- 16,704 issuers
	- 8,461 schools
	- 1,587 counties
	- 6,656 cities
*/

*browse to check
*check schools
br state issuer_long_name issuer_id school if school == 1
drop if school == 1 & strpos(issuer_long_name,"FING AU") > 0 
drop if school == 1 & strpos(issuer_long_name,"PASS THRU") > 0 
drop if school == 1 & strpos(issuer_long_name,"CTFS") > 0 
drop if school == 1 & strpos(issuer_long_name,"INFRASTRUCTURE") > 0 
drop if school == 1 & strpos(issuer_long_name,"LEASE REV") > 0 
drop if school == 1 & strpos(issuer_long_name,"LTD TAX") > 0 
drop if school == 1 & strpos(issuer_long_name,"LEASE PUR") > 0 
gen temp1 = 1 if inlist(issuer_id,287,11370,27648,31886,32138,14585,32481,32484,30489 ///
	32593,10647)
drop if temp1 == 1
drop temp1

*check counties
*br state issuer_long_name issuer_id county if county == 1
*fix that counties in Alaska are called boroughs
replace county = 1 if state == "AK" & strpos(issuer_long_name,"BORO") > 0 
replace city = 0 if state == "AK" & strpos(issuer_long_name,"BORO") > 0 

*check cities
br state issuer_long_name issuer_id city if city == 1
*Remove Native American tribes and other issuers that look like special districts but were missed earlier
gen temp1 = 1 if inlist(issuer_id,29872,203,13596,13605,37899,25371)
drop if temp1 == 1
drop temp1

count
*16,642
count if school == 1
*8,405
count if city == 1
*6,644
count if county == 1
*1,593

**# Bookmark #4
**Make unique identifier for each issuer that remains**
*E.g., create a var that's the same for "colorado springs" and for "colorado springs rev"

*br state issuer_long_name cusip6 fips issuer_id county if county == 1
sort state issuer_long_name
gen temp1 = _n

gen temp2 = .
replace temp2 = 22 if inlist(issuer_long_name,"ARKADELPHIA ARK SCH DIST NO 001","ARKADELPHIA ARK SPL SCH DIST NO 001")
replace temp2 = 105 if inlist(issuer_long_name,"FORREST CITY ARK SCH DIST NO 007","FORREST CITY ARK SCH DIST NO 007")
replace temp2 = 107 if inlist(issuer_long_name,"FORT SMITH ARK SCH DIST NO 100","FORT SMITH ARK SCH DIST NO 100")
replace temp2 = 118 if inlist(issuer_long_name,"GREENE CNTY ARK TECH SCH DIST NO T-1","GREENE CNTY ARK TECHNICAL SCH DIST NO 1")
replace temp2 = 127 if inlist(issuer_long_name,"HARMONY GROVE ARK SCH DIST NO 1","HARMONY GROVE SCH DIST NO 1 ARK OUACHITA CNTY")
replace temp2 = 141 if inlist(issuer_long_name,"HOT SPRINGS ARK SCH DIST NO 6","HOT SPRINGS ARK SPL SCH DIST NO 006")
replace temp2 = 147 if inlist(issuer_long_name,"JACKSON CNTY ARK SCH DIST","JACKSON CNTY ARK SPL SCH DIST")
replace temp2 = 177 if inlist(issuer_long_name,"MALVERN ARK SCH DIST HOT SPRING CNTY","MALVERN ARK SPL SCH DIST HOT SPRING CNTY")
replace temp2 = 255 if inlist(issuer_long_name,"SEARCY ARK SPL SCH DIST","SEARCY CNTY ARK SCH DIST")
replace temp2 = 311 if inlist(issuer_long_name,"APACHE CNTY ARIZ UNI SCH DIST NO 8 WINDOW ROCK","APACHE CNTY ARIZ UNI SCH DIST NO 8 WINDOW ROCK IMPACT A")
replace temp2 = 324 if inlist(issuer_long_name,"COCONINO CNTY ARIZ UNI SCH DIST NO 15 TUBA CITY","COCONINO CNTY ARIZ UNI SCH DIST NO 15 TUBA CITY IMPACT")
drop if issuer_long_name == "NAVAJO NATION ARIZ"
replace temp2 = 535 if inlist(issuer_long_name,"BONSALL CALIF UN SCH DIST","BONSALL CALIF UNI SCH DIST")
replace temp2 = 707 if inlist(issuer_long_name,"FREMONT CALIF","FREMONT CALIF ALAMEDA CNTY")
replace temp2 = 1298 if inlist(issuer_long_name,"COLORADO SPRINGS COLO","COLORADO SPRINGS COLO REV")
replace temp2 = 1428 if inlist(issuer_long_name,"WELD & ADAMS CNTYS COLO SCH DIST NO RE 003 J","WELD & ADAMS CNTYS COLO SCH DIST NO RE 003J")
replace temp2 = 1456 if issuer_long_name == "BRIDGEPORT CONN" | cusip6 == "108152"
replace temp2 = 1609 if inlist(issuer_long_name,"KENT CNTY DEL","KENT CNTY DEL REV")
replace temp2 = 1614 if inlist(issuer_long_name,"NEW CASTLE CNTY DEL","NEW CASTLE CNTY DEL REV")
replace temp2 = 1619 if inlist(issuer_long_name,"SUSSEX CNTY DEL","SUSSEX CNTY DEL REV")
replace temp2 = 1648 if inlist(issuer_long_name,"GULF CNTY FLA","GULF CNTY FLA REV")
replace temp2 = 1653 if inlist(issuer_long_name,"HILLSBOROUGH CNTY FLA","HILLSBOROUGH CNTY FLA REV")
replace temp2 = 1657 if inlist(issuer_long_name,"INDIAN RIVER CNTY FLA","INDIAN RIVER CNTY FLA REV")

replace temp2 = 1671 if inlist(issuer_long_name,"MANATEE CNTY FLA","MANATEE CNTY FLA REV")
replace temp2 = 1678 if inlist(issuer_long_name,"MIAMI FLA","MIAMI FLA REV")
replace temp2 = 1691 if inlist(issuer_long_name,"PALM BAY FLA","PALM BAY FLA REV")
replace temp2 = 1693 if inlist(issuer_long_name,"PALM BEACH CNTY FLA","PALM BEACH CNTY FLA REV")
replace temp2 = 1696 if inlist(issuer_long_name,"PALM BEACH FLA","PALM BEACH FLA REV")
replace temp2 = 1701 if inlist(issuer_long_name,"PLANTATION FLA","PLANTATION FLA REV")
replace temp2 = 1703 if inlist(issuer_long_name,"POMPANO BEACH FLA","POMPANO BEACH FLA REV")
replace temp2 = 1708 if inlist(issuer_long_name,"SARASOTA CNTY FLA","SARASOTA CNTY FLA REV")
drop if issuer_long_name == "SEMINOLE TRIBE FLA" | issuer_long_name == "SEMINOLE TRIBE FLA REV"
replace temp2 = 2013 if inlist(issuer_long_name,"CEDAR RAPIDS IOWA","CEDAR RAPIDS IOWA REV")
replace temp2 = 2185 if inlist(issuer_long_name,"MASON CITY IOWA","MASON CITY IOWA REV")
replace temp2 = 2250 if inlist(issuer_long_name,"POTTAWATTAMIE CNTY IOWA","POTTAWATTAMIE CNTY IOWA REV")
replace temp2 = 2347 if inlist(issuer_long_name,"WINDSOR HEIGHTS IOWA","WINDSOR HEIGHTS IOWA REV")
replace temp2 = 2371 if inlist(issuer_long_name,"BOISE CITY IDAHO","BOISE CITY IDAHO REV")
replace temp2 = 2506 if inlist(issuer_long_name,"BRADLEY ILL","BRADLEY ILL REV")
replace temp2 = 2557 if inlist(issuer_long_name,"CHICAGO ILL","CHICAGO ILL REV")
replace temp2 = 2586 if inlist(issuer_long_name,"COOK CNTY ILL","COOK CNTY ILL REV")
replace temp2 = 2719 if inlist(issuer_long_name,"DU PAGE CNTY ILL","DU PAGE CNTY ILL REV")
replace temp2 = 2845 if inlist(issuer_long_name,"HAWTHORN WOODS ILL","HAWTHORN WOODS ILL REV")
replace temp2 = 2948 if inlist(issuer_long_name,"LAKE IN HILLS ILL","LAKE IN HILLS ILL REV")
replace temp2 = 3111 if inlist(issuer_long_name,"PINGREE GROVE VLG ILL","PINGREE GROVE VLG ILL REV")
replace temp2 = 3123 if inlist(issuer_long_name,"QUINCY ILL","QUINCY ILL REV")
replace temp2 = 3151 if inlist(issuer_long_name,"ROMEOVILLE ILL","ROMEOVILLE ILL REV")
replace temp2 = 3311 if inlist(issuer_long_name,"BOONVILLE IND","BOONVILLE IND REV")
replace temp2 = 3353 if inlist(issuer_long_name,"EVANSVILLE VANDERBURGH IND SCH CORP","EVANSVILLE-VANDERBURGH IND SCH CORP")
replace temp2 = 3366 if inlist(issuer_long_name,"GREATER CLARK CNTY IND SCHS","GREATER CLARK CNTY SCH BDLG CORP IND")
replace temp2 = 3374 if inlist(issuer_long_name,"HAMILTON CNTY IND","HAMILTON CNTY IND REV")
replace temp2 = 3377 if inlist(issuer_long_name,"HAMILTON IND SOUTHEASTN SCHS","HAMILTON SOUTHEASTERN IND SCHS")
replace temp2 = 3443 if inlist(issuer_long_name,"NOBLESVILLE IND","NOBLESVILLE IND REV")
replace temp2 = 3514 if inlist(issuer_long_name,"VIGO CNTY IND","VIGO CNTY IND GEN REV")
replace temp2 = 3960 if inlist(issuer_long_name,"PARK CITY KANS","PARK CITY KANS REV")
replace temp2 = 4032 if inlist(issuer_long_name,"SHAWNEE CNTY KANS","SHAWNEE CNTY KANS REV")
replace temp2 = 4166 if inlist(issuer_long_name,"JEFFERSON CNTY KY","JEFFERSON CNTY KY REV")
replace temp2 = 4175 if inlist(issuer_long_name,"LEXINGTON-FAYETTE URBAN CNTY GOVT KY","LEXINGTON-FAYETTE URBAN CNTY GOVT KY REV")
replace temp2 = 4179 if inlist(issuer_long_name,"LOUISVILLE & JEFFERSON CNTY KY METRO GOVT","LOUISVILLE/JEFFERSON CNTY KY METRO GOVT REV")
replace temp2 = 4244 if inlist(issuer_long_name,"BOGALUSA LA","BOGALUSA LA REV")
replace temp2 = 4250 if inlist(issuer_long_name,"CADDO PARISH LA PARISH WIDE SCH DIST","CADDO PARISH LA PARISHWIDE SCH DIST")
replace temp2 = 4307 if inlist(issuer_long_name,"LIVINGSTON PARISH LA","LIVINGSTON PARISH LA REV")
replace temp2 = 4324 if inlist(issuer_long_name,"NEW IBERIA LA","NEW IBERIA LA REV")
replace temp2 = 4332 if inlist(issuer_long_name,"PLAQUEMINES PARISH LA","PLAQUEMINES PARISH LA REV")
replace temp2 = 4760 if inlist(issuer_long_name,"BALTIMORE CNTY MD","BALTIMORE CNTY MD REV")
replace temp2 = 4762 if inlist(issuer_long_name,"BALTIMORE MD","BALTIMORE MD REV")
replace temp2 = 4780 if inlist(issuer_long_name,"HOWARD CNTY MD","HOWARD CNTY MD REV")
replace temp2 = 4783 if inlist(issuer_long_name,"MONTGOMERY CNTY MD","MONTGOMERY CNTY MD REV")
replace temp2 = 4786 if inlist(issuer_long_name,"PRINCE GEORGES CNTY MD","PRINCE GEORGES CNTY MD REV")
replace temp2 = 4985 if inlist(issuer_long_name,"CALHOUN CNTY MICH","CALHOUN CNTY MICH REV")
replace temp2 = 5080 if inlist(issuer_long_name,"EAST DETROIT MICH PUB SCHS","EAST DETROIT MICH SCH DIST")
replace temp2 = 5703 if inlist(issuer_long_name,"ANOKA MINN","ANOKA MINN REV")
replace temp2 = 5754 if inlist(issuer_long_name,"BETHEL MINN","BETHEL MINN REV")
replace temp2 = 5782 if inlist(issuer_long_name,"BRECKENRIDGE MINN","BRECKENRIDGE MINN REV")
replace temp2 = 5933 if inlist(issuer_long_name,"ELK RIVER MINN","ELK RIVER MINN REV")
replace temp2 = 6088 if inlist(issuer_long_name,"ITASCA CNTY MINN","ITASCA CNTY MINN REV")
replace temp2 = 6204 if inlist(issuer_long_name,"MAPLEWOOD MINN","MAPLEWOOD MINN REV")
replace temp2 = 6233 if inlist(issuer_long_name,"MINNEAPOLIS MINN","MINNEAPOLIS MINN REV")
replace temp2 = 6251 if inlist(issuer_long_name,"MOORHEAD MINN","MOORHEAD MINN REV")
replace temp2 = 6319 if inlist(issuer_long_name,"OAKDALE MINN","OAKDALE MINN REV")
replace temp2 = 6342 if inlist(issuer_long_name,"OTTER TAIL CNTY MINN","OTTER TAIL CNTY MINN REV")
replace temp2 = 6605 if inlist(issuer_long_name,"WAYZATA MINN","WAYZATA MINN REV")
replace temp2 = 6618 if inlist(issuer_long_name,"WHITE BEAR LAKE MINN","WHITE BEAR LAKE MINN REV")
replace temp2 = 7363 if inlist(issuer_long_name,"OLIVE BRANCH MISS","OLIVE BRANCH MISS REV")
replace temp2 = 7531 if inlist(issuer_long_name,"LIVINGSTON MONT","LIVINGSTON MONT REV")
replace temp2 = 7740 if inlist(issuer_long_name,"WINSTON SALEM N C","WINSTON-SALEM N C")
replace temp2 = 7850 if inlist(issuer_long_name,"MANDAN N D","MANDAN N D REV")
replace temp2 = 7924 if inlist(issuer_long_name,"STUTSMAN CNTY N D","STUTSMAN CNTY N D REV")
replace temp2 = 8098 if inlist(issuer_long_name,"CRETE NEB","CRETE NEB REV")
replace temp2 = 8302 if inlist(issuer_long_name,"LAUREL NEB","LAUREL NEB REV")
replace temp2 = 8324 if inlist(issuer_long_name,"MADISON CNTY NEB","MADISON CNTY NEB REV")
replace temp2 = 8373 if inlist(issuer_long_name,"O NEILL NEB","O NEILL NEB REV")
replace temp2 = 10836 if inlist(issuer_long_name,"BELLEVUE OHIO","BELLEVUE OHIO REV")
replace temp2 = 10964 if inlist(issuer_long_name,"CUYAHOGA CNTY OHIO","CUYAHOGA CNTY OHIO REV")
replace temp2 = 11040 if inlist(issuer_long_name,"FRANKLIN CNTY OHIO","FRANKLIN CNTY OHIO REV")
replace temp2 = 11081 if inlist(issuer_long_name,"GREENE CNTY OHIO","GREENE CNTY OHIO REV")
replace temp2 = 11299 if inlist(issuer_long_name,"MONTGOMERY CNTY OHIO","MONTGOMERY CNTY OHIO REV")
drop if issuer_long_name == "OHIO ST PARKS & REC CAP FACS"
replace temp2 = 11457 if inlist(issuer_long_name,"READING OHIO","READING OHIO REV")
replace temp2 = 11527 if inlist(issuer_long_name,"SPRINGBORO OHIO","SPRINGBORO OHIO REV")
replace temp2 = 11536 if inlist(issuer_long_name,"SPRINGFIELD TWP OHIO","SPRINGFIELD TWP OHIO REV")
replace temp2 = 11558 if inlist(issuer_long_name,"SUGARCREEK OHIO TWP","SUGARCREEK TWP OHIO REV")
replace temp2 = 12201 if inlist(issuer_long_name,"ALBANY ORE","ALBANY ORE REV")
replace temp2 = 12248 if inlist(issuer_long_name,"CORNELIUS ORE","CORNELIUS ORE REV")
replace temp2 = 12328 if inlist(issuer_long_name,"LINCOLN CITY ORE","LINCOLN CITY ORE LINCOLN CNTY")
replace temp2 = 12354 if inlist(issuer_long_name,"MEDFORD ORE","MEDFORD ORE REV")
replace temp2 = 12686 if inlist(issuer_long_name,"DU BOIS PA","DUBOIS PA")
replace temp2 = 13516 if inlist(issuer_long_name,"SPARTANBURG CNTY S C","SPARTANBURG CNTY S C REV")
replace temp2 = 13786 if inlist(issuer_long_name,"PULASKI TENN","PULASKI TENN REV")
drop if issuer_long_name == "VIRGINIA ST PUB SCH AUTH"
drop if issuer_long_name == "VIRGINIA ST PUB SCH AUTH SCH TECHNOLOGY & SEC NTS"
drop if issuer_long_name == "SEATAC WASH"
replace temp2 = 16132 if inlist(issuer_long_name,"KIEL","KIEL WIS")
*replace temp2 =  if inlist(issuer_long_name,"","")

*gen new ID var
gen issuer_id_new = temp2 if temp2 != .
replace issuer_id_new = temp1 if issuer_id_new == .
rename issuer_id issuer_name_id
rename issuer_id_new issuer_id
*how many unique issuers now?
gunique issuer_id
*16,531 unique issuers; 16,635 obs overall

*drop temps
drop temp*
drop issuer_county location

*save 
save "$MERGENT\Clean\241031_citycountyschool_issuer_unique.dta", replace	
*/

**# Bookmark #3

*Bring in 10/31/24 list of city and county issuer names
*drop some vars to prepare
drop issuer_name issuer_id issuer_short_name 
mmerge issuer_long_name using "$MERGENT\Clean\241031_citycountyschool_issuer_unique.dta", ///
	type(n:1) missing(nomatch)
/*
                 obs | 2373231
                vars |    181  (including _merge)
         ------------+---------------------------------------------------------
              _merge | 1105408  obs only in master data                (code==1)
                     | 1267823  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*br cusip year state issuer_long_name issuer_id_new _merge
*seems like this works
keep if _merge == 3
drop _merge
sort state issuer_id offering_date

gunique cusip6 
*1,267,823 obs; 16,840 unique cusip6
gunique issuer_long_name
*16,635 issuer_long_name
gunique issuer_id 
*16,531 unique issuers

tab year
/*
       year |      Freq.     Percent        Cum.
------------+-----------------------------------
       2000 |     41,266        3.25        3.25
       2001 |     57,403        4.53        7.78
       2002 |     64,383        5.08       12.86
       2003 |     72,949        5.75       18.61
       2004 |     66,412        5.24       23.85
       2005 |     75,074        5.92       29.77
       2006 |     60,634        4.78       34.56
       2007 |     57,675        4.55       39.11
       2008 |     50,758        4.00       43.11
       2009 |     57,739        4.55       47.66
       2010 |     59,228        4.67       52.34
       2011 |     55,920        4.41       56.75
       2012 |     74,014        5.84       62.58
       2013 |     59,042        4.66       67.24
       2014 |     58,438        4.61       71.85
       2015 |     70,417        5.55       77.40
       2016 |     72,009        5.68       83.08
       2017 |     61,171        4.82       87.91
       2018 |     46,786        3.69       91.60
       2019 |     61,071        4.82       96.42
       2020 |     45,434        3.58      100.00
------------+-----------------------------------
      Total |  1,267,823      100.00
*/

*try to shrink file size
drop issuer_note COUNTYFP_STATEFP timing name_disclosure url_issuer url_cafr type converted failure_to_provide_fr missed_md_a

order state issuer_id issuer_long_name city county school, before(cusip)
order issue_id, after(cusip)
*JH note to self: cusip is what uniquely identifies; a bundle of cusips have the same issue_id
sort state issuer_id offering_date issue_id

*save file
save "$MERGENT\Clean\241031_citycountyschool_allbonds.dta", replace

**# Bookmark #4
***Start with all bonds, then filter to GO or revenue***
***Then collapse to issuance-level***

use "$MERGENT\Clean\241031_citycountyschool_allbonds.dta", clear
count
*1,267,823 obs
count if city == 1
*524,288 city obs
count if county == 1
*142,091 county obs
count if school == 1
*601,444 school obs

tab security_code
/*security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |     42,552        3.36        3.36
          B |        297        0.02        3.38
          C |      2,165        0.17        3.55
          D |    197,391       15.57       19.12
          E |        185        0.01       19.13
          F |         80        0.01       19.14
          G |     12,868        1.01       20.16
          H |      4,514        0.36       20.51
          I |     22,446        1.77       22.28
          J |      1,375        0.11       22.39
          K |    977,392       77.09       99.48
          L |      2,256        0.18       99.66
          N |      2,312        0.18       99.84
          P |         31        0.00       99.85
          Q |      1,917        0.15      100.00
          R |         42        0.00      100.00
------------+-----------------------------------
      Total |  1,267,823      100.00
*/
*K=77% (unlimited GO), D=16% (limited GO), G=1% (revenue)

*should we drop refunding? It's not here that we lose rev bonds
*feel like we still drop refunding because it isn't the same as new debt

**Drop refunding bonds**
*br issuer_long_name year cusip issue_description new_money use_proceeds
*based on comparing "refund" in issue_description and new_money, seems new_money == 0 does a good job of capturing when "refund" is in description
drop if new_money == 0
*617,202 obs dropped; 650,621 left
*note that this also drops colorado springs and colorado springs rev
drop new_money

gunique issuer_id
*13,819
gunique issuer_id if city == 1
*5,244 cities; 270,244 obs
gunique issuer_id if county == 1
*1,303 counties; 79,186 obs
gunique issuer_id if school == 1
*7,272 school districts; 301,191 obs

**Identify GO bonds vs. revenue bonds**
*br issuer_long_name year cusip issue_description repayment_source source_of_repayment use_proceeds

*JH: doesn't seem like repayment_source == 1 captures all GO bonds
*E.g., cusip 033161A59 has repayment_source == 0 but description is "General Obligation General Purpose"
*what uniquely identifies GO bonds?
*For anchorage, alaska, use_proceeds can == PSED and issue_description can have "General Obligation"
tab use_proceeds
*PSED (primary/secondary educ) is 45.05%; GPPI (gen purpose/public improvement) is 39.6% 
tab use_proceeds if school == 1
*PSED is 94%, OTED (other education) is 4%, GPPI is 1%
tab use_proceeds if city == 1 | county == 1
*GPPI is 73%, PSED is 3%

/*Notes on types of bonds:
- Source 1: https://mrsc.org/explore-topics/finance/debt/types-of-municipal-debt
- Source 2: https://www.investopedia.com/terms/g/generalobligationbond.asp

- GO
	- Is it true that all GO bonds are either limited tax or unlimited tax?
	- Unlimited tax GO: Typically voted on (e.g., WA), voters simultaneously vote on approving issuance AND potential tax levy
	- Limited tax GO: General fund revenues are pledged to the debt service, not potential for new taxes; often not voted on (e.g., no vote in WA)
		- Potential falsification test?
- Revenue
- Special assessment: assessment is only paid by people the project will benefit
- Tax anticipation: short-term borrowing in anticipation of taxes the govt knows they'll collect in the next year
	- Usually not voted on

- Think it makes sense to drop Tax and Special Assessment
- Then keep GO (unlimited tax and limited tax), and Revenue
*/

*make uppercase version of issue description
gen temp1 = strupper(issue_description)
drop issue_description
rename temp1 issue_description
order issue_description, after(cusip)

*Note that while source_of_repayment is often missing, we can fill it in for the rest of the series
*per Mergent, source_of_repayment = D if GO, = G if Revenue, = A if double-barreled (very confusing)
gegen temp1 = mode(source_of_repayment), by(issuer_id issue_id)

*Note that security_code is never missing
*per Mergent, security_code is "A code denoting the type of assets that will pay the debt service (e.g. General Obligation Bonds, Public Improvement Bonds, Revenue Bonds,etc.)."
/*security_code list:
- A: Double barreled
- B: Fuel/vehicle tax
- C: Lease/rent
- D: Limited GO
- E: Other
- F: Public Improvement
- G: Revenue
- H: Sales/Excise Tax
- I: Special Assessment
- J: Tax Allocation
- K: Unlimited Tax GO
- L: US Government
- M: Sales Agreement
- N: Loan Agreement
- O: Tobacco Agreement
- P: Tuition Agreement
- Q: Special Tax
- R: Mortgage Loans
- S: Education Loans
- T: COP
*/
tab security_code
/*
security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |     24,060        3.70        3.70
          B |        209        0.03        3.73
          C |      1,147        0.18        3.91
          D |     83,004       12.76       16.66
          E |        107        0.02       16.68
          F |         26        0.00       16.68
          G |      7,240        1.11       17.80
          H |      3,518        0.54       18.34
          I |     11,612        1.78       20.12
          J |        870        0.13       20.26
          K |    514,453       79.07       99.33
          L |      1,857        0.29       99.61
          N |      1,292        0.20       99.81
          P |         31        0.00       99.82
          Q |      1,156        0.18       99.99
          R |         39        0.01      100.00
------------+-----------------------------------
      Total |    650,621      100.00
*/
*79% are unlimited tax GO; 13% are limited tax GO; 1% are revenue
*I wonder to what extent this composition is skewed from dropping all those other special districts or weirdly name issuers? E.g., "toll rd" in an issuer could have meant revenue bond
*went back and tab security_code before dropping all the other issuers. There, 50% are unlimited tax GO, 18% are revenue, 9% are limited GO, 6% are lease/rent
*so, we are dropping a lot of revenue bonds with the earlier issuer name filter

*To what extent are these codes overlapping? E.g., could something be Limited GO and Education Loan?
*How well do these line up with source_of_repayment?
count if source_of_repayment != security_code & source_of_repayment != ""
*293,914 are different
*br issuer_long_name year cusip issue_description source_of_repayment security_code if source_of_repayment != security_code & source_of_repayment != ""
*look at when source_of_repayment is not the same as security_code
preserve
keep if source_of_repayment != security_code & source_of_repayment != ""
keep issue_id issue_description source_of_repayment security_code
duplicates drop
count
*27,655 issues
drop issue_description
gcollapse (count) n_issues = issue_id, by(source_of_repayment security_code)
count
*16 combos
list
restore
/*
   +--------------------------------+
     | source~t   securi~e   n_issues |
     |--------------------------------|
  1. |        A          G         20 |
  2. |        A          H          8 |
  3. |        A          I          5 |
  4. |        D          A          2 |
  5. |        D          G          2 |
     |--------------------------------|
  6. |        D          J          1 |
  7. |        D          K      26413 |
  8. |        G          B          4 |
  9. |        G          C        103 |
 10. |        G          E          1 |
     |--------------------------------|
 11. |        G          H        225 |
 12. |        G          I        666 |
 13. |        G          J         50 |
 14. |        G          N         98 |
 15. |        G          Q         55 |
     |--------------------------------|
 16. |        G          R          2 |
     +--------------------------------+

*/
/*Notes:
- source_of_repayment is broader than security_code
- most common difference is source_of_repayment = D (GO) but security_code = K (unlimited tax GO)
- 2nd most common difference is source_of_repayment = G (Rev) but security_code = I (special assessment)
- 3rd most common difference is source_of_repayment = G (Rev) but security_code = H (sales/excise tax)
*/

*work with filled-in source_of_repayment
order temp1, after(source_of_repayment)
drop source_of_repayment
rename temp1 source_of_repayment

*if source_of_repayment == D (GO), how often does security_code equal D (limited GO) or K (unlimited tax) ?
count if source_of_repayment == "D"
count if source_of_repayment == "D" & security_code == "D"
*65,037 
count if source_of_repayment == "D" & security_code == "K"
*351,854 - makes sense that unlimited tax is a lot more common

*Given security_code is never missing, work with that instead
gen go_unlim = 1 if security_code == "K"
gen go_lim = 1 if security_code == "D"
*gen temp1 = 1 if strpos(issue_description,"UNLIMITED") > 0 & strpos(issue_description,"TAX") > 0
*br issuer_long_name year cusip issue_description source_of_repayment security_code go_unlim go_lim if temp1 == 1
*sometimes, security_code is limited, but issue description says unlimited
*I feel like the best we can do is to trust the security codes though
*drop temp1

*For revenue, go with higher-level source_of_repayment var because we aren't going to break down into different types of revenue bonds
gen rev = 1 if source_of_repayment == "G"

*what hasn't been captured?
local varlist go_unlim go_lim rev
foreach x of local varlist{
	count if `x' == 1
	replace `x' = 0 if `x' == .
	gunique issue_id if `x' == 1
	gunique issuer_id if `x' == 1
}
/*Notes:
- go_unlim = 514,453 obs; 39,474 issuances; 11,898 issuers
- go_lim = 83,004; 6,256 issuances; 2,642 issuers
- rev = 16,070; 1,541 issuances; 948 issuers
*Not sure we're going to have enough variation with the revenue alone
*/

*how many are missing?
gen temp1 = go_unlim + go_lim + rev
tab temp1
/*
      temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |     37,094        5.70        5.70
          1 |    613,527       94.30      100.00
------------+-----------------------------------
      Total |    650,621      100.00
*/
*look at where temp1 == 0

br issuer_long_name year cusip issue_description source_of_repayment security_code if temp1 == 0
tab security_code if temp1 == 0
/*
security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |     24,060       64.86       64.86
          B |        150        0.40       65.27
          C |        377        1.02       66.28
          E |         93        0.25       66.53
          F |         26        0.07       66.60
          G |      3,414        9.20       75.81
          H |      1,420        3.83       79.64
          I |      4,273       11.52       91.15
          J |        429        1.16       92.31
          L |      1,857        5.01       97.32
          N |        599        1.61       98.93
          P |         31        0.08       99.02
          Q |        353        0.95       99.97
          R |         12        0.03      100.00
------------+-----------------------------------
      Total |     37,094      100.00
*/
*mostly A=double-barreled (both rev and GO); we're going to drop these
*9% are revenue by security code
br issuer_long_name year cusip issue_description source_of_repayment security_code if temp1 == 0 & security_code == "G"
*most of these are missing source_of_repayment
replace rev = 1 if rev == 0 & security_code == "G" & source_of_repayment == ""
*sometimes source_of_repayment says it's GO but security_code says revenue, and the issue description isn't clear. ex: "GENERAL OBLIGATION WATER REVENUE" for Dexter, Minn
*let these inconsistent ones end up being dropped. They may be double-barrelled, which we want to drop
br issuer_long_name year cusip issue_description source_of_repayment security_code if temp1 == 0 & security_code == "I"
*these are special assessment / tax increment financing
*some of the issue descriptions say GO, but think don't want to risk the noise if they issue description is just incomplete

*now regen temp1
drop temp1
gen temp1 = go_unlim + go_lim + rev
tab temp1
/*
      temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |     33,963        5.22        5.22
          1 |    616,658       94.78      100.00
------------+-----------------------------------
      Total |    650,621      100.00
*/
*pretty good, drop the others
drop if temp1 == 0
drop temp1

/*For now, don't drop non-fixed coupon. Don't see why we wouldn't want to keep zero-coupon

tab coupon_code
/*
coupon_code |      Freq.     Percent        Cum.
------------+-----------------------------------
        ADJ |          3        0.00        0.00
        DEF |        310        0.05        0.05
        FAR |          1        0.00        0.05
        FLX |          5        0.00        0.05
        FXD |    102,356       16.60       16.65
        IXL |          2        0.00       16.65
        OID |    123,780       20.07       36.72
        OIP |    373,530       60.57       97.30
        SPC |        276        0.04       97.34
        STC |         30        0.00       97.35
        STP |         38        0.01       97.35
        VAR |          6        0.00       97.35
        ZER |     16,321        2.65      100.00
------------+-----------------------------------
      Total |    616,658      100.00
*/
keep if coupon_code == "FXD" |  coupon_code == "OID" |  coupon_code == "OIP"
*16,992 obs dropped

*/

**Keep only federal exempt**
*This is because the vast majority of them should be federally exempt, so the situation is a little weird if not federally exempt
tab taxexempt_federal
/*
taxexempt_f |
     ederal |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |     19,748        3.20        3.20
          1 |    596,910       96.80      100.00
------------+-----------------------------------
      Total |    616,658      100.00
*/
keep if taxexempt_federal == 1

gunique issue_id
*45,034 unique issues
gunique issuer_id
*13,314 unique issuers

**Clean other variables**

replace agent_count = 0 if agent_count==.

*Variable - numerical values for categories of use_proceeds
gegen use_proceeds_num = group(use_proceeds)

*Logs
foreach v in /*maturity*/ agent_count  {
	g ln_`v' = log(`v')
}


*Variable - Tax Exempt - state tax
g taxexempt_state = 1
replace taxexempt_state=0 if state_tax==""
	

**# Bookmark #5
***Calculate issue/series-level variables that aggregate cusip-level vars***

sort state issuer_id year issue_id cusip
order year issue_id, before(cusip)
order go_unlim go_lim rev, after(cusip)

br issuer_id issuer_long_name issue_id cusip year offering_date yield amount maturity num_cusip

*label vars*
label var num_cusip "Num bonds in a series"
label var issuer_id "Issuer ID"
label var city "Dummy if issuer is a city"
label var county "Dummy if issuer is a county"
label var school "Dummy if issuer is a school district"
label var issue_id "Series ID"
label var go_unlim "Dummy if series is unlimited GO"
label var go_lim "Dummy if series is limited GO"
label var rev "Dummy if series is Revenue"
label var offering_date "Issuance date"

*Amount: Calc total amount raised in a series
gegen total_amount = sum(amount), by(issue_id)
count if total_amount != total_offering_amount
*70,258 differences
*br issuer_id issuer_long_name issue_id cusip year offering_date yield amount maturity if total_amount != total_offering_amount
*drop total_offering_amount
drop total_offering_amount
label var total_amount "Total amount raised in a series"

br issuer_id issuer_long_name issue_id issue_description cusip year offering_date amount if rev == 1


*Yield: Calc largest yield and weighted average
*Version 1: Base wavg calcs off the raw yield and winsorize or trim at the end
gen temp1 = yield * amount
gegen temp2 = sum(temp1), by(issue_id)
gen yield_wavg = temp2 / total_amount
drop temp*
*Version 2: Base yield of largest bond off of raw yield
gegen temp1 = max(amount), by(issue_id)
gen temp2 = 1 if amount == temp1
gen temp3 = yield if temp2 == 1
gegen yield_bigamt = max(temp3), by(issue_id)
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


