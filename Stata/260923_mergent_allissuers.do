********************************
*Voting on bonds               *
*Get debt types for all issuers*
*Last updated: 09/23/26        *
********************************

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
	- From raw Mergent data, do basic cleaning, categorize issuers, classify bond types
	- Then see within types of issuers, what the proportion of bond types look like
*/

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
***Start sample selection***
**Basic cleaning**

*Drop non-federally exempt and weird coupons
keep if taxexempt_federal == 1
keep if coupon_code == "FXD" |  coupon_code == "OID" |  coupon_code == "OIP"

gunique issuer_name_id
*2,227,310 obs; 39,139 issuer names

***Classify issuer types***

*State issuers*
gen temp1 = (substr(issuer_long_name, strlen(issuer_long_name)-2, 3) == " ST")
replace temp1 = 1 if strpos(issuer_long_name," ST ") > 0
rename temp1 issuer_state 

gunique issuer_name_id if issuer_state == 1
*State issuers: 712 names; 127,4418 bonds

*Weird authorities and agencies*
gen temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0 & issuer_state == 0
*avoid corpus christi
gen temp2 = 1 if strpos(issuer_long_name,"CORPUS CHRISTI TEX") > 0 
replace temp1 = 1 if strpos(issuer_long_name,"CORP") > 0 & temp2 != 1 > 0 & issuer_state == 0
replace temp1 = 1 if strpos(issuer_long_name,"AGY") > 0 > 0 & issuer_state == 0
replace temp1 = 1 if strpos(issuer_long_name,"AGENCY") > 0 > 0 & issuer_state == 0
replace temp1 = 1 if issuer_long_name == "CORPUS CHRISTI TEX BUSINESS & JOB DEV CORP SALES TAX RE"

rename temp1 issuer_auth 
replace issuer_auth = 0 if issuer_auth == .
gunique issuer_name_id if issuer_auth == 1
*7,447 names; 328,333 bonds

drop temp2
gen temp1 = issuer_state + issuer_auth

*School districts*
gen issuer_school = 1 if strpos(issuer_long_name,"SCH DI") > 0 & temp1 == 0
replace issuer_school = 1 if strpos(issuer_long_name,"PUB") > 0 & strpos(issuer_long_name,"SCH") > 0 & issuer_school == . & temp1 == 0
replace issuer_school = 1 if strpos(issuer_long_name,"SCH") > 0 & strpos(issuer_long_name,"IND") > 0  & issuer_school == . & temp1 == 0
replace issuer_school = 1 if strpos(issuer_long_name,"REG") > 0 & strpos(issuer_long_name,"SCH") > 0 & issuer_school == . & temp1 == 0	 
replace issuer_school = 1 if strpos(issuer_long_name,"SCHOOL") > 0 & strpos(issuer_long_name,"DIST") > 0 & issuer_school == . & temp1 == 0	
replace issuer_school = 1 if strpos(issuer_long_name,"SCHS") > 0 & issuer_school == . & temp1 == 0	
replace issuer_school = 1 if strpos(issuer_long_name,"SCH SYS") > 0 & issuer_school == . & temp1 == 0	
replace issuer_school = 1 if strpos(issuer_long_name,"AREA SCH") > 0 & issuer_school == . & temp1 == 0	

gunique issuer_long_name if issuer_school == 1
*9,672 issuer names; 614,160 bonds
replace issuer_school = 0 if issuer_school == .

replace temp1 = issuer_state + issuer_auth + issuer_school

*now classify "DIST" that are NOT school districts -- these are special districts
gen issuer_spdist = 1 if strpos(issuer_long_name,"DIST") > 0 & temp1 == 0
replace issuer_spdist = 0 if issuer_spdist == .
gunique issuer_long_name if issuer_spdist == 1
*5,727 issuer names; 244,007 obs

drop temp*
gen temp1 = issuer_state + issuer_auth + issuer_school + issuer_spdist

