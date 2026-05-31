**************************
*Voting on bonds         *
*Analysis with state laws*
*Last updated: 06/25/25  *
**************************

***Goals***
/*
- Explore different combinations of state laws
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

/*Notes from Moody's 2024 rating methodology
- Separate fund for pledged revenues + statutory lien go together. Moody's only considers them if they both exist, not one or the other 
- Variation in the full faith and credit pledge only applies to LTGO
- Debt service levy seems to be separate
*/

**Start with main city file**
use "$MERGENT\Clean\250624_city_cusiplevel_statereq_purpose.dta", clear

**Create additional state law variables**
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
          0 |      1,506        0.46        0.46
          1 |    135,294       41.22       41.68
          2 |    155,598       47.41       89.09
          3 |     35,803       10.91      100.00
------------+-----------------------------------
      Total |    328,201      100.00
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

global countydemo ln_gdp ln_pop ln_pers_inc ln_emp

**Output versions with state clustering**
eststo clear
*Exclude fidelity vars, cluster by state
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
*Include index
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	invest_prot_scaled ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
*Include index components separately 
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
*Include sepfund_statlien and debt service only
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	/*state_fullfaith*/ state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250625_yield_UTGO_statecontrols_v3_stateclus.tex", ///
	replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield (cluster by state)") ///
	star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $countydemo state_go_vote glm_proactive state_ltgo_allowed)		
	
**Output versions with issue clustering**
eststo clear
*Exclude fidelity vars
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*Include index
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	invest_prot_scaled ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*Include index components separately 
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*Include sepfund_statlien and debt service only
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	/*state_fullfaith*/ state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
esttab using "$RESULTS/250625_yield_UTGO_statecontrols_v3_issueclus.tex", ///
	replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield (cluster by issue)") ///
	star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $countydemo state_go_vote glm_proactive state_ltgo_allowed)	

	
**# Bookmark #2
***Issuer-level analysis***

use "$MERGENT\Clean\250625_city_issuerlevel.dta", clear

**Create additional state law variables**
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

global countydemo ln_gdp ln_pop ln_pers_inc ln_emp

*Output: benchmark vs. All GO*
eststo clear
*Reg without fidelity vars; clustered by county 
eststo: qui reg frac_rev city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
*cluster by state
eststo: qui reg frac_rev city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	if insample_allgo == 1, vce(cluster state)
	estadd local SE "State"	
*Include fidelity index
eststo: qui reg frac_rev city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed invest_prot_scaled ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
*Include index components separately 
eststo: qui reg frac_rev city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed  ///
	state_fullfaith state_sep_debtservice_levy sepfund_statlien ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
*Include debt service levy + sepfund_statlien only
eststo: qui reg frac_rev city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed sepfund_statlien state_sep_debtservice_levy ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
esttab using "$RESULTS/250625_allgo_fracrev_v2.tex", replace t noconstant b(3) ///
	title("Revenue debt: Only compare control states with all GO only states (i.e, drop OH, MI, WA) ") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_county_debt_other $countydemo state_go_vote glm_proactive state_ltgo_allowed)

*Output: benchmark vs. UTGO vote only states (WI, MA, OH)*
eststo clear
*Reg without fidelity vars; clustered by county 
eststo: qui reg frac_ltgo city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
*cluster by state
eststo: qui reg frac_ltgo city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	if insample_utgo_only == 1, vce(cluster state)
	estadd local SE "State"	
*Include fidelity index
eststo: qui reg frac_ltgo city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed invest_prot_scaled ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
*Include index components separately 
eststo: qui reg frac_ltgo city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed  ///
	state_fullfaith state_sep_debtservice_levy sepfund_statlien ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
*Include debt service levy + sepfund_statlien only
eststo: qui reg frac_ltgo city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed sepfund_statlien state_sep_debtservice_levy ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
esttab using "$RESULTS/250625_utgoonly_fracltgo_v2.tex", replace t noconstant b(3) ///
	title("LTGO debt: Only compare control states with UTGO-vote-only states (OH, MI, WA) ") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_county_debt_other $countydemo state_go_vote glm_proactive state_ltgo_allowed)
