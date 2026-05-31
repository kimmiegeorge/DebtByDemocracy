**************************
*Voting on bonds         *
*Fix FIPS codes          *
*Last updated: 06/05/25  *
**************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global DESCRIPT "$MAIN\Descriptives"
global RESULTS "$MAIN\Results\2025-06_bondlevel"

***Start with list of FIPS to fix***
use "$BEA\250605_fips_tofix.dta", clear
sort state seed_issuer
rename fips fips_wrong
*spot-checked that other issuers that do get their fips matched have the correct fips

gen fips_right = ""
*fix by hand
replace fips_right = "04025" if seed_issuer_id == 11178
replace fips_right = "04005" if seed_issuer_id == 4456
replace fips_right = "04025" if seed_issuer_id == 8351
replace fips_right = "06081" if seed_issuer_id == 13765
*is every right fips the last 2 digits of the wrong one + first 3 dig of wrong one?
*I think so - checked for colorado as well

*make correct fips
gen temp1 = substr(fips_wrong,-2,.)
gen temp2 = substr(fips_wrong,1,3)
gen temp3 = temp1+temp2
*save this
drop fips_right temp1 temp2
rename temp3 fips_right
rename fips_wrong fips

*check for duplicates
duplicates tag seed_issuer_id, gen(dup)
br if dup > 0
*this issuer is in two counties
drop dup


*save file and merge into earlier point of cleaning
save "$BEA\250605_fips_fixed.dta", replace

***Start from 250124 mergent_bondlevel_state code***
use "$MERGENT\Clean\241112_citycountyschool_cusiplevel.dta", clear
*merge in fips_right
mmerge seed_issuer_id fips using "$BEA\250605_fips_fixed.dta", type(n:1) missing(nomatch)
/*
                 obs | 730457
                vars |    188  (including _merge)
         ------------+---------------------------------------------------------
              _merge | 724850  obs only in master data                (code==1)
                     |   5607  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
replace fips = fips_right if _merge == 3 
drop fips_right _merge

**# Bookmark #1

*re-run rest of 250124 cleaning code
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
       COMP |    391,639       68.35       68.35
        LTD |        669        0.12       68.47
       NEGO |    179,473       31.32       99.79
       PPLC |      1,196        0.21      100.00
       REMK |         13        0.00      100.00
------------+-----------------------------------
      Total |    572,990      100.00
*/
gen comp_offering = 1 if offering_type == "COMP"
replace comp_offering = 0 if comp_offering == . & offering_type != ""
drop offering_type
tab bank_qualified
gen bank_qual = 1 if bank_qualified == "Y"
replace bank_qual = 0 if bank_qual == .
drop bank_qualified

*drop debt_type, these are all bonds
drop debt_type

*Fix that parishes in LA and boros in AK are considered cities
gen temp1 = 1 if strpos(seed_issuer, "BORO") > 0 & state == "AK"
replace temp1 = 1 if strpos(seed_issuer, "PARISH") > 0 & state == "LA"
replace temp1 = 1 if strpos(seed_issuer, " PA") > 0 & state == "LA"
replace county = 1 if temp1 == 1 & city == 1
replace city = 0 if temp1 == 1 & city == 1
drop temp1

*Make comprehensive categorical vars for city/county/school and type of bond
gen issuer_type = "city" if city == 1
replace issuer_type = "county" if county == 1
replace issuer_type = "school" if school == 1
count if issuer_type == ""
*0, good

gen bond_type = "go" if go_unlim == 1 | go_lim == 1
replace bond_type = "rev" if bond_type == "" & rev == 1
count if bond_type == ""
*0, good

order issuer_type, after(year)
order bond_type, after(issue_id)
order city county school, before(fips)
order go_unlim go_lim rev, after(offering_date)

*merge in state laws
mmerge state using "$DATA\Bond Elections\250123_election_requirements_by_state.dta", ///
	type (n:1) missing(nomatch)
