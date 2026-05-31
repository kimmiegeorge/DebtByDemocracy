************************
*Voting on bonds       *
*Bond data cleaning    *
*Last updated: 11/01/24*
************************

***Set up globals***
*global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
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
 	
*drop issuer_id and gen new issuer_id from issuer_long_name
drop issuer_id
gegen issuer_name_id = group(issuer_long_name)
gunique issuer_name_id
*2,406,477 obs; 40,507 issuer names
	
**# Bookmark #2
***Start sample selection: Drop state bonds***
gen temp1 = (substr(issuer_long_name, strlen(issuer_long_name)-2, 3) == " ST")
keep if temp1 == 0 
*33,246 obs dropped
drop temp1
gunique issuer_name_id
*2,373,231 obs; 40,478 issuer names

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

***Drop refunding bonds***
drop if new_money == 0
*1,144,351 obs dropped; 1,228,880 left
drop new_money

gunique issuer_name_id
*31,304 unique issuer names

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
          0 |    291,126       23.69       23.69
          1 |    937,754       76.31      100.00
------------+-----------------------------------
      Total |  1,228,880      100.00
*/

tab go_unlim
/*
   go_unlim |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    589,794       47.99       47.99
          1 |    639,086       52.01      100.00
------------+-----------------------------------
      Total |  1,228,880      100.00
*/
tab go_lim
/*
------------+-----------------------------------
          0 |  1,129,127       91.88       91.88
          1 |     99,753        8.12      100.00
------------+-----------------------------------
      Total |  1,228,880      100.00
*/
tab rev
/*
        rev |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |  1,029,965       83.81       83.81
          1 |    198,915       16.19      100.00
------------+-----------------------------------
      Total |  1,228,880      100.00
*/

*Then, classify Rev if issue description says Rev
*make uppercase version of issue description
gen temp2 = strupper(issue_description)
drop issue_description
rename temp2 issue_description
order issue_description, after(issuer_long_name)

replace rev = 1 if strpos(issue_description,"REVENUE") > 0 & temp1 == 0
*163,053 changes

drop temp1
gen temp1 = go_unlim + go_lim + rev
tab temp1
/*
      temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    126,073       10.26       10.26
          1 |  1,102,807       89.74      100.00
------------+-----------------------------------
      Total |  1,228,880      100.00
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
          0 |    125,903       10.25       10.25
          1 |  1,102,977       89.75      100.00
------------+-----------------------------------
      Total |  1,228,880      100.00
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
          0 |    122,649        9.98        9.98
          1 |  1,106,231       90.02      100.00
------------+-----------------------------------
      Total |  1,228,880      100.00
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
          0 |     96,336        7.84        7.84
          1 |  1,132,544       92.16      100.00
------------+-----------------------------------
      Total |  1,228,880      100.00
*/
tab go_unlim
/*
   go_unlim |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    563,311       45.84       45.84
          1 |    665,569       54.16      100.00
------------+-----------------------------------
      Total |  1,228,880      100.00
*/
tab go_lim
/*
     go_lim |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |  1,125,873       91.62       91.62
          1 |    103,007        8.38      100.00
------------+-----------------------------------
      Total |  1,228,880      100.00
*/
tab rev
/*
        rev |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    864,912       70.38       70.38
          1 |    363,968       29.62      100.00
------------+-----------------------------------
      Total |  1,228,880      100.00
*/
*54% unlim GO, 8% lim GO, 30% revenue

gunique issuer_name_id
*1,228,880 obs; 31,304 issuer names

*drop uncategorized bonds
drop if temp1 == 0
drop temp1
gunique issuer_name_id
*1,132,544 obs; 28,947 issuer names

***Identify city, county, school bonds***
*Drop "AUTH", "CORP", "AGY"
gen temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0
count if temp1 == 1
drop if temp1 == 1
*128,574 obs
gunique issuer_name_id
*1,003,970 obs; 25,231 issuer names

*br issuer_long_name if strpos(issuer_long_name,"CORP") > 0
*watch out for corpus christi
gen temp2 = 1 if strpos(issuer_long_name,"CORPUS CHRISTI TEX") > 0 
replace temp1 = 1 if strpos(issuer_long_name,"CORP") > 0 & temp2 != 1
*39,363 obs
drop if temp1 == 1
*drop corp for corpus christi
drop if issuer_long_name == "CORPUS CHRISTI TEX BUSINESS & JOB DEV CORP SALES TAX RE"
*14 obs dropped
*corp total = 39,377
drop temp2

gunique issuer_name_id
*964,593 obs; 24,105 issuer names

replace temp1 = 1 if strpos(issuer_long_name,"AGY") > 0 
replace temp1 = 1 if strpos(issuer_long_name,"AGENCY") > 0 
drop if temp1 == 1
drop temp1
*11,525 obs dropped

gunique issuer_name_id
*953,068 obs; 23,759 issuer names

*only keep certain vars and save temp file
keep issue_id cusip year offering_date state issuer_long_name issue_description security_code fips issuer_name_id go_unlim go_lim rev cusip6
order state issuer_name_id issuer_long_name cusip6 year cusip issue_description security_code offering_date go_unlim go_lim rev fips

count if go_unlim == 1
*660,762 
count if go_lim == 1
*99,417
count if rev == 1
*192,889

*save temp file
save "$MERGENT\Clean\241105_bond_temp.dta", replace

*save unique issuer names
gcollapse (count) n_bonds = issue_id, by(state issuer_name_id issuer_long_name)
*23,759 issuer names
save "$MERGENT\Clean\241105_issuernames_unique.dta", replace



