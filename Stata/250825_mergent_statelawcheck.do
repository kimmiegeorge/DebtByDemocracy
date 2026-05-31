********************************************
*Voting on bonds                           *
*Check sample for state law classifications*
*Last updated: 08/25/25                    *
********************************************

***Goals***
/*
- Get cusips to check for states with unclear laws
*/

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global DESCRIPT "$MAIN\Descriptives"
global RESULTS "$MAIN\Results\2025-06_bondlevel"

**# Bookmark #1
***Bond-level analysis with state law variables***

**Start with main city file with yield spreads**
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

*Make histograms by state of pct bonds*
/*
preserve
gcollapse (sum) go_unlim go_lim rev, by(state)
gen n_bonds_total = go_unlim + go_lim + rev
restore
*copied and pasted results into Excel
*/

/*
*7/30: get categories of IA bonds by purpose, size, bond issuance names to look at with KM
keep if state == "IA" & go_unlim == 1
*collapse to issuance-level, keep one cusip
*gegen cusip_id = group(cusip)
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*1,146 issuances
sum amt_issue, d
*mean = 4,138,708; median = 2,290,000, p25 = 1M, p75 = 5M
tab num_use_proceeds
*84% are code 14; 2% are code 11; 2% are code 31; 5.5% are code 56
*of 150 to sample, get 8 that are code 56; 4 that are code 31 and 11
br if num_use_proceeds == 11
*now drop codes 56, 31, 11
drop if num_use_proceeds == 56
drop if num_use_proceeds == 11
drop if num_use_proceeds == 31
sum amt_issue, d
*gen indicator for below 1M, between 1M-5M, above 5M
gen strat = 1 if amt_issue <= 1000000
replace strat = 2 if inrange(amt_issue,1000001,4000000)
replace strat = 3 if amt_issue > 4000000
sample 45, count by(strat)
*pasted these into Excel

*/
*Merge in list of issue id from Iowa random sample
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

mmerge issue_id using "$DATA\Other\2025-07-30_IA_sample150_issue_id.dta", type(n:1) missing(nomatch)
keep if _merge == 3
gunique issue_id
*keep one cusip
sort issue_id
by issue_id: egen temp1 = rank(amount), unique
count if temp1 == 1
*151, good
keep if temp1 == 1
keep seed_issuer seed_issuer_id year issue_id cusip issue_description security_code use_proceeds amount
sort seed_issuer year

*save
save "$DATA\Other\250730_IA_sample150.dta", replace
export delimited using "$DATA\Other\250730_IA_sample150.csv", replace

/*
**Get random samples of cusips to check for: KY, MN, NV, SC, VA, WI**
*8/5: get categories of bonds by purpose, size, bond issuance names to look at with KM
*KY
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
keep if state == "KY" & go_unlim == 1
*collapse to issuance-level
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*88 issuances
sum amt_issue, d
*mean = 6,746,648; median = 4,477,500, p25 = 2.9M, p75 = 8.8M
*paste all into Excel

*MN
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
keep if state == "MN" & go_unlim == 1
*collapse to issuance-level
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*2,496 issuances
sum amt_issue, d
*mean = 3.2M; median = 1.7M, p25 = 0.9M, p75 = 3.4M
tab num_use_proceeds
*85% are code 14; 2% are code 11; 2% are code 31; 5% are code 56
sample 50, count 
*pasted these into Excel


*NV
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
keep if state == "NV" & go_unlim == 1
*collapse to issuance-level
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*4 issuances
*paste all into Excel

*SC
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
keep if state == "SC" & go_unlim == 1
*collapse to issuance-level
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*55 issuances
sum amt_issue, d
*mean = 9.2M; median = 7.0M, p25 = 3.9M, p75 = 15M
tab num_use_proceeds
*76% are code 14 
*pasted all into Excel

*VA
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
keep if state == "VA" & go_unlim == 1
*collapse to issuance-level
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*171 issuances
sum amt_issue, d
tab num_use_proceeds
*89% code 14
sample 50, count 
*paste into Excel

*WI
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
keep if state == "WI" & go_unlim == 1
*collapse to issuance-level
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*1,332 issuances
sum amt_issue, d
*Mean = 4.8M, median = 3M
tab num_use_proceeds
*93% code 14
sample 50, count 
*paste into Excel
*/

*Get cusips to check from each of these states

*Merge in list of issue id from states' random sample
local states KY MN NV SC VA WI
foreach x of local states{
	use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
	mmerge issue_id using `"$DATA\Other\2025-08-05_`x'_sample_issue_id.dta"', type(n:1) missing(nomatch)
	keep if _merge == 3
	sort issue_id
	by issue_id: egen temp1 = rank(amount), unique
	keep if temp1 == 1
	keep seed_issuer seed_issuer_id year issue_id cusip issue_description security_code use_proceeds amount
	sort seed_issuer year
	save `"$DATA\Other\250805_`x'_sample.dta"'
	export delimited using `"$DATA\Other\250805_`x'_sample.csv"'
	
}