drop _merge
order state seed_issuer seed_issuer_id issuer_type year issue_id bond_type city_go_vote city_rev_vote cusip6

*br state seed_issuer year bond_type city_go_vote city_rev_vote county_go_vote county_rev_vote

*gen vote req for each issue_id
*manually adjust for 3 states where limited tax GO aren't voted on for cities: Michigan, Ohio, Washington
gen vote_req = 0 if go_lim == 1 & state == "MI" & issuer_type == "city"
replace vote_req = 0 if go_lim == 1 & state == "OH" & issuer_type == "city"
replace vote_req = 0 if go_lim == 1 & state == "WA" & issuer_type == "city"
replace vote_req = 0 if go_lim == 1 & state == "LA" & issuer_type == "city"

replace vote_req = 1 if bond_type == "go" & issuer_type == "city" & city_go_vote == 1 & vote_req == .
replace vote_req = 0 if bond_type == "go" & issuer_type == "city" & city_go_vote == 0 & vote_req == .
replace vote_req = 1 if bond_type == "rev" & issuer_type == "city" & city_rev_vote == 1 & vote_req == .
replace vote_req = 0 if bond_type == "rev" & issuer_type == "city" & city_rev_vote == 0 & vote_req == .

*label vars*
label var offering_date "Issue date"
label var seed_issuer_id "Unique issuer ID"
label var seed_issuer "Unique issuer name"
label var vote_req "Vote required"
label var issue_id "Issue ID"
label var ln_num_cusip "ln(Num bonds in issuance)"
label var county_name "Issuer county"
label var fips "County FIPS"
label var gdp "Lag GDP"
label var pop "Lag population"
label var pers_inc "Lag personal income"
label var percap_inc "Lag per capita income"
label var city "City issuer"
label var county "County issuer"
label var school "School issuer"
label var issuer_type "Issuer type"
label var bond_type "Bond type"
label var go_unlim "GO bond (unlim tax)"
label var go_lim "GO bond (lim tax)"
label var rev "Rev bond"
label var city_go_vote "City GO vote"
label var city_rev_vote "City rev vote"
label var bank_qual "Bank qual"
label var comp_offering "Competitive"
label var rated "Rated"
label var callable "Callable"
label var sinkable "Sinkable"
label var insured "Insured"

*label var for state-related debt considerations
label var state_godebt_limit "State GO debt limit"
label var state_utgo_allowed "Unlim tax GO allowed"
label var state_ltgo_allowed "Lim tax GO allowed"
label var state_fullfaith "Full faith pledge"
label var state_sep_debtservice_levy "Debt-service prop tax"
label var state_sep_pledgerev "Fund for pledged prop tax"
label var state_statutorylien "Statutory lien on pledged prop tax"

*trim offering yield and label
*drop duplicate var
drop yield
winsor2 offering_yield, cuts(1 99) trim suffix(_tr)
label var offering_yield "Yield"
label var offering_yield_tr "Yield"

*trim size and maturity; gen logs
winsor2 amount, cuts(1 99) trim suffix(_tr)
gen ln_amount_tr = ln(1+amount_tr)
drop ln_amount
gen ln_amount = ln(1+amount)
label var ln_amount "ln(Size)"
label var ln_amount_tr "ln(Size)"

winsor2 maturity, cuts(1 99) trim suffix(_tr)
gen ln_maturity_tr = ln(1+maturity_tr)
gen ln_maturity = ln(1+maturity)
label var ln_maturity "ln(Maturity)"
label var ln_maturity_tr "ln(Maturity)"

