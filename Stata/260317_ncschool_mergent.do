**************************
*NC Schools        *
*Mergent data  *
*Last updated: 03/17/26  *
**************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global NC "$DATA\NC School"
global DESCRIPT "$NC\descript"

**# Bookmark #1
***Start with original Mergent dataset*** 
use "$MERGENT\Clean\MuniBond_20210716_v3.dta", clear

keep if state == "NC"
*28,129 obs
sum year
*2000-2020

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

*dropped 100 obs missing amount

*bring in FIPS code
merge m:1 cusip6 using  "$MERGENT\Clean\CUSIP_LOCATION_FIP_INDEX_Jan_05_2023.dta", keepusing(COUNTYFP_STATEFP timing)
/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                        52,633
        from master                       586  (_merge==1)
        from using                     52,047  (_merge==2)

    Matched                            27,443  (_merge==3)
    -----------------------------------------
*/

*Look through unmatched
drop if _merge == 2
*br if _merge == 1

*Only a few places. Correct FIPS manually using BEA data as a reference
rename COUNTYFP_STATEFP fips
*br issue_id cusip year issuer_long_name cusip6 fips if _merge == 1
replace fips = "37063" if issuer_long_name == "DURHAM N C"
replace fips = "37051" if issuer_long_name == "FAYETTEVILLE METROPOLITAN HOUSING AUTHORITY"
replace fips = "37067" if issuer_long_name == "FORSYTH CNTY N C"
replace fips = "37071" if issuer_long_name == "GASTONIA HOUSING AUTHORITY"
replace fips = "37119" if issuer_long_name == "MECKLENBURG CNTY N C"
replace fips = "37183" if issuer_long_name == "RALEIGH N C"
replace fips = "37183" if issuer_long_name == "WAKE CNTY N C"
drop _merge
*28,029 obs

sort issuer_long_name offering_date coupon

*Cleaning unneeded variables
*two use of proceeds vars are redundant
drop use_of_proceeds
*drop some unnecessary vars
drop address___mitigation___taking_ac has_climate_sentence risk___uncertainty affect___is_affecting regulation county ///
	state_full state2 location coordinates state_geo zipcode issuer_type

 *drop issuer_id and gen new issuer_id from issuer_long_name
drop issuer_id
gegen issuer_name_id = group(issuer_long_name)
gunique issuer_name_id
*369 issuer names
	
**# Bookmark #2
***Start sample selection: Drop state bonds***
gen temp1 = (substr(issuer_long_name, strlen(issuer_long_name)-2, 3) == " ST")
replace temp1 = 1 if strpos(issuer_long_name," ST ") > 0
br issuer_long_name issue_description if temp1 == 1
*Good, catches state bonds and some university bonds
keep if temp1 == 0 
*1,600 obs dropped
drop temp1
gunique issuer_name_id
*26,429 obs; 356 issuer names

*drop taxable bonds
drop if taxexempt_federal == 0
drop taxexempt_federal
gunique issuer_name_id
*24,552 bonds; 334 issuers

tab security_code
/*
security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |         26        0.11        0.11
          C |      2,260        9.20        9.31
          D |        308        1.25       10.57
          E |         16        0.07       10.63
          G |      7,545       30.73       41.36
          H |         91        0.37       41.73
          I |          3        0.01       41.74
          K |     11,368       46.30       88.05
          M |        232        0.94       88.99
          N |      2,136        8.70       97.69
          P |         63        0.26       97.95
          Q |         15        0.06       98.01
          R |        489        1.99      100.00
------------+-----------------------------------
      Total |     24,552      100.00
*/
/*
C = lease/rent
D = LTGO
G = Revenue
K = UTGO
N = Loan Agreement
R = Mortgage Loans
*/

*Keep refunding bonds for now
tab new_money
/*
  new_money |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |     10,991       44.77       44.77
          1 |     13,561       55.23      100.00
------------+-----------------------------------
      Total |     24,552      100.00
*/
*45% are refunding bonds. Keep for now, can maybe do something clever with them later

*Identify rev, limited tax GO, unlimited tax GO*
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
          0 |      5,331       21.71       21.71
          1 |     19,221       78.29      100.00
------------+-----------------------------------
      Total |     24,552      100.00
*/

*Then, classify Rev if issue description says Rev
*make uppercase version of issue description
gen temp2 = strupper(issue_description)
drop issue_description
rename temp2 issue_description
order issue_description, after(issuer_long_name)

replace rev = 1 if strpos(issue_description,"REVENUE") > 0 & temp1 == 0
*3,228 changes

