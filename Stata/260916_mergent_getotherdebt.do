**************************
*Voting on bonds         *
*Get non-GO/Rev bonds    *
*Last updated: 09/16/26  *
**************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global DESCRIPT "$MAIN\Descriptives"
global RESULTS "$MAIN\Results\2025-10_results"

/*Plan:
	- From final sample, get issuers, FIPS, indicator for being included in final sample 
	- Merge back into raw data
	- Get descriptives of non-GO, rev debt
*/

**# Bookmark #1
*use latest bondlevel data
use "$MERGENT\Clean\260716_city_cusiplevel_statereq_purpose_yieldspread.dta", replace

*Only keep certain vars
keep state seed_issuer seed_issuer_id issuer_long_name issuer_name_id issuer_type issue_id bond_type cusip6 cusip issue_description security_code go_unlim go_lim rev city county school fips county_name city_go_vote city_rev_vote num_use_proceeds purp_broad* state_gdp-ln_maturity_mths employment-ln_pop rating_issue_max issue_unrated 

*save bond-level with identifiers
save "$MERGENT\Clean\260716_city_cusiplevel_slim.dta", replace

*save issuer-level with identifiers
keep state seed_issuer seed_issuer_id issuer_long_name issuer_name_id issuer_type city county school fips county_name city_go_vote city_rev_vote
duplicates drop
duplicates tag issuer_long_name, gen(dup)
tab dup
*no dups, 8,218 issuers
drop dup

save "$MERGENT\Clean\260716_city_issuerlevel.dta", replace

**Go back to raw bond data and merge this in**
*Note: seed issuer matching happened after dropping unclassified bonds and after dropping special districts and higher education

***Start with original main dataset*** 
use "$MERGENT\Clean\MuniBond_20210716_v3.dta", clear

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

merge m:1 cusip6 using "$MERGENT\Clean\CUSIP_LOCATION_FIP_INDEX_Jan_05_2023.dta", keepusing(COUNTYFP_STATEFP timing)
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
 	
*drop issuer_id and gen new issuer_id from issuer_long_name
drop issuer_id
gegen issuer_name_id = group(issuer_long_name)
gunique issuer_name_id
*2,406,477 obs; 40,507 issuer names
	
**# Bookmark #2
***Start sample selection: Drop state bonds***
gen temp1 = (substr(issuer_long_name, strlen(issuer_long_name)-2, 3) == " ST")
replace temp1 = 1 if strpos(issuer_long_name," ST ") > 0
keep if temp1 == 0 
*149,266 obs dropped
drop temp1
gunique issuer_name_id
*2,257,211 obs; 39,748 issuer names

***Identify city, county, school bonds***
*Drop "DIST", "AUTH", "CORP", "AGY"

gen temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0
count if temp1 == 1
drop if temp1 == 1

gen temp2 = 1 if strpos(issuer_long_name,"CORPUS CHRISTI TEX") > 0 
replace temp1 = 1 if strpos(issuer_long_name,"CORP") > 0 & temp2 != 1
drop if temp1 == 1
*drop corp for corpus christi
drop if issuer_long_name == "CORPUS CHRISTI TEX BUSINESS & JOB DEV CORP SALES TAX RE"
drop temp2

replace temp1 = 1 if strpos(issuer_long_name,"AGY") > 0 
replace temp1 = 1 if strpos(issuer_long_name,"AGENCY") > 0 
drop if temp1 == 1

gunique issuer_name_id

*Before dropping "DIST", gen indicator for school districts
gen school = 1 if strpos(issuer_long_name,"SCH DI") > 0
replace school = 1 if strpos(issuer_long_name,"PUB") > 0 & strpos(issuer_long_name,"SCH") > 0 & school == .
replace school = 1 if strpos(issuer_long_name,"SCH") > 0 & strpos(issuer_long_name,"IND") > 0  & school == .
replace school = 1 if strpos(issuer_long_name,"REG") > 0 & strpos(issuer_long_name,"SCH") > 0 & school == .	
replace school = 1 if strpos(issuer_long_name,"SCHOOL") > 0 & strpos(issuer_long_name,"DIST") > 0 & school == .	
replace school = 1 if strpos(issuer_long_name,"SCHS") > 0 & school == .	
replace school = 1 if strpos(issuer_long_name,"SCH SYS") > 0 & school == .	
replace school = 1 if strpos(issuer_long_name,"AREA SCH") > 0 & school == .	
gunique issuer_long_name if school == 1