*gen numbers for use of proceeds
gegen num_use_proceeds = group(use_proceeds)
label var num_use_proceeds "Categorical var for purpose"
*get list to match with use_proceeds
preserve
keep use_proceeds num_use_proceeds
duplicates drop
sort num_use_proceeds
list
restore
/*

     +---------------------+
     | use_pr~s   num_us~s |
     |---------------------|
  1. |     AGRI          1 |
  2. |      AIR          2 |
  3. |     BRDG          3 |
  4. |     CFCT          4 |
  5. |     CIVC          5 |
     |---------------------|
  6. |     CORR          6 |
  7. |     CSED          7 |
  8. |     CUTI          8 |
  9. |     EDEV          9 |
 10. |     ELEC         10 |
     |---------------------|
 11. |     FISE         11 |
 12. |     FLOD         12 |
 13. |      GAS         13 |
 14. |     GPPI         14 |
 15. |     GVPB         15 |
     |---------------------|
 16. |     HIED         16 |
 17. |     HOEQ         17 |
 18. |     HOSP         18 |
 19. |     IDEV         19 |
 20. |     IRRG         20 |
     |---------------------|
 21. |     LIMU         21 |
 22. |     MALL         22 |
 23. |     MASS         23 |
 24. |     MFHG         24 |
 25. |       NA         25 |
     |---------------------|
 26. |     NURS         26 |
 27. |     OFFB         27 |
 28. |     OHCA         28 |
 29. |     ONDV         29 |
 30. |     OPUB         30 |
     |---------------------|
 31. |     OREC         31 |
 32. |     OTED         32 |
 33. |     OTHS         33 |
 34. |     OTRN         34 |
 35. |     OUTI         35 |
     |---------------------|
 36. |     PARK         36 |
 37. |      PFR         37 |
 38. |      PKG         38 |
 39. |     POLE         39 |
 40. |     POLL         40 |
     |---------------------|
 41. |     PRES         41 |
 42. |     PSED         42 |
 43. |     REDV         43 |
 44. |     RETR         44 |
 45. |     SANI         45 |
     |---------------------|
 46. |     SEAP         46 |
 47. |     SFHG         47 |
 48. |     SMHG         48 |
 49. |     SPOR         49 |
 50. |     STLN         50 |
     |---------------------|
 51. |     TELE         51 |
 52. |     THTR         52 |
 53. |     TOLL         53 |
 54. |     VETS         54 |
 55. |     WAST         55 |
     |---------------------|
 56. |      WTR         56 |
     +---------------------+
*/

*gen indicator var for each purpose
local temp agri air brdg cfct civc corr csed cuti edev elec fise flod gas gppi gvpb hied hoeq hosp idev ///
	irrg limu mall mass mfhg na nurs offb ohca ondv opub orec oted oths otrn outi park pfr pkg pole poll ///
	pres psed redv sani seap sfhg smhg spor stln tele thtr toll vets wast wtr 
foreach x of local temp{
	gen purpose_`x' = 1 if use_proceeds == strupper("`x'")
	replace purpose_`x' = 0 if purpose_`x' == .
}

*log of county vars
local varlist gdp pop pers_inc percap_inc
foreach x of local varlist{
	gen ln_`x' = ln(`x')
}
label var ln_gdp "Lag County ln(GDP)"
label var ln_pop "Lag County ln(pop)"
label var ln_pers_inc "Lag County ln(pers inc)"
label var ln_percap_inc "Lag County ln(percap inc)"

*bring in county employment
rename year year_actual
gen year = year_actual - 1

mmerge fips year using "$BEA\employment_2001_2022.dta", ///
	type(n:1) missing(nomatch)
drop if _merge == 2
drop geoname
rename employment emp
gen ln_emp = ln(emp)
label var emp "Lag employment"
label var ln_emp "Lag County ln(emp)"
drop _merge

*bring in state-level demographics, still lagged
mmerge state_name year using "$BEA\state_gdp_2001_2022.dta", ///
	type(n:1) missing(nomatch)
drop if _merge == 2
drop _merge

mmerge state_name year using "$BEA\state_persinc_2001_2022.dta", ///
	type(n:1) missing(nomatch)
drop if _merge == 2
drop _merge

mmerge state_name year using "$BEA\state_percap_inc_2001_2022.dta", ///
	type(n:1) missing(nomatch)
