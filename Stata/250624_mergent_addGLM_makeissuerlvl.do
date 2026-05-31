**************************
*Voting on bonds         *
*State law cleaning      *
*Last updated: 06/24/25  *
**************************

***Goals***
/*
- Check 16 issuers in states where LTGO are not allowed according to Fidelity, but where there seem to be LTGO bonds: MS, MO, WI, NJ, NC, KY
- Bring in Gao et al. proactive state indicators
- Explore dropping full faith and credit pledge
- Explore a combo of separate debt service levy; pledged revenues held separately; statutory lien
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

**Start with main file***
use "$MERGENT\Clean\250605_citycountyschool_cusiplevel_statereq_purpose.dta", clear
drop _merge

*drop just to cities
keep if issuer_type == "city"
*drop hawaii because no city concept
drop if state == "HI"

*number of issuers
gunique seed_issuer
*N = 328,201; 5,900 unbalanced groups of sizes 1 to 1,681
count if go_unlim == 1 
*196,760

**Check issuers with LTGO bonds where LTGO not allowed**
count if go_lim == 1 & state_ltgo_allowed == 0
*1,287
tab state if go_lim == 1 & state_ltgo_allowed == 0
*br state seed_issuer year issue_description security_code cusip if go_lim == 1 & state_ltgo_allowed == 0
*security_code == D, which is Mergent's code for LTGO
/*
- AZ: Mergent code says LTGO, not obvious from OS
- CA: Mergent code says LTGO, bond description says "limited obligation"
- CO: Mergent code says LTGO, bond description says "limited tax general obligation"
- CT: Mergent code says LTGO, not obvious from OS. OS from 977623RU3 makes it sound like UTGO
- MN: Detroit Lakes is an electric revenue bond but Mergent code says LTGO
- MO: Mergent code says special assessment, bond description says LTGO
- States where Fidelity says LTGO not allowed by bond description says LTGO: MS, MO, CO, CA 
*/ 
*Not clear what the right way to reconcile this is. Sometimes Fidelity report is wrong, sometimes right. Sometimes Mergent code is wrong, sometimes right.

**Bring in Gao et al indicator**
mmerge state using "$DATA\Gao et al\250624_GLM_table1.dta", ///
	type(n:1) missing(nomatch)
br if _merge == 2
*DC and HI, drop
drop if _merge == 2
*rest of them matched
drop _merge

*save file
save "$MERGENT\Clean\250624_city_cusiplevel_statereq_purpose.dta", replace

**# Bookmark #2
**Make issuer-level data**

*Go back to main file to calc other debt raised in same county by other non-city issuers
*Cleaning code below is from 250605_mergent_analysis_and_issuerlevel
use "$MERGENT\Clean\250605_citycountyschool_cusiplevel_statereq_purpose.dta", clear
drop if state == "HI"

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

*make indicators for categories of states in the map
*only want to compare control (no vote) with UTGO vote only OR all GO vote only
gen control = 1 if city_go_vote == 0 & city_rev_vote == 0
gen utgo_only = 1 if inlist(state, "WA", "MI", "OH") 
gen allgo_only = 1 if inlist(state, "OR","MT","WY","UT","NM","AK","TX","NE")
replace allgo_only = 1 if inlist(state,"IA","MO","LA","GA","FL","NC","WV")

local temp control utgo_only allgo_only
foreach x of local temp{
	replace `x' = 0 if `x' == .
}

gen insample = 1 if control == 1 | utgo_only == 1 | allgo_only == 1
replace insample = 0 if insample == .

tab control
*20.5% control; 1,242 issuers
tab utgo_only
*11.6% UTGO only; 699 issuers
tab allgo_only
*23.5% all GO only; 1,422 issuers
tab insample
*55.58% in sample; 3,363 issuers

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

*Make sample indicators:
*Look at comparison between benchmark and UTGO+LTGO states (excluding UTGO only)

gen insample_allgo = 1 if control == 1
replace insample_allgo = 1 if allgo_only == 1
replace insample_allgo = 0 if insample_allgo == .

*Look at comparison between benchmark and UTGO only states
gen insample_utgo_only = 1 if control == 1 | utgo_only == 1
replace insample_utgo_only = 0 if insample_utgo_only == .

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

*save file
save "$MERGENT\Clean\250625_city_issuerlevel.dta", replace