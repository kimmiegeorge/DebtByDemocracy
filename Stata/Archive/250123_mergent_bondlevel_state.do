****************************************
*Voting on bonds                       *
*To Mergent bond-level, add state-level*
*Last updated: 01/23/25                *
****************************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"

**# Bookmark #1
*Start with excel of state laws
import delimited "$DATA\Bond Elections\250123_election_requirements_by_state.csv", clear
*save
save "$DATA\Bond Elections\250123_election_requirements_by_state.dta", replace

*Start with bond-level Mergent data*
use "$MERGENT\Clean\241112_citycountyschool_cusiplevel.dta", replace
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

*save file
save "$MERGENT\Clean\250123_citycountyschool_cusiplevel_statereq.dta", replace