drop if _merge == 2
drop _merge

mmerge state_name year using "$BEA\state_employment_2001_2022.dta", ///
	type(n:1) missing(nomatch)
drop if _merge == 2
drop _merge
rename state_employment state_emp

*log of state vars
local varlist gdp persinc percap_inc emp
foreach x of local varlist{
	gen ln_state_`x' = ln(state_`x')
}
label var ln_state_gdp "Lag State ln(GDP)"
label var ln_state_persinc "Lag State ln(pers inc)"
label var ln_state_percap_inc "Lag State ln(percap inc)"
label var ln_state_emp "Lag State ln(emp)"

*go back to correct years
drop year
rename year_actual year

*gen month variable
gen month = month(offering_date)

*gen year-month FE
gegen yrmonth = group(year month)

**# Bookmark #2
*Run rest of 250313 code EXCEPT WITH 250605 maturity fix

*Prior maturity vars were for longest maturity in an issuance
drop maturity total_maturity_offering max_maturity maturity_tr ln_maturity_tr ln_maturity
gen maturity_days = maturity_date - offering_date
gen maturity_mths = floor(maturity_days/30.437)
sum maturity_mths, d
*avg is 108 months ~ 9 years; p75 is 171 months ~14.25 years
*30.437 = avg month length in days
*make ln and trimmed
*note that trimmed amount and trimmed yield are done at the 1, 99 pctiles and ln_x_tr = ln(1+x_tr)
gen ln_maturity_mths = ln(1+maturity_mths)
winsor2 maturity_mths, trim cuts(1 99) suffix(_tr)
gen ln_maturity_tr = ln(1+maturity_mths_tr)
sum maturity_mths_tr, d

*label var
label var ln_maturity_mths "ln(Maturity)"
label var ln_maturity_tr "ln(Maturity)"
label var maturity_mths "Maturity (months)"
label var maturity_days "Maturity (days)"

sort seed_issuer year offering_date cusip


*bring in broader purpose classification
*Converted from Excel to Stata using StatTransfer, then did minimal variable name cleaning
mmerge use_proceeds using "$MERGENT\Clean\2025-01-25_bondpurpose_classify.dta", type(n:1) missing(nomatch)
/*
                 obs | 730461
                vars |    168  (including _merge)
         ------------+---------------------------------------------------------
              _merge |    175  obs only in master data                (code==1)
                     |      4  obs only in using data                 (code==2)
                     | 730282  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*br state seed_issuer year issue_description use_proceeds num_use_proceeds if _merge == 1
*fix manually
replace purp_broad = "educ" if use_proceeds == "CSED"
*make purpose other for NAs
replace purp_broad = "other" if use_proceeds == "NA"
*br state seed_issuer year issue_description use_proceeds num_use_proceeds if _merge == 2
*never used codes in sample: AIL (airlines), CMOH (CMO-backed housing), NPHG (new public housing), TUNN (tunnels)
drop if _merge == 2
*br state seed_issuer year issue_description use_proceeds num_use_proceeds purp_broad

*Clean and make new vars for broader purpose variable
tab purp_broad
*16 categories
/*
  purp_broad |      Freq.     Percent        Cum.
-------------+-----------------------------------
        arts |      7,249        0.99        0.99
     econdev |      2,142        0.29        1.29
        educ |    322,094       44.09       45.38
       envir |        916        0.13       45.51
genpubimprov |    256,316       35.09       80.60
      health |      8,960        1.23       81.82
     housing |      1,760        0.24       82.06
     justice |      5,777        0.79       82.85
       other |      1,502        0.21       83.06
    parksrec |      7,693        1.05       84.11
     pension |         20        0.00       84.12
     pubbldg |     12,165        1.67       85.78
      safety |      5,923        0.81       86.59
   transport |     10,504        1.44       88.03
   utilities |     18,595        2.55       90.58
      wtrswr |     68,841        9.42      100.00
-------------+-----------------------------------
       Total |    730,457      100.00
*/
*pension and envir are so small, put that into other
replace purp_broad = "other" if inlist(purp_broad, "pension","envir")
tab purp_broad /*now 14 categories*/
/*
  purp_broad |      Freq.     Percent        Cum.
-------------+-----------------------------------
        arts |      7,249        0.99        0.99
     econdev |      2,142        0.29        1.29
        educ |    322,094       44.09       45.38
genpubimprov |    256,316       35.09       80.47
      health |      8,960        1.23       81.70
     housing |      1,760        0.24       81.94
     justice |      5,777        0.79       82.73
       other |      2,438        0.33       83.06
    parksrec |      7,693        1.05       84.12
     pubbldg |     12,165        1.67       85.78
      safety |      5,923        0.81       86.59
   transport |     10,504        1.44       88.03
   utilities |     18,595        2.55       90.58
      wtrswr |     68,841        9.42      100.00
-------------+-----------------------------------
       Total |    730,457      100.00
*/

