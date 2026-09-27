**************************
*Voting on bonds         *
*Get non-GO/Rev bonds    *
*Last updated: 09/18/26  *
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

**# Bookmark #3
***Bring in other-debt issuers matched to an existing city seed_issuer***
*seed matching done in Code\Python\260916_otherdebt_seed_match.py
*review file: $MERGENT\Clean\260916_otherdebt_issuerforseed_matched.csv (plus manual overrides csv)

*build seed issuer-level lookup: one row per known city seed, with city attributes
preserve
	use "$MERGENT\Clean\260716_city_issuerlevel.dta", clear
	keep seed_issuer seed_issuer_id state fips county_name city_go_vote city_rev_vote
	*collapse to one row per seed_issuer (attributes should be constant within a city; keep first if not, so the merge below is m:1)
	bysort seed_issuer: keep if _n == 1
	tempfile seedlevel
	save `seedlevel'
restore

*bring in python seed-matching results for issuers not already in the GO/rev final sample
preserve
	import delimited using "$MERGENT\Clean\260916_otherdebt_issuerforseed_matched.csv", clear varnames(1)
	keep issuer_long_name seed_issuer in_finalsample
	rename seed_issuer seed_issuer_match
	tempfile seedmatch
	save `seedmatch'
restore

merge m:1 issuer_long_name using `seedmatch', keepusing(seed_issuer_match in_finalsample)
*expect finsample==1 obs to not match (code==1, already in GO/rev final sample); finsample==0 obs to match (code==3)
tab finsample _merge
drop if _merge == 2
drop _merge

*only keep "other debt" bonds (finsample==0) whose issuer matched to a city already in the final sample
drop if finsample == 0 & (missing(in_finalsample) | in_finalsample == 0)

*fill in seed_issuer for the newly retained other-debt bonds
replace seed_issuer = seed_issuer_match if finsample == 0
drop seed_issuer_match in_finalsample

*fill in city attributes (fips, county, go/rev vote history, seed_issuer_id) for these bonds via the seed issuer-level lookup
drop seed_issuer_id fips county_name city_go_vote city_rev_vote
merge m:1 seed_issuer using `seedlevel', keepusing(seed_issuer_id fips county_name city_go_vote city_rev_vote)
*expect all obs to match (code==3); every kept seed_issuer should exist in the city issuer-level file
tab _merge
drop if _merge == 2
drop _merge

*indicator for whether bond is "other debt" added via seed-issuer matching, vs. originally a GO/rev bond in the final sample
gen newmatch = (finsample == 0)
tab newmatch
/*  Non-GO or |
        Rev |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    331,183       98.53       98.53
          1 |      4,930        1.47      100.00
------------+-----------------------------------
      Total |    336,113      100.00
*/

sort state seed_issuer issue_id

**# Bookmark #1
*Classify UTGO, LTGO, Rev, COP

*First, identify UTGO, LTGO, Rev
*Follow same steps as in 241112_mergent and then later 260716_updatestatelaw do files

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
          0 |     50,092       14.90       14.90
          1 |    286,021       85.10      100.00
------------+-----------------------------------
      Total |    336,113      100.00
*/

tab go_unlim
/*
   go_unlim |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    157,924       46.99       46.99
          1 |    178,189       53.01      100.00
------------+-----------------------------------
      Total |    336,113      100.00
*/
tab go_lim
/*
     go_lim |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    295,436       87.90       87.90
          1 |     40,677       12.10      100.00
------------+-----------------------------------
      Total |    336,113      100.00
*/
tab rev
/*

        rev |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    268,958       80.02       80.02
          1 |     67,155       19.98      100.00
------------+-----------------------------------
      Total |    336,113      100.00
*/

*Then, classify Rev if issue description says Rev
*make uppercase version of issue description
gen temp2 = strupper(issue_description)
drop issue_description
rename temp2 issue_description
order issue_description, after(issuer_long_name)

replace rev = 1 if strpos(issue_description,"REVENUE") > 0 & temp1 == 0

drop temp1
gen temp1 = go_unlim + go_lim + rev
tab temp1
/*

      temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |     28,087        8.36        8.36
          1 |    308,026       91.64      100.00
------------+-----------------------------------
      Total |    336,113      100.00
*/

*Then, classify as unlimited tax GO based on issue description
replace go_unlim = 1 if temp1 == 0 & strpos(issue_description,"GENERAL") > 0 & strpos(issue_description,"OBLIGATION") > 0 & strpos(issue_description,"UNLIMITED") > 0 
*170 changes
drop temp1
gen temp1 = go_unlim + go_lim + rev

