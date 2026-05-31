************************
*Voting on bonds       *
*Bond data cleaning    *
*Last updated: 11/12/24*
************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"

**# Bookmark #1
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
replace temp1 = 1 if strpos(issuer_long_name," ST ") > 0
keep if temp1 == 0 
*149,266 obs dropped
drop temp1
gunique issuer_name_id
*2,257,211 obs; 39,748 issuer names

tab security_code
/*
security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |     66,925        2.96        2.96
          B |      1,665        0.07        3.04
          C |    131,986        5.85        8.89
          D |    224,151        9.93       18.82
          E |        258        0.01       18.83
          F |         80        0.00       18.83
          G |    376,193       16.67       35.50
          H |     41,594        1.84       37.34
          I |     43,829        1.94       39.28
          J |     21,155        0.94       40.22
          K |  1,186,684       52.57       92.79
          L |      2,706        0.12       92.91
          M |      5,184        0.23       93.14
          N |     90,418        4.01       97.15
          O |      1,040        0.05       97.19
          P |      1,333        0.06       97.25
          Q |     36,959        1.64       98.89
          R |     24,687        1.09       99.98
          S |        364        0.02      100.00
------------+-----------------------------------
      Total |  2,257,211      100.00
*/
*53% are unlimited tax GO, 17% are revenue, 10% are limited GO

***Drop refunding bonds***
drop if new_money == 0
*1,091,253 obs dropped; 1,165,958 left
drop new_money

gunique issuer_name_id
*30,727 unique issuer names

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

***Identify city, county, school bonds***
*Drop "DIST", "AUTH", "CORP", "AGY"

gen temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0
count if temp1 == 1
drop if temp1 == 1
*107,270 obs
gunique issuer_name_id
*973,087 obs; 24,883 issuer names

*br issuer_long_name if strpos(issuer_long_name,"CORP") > 0
*watch out for corpus christi
gen temp2 = 1 if strpos(issuer_long_name,"CORPUS CHRISTI TEX") > 0 
replace temp1 = 1 if strpos(issuer_long_name,"CORP") > 0 & temp2 != 1
drop if temp1 == 1
*drop corp for corpus christi
drop if issuer_long_name == "CORPUS CHRISTI TEX BUSINESS & JOB DEV CORP SALES TAX RE"
drop temp2

gunique issuer_name_id
*935,490 obs; 23,790 issuer names

replace temp1 = 1 if strpos(issuer_long_name,"AGY") > 0 
replace temp1 = 1 if strpos(issuer_long_name,"AGENCY") > 0 
drop if temp1 == 1
*9,720 obs dropped

gunique issuer_name_id
*925,770 obs; 23,460 issuer names

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
*329,622 obs; 8,330 issuers

*replace school = 0
replace school = 0 if school == .
*now drop "DIST" that are NOT school districts
replace temp1 = 1 if strpos(issuer_long_name,"DIST") > 0 & school == 0
count if temp1 == 1
drop if temp1 == 1
*120,881 obs
gunique issuer_name_id
*804,889 obs; 19,737 issuer names

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

order state issuer_name_id issuer_long_name school cusip6 year cusip issue_description security_code offering_date go_unlim go_lim rev fips, before(maturity_date)

count if go_unlim == 1
*569,239 
count if go_lim == 1
*90,074
count if rev == 1
*128,868

**# Bookmark #3
***Bring in Kimmie's name matching***
mmerge issuer_name_id using "$MERGENT\Clean\241108_all_issuernames_with_seed_issuer.dta", ///
	type(n:1) missing(nomatch)
/*
                 obs | 788181
                vars |    184  (including _merge)
         ------------+---------------------------------------------------------
              _merge |   8122  obs only in master data                (code==1)
                     | 780059  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*br if _merge == 1
*these are ones excluded in the hand-matching process
keep if _merge == 3
drop _merge n_bonds
order seed_issuer seed_issuer_id, after(state)
sort state seed_issuer_id
order issuer_long_name issuer_name_id, after(COUNTYFP_STATEFP)
drop COUNTYFP_STATEFP
*make city var
tab school
/*
     school |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    450,497       57.75       57.75
          1 |    329,562       42.25      100.00
------------+-----------------------------------
      Total |    780,059      100.00
*/
tab county
/*
     county |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    684,623       87.77       87.77
          1 |     95,436       12.23      100.00
------------+-----------------------------------
      Total |    780,059      100.00
*/
gen city = 1 if school == 0 & county == 0
replace city = 0 if city == .
tab city
/*
       city |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    424,998       54.48       54.48
          1 |    355,061       45.52      100.00
------------+-----------------------------------
      Total |    780,059      100.00
*/

*how many issuers now based on seed issuers?
gunique seed_issuer_id
*15,759 seed issuers
*city/county/school?
gunique seed_issuer_id if city == 1
*6,083 cities
gunique seed_issuer_id if county == 1
*1,535 counties
gunique seed_issuer_id if school == 1
*8,168 schools

*weird that the total is greater than the gunique seed_issuer_id total
gen temp1 = city + county + school
tab temp1
*never more than 1; something weird with gunique?
drop temp1