gegen purp_broad_id = group(purp_broad)
label var purp_broad_id "Purpose ID"

*gen indicator var for each broad purpose
local temp arts econdev educ genpubimprov health housing justice other parksrec pubbldg safety transport utilities wtrswr
foreach x of local temp{
	gen purp_broad_`x' = 1 if purp_broad == "`x'"
	replace purp_broad_`x' = 0 if purp_broad_`x' == .
}

*does the broad purpose ever vary within an issuance?
gegen temp1 = min(purp_broad_id), by(issue_id)
gegen temp2 = max(purp_broad_id), by(issue_id)
count if temp1 != temp2
*336 where the purpose varies within issuance - very rare, but don't seem like data errors
*br state seed_issuer year issue_id issue_description purp_broad if temp1 != temp2

drop temp*

*for gegen, gen temp numeric ID per cusip
sort state seed_issuer year issue_id cusip
gegen cusip_id = group(cusip)

*for each issuer-year and purpose, gen # of bonds, amount for each bond 
local temp arts econdev educ genpubimprov health housing justice other parksrec pubbldg safety transport utilities wtrswr
foreach x of local temp{
	*# of bonds for issuer-year
	gegen `x'_nbonds = count(cusip_id) if purp_broad == "`x'", by(seed_issuer year)
	replace `x'_nbonds = 0 if `x'_nbonds == .
	*amount of $ raised for issuer-year
	gegen `x'_amt = sum(amount) if purp_broad == "`x'", by(seed_issuer year)
	replace `x'_amt = 0 if `x'_amt == .
	*gen ln of amount
	gen `x'_amt_ln = ln(1+`x'_amt)
}

*drop cusip numeric
drop cusip_id