*Then, classify as limited tax GO based on issue description
replace go_lim = 1 if temp1 == 0 & strpos(issue_description,"GENERAL") > 0 & strpos(issue_description,"OBLIGATION") > 0 & strpos(issue_description,"LIMITED") > 0 
drop temp1
gen temp1 = go_unlim + go_lim + rev
tab temp1
/*

      temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |     26,771        7.96        7.96
          1 |    309,342       92.04      100.00
------------+-----------------------------------
      Total |    336,113      100.00
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
          0 |     10,493        3.12        3.12
          1 |    325,620       96.88      100.00
------------+-----------------------------------
      Total |    336,113      100.00

*/

*Now adjust rev for sales or excise tax
gen temp_salestax = 1 if strpos(issue_description, "SALE") > 0 & strpos(issue_description, "TAX") > 0
replace temp_salestax = 0 if temp_salestax == .
gen temp_excisetax = 1 if strpos(issue_description, "EXCISE") > 0 & strpos(issue_description, "TAX") > 0
replace temp_excisetax = 0 if temp_excisetax == .
gen temptax = 1 if temp_salestax == 1 | temp_excisetax == 1
replace temptax = 0 if temptax == .

count if source_of_repayment == "" & rev == 1 & security_code == "G" & temptax == 1
*179
count if source_of_repayment == "G" & rev == 1 & security_code == "G" & temptax == 1
*86


*Types of rev bonds we want to filter out in case there's variation in whether they're voted on: excise tax; sales tax; 
gen bond_type = "rev" if security_code == "G" & temptax == 0
replace bond_type = "" if security_code == "G" & source_of_repayment == "A" 
replace bond_type = "" if security_code == "G" & source_of_repayment == "D" 
replace bond_type = "go" if (go_unlim == 1 | go_lim == 1) & bond_type == ""
tab bond_type
/*
  bond_type |      Freq.     Percent        Cum.
------------+-----------------------------------
         go |    236,460       77.98       77.98
        rev |     66,756       22.02      100.00
------------+-----------------------------------
      Total |    303,216      100.00
*/

count if bond_type == ""

*32,897 bonds are not classified. These will mostly be the sales tax revenue bonds

*Look at these security codes and security codes overall
tab security_code if bond_type != ""
/*

security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |      9,011        2.97        2.97 - double-barreled
          B |         41        0.01        2.99 - fuel/vehicle tax
          C |         52        0.02        3.00 - lease/rent
          D |     40,677       13.42       16.42 - limited GO
          E |         28        0.01       16.43 - Other
          G |     66,756       22.02       38.44 - Revenue
          H |        582        0.19       38.63 - Sales/excise tax
          I |      6,687        2.21       40.84 - Special Assessment
          J |        199        0.07       40.91 - Tax allocation
          K |    178,189       58.77       99.67 - UTGO
          L |        265        0.09       99.76 - US Gov
          N |        536        0.18       99.94 - Loan Agreement
          Q |        193        0.06      100.00 - Special Tax
------------+-----------------------------------
      Total |    303,216      100.00
*/
*By code: 58.8% UTGO; 13.4% LTGO; 22.0% Revenue (no sales or excise tax); 3% double-barreled

tab security_code if bond_type == ""
/*
security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |      8,901       27.06       27.06 - double-barreled
          B |        254        0.77       27.83 - fuel/vehicle tax
          C |      2,631        8.00       35.83 - lease/rent
          F |         16        0.05       35.88 - public improvement
          G |        399        1.21       37.09 - Revenue
          H |      7,040       21.40       58.49 - Sales/excise tax
          I |      5,866       17.83       76.32 - Special Assessment
          J |        912        2.77       79.09 - Tax allocation
          L |         87        0.26       79.36 - US Gov
          M |        141        0.43       79.79 - Sales Agreement
          N |      3,784       11.50       91.29 - Loan Agreement
          P |         20        0.06       91.35 - Tuition Agreement
          Q |      2,370        7.20       98.55 - Special Tax
          R |        476        1.45      100.00 - Mortgage loan
------------+-----------------------------------
      Total |     32,897      100.00
*/

*27% double-barreled; 8% lease/rent; 21% sales/excise tax; 18% special assessment; 11.5% loan agreement; 7.2% special tax

replace bond_type = "other" if bond_type == ""

tab bond_type
/*
  bond_type |      Freq.     Percent        Cum.
------------+-----------------------------------
         go |    236,460       70.35       70.35
      other |     32,897        9.79       80.14
        rev |     66,756       19.86      100.00
------------+-----------------------------------
      Total |    336,113      100.00
*/

sum amount if bond_type == "go"
sum amount if bond_type == "rev"
sum amount if bond_type == "other"

*On average, the "other" bonds are smaller than both GO and rev bonds, so unlikely to explain all that is missing. Maybe the refunding bonds though?
*Look at composition of refunding bonds

save "$MERGENT\Clean\260917_city_cusiplevel_finsample_allbonds.dta", replace
use "$MERGENT\Clean\260917_city_cusiplevel_finsample_allbonds.dta", clear