drop temp1
gen temp1 = go_unlim + go_lim + rev
tab temp1
/*
      temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      2,483       10.11       10.11
          1 |     22,069       89.89      100.00
------------+-----------------------------------
      Total |     24,552      100.00
*/

*Then, classify as unlimited tax GO based on issue description
replace go_unlim = 1 if temp1 == 0 & strpos(issue_description,"GENERAL") > 0 & strpos(issue_description,"OBLIGATION") > 0 & strpos(issue_description,"UNLIMITED") > 0 
*0 changes

*Then, classify as limited tax GO based on issue description
replace go_lim = 1 if temp1 == 0 & strpos(issue_description,"GENERAL") > 0 & strpos(issue_description,"OBLIGATION") > 0 & strpos(issue_description,"LIMITED") > 0 
*45 changes
drop temp1
gen temp1 = go_unlim + go_lim + rev
tab temp1
/*
      temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      2,438        9.93        9.93
          1 |     22,114       90.07      100.00
------------+-----------------------------------
      Total |     24,552      100.00
*/

*Then, classify remaining GO as go_unlimited
replace go_unlim = 1 if temp1 == 0 & strpos(issue_description,"GENERAL") > 0 & strpos(issue_description,"OBLIGATION") > 0 
*26 changes
drop temp1
gen temp1 = go_unlim + go_lim + rev
tab temp1
/*
      temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      2,412        9.82        9.82
          1 |     22,140       90.18      100.00
------------+-----------------------------------
      Total |     24,552      100.00
*/

*put uncategorized bonds into other
gen bond_other = 1 if temp1 == 0
replace bond_other = 0 if bond_other == .

rename (go_unlim go_lim rev) (bond_utgo bond_ltgo bond_rev)
*get one combined bond type var
gen bond_type = "utgo" if bond_utgo == 1
replace bond_type = "ltgo" if bond_ltgo == 1
replace bond_type = "rev" if bond_rev == 1
replace bond_type = "other" if bond_other == 1
tab bond_type
/*
  bond_type |      Freq.     Percent        Cum.
------------+-----------------------------------
       ltgo |        353        1.44        1.44
      other |      2,412        9.82       11.26
        rev |     10,393       42.33       53.59
       utgo |     11,394       46.41      100.00
------------+-----------------------------------
      Total |     24,552      100.00
*/

drop temp1

***Identify issuer type***

*In NC, school districts themselves don't issue bonds. Counties fund educational capex
*Identify counties
gen county = 1 if strpos(issuer_long_name, "CNTY") > 0
replace county = 0 if county == .
*br issuer_long_name if county == 1
*Need to combine into seed issuers, but seems to pick up counties
*br issuer_long_name if use_proceeds == "PSED"
tab use_proceeds
*primary and secondary education is 2,487 (10.1%)
tab county if use_proceeds == "PSED"
*99.4% identified as counties
/*
     county |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |         15        0.60        0.60
          1 |      2,471       99.40      100.00
------------+-----------------------------------
      Total |      2,486      100.00
*/
*Counties are the ones issuing education bonds, not cities
*br year issuer_long_name issue_description if county == 0

*Classify and drop authorities
gen auth = 1 if strpos(issuer_long_name,"AUTH") > 0
*enterprise systems seems like a normal issuance by the town
replace auth = 0 if auth == .
drop if auth == 1
gunique issuer_long_name
*23,495 obs; 301 issuers

*Classify and drop universities
gen univ = 1 if strpos(issuer_long_name,"UNIV") > 0
br if univ == 1
drop if univ == 1
gunique issuer_long_name
*21,381 obs; 286 issuers

*Classify and drop special districts; do not drop public facilities corps
gen special = 1 if strpos(issuer_long_name,"FACS") > 0 & strpos(issuer_long_name,"AGY") > 0 
replace special = 1 if strpos(issuer_long_name,"FIN") > 0 & strpos(issuer_long_name,"AGY") > 0 
replace special = 1 if strpos(issuer_long_name,"FIN") > 0 & strpos(issuer_long_name,"CORP") > 0 
replace special = 1 if strpos(issuer_long_name,"MUN PWR AGY") > 0  
replace special = 1 if strpos(issuer_long_name,"MET SEW DIST") > 0  
replace special = 1 if strpos(issuer_long_name,"HEALTH CARE SYS") > 0  
drop if special == 1

gunique issuer_long_name
*19,695 obs; 268 issuers

drop auth univ special