*Additional cleaning: fix some duplicate issuer names from fuzzy matching
*see 3/7 KM file on seedissuer dups
sort state seed_issuer year issue_id cusip
*br state seed_issuer seed_issuer_id issuer_long_name
*fix by hand. gen new seed_issuer_id's where appropriate 
*what's the max seed issuer ID right now?
sum seed_issuer_id
*max is 15758
replace seed_issuer = issuer_long_name if seed_issuer_id == 1077 & state == "CA"
replace seed_issuer = "EL PASO CNTY COLO" if seed_issuer_id == 1077 & state == "CO"
replace seed_issuer_id = 15759 if seed_issuer_id == 1077 & state == "CO"
replace seed_issuer = issuer_long_name if seed_issuer_id == 1077 & state == "IL"
replace seed_issuer = issuer_long_name if seed_issuer_id == 1077 & state == "TX"
replace seed_issuer_id = 15760 if seed_issuer_id == 1077 & state == "TX"
replace seed_issuer = issuer_long_name if seed_issuer_id == 1381 & state == "MI"
replace seed_issuer = issuer_long_name if seed_issuer_id == 1381 & state == "MN"
replace seed_issuer_id = 15761 if seed_issuer_id == 1381 & state == "MN"
replace seed_issuer = issuer_long_name if seed_issuer_id == 1984 & state == "MI"
replace seed_issuer = issuer_long_name if seed_issuer_id == 1984 & state == "MO"
replace seed_issuer_id = 15762 if seed_issuer_id == 1984 & state == "MO"
replace seed_issuer = issuer_long_name if seed_issuer_id == 2529 & state == "IL"
replace seed_issuer = issuer_long_name if seed_issuer_id == 2529 & state == "PA"
replace seed_issuer_id = 15763 if seed_issuer_id == 2529 & state == "PA"
replace seed_issuer = "LINCOLN PA INTER UNIT NO 12" if seed_issuer_id == 2909 & state == "PA"
replace seed_issuer = issuer_long_name if seed_issuer_id == 2909 & state == "LA"
replace seed_issuer_id = 15764 if seed_issuer_id == 2909 & state == "LA"
replace seed_issuer = issuer_long_name if seed_issuer_id == 2909 & state == "MI"
replace seed_issuer_id = 15765 if seed_issuer_id == 2909 & state == "MI"
replace seed_issuer = issuer_long_name if seed_issuer_id == 2909 & state == "NJ"
replace seed_issuer_id = 15766 if seed_issuer_id == 2909 & state == "NJ"
*WASHINGTON CNTY IOWA has the wrong state, weird Mergent error
replace state = "IA" if state == "WA" & issuer_long_name == "WASHINGTON CNTY IOWA HOSP REV"
replace seed_issuer = issuer_long_name if seed_issuer_id == 5950 & state == "IL"
replace seed_issuer = issuer_long_name if seed_issuer_id == 5950 & state == "NY"
replace seed_issuer_id = 15767 if seed_issuer_id == 5950 & state == "NY"
replace seed_issuer = issuer_long_name if seed_issuer_id == 5950 & state == "TX"
replace seed_issuer_id = 15768 if seed_issuer_id == 5950 & state == "TX" 
replace seed_issuer = issuer_long_name if seed_issuer_id == 6822 & state == "IL"
replace seed_issuer = issuer_long_name if seed_issuer_id == 6822 & state == "NJ"
replace seed_issuer_id = 15769 if seed_issuer_id == 6822 & state == "NJ"
replace seed_issuer = issuer_long_name if seed_issuer_id == 7809 & state == "NJ"
replace seed_issuer_id = 15770 if seed_issuer_id == 7809 & state == "NJ"
replace seed_issuer = "COLLEGE PARK GA" if seed_issuer_id == 10104 & state == "GA"
replace seed_issuer = issuer_long_name if seed_issuer_id == 10104 & state == "MD"
replace seed_issuer_id = 15771 if seed_issuer_id == 10104 & state == "MD"
replace seed_issuer = issuer_long_name if seed_issuer_id == 11061 & state == "MN"
replace seed_issuer = issuer_long_name if seed_issuer_id == 11061 & state == "WI"
replace seed_issuer_id = 15772 if seed_issuer_id == 11061 & state == "WI"
replace seed_issuer = "BRIDGEPORT CONN" if seed_issuer_id == 11327 & state == "CT"
replace seed_issuer = issuer_long_name if seed_issuer_id == 11327 & state == "IL"
replace seed_issuer_id = 15773 if seed_issuer_id == 11327 & state == "IL"
replace seed_issuer = issuer_long_name if seed_issuer_id == 11327 & state == "MI"
replace seed_issuer_id = 15774 if seed_issuer_id == 11327 & state == "MI"
replace seed_issuer = issuer_long_name if seed_issuer_id == 11327 & state == "NE"
replace seed_issuer_id = 15775 if seed_issuer_id == 11327 & state == "NE"
replace seed_issuer = "DEER PARK ILL" if seed_issuer_id == 11952 & state == "IL"
replace seed_issuer = issuer_long_name if seed_issuer_id == 11952 & state == "WA"
replace seed_issuer_id = 15776 if seed_issuer_id == 11952 & state == "WA"
replace seed_issuer = issuer_long_name if seed_issuer_id == 12700 & state == "OR"
replace seed_issuer = issuer_long_name if seed_issuer_id == 12700 & state == "TN"
replace seed_issuer_id = 15777 if seed_issuer_id == 12700 & state == "TN"
replace seed_issuer = issuer_long_name if seed_issuer_id == 14222 & state == "MI" & issuer_long_name == "SPRING LAKE VLG MICH"
replace seed_issuer = issuer_long_name if seed_issuer_id == 14222 & state == "MI" & issuer_long_name == "SPRING LAKE TWP MICH"
replace seed_issuer_id = 15778 if seed_issuer_id == 14222 & state == "MI" & issuer_long_name == "SPRING LAKE TWP MICH"
replace seed_issuer = issuer_long_name if seed_issuer_id == 14222 & state == "MN" & issuer_long_name == "SPRING LAKE MINN"
replace seed_issuer_id = 15779 if seed_issuer_id == 14222 & state == "MN" & issuer_long_name == "SPRING LAKE MINN"
replace seed_issuer = issuer_long_name if seed_issuer_id == 14222 & state == "MN" & issuer_long_name == "SPRING LAKE PARK MINN"
replace seed_issuer_id = 15780 if seed_issuer_id == 14222 & state == "MN" & issuer_long_name == "SPRING LAKE PARK MINN"
replace seed_issuer = issuer_long_name if seed_issuer_id == 14805 & state == "IL"
replace seed_issuer = issuer_long_name if seed_issuer_id == 14805 & state == "NJ"
replace seed_issuer_id = 15781 if seed_issuer_id == 14805 & state == "NJ"
replace seed_issuer = issuer_long_name if seed_issuer_id == 14805 & state == "WI"
replace seed_issuer_id = 15782 if seed_issuer_id == 14805 & state == "WI"