*replace school = 0
replace school = 0 if school == .
*now drop "DIST" that are NOT school districts
replace temp1 = 1 if strpos(issuer_long_name,"DIST") > 0 & school == 0
count if temp1 == 1
drop if temp1 == 1

gunique issuer_name_id

***Drop universities***
*tough to use "UNIV" in the name because a lot of cities have "UNIV" in them too
*look at use_of_proceeds
*br issuer_long_name if use_proceeds == "HIED"
*unfortunately there are some cities and towns here
*maybe use combo of use_proceeds and name?
replace temp1 = 1 if strpos(issuer_long_name,"UNIV") > 0 & use_proceeds == "HIED"
replace temp1 = 1 if strpos(issuer_long_name,"COLLEGE") > 0 & use_proceeds == "HIED"
*br issuer_long_name if temp1 == 1
*this seems okay
drop if temp1 == 1
drop temp1
gunique issuer_name_id
*788,181 obs; 19,529 issuer names

order state issuer_name_id issuer_long_name school cusip6 year cusip issue_description security_code offering_date fips, before(maturity_date)

*Drop non-federally exempt and weird coupons
keep if taxexempt_federal == 1
keep if coupon_code == "FXD" |  coupon_code == "OID" |  coupon_code == "OIP"

**# Bookmark #1
*Merge in issuers
rename fips fips_old

mmerge issuer_long_name issuer_name_id using "$MERGENT\Clean\260716_city_issuerlevel.dta", ///
	type(n:1) missing(nomatch)
/*
                 obs | 1495828
                vars |    186  (including _merge)
         ------------+---------------------------------------------------------
              _merge | 898944  obs only in master data                (code==1)
                     | 596884  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
sort state issuer_long_name seed_issuer offering_date
*br state issuer_long_name seed_issuer offering_date issue_description _merge

*Drop refunding bonds. Note that some issuances that combine refunding with new money get classified as refunding by Mergent. This could also contribute to the wedge between Mergent and Census
drop if new_money == 0
*726,497 obs dropped; 769,331 remaining

*Want to gen indicator for issuer being in final sample. Then merge in issuers from last citycountyschool cusiplevel to get county/school indicators, then can drop those safely
gen finsample = 1 if _merge == 3
drop _merge
drop city county school issuer_type

*Merge in issuers from citycountyschool
mmerge issuer_long_name issuer_name_id using "$MERGENT\Clean\250605_citycountyschool_issuerlevel.dta", ///
	type(n:1) missing(nomatch)
/*
                 obs | 769331
                vars |    187  (including _merge)
         ------------+---------------------------------------------------------
              _merge |  28275  obs only in master data                (code==1)
                     | 741056  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*Most of these are matched

*Check if there are any in city file that the 2nd merge says are counties or schools
count if finsample == 1 & issuer_type == "county"
*0
count if finsample == 1 & issuer_type == "school"
*0
count if finsample == 1
*331,183 obs

drop if _merge == 3 & issuer_type == "county"
*93,432 dropped

drop if _merge == 3 & issuer_type == "school"
*313,010 dropped; 362,889 obs left 

drop issuer_type city county school _merge

replace finsample = 0 if finsample == .
tab finsample
*31,706 bonds are not included 

sort state issuer_long_name seed_issuer issue_id offering_date

br state issuer_long_name seed_issuer offering_date issue_description finsample

*Drop ones with "CNTY" in them
drop if strpos(issuer_long_name,"CNTY") > 0 & finsample == 0
*5000 obs dropped

*drop ones with school
drop if strpos(issuer_long_name,"SCH") > 0 & strpos(issuer_long_name,"DIST") > 0 & finsample == 0
drop if strpos(issuer_long_name,"SCH") > 0 & strpos(issuer_long_name,"BRD") > 0 & finsample == 0
*6,800 obs dropped

tab finsample
*20,000 bonds

*get list of issuer_long_name not included
preserve
keep if finsample == 0
keep issuer_long_name
duplicates drop
export delimited using "$MERGENT\Clean\260916_otherdebt_issuerforseed.csv", replace
restore






/*

***Identify rev, limited tax GO, unlimited tax GO; drop others***
*First, identify these based on security codes alone
gen go_unlim = 1 if security_code == "K"
gen go_lim = 1 if security_code == "D"
gen rev = 1 if security_code == "G"

local varlist go_unlim go_lim rev
foreach x of local varlist{
	replace `x' = 0 if `x' == .
}
*gen temp var for not categorized yet
gen temp1 = go_unlim + go_lim + rev
tab temp1
/*
      temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    256,818       22.03       22.03
          1 |    909,140       77.97      100.00
------------+-----------------------------------
      Total |  1,165,958      100.00
*/