*what is the composition of city/county/school and types of bonds?
local bond go_unlim go_lim rev
foreach x of local bond{
	count if `x' == 1 & city == 1
	count if `x' == 1 & county == 1
	count if `x' == 1 & school == 1
}
/*Notes
- city: go_unlim = 213,281; go_lim = 44,917; rev = 96,863
- county: go_unlim = 61,826; go_unlim = 13,019; rev = 20,591
- school: go_unlim = 291,337; go_unlim = 31,727; rev = 6,498
*/

**Additional cleaning**
*Drop zero-coupon bonds because those are issued at a substantial discount to face value and terms will be weird
*Drop other weird types of structures
tab coupon_code
/*
coupon_code |      Freq.     Percent        Cum.
------------+-----------------------------------
        ADJ |          7        0.00        0.00
        DEF |        337        0.04        0.04
        FAR |          1        0.00        0.04
        FLX |          6        0.00        0.04
        FXD |    139,374       17.87       17.91
        IXL |          4        0.00       17.91
        OID |    158,335       20.30       38.21
        OIP |    462,491       59.29       97.50
        SPC |        298        0.04       97.54
        STC |         30        0.00       97.54
        STP |         70        0.01       97.55
        VAR |         15        0.00       97.55
        ZER |     19,091        2.45      100.00
------------+-----------------------------------
      Total |    780,059      100.00
*/
keep if coupon_code == "FXD" |  coupon_code == "OID" |  coupon_code == "OIP"
*19,859 obs dropped
gunique seed_issuer_id
*760,200 bonds; 15,707 seed issuers
gunique seed_issuer_id if city == 1
*6,078 cities
gunique seed_issuer_id if county == 1
*1,535 counties
gunique seed_issuer_id if school == 1
*8,120 schools
local bond go_unlim go_lim rev
foreach x of local bond{
	count if `x' == 1 & city == 1
	count if `x' == 1 & county == 1
	count if `x' == 1 & school == 1
}

**Keep only federal exempt**
*Federally exempt bonds will be fundamentally different from non-fundamentally exempt bonds
tab taxexempt_federal
/*
taxexempt_f |
     ederal |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |     29,743        3.91        3.91
          1 |    730,457       96.09      100.00
------------+-----------------------------------
      Total |    760,200      100.00
*/
keep if taxexempt_federal == 1

gunique seed_issuer_id if city == 1
*6,078 cities
gunique seed_issuer_id if county == 1
*1,535 counties
gunique seed_issuer_id if school == 1
*8,120 schools
local bond go_unlim go_lim rev
foreach x of local bond{
	count if `x' == 1 & city == 1
	count if `x' == 1 & county == 1
	count if `x' == 1 & school == 1
}
order city county, before(school)

**# Bookmark #4
**Pull in fips-related demographics data**
*Temporarily adjust year to be prior year so that we're pulling in lagged demographics
rename year year_actual
gen year = year_actual - 1

*Merge in democraphics
mmerge fips year using "$BEA\pop_2001_2022.dta", ///
	type(n:1) missing(nomatch)
/*
                 obs | 781404
                vars |    186  (including _merge)
         ------------+---------------------------------------------------------
              _merge |  88497  obs only in master data                (code==1)
                     |  50947  obs only in using data                 (code==2)
                     | 641960  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*br if _merge == 1
tab year if _merge == 1
*mostly 1999-2000
*evenly distributed across years
drop if _merge == 2
drop _merge
rename geoname county_name
label var county_name "Issuer county"

mmerge fips year using "$BEA\gdp_2001_2022.dta", ///
	type(n:1) missing(nomatch) ukeep(gdp)
drop if _merge == 2
drop _merge

mmerge fips year using "$BEA\pers_inc_2001_2022.dta", ///
	type(n:1) missing(nomatch) ukeep(pers_inc)
drop if _merge == 2
drop _merge

mmerge fips year using "$BEA\percap_inc_2001_2022.dta", ///
	type(n:1) missing(nomatch) ukeep(percap_inc)
drop if _merge == 2
drop _merge

sort state seed_issuer_id offering_date

*apply county name to other years if they weren't matched
gegen temp1 = mode(county_name), by(seed_issuer_id)
drop county_name
rename temp1 county_name
order county_name, after(fips)

drop year
rename year_actual year

**# Bookmark #5
***Other cleaning***
*clean vars for state tax
tab state_tax
/*
  state_tax |      Freq.     Percent        Cum.
------------+-----------------------------------
          N |    627,451       89.01       89.01
          Y |     77,500       10.99      100.00
------------+-----------------------------------
      Total |    704,951      100.00
*/
drop tax_state

*label vars*
label var num_cusip "Num bonds in a series"
label var city "City issuer is a city"
label var county "County issuer is a county"
label var school "School issuer"
label var issue_id "Series ID"
label var go_unlim "GO unlimited tax"
label var go_lim "GO limited tax"
label var rev "Revenue bond"
label var offering_date "Issuance date"
label var seed_issuer_id "Unique issuer ID"
label var seed_issuer "Unique issuer name"

*save version at bond-level
save "$MERGENT\Clean\241112_citycountyschool_cusiplevel.dta", replace