*check for dups by seed_issuer_id and seed_issuer
preserve
gcollapse (count) temp1 = amount, by(seed_issuer seed_issuer_id)
duplicates report seed_issuer seed_issuer_id
/*
--------------------------------------
   Copies | Observations       Surplus
----------+---------------------------
        1 |        15493             0
--------------------------------------
*/
*hooray, no dups
restore

*Other cleaning
*Fix state_godebt_limit. Rename so it's clear it's whether the state requires voter approval for GO debt
rename state_godebt_limit state_go_vote
label var state_go_vote "State-level GO vote"
replace state_go_vote = 0 if state == "NY"
replace state_go_vote = 1 if state == "WV"
replace state_go_vote = 1 if state == "WY"
replace state_go_vote = 1 if state == "OK"
replace state_go_vote = 1 if state_go_vote == 2
replace state_go_vote = 1 if state_go_vote == 0.5

**Other cleaning from 250605 file**

**Other cleaning**

*fix NJ, where seed_issuer is sometimes "WEEHAWKEN TWP N J" but issuer_long_name is "WEEHAWKEN TWP N J BRD ED"
count if state == "NJ"
*br seed_issuer issuer_long_name issue_description cusip if state == "NJ" & purp_broad == "educ"
*get indicator if "BRD ED" is in the name
gen temp1 = 1 if strpos(issuer_long_name, "BRD ED") > 0 & state == "NJ"
count if temp1 == 1
*br seed_issuer issuer_long_name issue_description cusip if temp1 == 1
replace issuer_type = "school" if temp1 == 1
replace school = 1 if temp1 == 1
replace city = 0 if temp1 == 1
replace county = 0 if temp1 == 1
drop temp1

*Gen year+quarter FE
gegen yrqtr = group(year qtr)

*save file
save "$MERGENT\Clean\250605_citycountyschool_cusiplevel_statereq_purpose.dta", replace