*Classify universities
*tough to use "UNIV" in the name because a lot of cities have "UNIV" in them too
*look at use_of_proceeds
*br issuer_long_name if use_proceeds == "HIED"
*unfortunately there are some cities and towns here
*maybe use combo of use_proceeds and name?
gen issuer_univ = 1 if strpos(issuer_long_name,"UNIV") > 0 & use_proceeds == "HIED" & temp1 == 0
replace issuer_univ = 1 if strpos(issuer_long_name,"COLLEGE") > 0 & use_proceeds == "HIED" & temp1 == 0
gunique issuer_long_name if issuer_univ == 1
*281 issuer names; 31,589 obs
replace issuer_univ = 0 if issuer_univ == .

drop temp1

gen issuer_type = "state" if issuer_state == 1
replace issuer_type = "auth" if issuer_auth == 1
replace issuer_type = "school" if issuer_school == 1
replace issuer_type = "spdist" if issuer_spdist == 1
replace issuer_type = "univ" if issuer_univ == 1

tab issuer_type
/*
issuer_type |      Freq.     Percent        Cum.
------------+-----------------------------------
       auth |    328,333       24.40       24.40
     school |    614,160       45.64       70.05
     spdist |    244,007       18.13       88.18
      state |    127,441        9.47       97.65
       univ |     31,589        2.35      100.00
------------+-----------------------------------
      Total |  1,345,530      100.00
*/
*881,780 bonds still not categorized

order state issuer_name_id issuer_long_name issuer_type cusip6 year cusip issue_description security_code offering_date fips, before(maturity_date)

**# Bookmark #1

*Bring in Kimmie's name matching for cities and counties
mmerge issuer_name_id using "$MERGENT\Clean\241108_all_issuernames_with_seed_issuer.dta", ///
	type(n:1) missing(nomatch)

/*
                vars |    188  (including _merge)
         ------------+---------------------------------------------------------
              _merge | 870427  obs only in master data                (code==1)
                     |    407  obs only in using data                 (code==2)
                     | 1356883  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
drop if _merge == 2
drop _merge

sort state issuer_type issuer_long_name issue_id offering_date

*Do seed matching based on issuers in final sample to pick up other issuer names tied to these issuers
preserve
keep if seed_issuer_id == .
keep issuer_long_name
duplicates drop
export delimited using "$MERGENT\Clean\260923_otherdebt_issuerforseed.csv", replace
restore


**# Bookmark #3
***Bring in other-debt issuers matched to an existing city seed_issuer***
*seed matching done in Code\Python\260923_otherdebt_seed_match.py
*review file: $MERGENT\Clean\260923_otherdebt_issuerforseed_matched_jh.csv (plus manual overrides csv)

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
	import delimited using "$MERGENT\Clean\260923_otherdebt_issuerforseed_matched_jh.csv", clear varnames(1)
	keep issuer_long_name seed_issuer 
	rename seed_issuer seed_issuer_match
	tempfile seedmatch
	save `seedmatch'
restore

merge m:1 issuer_long_name using `seedmatch', keepusing(seed_issuer_match)
tab _merge
/*   Matching result from |
                  merge |      Freq.     Percent        Cum.
------------------------+-----------------------------------
        Master only (1) |  1,356,883       60.92       60.92
            Matched (3) |    870,427       39.08      100.00
------------------------+-----------------------------------
                  Total |  2,227,310      100.00
*/
drop if _merge == 2
drop _merge

sort state issuer_type issuer_long_name issue_id offering_date

*fill in seed_issuer for the newly retained other-debt bonds
replace seed_issuer = seed_issuer_match if seed_issuer == "" & seed_issuer_match != ""
drop seed_issuer_match

