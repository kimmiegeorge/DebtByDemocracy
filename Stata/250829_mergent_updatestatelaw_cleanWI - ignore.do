**************************
*Voting on bonds         *
*Update state laws       *
*Last updated: 08/29/25  *
**************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global DESCRIPT "$MAIN\Descriptives"

**# Bookmark #1
*Start with main city file with yield spreads and update state law classifications*
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

*Rename old city_go_vote and city_rev_vote
rename (city_go_vote city_rev_vote) (city_go_vote_old city_rev_vote_old)

*Merge in updated classification
mmerge state using "$DATA\Bond Elections\250827_election_requirements_by_state.dta", ///
	type(n:1) missing(nomatch)
*all matched except Hawaii
drop if _merge == 2
drop _merge

*check which states have changes in GO vote
preserve
keep state city_go_vote city_go_vote_old
duplicates drop
list state if city_go_vote != city_go_vote_old
restore
*Iowa and Indiana
*check which states have changes in rev vote
preserve
keep state city_rev_vote city_rev_vote_old
duplicates drop
list state if city_rev_vote != city_rev_vote_old
restore
*California

*Drop old classifications, move in new ones
drop city_go_vote_old city_rev_vote_old
order city_go_vote city_rev_vote, after(bond_type)

*Remove promissory notes from WI
count if state == "WI"
gen temp1 = 1 if state == "WI" & strpos(issue_description, "PROMIS") > 0 & strpos(issue_description, "NOTE") > 0
br if temp1 == 1
*these all pick up promissory notes
*drop these
drop if temp1 == 1
drop temp1

*save file
save "$MERGENT\Clean\250828_city_cusiplevel_statereq_purpose_yieldspread.dta", replace

**# Bookmark #2
**Make new issuer-level version**

**First, make new issuer-level aggregated yield spread without WI promissory notes**
use "$MERGENT\Clean\250828_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

*Make weighted average for an issuance; weighted based on amount
*br state seed_issuer seed_issuer_id issue_id cusip amount offering_yield_spread

*Multiply yield spreads times amounts; sum
gen amt_x_ys = amount * offering_yield_spread
gegen temp1 = sum(amt_x_ys), by(issue_id)
*Gen total amount per issuance
gegen issue_amt_total = sum(amount), by(issue_id)
*Divide numerator by denominator:
gen issue_yield_spread = temp1 / issue_amt_total

drop amt_x_ys temp1

*Now collapse just necessary vars to issuer-level, then make wavg for issuer
keep state seed_issuer seed_issuer_id issue_id issue_amt_total issue_yield_spread
duplicates drop

*Multiple issue_yield_spread * amounts; sum
gen amt_x_ys = issue_amt_total * issue_yield_spread
gegen temp1 = sum(amt_x_ys), by(seed_issuer)
*group by seed_issuer, not seed_issuer_id; note that EL PASO ILL and EL PASO ROBLES... CA have the same seed_issuer_id 
*Gen total amount per issuer
gegen issuer_amt_total = sum(issue_amt_total), by(seed_issuer)
*Divide num by denom:
gen issuer_yield_spread = temp1 / issuer_amt_total
*just keep issuer_level

drop temp1 amt_x_ys
drop issue_amt_total issue_yield_spread issue_id
duplicates drop

*Note there are some issuers where the overall issuer yield == 0; this happens when all that issuer's bonds don't have the yield spread calculated; these are cities with very few bonds
count if issuer_yield_spread == 0
*58 issuers only

replace issuer_yield_spread = . if issuer_yield_spread == 0

*check for duplicates
duplicates tag seed_issuer, gen(dup)
count if dup > 0
*none, good
drop dup

*save file
save "$MERGENT\Clean\250829_issuers_yieldspread.dta", replace

**Now make new issuer-level version**
*Start with city/county/school file to calculate other debt raised in a county
use "$MERGENT\Clean\250605_citycountyschool_cusiplevel_statereq_purpose.dta", clear
drop if state == "HI"

*change state laws
drop city_go_vote city_rev_vote
mmerge state using "$DATA\Bond Elections\250827_election_requirements_by_state.dta", ///
	type(n:1) missing(nomatch)
*all matched except Hawaii
drop if _merge == 2
drop _merge
order city_go_vote city_rev_vote, after(state_name)

*drop WI promissory notes
*Actually, this variable doesn't include other types of debt (e.g., sales tax bonds). So consider not including it
gen temp1 = 1 if state == "WI" & strpos(issue_description, "PROMIS") > 0 & strpos(issue_description, "NOTE") > 0
drop if temp1 == 1
drop temp1

*gen var for total debt raised within a county 2000-2020
tab year
gegen county_debt = sum(amount), by(fips)
*gen additional vars for total UTGO debt, LTGO debt, and REV debt raised in a county
gegen county_utgo = sum(amount) if go_unlim == 1, by(fips)
gegen county_ltgo = sum(amount) if go_lim == 1, by(fips)
gegen county_rev = sum(amount) if rev == 1, by(fips)

*make lns
local temp debt utgo ltgo rev
foreach x of local temp{
	replace county_`x' = 0 if county_`x' == .
	gen ln_county_`x' = ln(1+county_`x')
}

*then drop to cities only
keep if issuer_type == "city"	

*gen total amounts by cities
gegen city_debt = sum(amount), by(seed_issuer)
gegen city_utgo = sum(amount) if go_unlim == 1, by(seed_issuer)
gegen city_ltgo = sum(amount) if go_lim == 1, by(seed_issuer)
gegen city_rev = sum(amount) if rev == 1, by(seed_issuer)
*make lns
local temp debt utgo ltgo rev
foreach x of local temp{
	replace city_`x' = 0 if city_`x' == .
	gen ln_city_`x' = ln(1+city_`x')
}

