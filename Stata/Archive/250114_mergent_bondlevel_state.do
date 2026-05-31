****************************************
*Voting on bonds                       *
*To Mergent bond-level, add state-level*
*Last updated: 01/14/25                *
****************************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"

**# Bookmark #1
*Start with excel of state laws
import delimited "$DATA\Bond Elections\250114_election_requirements_by_state v2.csv", clear
*save
save "$DATA\Bond Elections\250114_election_requirements_by_statev2.dta", replace

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
mmerge state using "$DATA\Bond Elections\250114_election_requirements_by_statev2.dta", ///
	type (n:1) missing(nomatch)
drop _merge
order state seed_issuer seed_issuer_id issuer_type year issue_id bond_type city_go_vote city_rev_vote county_go_vote county_rev_vote cusip6

*br state seed_issuer year bond_type city_go_vote city_rev_vote county_go_vote county_rev_vote

*gen vote req for each issue_id
*manually adjust for 3 cases where limited tax GO aren't voted on for cities: Michigan, Ohio, Washington
replace city_go_vote = 1 if state == "MI"
gen vote_req = 0 if go_lim == 1 & state == "MI" & issuer_type == "city"
replace vote_req = 0 if go_lim == 1 & state == "OH" & issuer_type == "city"
replace vote_req = 0 if go_lim == 1 & state == "WA" & issuer_type == "city"

replace vote_req = 1 if bond_type == "go" & issuer_type == "city" & city_go_vote == 1 & vote_req == .
replace vote_req = 0 if bond_type == "go" & issuer_type == "city" & city_go_vote == 0 & vote_req == .
replace vote_req = 1 if bond_type == "go" & issuer_type == "county" & county_go_vote == 1 & vote_req == .
replace vote_req = 0 if bond_type == "go" & issuer_type == "county" & county_go_vote == 0 & vote_req == .
replace vote_req = 1 if bond_type == "rev" & issuer_type == "city" & city_rev_vote == 1 & vote_req == .
replace vote_req = 0 if bond_type == "rev" & issuer_type == "city" & city_rev_vote == 0 & vote_req == .
replace vote_req = 1 if bond_type == "rev" & issuer_type == "county" & county_rev_vote == 1 & vote_req == .
replace vote_req = 0 if bond_type == "rev" & issuer_type == "county" & county_rev_vote == 0 & vote_req == .

*label vars*
label var offering_date "Issue date"
label var seed_issuer_id "Unique issuer ID"
label var seed_issuer "Unique issuer name"
label var vote_req "Bond required vote"
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
label var county_go_vote "County GO vote"
label var county_rev_vote "County rev vote"
label var state_go_vote "State GO vote"
label var bank_qual "Bank qual"
label var comp_offering "Competitive"
label var rated "Rated"
label var callable "Callable"
label var sinkable "Sinkable"
label var insured "Insured"
label var separate_debtservice_levy "Levy for debt-service"
label var statutory_lien "Lien on property taxes"
label var ultgo_allowed "State allows unlim tax GO"
label var ltgo_allowed "State allows lim tax GO"

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

*save file
save "$MERGENT\Clean\250114_citycountyschool_cusiplevel_statereq v2.dta", replace