*Merge in for Iowa
mmerge issue_id using "$DATA\Other\2025-07-30_IA_sample150_issue_id.dta", type(n:1) missing(nomatch)
keep if _merge == 3
gunique issue_id
*keep one cusip
sort issue_id
by issue_id: egen temp1 = rank(amount), unique
count if temp1 == 1
*151, good
keep if temp1 == 1
keep seed_issuer seed_issuer_id year issue_id cusip issue_description security_code use_proceeds amount
sort seed_issuer year

*save
save "$DATA\Other\250730_IA_sample150.dta", replace
export delimited using "$DATA\Other\250730_IA_sample150.csv", replace

**8/20: Get random samples of cusips to check for: AL Rev, OK Rev **
*AL Rev
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
keep if state == "AL" & rev == 1
*collapse to issuance-level
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*129 issuances
sample 25, count 
*paste issue id's into Excel

*OK Rev
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
keep if state == "OK" & rev == 1
*collapse to issuance-level
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*23 issuances
*paste all issue id's into Excel

local states AL OK
foreach x of local states{
	use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
	mmerge issue_id using `"$DATA\Other\2025-08-20_`x'_sample_issue_id_rev.dta"', type(n:1) missing(nomatch)
	keep if _merge == 3
	sort issue_id
	by issue_id: egen temp1 = rank(amount), unique
	keep if temp1 == 1
	keep seed_issuer seed_issuer_id year issue_id cusip issue_description security_code use_proceeds amount
	sort seed_issuer year
	save `"$DATA\Other\250820_`x'_sample_rev.dta"'
	export delimited using `"$DATA\Other\250820_`x'_sample_rev.csv"'
	
}

**# Bookmark #1
**8/25: Check whether it's accurate that there are so few UTGO bonds for Nevada cities and so few LTGO bonds for LA cities**
*Go back to data file with a lesser level of cleaning/filtering
*Focus on LA, NV
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

*keep if NV, LA
*keep if state == "NV" | state == "LA"

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
	
**# Bookmark #2
***Start sample selection: Drop state bonds***
gen temp1 = (substr(issuer_long_name, strlen(issuer_long_name)-2, 3) == " ST")
replace temp1 = 1 if strpos(issuer_long_name," ST ") > 0
keep if temp1 == 0 
*149,266 obs dropped
drop temp1
gunique issuer_name_id
*30k obs, 605 issuers

***Identify city, county, school bonds***
*Drop "DIST", "AUTH", "CORP", "AGY"

gen temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0
count if temp1 == 1
drop if temp1 == 1

replace temp1 = 1 if strpos(issuer_long_name,"AGY") > 0 
replace temp1 = 1 if strpos(issuer_long_name,"AGENCY") > 0 
drop if temp1 == 1

*Before dropping "DIST", gen indicator for school districts
gen school = 1 if strpos(issuer_long_name,"SCH DI") > 0
replace school = 1 if strpos(issuer_long_name,"PUB") > 0 & strpos(issuer_long_name,"SCH") > 0 & school == .
replace school = 1 if strpos(issuer_long_name,"SCH") > 0 & strpos(issuer_long_name,"IND") > 0  & school == .
replace school = 1 if strpos(issuer_long_name,"REG") > 0 & strpos(issuer_long_name,"SCH") > 0 & school == .	
replace school = 1 if strpos(issuer_long_name,"SCHOOL") > 0 & strpos(issuer_long_name,"DIST") > 0 & school == .	
replace school = 1 if strpos(issuer_long_name,"SCHS") > 0 & school == .	
replace school = 1 if strpos(issuer_long_name,"SCH SYS") > 0 & school == .	
replace school = 1 if strpos(issuer_long_name,"AREA SCH") > 0 & school == .	

*replace school = 0
replace school = 0 if school == .
*now drop "DIST" that are NOT school districts
replace temp1 = 1 if strpos(issuer_long_name,"DIST") > 0 & school == 0
count if temp1 == 1
drop if temp1 == 1
*120,881 obs
gunique issuer_name_id
*804,889 obs; 19,737 issuer names

*drop schools
drop if school == 1

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

*Now, should be mostly cities and counties
*Check security code: K = UTGO, D = LTGO, G = REV, A = double-barreled

*which bonds are most common for cities and counties?
tab security_code
/*
security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |     41,548        4.24        4.24
          B |      1,438        0.15        4.39
          C |     30,794        3.14        7.53
          D |    126,738       12.94       20.47
          E |        119        0.01       20.48
          F |         80        0.01       20.49
          G |    193,801       19.79       40.28
          H |     27,663        2.82       43.10
          I |     29,475        3.01       46.11
          J |      3,129        0.32       46.43
          K |    474,208       48.41       94.85
          L |        661        0.07       94.91
          M |        601        0.06       94.98
          N |     28,128        2.87       97.85
          O |        628        0.06       97.91
          P |         41        0.00       97.92
          Q |      9,832        1.00       98.92
          R |     10,400        1.06       99.98
          S |        189        0.02      100.00
------------+-----------------------------------
      Total |    979,473      100.00
*/
*UTGO (K) = 48%, LTGO (D) = 13%, Revenue (G) = 20%; H (sales and excise tax) = 3%