tab go_unlim
/*
   go_unlim |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    530,067       45.46       45.46
          1 |    635,891       54.54      100.00
------------+-----------------------------------
      Total |  1,165,958      100.00
*/
tab go_lim
/*
     go_lim |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |  1,066,336       91.46       91.46
          1 |     99,622        8.54      100.00
------------+-----------------------------------
      Total |  1,165,958      100.00
*/
tab rev
/*
        rev |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    992,331       85.11       85.11
          1 |    173,627       14.89      100.00
------------+-----------------------------------
      Total |  1,165,958      100.00
*/

*Then, classify Rev if issue description says Rev
*make uppercase version of issue description
gen temp2 = strupper(issue_description)
drop issue_description
rename temp2 issue_description
order issue_description, after(issuer_long_name)

replace rev = 1 if strpos(issue_description,"REVENUE") > 0 & temp1 == 0
*141,721 changes

drop temp1
gen temp1 = go_unlim + go_lim + rev
tab temp1
/*
      temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    115,097        9.87        9.87
          1 |  1,050,861       90.13      100.00
------------+-----------------------------------
      Total |  1,165,958      100.00
*/

*Then, classify as unlimited tax GO based on issue description
replace go_unlim = 1 if temp1 == 0 & strpos(issue_description,"GENERAL") > 0 & strpos(issue_description,"OBLIGATION") > 0 & strpos(issue_description,"UNLIMITED") > 0 
*170 changes
drop temp1
gen temp1 = go_unlim + go_lim + rev
tab temp1
/*
      temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    114,927        9.86        9.86
          1 |  1,051,031       90.14      100.00
------------+-----------------------------------
      Total |  1,165,958      100.00
*/

*Then, classify as limited tax GO based on issue description
replace go_lim = 1 if temp1 == 0 & strpos(issue_description,"GENERAL") > 0 & strpos(issue_description,"OBLIGATION") > 0 & strpos(issue_description,"LIMITED") > 0 
*3,254 changes
drop temp1
gen temp1 = go_unlim + go_lim + rev
tab temp1
/*
      temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    111,673        9.58        9.58
          1 |  1,054,285       90.42      100.00
------------+-----------------------------------
      Total |  1,165,958      100.00
*/

*Then, classify remaining GO as go_unlimited
replace go_unlim = 1 if temp1 == 0 & strpos(issue_description,"GENERAL") > 0 & strpos(issue_description,"OBLIGATION") > 0 
*26,313 changes
drop temp1
gen temp1 = go_unlim + go_lim + rev
tab temp1
/*
      temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |     85,664        7.35        7.35
          1 |  1,080,294       92.65      100.00
------------+-----------------------------------
      Total |  1,165,958      100.00
*/
tab go_unlim
/*
   go_unlim |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    503,888       43.22       43.22
          1 |    662,070       56.78      100.00
------------+-----------------------------------
      Total |  1,165,958      100.00
*/
tab go_lim
/*
     go_lim |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |  1,063,082       91.18       91.18
          1 |    102,876        8.82      100.00
------------+-----------------------------------
      Total |  1,165,958      100.00
*/
tab rev
/*
        rev |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    850,610       72.95       72.95
          1 |    315,348       27.05      100.00
------------+-----------------------------------
      Total |  1,165,958      100.00
*/
*57% unlim GO, 9% lim GO, 27% revenue

*drop uncategorized bonds
drop if temp1 == 0
drop temp1
gunique issuer_name_id
*1,080,294 obs; 28,393 issuer names

*/





*Note: After everything is in, do other cleaning after line 545 of 241112 do file

*drop refunding bonds


***Drop refunding bonds***
drop if new_money == 0
*1,091,253 obs dropped; 1,165,958 left
drop new_money

gunique issuer_name_id
*30,727 unique issuer names