*for collapse, don't include county and state demos for now
*don't want the county/state demos to be weighted based on # or timing of issuances
*merge in beginning-period county/state demos separately after collapse

*collapse to issuer level, getting avg of the county demos
gcollapse (max) county_debt county_utgo county_ltgo county_rev ln_county_debt ///
	ln_county_utgo ln_county_ltgo ln_county_rev city_debt city_utgo city_ltgo city_rev ///
	ln_city_debt ln_city_utgo ln_city_ltgo ln_city_rev ///
	, by(seed_issuer seed_issuer_id fips state state_name city_go_vote city_rev_vote state_go_vote state_utgo_allowed state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien)

sort state seed_issuer

*make LTGO, UTGO, REV percentages
gen frac_utgo = city_utgo / city_debt
gen frac_ltgo = city_ltgo / city_debt
gen frac_rev = city_rev / city_debt

*gen insample for controls
gen insample = 1 if city_go_vote == 0 & city_rev_vote == 0
*include UTGO only for sample
replace insample = 1 if inlist(state,"WA","MI","OH")
*include All GO Vote for sample
replace insample = 1 if city_go_vote == 1 & city_rev_vote == 0
replace insample = 0 if insample == .

*Make insample_utgo_only
gen insample_utgo_only = 1 if city_go_vote == 0 & city_rev_vote == 0
replace insample_utgo_only = 1 if inlist(state,"WA","MI","OH")
replace insample_utgo_only = 0 if insample_utgo_only == .

*Make insample_allgo
gen insample_allgo = 1 if city_go_vote == 0 & city_rev_vote == 0
replace insample_allgo = 1 if city_go_vote == 1 & city_rev_vote == 0
replace insample_allgo = 0 if inlist(state,"WA","MI","OH")
replace insample_allgo = 0 if insample_allgo == .


*make vars for other debt raised in the same county, but not by the issuer
gen county_debt_other = county_debt - city_debt
gen ln_county_debt_other = ln(1+county_debt_other)

*merge in county demos from 2001
mmerge fips using "$BEA\countydemos_2001.dta", type(n:1) missing(nomatch)
/*
                vars |     47  (including _merge)
         ------------+---------------------------------------------------------
              _merge |     21  obs only in master data                (code==1)
                     |   1447  obs only in using data                 (code==2)
                     |   6028  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/

drop if _merge == 2
drop _merge

*merge in state demos from 2001
mmerge state_name using "$BEA\state_demos_2001.dta", type(n:1) missing(nomatch)
*DC and HI not matched, as expected
drop if _merge == 2
drop _merge

*make ln's of state and county demos
rename state_persinc state_pers_inc
rename (employment state_employment) (emp state_emp)
local temp emp gdp percap_inc pers_inc
foreach x of local temp{
	gen ln_`x' = ln(1+`x')
}
local temp emp gdp percap_inc pers_inc
foreach x of local temp{
	gen ln_state_`x' = ln(1+state_`x')
}

gen ln_pop = ln(1+pop)

*Bring in Gao et al indicator
mmerge state using "$DATA\Gao et al\250624_GLM_table1.dta", ///
	type(n:1) missing(nomatch)
*DC and HI, drop
drop if _merge == 2
*rest of them matched
drop _merge

*label vars*
label var frac_ltgo "Pct LTGO"
label var frac_rev "Pct Rev"
label var frac_utgo "Pct UTGO"
label var state_go_vote "State GO vote"
label var ln_gdp "County ln(GDP)"
label var ln_emp "County ln(Emp)"
label var ln_percap_inc "County ln(Percap Inc)"
label var ln_pers_inc "County ln(Pers. Inc)"
label var ln_city_debt "ln(Issuer debt)"
label var ln_county_debt_other "ln(Non-issuer debt in county)"

*Merge in aggregate yield spreads
mmerge seed_issuer using "$MERGENT\Clean\250829_issuers_yieldspread.dta", ///
	type(n:1) missing(nomatch)
*all matched, hooray
drop _merge
sort state seed_issuer


*Do additional cleaning
*Gen indicator for both statutory lien and separate fund for pledged revenues
gen sepfund_statlien = 1 if state_sep_pledgerev == 1 & state_statutorylien == 1
replace sepfund_statlien = 0 if sepfund_statlien == .
*Going forward, treat these as one measure. For future variable naming, can use something like "Separate pledged revenue"

*Make an index out of this combo, full faith, and separate debt service
gen invest_protect = state_fullfaith + state_sep_debtservice_levy + sepfund_statlien
tab invest_protect
/*
invest_prot |
        ect |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |         17        0.28        0.28
          1 |      2,426       40.11       40.39
          2 |      2,838       46.92       87.30
          3 |        768       12.70      100.00
------------+-----------------------------------
      Total |      6,049      100.00
*/
gen invest_prot_scaled = 0 if invest_protect == 0
replace invest_prot_scaled = 0.33 if invest_protect == 1
replace invest_prot_scaled = 0.67 if invest_protect == 2
replace invest_prot_scaled = 1 if invest_protect == 3

*Label vars
label var glm_proactive "Proactive State"
label var state_sep_debtservice_levy "SepLevy"
label var state_sep_pledgerev "PledgedFund"
label var state_statutorylien "StatLien"
label var sepfund_statlien "PledgedFund + StatLien"
label var invest_prot_scaled "Fidelity Index"
label var state_fullfaith "FullFaith"
label var state_ltgo_allowed "LTGO Allowed"
label var ln_pop "County ln(Pop)"
label var issuer_yield_spread "WAvg Yield Spread"

*save file
save "$MERGENT\Clean\250829_city_issuerlevel_yieldspread.dta", replace