tab security_code if state == "NV"
/*
security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |      2,124       45.81       45.81
          B |        323        6.97       52.77
          D |        932       20.10       72.87
          G |        351        7.57       80.44
          H |        118        2.54       82.98
          I |        188        4.05       87.04
          J |         36        0.78       87.82
          K |        157        3.39       91.20
          L |         18        0.39       91.59
          N |        374        8.07       99.65
          Q |         14        0.30       99.96
          R |          2        0.04      100.00
------------+-----------------------------------
      Total |      4,637      100.00
*/
*46% double-barreled = backed by GO + pledged revenues
*20% LTGO, 8% rev, 4% UTGO
*Makes sense why NV has so few UTGO - they're all issued as double-barreled

tab security_code if state == "LA"
/*
security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |         17        0.22        0.22
          C |         33        0.42        0.64
          D |        332        4.22        4.85
          G |      2,301       29.23       34.08
          H |      3,442       43.72       77.81
          K |      1,533       19.47       97.28
          M |          5        0.06       97.35
          N |         35        0.44       97.79
          O |         22        0.28       98.07
          Q |        148        1.88       99.95
          R |          4        0.05      100.00
------------+-----------------------------------
      Total |      7,872      100.00
*/
*29% are revenue (G), 4% are limited GO (D), 44% are H (sales / excise tax), 19% are UTGO

*What are the average yields?
sum yield if state == "NV" & security_code == "A"
*mean = 3.24
sum yield if state == "NV" & security_code == "K"
*mean = 4.08
sum yield if state == "NV" & security_code == "G"
*mean = 3.59
sum yield if state == "LA" & security_code == "G"
*mean = 3.24
sum yield if state == "LA" & security_code == "K"
*mean = 3.30
sum yield if state == "LA" & security_code == "H"
*mean = 3.25

***Drop refunding bonds***
*Does this code change within issuance?
gegen temp1 = max(new_money), by(issue_id)
gegen temp2 = min(new_money), by(issue_id)
count if temp1 != temp2
*No, doesn't change within issuance

drop if new_money == 0
drop new_money

tab security_code
*Most common types of bonds when only looking at new money
/*
security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |     23,069        4.56        4.56
          B |        842        0.17        4.73
          C |     15,344        3.03        7.76
          D |     56,480       11.16       18.92
          E |         99        0.02       18.94
          F |         26        0.01       18.95
          G |     90,405       17.87       36.82
          H |     16,053        3.17       39.99
          I |     16,529        3.27       43.26
          J |      1,936        0.38       43.64
          K |    257,130       50.83       94.47
          L |        616        0.12       94.59
          M |        241        0.05       94.64
          N |     13,141        2.60       97.24
          O |        382        0.08       97.31
          P |         41        0.01       97.32
          Q |      6,373        1.26       98.58
          R |      7,090        1.40       99.98
          S |         90        0.02      100.00
------------+-----------------------------------
      Total |    505,887      100.00
*/
*UTGO (K) = 51%, LTGO (D) = 11%, Revenue (G) = 18%; H (sales and excise tax) = 3%

tab security_code if state == "LA"
*now 6% are LTGO

keep if state == "LA"
gen county = 1 if strpos(issuer_long_name,"PARISH") > 0
br if county == .
*it's true that even at this earlier level of cleaning, there are only 2 issuances coded as LTGO

*Look at proportion of bond types
tab security_code
*before dropping counties:
/*
security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |     23,069        4.56        4.56
          B |        842        0.17        4.73
          C |     15,344        3.03        7.76
          D |     56,480       11.16       18.92
          E |         99        0.02       18.94
          F |         26        0.01       18.95
          G |     90,405       17.87       36.82
          H |     16,053        3.17       39.99
          I |     16,529        3.27       43.26
          J |      1,936        0.38       43.64
          K |    257,130       50.83       94.47
          L |        616        0.12       94.59
          M |        241        0.05       94.64
          N |     13,141        2.60       97.24
          O |        382        0.08       97.31
          P |         41        0.01       97.32
          Q |      6,373        1.26       98.58
          R |      7,090        1.40       99.98
          S |         90        0.02      100.00
------------+-----------------------------------
      Total |    505,887      100.00
*/
*18% are revenue (G), 11% are limited GO (D), 3% are H (sales / excise tax), 51% are UTGO (K)

*look at LA LTGO in cleaned city dataset
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
br if state == "LA" & go_lim == 1
*2 issuances

*Look at WV
br if state == "WV" & go_unlim == 1
gunique issue_id if state == "WV" & go_unlim == 1
*37 obs, 2 issuances
*one of these is wrong - the Mergent security code is K (UTGO), but the description in data and OS is "SEWERAGE SYSTEM REFUNDING REVENUE"
*for the one GO bond, there was a vote: https://emma.msrb.org/MS203025-MS178333-MD345567.pdf

br if state == "WV"