*how many counties?
gunique issuer_long_name if county == 1
*9,639 obs; 141 issuers. Know max is 100. This is because we need to identify seed_issuers
tab use_proceeds if county == 1
/*
use_proceed |
          s |      Freq.     Percent        Cum.
------------+-----------------------------------
       CFCT |         27        0.28        0.28
       CORR |        108        1.12        1.40
       CUTI |         35        0.36        1.76
       GPPI |      4,929       51.14       52.90
       GVPB |         95        0.99       53.89
       HIED |        352        3.65       57.54
       HOSP |        133        1.38       58.92
       LIMU |         73        0.76       59.67
       MFHG |         21        0.22       59.89
       OHCA |         17        0.18       60.07
       OREC |         38        0.39       60.46
       OTED |        511        5.30       65.76
       OUTI |         19        0.20       65.96
       PARK |         83        0.86       66.82
       PSED |      2,471       25.64       92.46
       SANI |         56        0.58       93.04
       SPOR |         15        0.16       93.19
       WAST |         15        0.16       93.35
        WTR |        641        6.65      100.00
------------+-----------------------------------
      Total |      9,639      100.00
*/
*26% is PSED

tab use_proceeds if county == 1 & new_money == 1
/*
use_proceed |
          s |      Freq.     Percent        Cum.
------------+-----------------------------------
       CFCT |         18        0.30        0.30
       CORR |        108        1.80        2.11
       CUTI |         35        0.58        2.69
       GPPI |      2,156       36.03       38.72
       GVPB |         95        1.59       40.31
       HIED |        284        4.75       45.05
       HOSP |         33        0.55       45.60
       LIMU |         73        1.22       46.82
       MFHG |         21        0.35       47.18
       OREC |         38        0.64       47.81
       OTED |        474        7.92       55.73
       PARK |         83        1.39       57.12
       PSED |      2,219       37.08       94.20
       SANI |         14        0.23       94.44
       SPOR |         15        0.25       94.69
       WAST |         15        0.25       94.94
        WTR |        303        5.06      100.00
------------+-----------------------------------
      Total |      5,984      100.00
*/
*37% is PSED

gunique issue_id if county == 1 & new_money == 1
*5,984 bonds; 332 issuances by counties that are new money

gunique issue_id if county == 1 & new_money == 1 & use_proceeds == "PSED"
*2,219 bonds; 120 issuances by counties that are new money and for education

gunique issuer_long_name if county == 1 & new_money == 1 & use_proceeds == "PSED"
*56 issuers

gunique issuer_long_name if county == 1 & new_money == 0 & use_proceeds == "PSED"
*19 issuers ever do refunding bonds for education

tab coupon_code
/*
coupon_code |      Freq.     Percent        Cum.
------------+-----------------------------------
        ADJ |          1        0.01        0.01
        FXD |        992        5.04        5.04
        OID |      4,121       20.92       25.97
        OIP |     14,579       74.02       99.99
        VAR |          2        0.01      100.00
------------+-----------------------------------
      Total |     19,695      100.00
*/
*pretty much everything is a normal coupon code

*save list of issuers
preserve
keep issuer_long_name
duplicates drop
export delimited using "$NC\mergent_issuer_list.csv", replace
restore

*Other cleaning
order fips issuer_name_id county bond_type, after(issue_description)
label var fips "County FIPS"

*clean callable
replace callable = . if optional_call_flag == ""

*drop unneeded vars
drop filename-material_event_flag
drop orig_cusip_status-total_issue_amount_out
drop disclosure_date-maturity_bond_years

*clean negotiated or competitive offering
tab offering_type
/*
offering_ty |
         pe |      Freq.     Percent        Cum.
------------+-----------------------------------
       COMP |      8,388       51.96       51.96
        LTD |         27        0.17       52.13
       NEGO |      7,685       47.61       99.73
       PPLC |          8        0.05       99.78
       REMK |         35        0.22      100.00
------------+-----------------------------------
      Total |     16,143      100.00
*/
gen comp_offering = 1 if offering_type == "COMP"
replace comp_offering = 0 if comp_offering == . & offering_type != ""
drop offering_type
tab bank_qualified
/*

bank_qualif |
        ied |      Freq.     Percent        Cum.
------------+-----------------------------------
          N |     17,393       88.31       88.31
          Y |      2,302       11.69      100.00
------------+-----------------------------------
      Total |     19,695      100.00
*/
gen bank_qual = 1 if bank_qualified == "Y"
replace bank_qual = 0 if bank_qual == .
drop bank_qualified
label var bank_qual "Bank qual"
label var comp_offering "Competitive"
label var rated "Rated"
label var callable "Callable"
label var sinkable "Sinkable"
label var insured "Insured"

*drop debt_type, these are all bonds
drop debt_type

*save NC Mergent data through 2020
save "$NC\260317_nc_mergent_thru2020.dta", replace