*fill in seed_issuer_id, school, county
drop n_bonds
local temp seed_issuer_id school county
foreach x of local temp{
	gegen temp1 = max(`x') if seed_issuer != "", by(seed_issuer)
	drop `x'
	rename temp1 `x'
}

*If school == 0 and county == 0, then call it a city
gen issuer_county = 1 if county == 1 & issuer_type == ""
replace issuer_county = 0 if issuer_county == .
replace issuer_type = "county" if issuer_county == 1

gen issuer_city = 1 if issuer_type == "" & school == 0 & county == 0
replace issuer_city = 0 if issuer_city == .
replace issuer_type = "city" if issuer_city == 1 

tab issuer_type
/*
issuer_type |      Freq.     Percent        Cum.
------------+-----------------------------------
       auth |    328,333       15.26       15.26
       city |    641,626       29.83       45.09
     county |    163,843        7.62       52.71
     school |    614,160       28.55       81.26
     spdist |    244,007       11.34       92.61
      state |    127,441        5.92       98.53
       univ |     31,589        1.47      100.00
------------+-----------------------------------
      Total |  2,150,999      100.00
*/
count if issuer_type == ""
*76,311 not categorized; most are categorized
*br state issuer_long_name issuer_type if issuer_type == ""

*These are ones that we'd dropped originally before name matching because no GO or rev bonds were classified

*Try to classify these now
*Other schools
gen temp1 = 1 if strpos(issuer_long_name,"BRD ED") > 0 & issuer_type == ""
replace temp1 = 1 if strpos(issuer_long_name, "SCH") > 0 & strpos(issuer_long_name, "BRD") > 0 & issuer_type == ""
replace issuer_school = 1 if temp1 == 1
replace issuer_type = "school" if temp1 == 1
drop temp1

*Other weird corp entities
gen temp1 = 1 if strpos(issuer_long_name,"LLC") > 0 & issuer_type == ""
replace temp1 = 1 if strpos(issuer_long_name,"INC") > 0 & issuer_type == ""
replace temp1 = 1 if strpos(issuer_long_name,"LTD") > 0 & issuer_type == ""
replace issuer_auth = 1 if temp1 == 1
replace issuer_type = "auth" if temp1 == 1
drop temp1

*Counties
gen temp1 = 1 if strpos(issuer_long_name,"CNTY") > 0 & issuer_type == ""
replace issuer_county = 1 if temp1 == 1
replace issuer_type = "county" if temp1 == 1
drop temp1

tab issuer_type
count if issuer_type == ""
*82,836 bonds left
*call these cities
replace issuer_type = "city" if issuer_type == ""
replace issuer_city = 1 if issuer_type == "city"

tab issuer_type
/*
issuer_type |      Freq.     Percent        Cum.
------------+-----------------------------------
       auth |    331,819       14.90       14.90
       city |    696,432       31.27       46.17
     county |    180,939        8.12       54.29
     school |    615,083       27.62       81.90
     spdist |    244,007       10.96       92.86
      state |    127,441        5.72       98.58
       univ |     31,589        1.42      100.00
------------+-----------------------------------
      Total |  2,227,310      100.00
*/

**# Bookmark #2
***Now classify bonds***

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
          0 |    485,478       21.80       21.80
          1 |  1,741,832       78.20      100.00
------------+-----------------------------------
      Total |  2,227,310      100.00
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
          0 |    205,284        9.22        9.22
          1 |  2,022,026       90.78      100.00
------------+-----------------------------------
      Total |  2,227,310      100.00
*/

*Then, classify as unlimited tax GO based on issue description
replace go_unlim = 1 if temp1 == 0 & strpos(issue_description,"GENERAL") > 0 & strpos(issue_description,"OBLIGATION") > 0 & strpos(issue_description,"UNLIMITED") > 0 
*570 changes
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
          0 |    199,053        8.94        8.94
          1 |  2,028,257       91.06      100.00
------------+-----------------------------------
      Total |  2,227,310      100.00
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
          0 |    149,106        6.69        6.69
          1 |  2,078,204       93.31      100.00
------------+-----------------------------------
      Total |  2,227,310      100.00
*/

*Now adjust rev for sales or excise tax
gen temp_salestax = 1 if strpos(issue_description, "SALE") > 0 & strpos(issue_description, "TAX") > 0
replace temp_salestax = 0 if temp_salestax == .
gen temp_excisetax = 1 if strpos(issue_description, "EXCISE") > 0 & strpos(issue_description, "TAX") > 0
replace temp_excisetax = 0 if temp_excisetax == .
gen temptax = 1 if temp_salestax == 1 | temp_excisetax == 1
replace temptax = 0 if temptax == .

count if source_of_repayment == "" & rev == 1 & security_code == "G" & temptax == 1
*835
count if source_of_repayment == "G" & rev == 1 & security_code == "G" & temptax == 1
*493

*Types of rev bonds we want to filter out in case there's variation in whether they're voted on: excise tax; sales tax; 
gen bond_type = "rev" if security_code == "G" & temptax == 0
replace bond_type = "" if security_code == "G" & source_of_repayment == "A" 
replace bond_type = "" if security_code == "G" & source_of_repayment == "D" 
replace rev = 0 if rev == 1 & bond_type == ""
replace bond_type = "go" if (go_unlim == 1 | go_lim == 1) & bond_type == ""

count if bond_type == ""
*431,204 bonds are not classified. These will mostly be the sales tax revenue bonds
replace bond_type = "other" if bond_type == ""

tab bond_type if issuer_type == "city"
/*
  bond_type |      Freq.     Percent        Cum.
------------+-----------------------------------
         go |    475,943       68.23       68.23
      other |     72,416       10.38       78.61
        rev |    149,217       21.39      100.00
------------+-----------------------------------
      Total |    697,576      100.00
*/

tab bond_type if issuer_type == "county"
/*
  bond_type |      Freq.     Percent        Cum.
------------+-----------------------------------
         go |    130,867       73.56       73.56
      other |     25,868       14.54       88.10
        rev |     21,176       11.90      100.00
------------+-----------------------------------
      Total |    177,911      100.00
*/

tab bond_type if issuer_type == "school"
/*
  bond_type |      Freq.     Percent        Cum.
------------+-----------------------------------
         go |    594,614       96.62       96.62
      other |     18,600        3.02       99.64
        rev |      2,214        0.36      100.00
------------+-----------------------------------
      Total |    615,428      100.00
*/

tab bond_type if issuer_type == "spdist"
/*
  bond_type |      Freq.     Percent        Cum.
------------+-----------------------------------
         go |    163,159       66.87       66.87
      other |     37,410       15.33       82.20
        rev |     43,438       17.80      100.00
------------+-----------------------------------
      Total |    244,007      100.00
*/

tab bond_type if issuer_type == "auth"
/*
  bond_type |      Freq.     Percent        Cum.
------------+-----------------------------------
         go |     11,058        3.32        3.32
      other |    224,090       67.22       70.54
        rev |     98,210       29.46      100.00
------------+-----------------------------------
      Total |    333,358      100.00
*/

tab bond_type if issuer_type == "state"
/*
  bond_type |      Freq.     Percent        Cum.
------------+-----------------------------------
         go |     33,564       26.34       26.34
      other |     50,482       39.61       65.95
        rev |     43,395       34.05      100.00
------------+-----------------------------------
      Total |    127,441      100.00
*/

tab bond_type if issuer_type == "univ"
/*
  bond_type |      Freq.     Percent        Cum.
------------+-----------------------------------
         go |      3,039        9.62        9.62
      other |      2,338        7.40       17.02
        rev |     26,212       82.98      100.00
------------+-----------------------------------
      Total |     31,589      100.00
*/

*Look at security codes for other bond types
tab security_code if bond_type != "other"
/*

security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |     32,418        1.80        1.80- double-barreled
          B |        91        0.01        1.81- fuel/vehicle tax
          C |       1,259        0.07        1.88 - lease/rent
          D |     215,669       12.01       13.89- limited GO
          E |          97        0.01       13.89 - Other
          F |         22        0.00       13.89
		  G |    383,862       21.37       35.27 - Revenue
          H |       3,381        0.19       35.45 - Sales/excise tax
          I |       14,621        0.81       36.27 - Special Assessment
          J |        514        0.03       36.30 - Tax allocation
          K |    1,140,397       63.49       99.79- UTGO
          L |        1,540        0.09       99.88- US Gov
          N |         996        0.06       99.93 - Loan Agreement
          P |         50        0.01       99.93   
		  Q |      1,148        0.06      100.00 - Special Tax
		  R |         41        0.00      100.00 
------------+-----------------------------------
      Total |    1,796,106       100.00
*/
*By code: 63% UTGO; 12% LTGO; 21% Revenue (no sales or excise tax); 2% double-barreled

drop temp1 school county

save "$MERGENT\Clean\260923_cusiplevel_allbonds_inclrefund.dta", replace


