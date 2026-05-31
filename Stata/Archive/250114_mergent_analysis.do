**************************
*Voting on bonds         *
*Broad sample tests      *
*Last updated: 01/14/25  *
**************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global DESCRIPT "$MAIN\Descriptives"
global RESULTS "$MAIN\Results\250114 bondlevel"

***Start with bond-level Mergent data with state voting requirements***
use "$MERGENT\Clean\250114_citycountyschool_cusiplevel_statereq v2.dta", clear

*drop schools
drop if issuer_type == "school"
tab issuer_type
/*
Issuer type |      Freq.     Percent        Cum.
------------+-----------------------------------
       city |    334,728       78.87       78.87
     county |     89,654       21.13      100.00
------------+-----------------------------------
      Total |    424,382      100.00
*/
*given cities are most of the sample, keep just cities for now
keep if issuer_type == "city"
*drop hawaii because no city concept
drop if state == "HI"

***Does having a GO voting requirement lead to a different offering yield on the pooled sample of GO and rev bonds?***
**Build specification: start with city GO vote requirement on GO and revenue bonds**
reg offering_yield_tr city_go_vote, vce(cluster state)
*coeff=0.170, t=2.75, p=0.009, r2=0.004

reghdfe offering_yield_tr city_go_vote ///
	, absorb(year) vce(cluster state)
*coeff=0.165, t=4.05, p=0.000, r2=0.493
	
reghdfe offering_yield_tr city_go_vote ///
	, absorb(year month) vce(cluster state)
*coeff=0.165, t=3.85, p=0.000, r2=0.495
	
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated  ///
	, absorb(year month) vce(cluster state)
*coeff=0.066, t=1.43, p=0.161, r2=0.743
	
reghdfe offering_yield_tr city_go_vote ln_state_gdp ln_state_persinc ///
	ln_state_percap_inc ln_state_emp state_go_vote separate_debtservice_levy statutory_lien ///
	, absorb(year month) vce(cluster state)
*coeff=0.117, t=3.20, p=0.003, r2=0.410
	
reghdfe offering_yield_tr city_go_vote ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(year month) vce(cluster state)
*coeff=0.146, t=3.95, p=0.000, r2=0.409
	
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	ln_state_gdp ln_state_persinc ln_state_percap_inc ln_state_emp state_go_vote separate_debtservice_levy statutory_lien ///
	, absorb(year month) vce(cluster state)
*coeff=-0.054, t=-0.90, p=0.375, r2=0.704	
	
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	ln_state_gdp ln_state_persinc ln_state_percap_inc ln_state_emp state_go_vote separate_debtservice_levy statutory_lien ///
	, absorb(year month) vce(cluster state)
*coeff=-0.054, t=-0.86, p=0.396, r2=0.705

reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	, absorb(year month) vce(cluster state)
*coeff=-0.032, t=-0.59, p=0.558, r2=0.741

reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	, absorb(year month) vce(cluster state)
*coeff=-0.052, t=-0.94, p=0.354, r2=0.703

reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	state_go_vote separate_debtservice_levy statutory_lien ultgo_allowed ltgo_allowed ///
	, absorb(year month) vce(cluster state)
*coeff=-0.055, t=-0.86, p=0.395, r2=0.704

*drop states with revenue bond vote requirement
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	state_go_vote separate_debtservice_levy statutory_lien ultgo_allowed ltgo_allowed ///
	if city_rev_vote == 0 ///
	, absorb(year month) vce(cluster state)
*coeff=-0.083, t=-1.16, p=0.258, r2=0.704

reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	state_go_vote separate_debtservice_levy statutory_lien ultgo_allowed ltgo_allowed ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
*coeff=-0.091, t=-1.32, p=0.201, r2=0.733

**Build specification: start with vote_req on GO and revenue bonds**
reg offering_yield_tr vote_req, vce(cluster state)
*coeff=-0.016, t=-0.25, p=0.805, r2=0.000

reghdfe offering_yield_tr vote_req ///
	, absorb(year) vce(cluster state)
	
reghdfe offering_yield_tr vote_req ///
	, absorb(year month) vce(cluster state)
	
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	, absorb(year month) vce(cluster state)
*coeff=-0.025, t=-0.74, p=0.463, r2=0.736

reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	, absorb(year month) vce(cluster state)
*coeff=-0.067, t=-2.42, p=0.020, r2=0.736
	
reghdfe offering_yield_tr vote_req ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	, absorb(year month) vce(cluster state)
*coeff=-0.054, t=-1.73, p=0.092, r2=0.403
	
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp state_go_vote separate_debtservice_levy statutory_lien ///
	, absorb(year month) vce(cluster state)
*coeff=-0.065, t=-2.24, p=0.031, r2=0.699

reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	ln_state_gdp ln_state_persinc ln_state_percap_inc ln_state_emp state_go_vote ///
	separate_debtservice_levy statutory_lien ///
	, absorb(year month) vce(cluster state)
*coeff=-0.073, t=-2.44, p=0.019, r2=0.700

reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	ln_state_gdp ln_state_persinc ln_state_percap_inc ln_state_emp state_go_vote ///
	separate_debtservice_levy statutory_lien ultgo_allowed ltgo_allowed ///
	, absorb(year month) vce(cluster state)
*coeff=-0.071, t=-2.30, p=0.027, r2=0.700


*show: noFE nocontrol, year month FE, +bond controls, +state controls, +county controls
label var vote_req "Bond referenda required"
eststo clear
eststo: qui reg offering_yield_tr vote_req, vce(cluster state)
	estadd local yearFE "No"
	estadd local monthFE "No"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr vote_req ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"
esttab using "$RESULTS/250114_city_yield_votereq_gorev v2.tex", replace t noconstant b(3) ///
	title("Bond referenda requirements and offering yield") star(* .10 ** .05 *** .01) ///
	s(N r2_a yearFE monthFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year FE" "Month FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	label booktabs noobs nonotes 
	
*try without states with revenue bond requirements
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(year month) vce(cluster state)
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
*all the above work fine

**Now do for GO and rev separately**
**Vote requirement on GO**
eststo clear
eststo: qui reghdfe offering_yield_tr vote_req if bond_type == "go" ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	if bond_type == "go" ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if bond_type == "go" ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"
esttab using "$RESULTS/250114_city_yield_votereq_go v2.tex", replace t noconstant b(3) ///
	title("GO bond referenda requirements and offering yield") star(* .10 ** .05 *** .01) ///
	s(N r2_a yearFE monthFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year FE" "Month FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	label booktabs noobs nonotes 
	
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if bond_type == "go" & city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
	
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if bond_type == "go" & city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
*doesn't work as well without separate_debtservice_levy
	
**Vote requirement on GO unlim**
eststo clear
eststo: qui reghdfe offering_yield_tr vote_req if go_unlim == 1 ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	if go_unlim == 1 ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if go_unlim == 1 ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"
esttab using "$RESULTS/250114_city_yield_votereq_go_unlim.tex", replace t noconstant b(3) ///
	title("GO bond referenda requirements and offering yield") star(* .10 ** .05 *** .01) ///
	s(N r2_a yearFE monthFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year FE" "Month FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	label booktabs noobs nonotes 	
	
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if go_unlim == 1 & city_rev_vote == 0 ///
	, absorb(year month) vce(cluster state)
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if go_unlim == 1 & city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if go_unlim == 1 & city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
*is better with separate_debtservice_levy, but not quite significant in either case
	
**Vote requirement on GO lim**
eststo clear
eststo: qui reghdfe offering_yield_tr vote_req if go_lim == 1 ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	if go_lim == 1 ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if go_lim == 1 ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"
esttab using "$RESULTS/250114_city_yield_votereq_go_lim.tex", replace t noconstant b(3) ///
	title("GO bond referenda requirements and offering yield") star(* .10 ** .05 *** .01) ///
	s(N r2_a yearFE monthFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year FE" "Month FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	label booktabs noobs nonotes 	

reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if go_lim == 1 & city_rev_vote == 0 ///
	, absorb(year month) vce(cluster state)
	
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if go_lim == 1 & city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
	
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if go_lim == 1 & city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
*overall, yrmonth works well

**Vote requirement on Rev**
eststo clear
eststo: qui reghdfe offering_yield_tr vote_req if rev == 1 ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	if rev == 1 ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if rev == 1 ///
	, absorb(year month) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"
esttab using "$RESULTS/250114_city_yield_votereq_rev v2.tex", replace t noconstant b(3) ///
	title("Revenue bond referenda requirements and offering yield") star(* .10 ** .05 *** .01) ///
	s(N r2_a yearFE monthFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year FE" "Month FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	label booktabs noobs nonotes 		
	
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if rev == 1 ///
	, absorb(yrmonth) vce(cluster state)	
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if rev == 1 ///
	, absorb(yrmonth) vce(cluster state)
*these are not that different	

**When there's a GO vote requirement, are GO bonds less likely?**	
gen go_all = 1 if go_lim == 1 | go_unlim == 1
replace go_all = 0 if go_all == .
label var go_all "GO bond"

reg go_all city_go_vote, vce(cluster state)
*coeff=-0.247, t=-2.21, p=0.034, r2=0.058

reghdfe go_all city_go_vote ///
	, absorb(year month) vce(cluster state)
*coeff=-0.247, t=-2.27, p=0.029, r2=0.065
	
reghdfe go_all city_go_vote state_go_vote separate_debtservice_levy statutory_lien ///
	, absorb(year month) vce(cluster state)
*coeff=-0.090, t=-0.89, p=0.381, r2=0.136

reghdfe go_all city_go_vote state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(year month) vce(cluster state)
*coeff=-0.070, t=-0.70, p=0.488, r2=0.167

reghdfe go_all city_go_vote state_go_vote separate_debtservice_levy statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(year month) vce(cluster state)
*I worry there are more things that go into the GO choice that are issuer-specific that we aren't controlling for 

reghdfe go_all city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(year month) vce(cluster state)
*separate_debtservice_levy makes a big difference
*coeff=-0.183, t=-1.95, p=0.060, r2=0.142

reghdfe go_all city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth) vce(cluster state)
*coeff=-0.186, t=-2.03, p=0.050, r2=0.164

reghdfe go_unlim city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth) vce(cluster state)
*coeff=-0.122, t=-1.47, p=0.152, r2=0.244

reghdfe go_lim city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth) vce(cluster state)
*coeff=-0.064, t=-0.86, p=0.396, r2=0.270

*drop states with rev bond vote requirement
reghdfe go_all city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
*coeff=-0.160, t=-1.69, p=0.105, r2=0.177

*note that running reg with rev as outcome variable is same result, just flipped sign

tab state bond_type if city_go_vote == 1		
/*

           |       Bond type
     state |        go        rev |     Total
-----------+----------------------+----------
        AK |     1,517        129 |     1,646 
        AL |       125      1,340 |     1,465 
        AR |       195      2,186 |     2,381 
        AZ |     2,063      1,504 |     3,567 
        CA |     1,966      3,132 |     5,098 
        CO |       472      2,472 |     2,944 
        FL |     1,342      4,977 |     6,319 
        GA |       834        672 |     1,506 
        ID |       203        170 |       373 
        LA |     1,304      1,495 |     2,799 
        ME |     3,252         30 |     3,282 
        MI |    12,343      2,529 |    14,872 
        MO |     2,446      2,361 |     4,807 
        MT |       475        347 |       822 
        NC |     3,014      1,900 |     4,914 
        ND |       392        991 |     1,383 
        NE |     5,352      2,366 |     7,718 
        NM |       603      1,215 |     1,818 
        NV |       758        125 |       883 
        OH |     7,231      1,887 |     9,118 
        OK |     2,750        202 |     2,952 
        OR |     1,751      1,500 |     3,251 
        RI |     2,197         24 |     2,221 
        SD |        84        948 |     1,032 
        TX |    11,587     11,367 |    22,954 
        UT |       490      2,160 |     2,650 
        VT |       374        124 |       498 
        WA |     3,946      2,443 |     6,389 
        WV |        37        415 |       452 
        WY |        43         35 |        78 
-----------+----------------------+----------
     Total |    69,146     51,046 |   120,192 
*/

tab state bond_type if city_go_vote == 0
/*
           |       Bond type
     state |        go        rev |     Total
-----------+----------------------+----------
        IN |     2,417      4,613 |     7,030 
        KY |     1,307      1,164 |     2,471 
        MA |    19,569        334 |    19,903 
        MS |     2,692        700 |     3,392 
        NH |     2,442        348 |     2,790 
        NJ |    14,191        205 |    14,396 
        TN |     3,388      2,585 |     5,973 
-----------+----------------------+----------
     Total |    46,006      9,949 |    55,955 
*/			
	
	
	
	
**When there's a rev vote requirement, are rev bonds less likely?**	
reghdfe rev city_rev_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(year month) vce(cluster state)	
*weirdly, rev bonds are more likely. this could just be because there are few rev vote requirements
	
reghdfe rev city_rev_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth) vce(cluster state)		
	
	
reghdfe rev city_rev_vote state_go_vote separate_debtservice_levy statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(year month num_use_proceeds) vce(cluster state)	
	
	
tab state bond_type if city_rev_vote == 1	
/*
           |       Bond type
     state |        go        rev |     Total
-----------+----------------------+----------
        AR |       195      2,186 |     2,381 
        CA |     1,966      3,132 |     5,098 
        CO |       472      2,472 |     2,944 
        ND |       392        991 |     1,383 
        RI |     2,197         24 |     2,221 
        SD |        84        948 |     1,032 
        VT |       374        124 |       498 
-----------+----------------------+----------
     Total |     5,680      9,877 |    15,557 
*/	
tab state bond_type if city_rev_vote == 0
/*
          |       Bond type
     state |        go        rev |     Total
-----------+----------------------+----------
        AK |     1,517        129 |     1,646 
        DE |       155         49 |       204 
        FL |     1,342      4,977 |     6,319 
        GA |       834        672 |     1,506 
        IA |    12,763      3,184 |    15,947 
        IL |    12,933      5,199 |    18,132 
        IN |     2,417      4,613 |     7,030 
        KS |     9,330      2,756 |    12,086 
        KY |     1,307      1,164 |     2,471 
        LA |     1,304      1,495 |     2,799 
        MA |    19,569        334 |    19,903 
        MD |       947        559 |     1,506 
        ME |     3,252         30 |     3,282 
        MI |    12,343      2,529 |    14,872 
        MN |    26,567      9,318 |    35,885 
        MO |     2,446      2,361 |     4,807 
        MS |     2,692        700 |     3,392 
        MT |       475        347 |       822 
        NC |     3,014      1,900 |     4,914 
        NE |     5,352      2,366 |     7,718 
        NH |     2,442        348 |     2,790 
        NJ |    14,191        205 |    14,396 
        NM |       603      1,215 |     1,818 
        NV |       758        125 |       883 
        OH |     7,231      1,887 |     9,118 
        SC |       951        858 |     1,809 
        TN |     3,388      2,585 |     5,973 
        TX |    11,587     11,367 |    22,954 
        UT |       490      2,160 |     2,650 
        VA |     3,159        424 |     3,583 
        WA |     3,946      2,443 |     6,389 
        WV |        37        415 |       452 
        WY |        43         35 |        78 
-----------+----------------------+----------
     Total |   169,385     68,749 |   238,134 
*/
	
	
**bond purpose**
*most common are: GPPI (62%) (#14), WTR (18%) (#56), PSED (3%) (#42), ELEC (2.4%) (#10), CUTI (1.5%) (#8) (multiple public utilities), OREC (1.20%) (#31) (other recreation), GVPB (1.17%) (#15) (buildings)	
	
gen purpose_gppi = 1 if num_use_proceeds == 14
replace purpose_gppi = 0 if purpose_gppi == .
gen purpose_wtr = 1 if num_use_proceeds == 56
replace purpose_wtr = 0 if purpose_wtr == .
gen purpose_psed = 1 if num_use_proceeds == 42
replace purpose_psed = 0 if purpose_psed == .
gen purpose_elec = 1 if num_use_proceeds == 10
replace purpose_elec = 0 if purpose_elec == .
gen purpose_cuti = 1 if num_use_proceeds == 8
replace purpose_cuti = 0 if purpose_cuti == .
gen purpose_orec = 1 if num_use_proceeds == 31
replace purpose_orec = 0 if purpose_orec == .
gen purpose_gpvb = 1 if num_use_proceeds == 15
replace purpose_gpvb = 0 if purpose_gpvb == .

local temp gppi wtr psed elec cuti orec gpvb
foreach x of local temp{
	sum go_unlim go_lim rev if purpose_`x' == 1
}
/*
- gppi: unlim mean=0.76, lim mean=0.16, rev mean=0.06
- wtr: unlim mean=0.20, lim mean=0.05, rev mean=0.75
- psed: unlim mean=0.84, lim mean=0.08, rev mean=0.07
- elec: unlim mean=0.07, lim mean=0.01, rev mean=0.92
- cuti: unlim mean=0.08, lim mean=0.01, rev mean=0.91
- orec: unlim mean=0.59, lim mean=0.15, rev mean=0.26
- gpvb: unlim mean=0.56, lim mean=0.25, rev mean=0.19
*/

reghdfe purpose_gppi city_go_vote state_go_vote separate_debtservice_levy statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(year month) vce(cluster state)	

gegen yrmonth = group(year month)	
	
reghdfe purpose_gppi city_go_vote ///
	, absorb(year month) vce(cluster state)	
reghdfe purpose_gppi city_go_vote ///
	, absorb(yrmonth) vce(cluster state)
	
reghdfe purpose_gppi city_go_vote state_go_vote statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth) vce(cluster state)	
*coeff=-0.108, t=-1.87, p=0.070, r2=0.110
*note separate debt service levy matters here

reghdfe purpose_gppi city_go_vote state_go_vote statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
*coeff=-0.092, t=-1.73, p=0.098, r2=0.128

reghdfe purpose_psed city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth) vce(cluster state)
*coeff=-0.062, t=-1.58, p=0.123, r2=0.109

reghdfe purpose_psed city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///	
	, absorb(yrmonth) vce(cluster state)

reghdfe purpose_orec city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth) vce(cluster state)
*coeff=0.024, t=4.40, p=0.000, r2=0.039
*surprising this result is so strong; also holds with separate_debtservice_levy

reghdfe purpose_orec city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
*coeff=0.024, t=4.26, p=0.000, r2=0.045

reghdfe purpose_gpvb city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth) vce(cluster state)
*coeff=0.013, t=2.00, p=0.053, r2=0.032	
*interesting that this goes up

reghdfe purpose_gpvb city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
*coeff=0.015, t=2.07, p=0.050, r2=0.036	

reghdfe purpose_wtr city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth) vce(cluster state)
*coeff=0.021, t=0.45, p=0.654, r2=0.096
*no evidence of anything; with separate_debtservice_levy, coeff=-0.066 and p=0.195

reghdfe purpose_wtr city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)

reghdfe purpose_elec city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth) vce(cluster state)
*coeff=0.003, t=0.23, p=0.818, r2=0.037		

reghdfe purpose_elec city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
		
reghdfe purpose_cuti city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth) vce(cluster state)
*coeff=0.011, t=1.06, p=0.296, r2=0.045		

reghdfe purpose_cuti city_go_vote state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ultgo_allowed ltgo_allowed ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)	
*coeff=0.013, t=1.42, p=0.169, r2=0.052

*can look more into other purposes as well

local temp gppi wtr psed elec cuti orec gpvb
foreach x of local temp{
	reghdfe offering_yield_tr purpose_`x' ln_amount ln_maturity callable sinkable insured rated ///
	state_go_vote /*separate_debtservice_levy*/ statutory_lien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
}
*yields are higher for elec; lower for gppi, cuti
	
		
sum offering_yield_tr if purpose_gppi == 1
*mean=3.023
sum offering_yield_tr if purpose_psed == 1		
*mean=3.290
sum offering_yield_tr if purpose_orec == 1		
*mean=3.013
sum offering_yield_tr if purpose_gpvb == 1		
*mean=3.129
sum offering_yield_tr if purpose_wtr == 1		
*mean=3.292
sum offering_yield_tr if purpose_elec == 1		
*mean=3.334
sum offering_yield_tr if purpose_cuti == 1		
*mean=3.239
		
		
		
		
		
sum offering_yield_tr if city_go_vote == 1 & bond_type == "rev", d
*n=47,606, mean=3.36, median=3.55
sum offering_yield_tr if city_go_vote == 0 & bond_type == "go", d		
*n=54,444, mean=3.08, median=3.25
sum offering_yield_tr if city_go_vote == 0 & bond_type == "rev", d	
*n=12,199, mean=3.27, median=3.45

sum offering_yield_tr if city_rev_vote == 1 & bond_type == "go", d	
*n=5,780, mean=3.36, median=3.60
sum offering_yield_tr if city_rev_vote == 1 & bond_type == "rev", d
*n=9,697, mean=3.36, median=3.55
sum offering_yield_tr if city_rev_vote == 0 & bond_type == "go", d		
*n=162,664, mean=3.10, median=3.25
sum offering_yield_tr if city_rev_vote == 0 & bond_type == "rev", d	
*n=63,696, mean=3.34, median=3.55	
	
	
	
***Start with issue-level matched Mergent + MSRB + voting data for TX***
use "$TX/241121_txmerge_election_issuelevel.dta", clear

*gen truncated yield
winsor2 wavg_offering_yield, cuts(1 99) trim suffix(_tr)
sum wavg_offering_yield wavg_offering_yield_tr, d 
*raw: mean = 3.15, median = 3.02, 1% = 0.43, 99% = 6.88
*truncated: mean = 3.13, median = 3.02, 1% = 0.74, 99% = 6.25

*look at how different they are within GO or rev
sum wavg_offering_yield wavg_offering_yield_tr if vote_req == 1, d 
*raw: mean = 2.89, median = 2.82, 1% = 0.54, 99% = 5.28
*truncated: mean = 2.91, median = 2.83, 1% = 0.74, 99% = 5.28
sum wavg_offering_yield wavg_offering_yield_tr if vote_req == 0, d 
*raw: mean = 3.60, median = 3.65, 1% = 0.25, 99% = 8.80
*truncated: mean = 3.53, median = 3.65, 1% = 0.72, 99% = 6.68
*Rev bonds have more action in the tails, so truncating makes more of a difference

*How does yield vary with margin for GO, Rev? Look at cities first
*Shouldn't see anything with rev
reg wavg_offering_yield min_winmargin if vote_req == 1 & city == 1, vce(robust)
*coeff = 0.257, p = 0.317
reg wavg_offering_yield avg_winmargin if vote_req == 1 & city == 1, vce(robust)
*coeff = 0.607, p = 0.029
reg wavg_offering_yield wavg_winmargin if vote_req == 1 & city == 1, vce(robust)
*coeff = 0.493, p = 0.063

reg wavg_offering_yield min_winmargin if vote_req == 0 & city == 1, vce(robust)
*coeff = -0.609, p = 0.217
reg wavg_offering_yield avg_winmargin if vote_req == 0 & city == 1, vce(robust)
*coeff = -0.865, p = 0.155
reg wavg_offering_yield wavg_winmargin if vote_req == 0 & city == 1, vce(robust)
*coeff = -1.176, p = 0.044
*Weird that for revenue bonds, we kind of see what we would've expected to see with GO bonds
*Note R2 through all of these is super small, so can't interpret these much

*Try with truncated yield
reg wavg_offering_yield_tr min_winmargin if vote_req == 1 & city == 1, vce(robust)
*similar to non-truncated
reg wavg_offering_yield_tr avg_winmargin if vote_req == 1 & city == 1, vce(robust)
*similar to non-truncated
reg wavg_offering_yield_tr wavg_winmargin if vote_req == 1 & city == 1, vce(robust)
*similar to non-truncated

reg wavg_offering_yield_tr min_winmargin if vote_req == 0 & city == 1, vce(robust)
*coeff = -0.234, p = 0.217
reg wavg_offering_yield_tr avg_winmargin if vote_req == 0 & city == 1, vce(robust)
*coeff = -0.003, p = 0.996
reg wavg_offering_yield_tr wavg_winmargin if vote_req == 0 & city == 1, vce(robust)
*coeff = -0.274, p = 0.592

*So, the truncation makes a big difference for revenue bonds. While the coeff is negative, nothing is statistically significant


sum avg_winmargin wavg_winmargin, d
*avg: mean = 0.36 = median
*wavg: mean = 0.39, median = 0.38

*Add FEs while looking at GO bonds
*add time FE or fips FE
*gen county-year FE 
*Do with truncated yield
gegen countyyrFE = group(fips year_issue)
reghdfe wavg_offering_yield_tr wavg_winmargin if vote_req == 1 & city == 1 ///
	, absorb(year_issue) vce(cluster year_issue)
*coeff = -0.386, p = 0.008, adj R2 = 0.692, N = 476
reghdfe wavg_offering_yield_tr wavg_winmargin if vote_req == 1 & city == 1 ///
	, absorb(year_issue) vce(cluster seed_issuer)
*coeff = -0.386, p = 0.069, adj R2 = 0.692, N = 476
reghdfe wavg_offering_yield_tr wavg_winmargin if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = -0.476, p = 0.012, adj R2 = 0.708
reghdfe wavg_offering_yield_tr wavg_winmargin if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue fips) vce(cluster seed_issuer)
*coeff = -0.416, p = 0.032, adj R2 = 0.747, N = 454
*countyFE drops observations a bit
/*
reghdfe wavg_offering_yield_tr wavg_winmargin if vote_req == 1 & city == 1 ///
	, absorb(countyyrFE month_issue) vce(cluster seed_issuer)
*coeff = -0.475, p = 0.190, adj R2 = 0.658, N = 280
*seems like county-year FE is too strict. N drops a lot. There aren't too many issuances in a county-year
*/

*Bring in controls for GO bonds
*County-level demo controls
reghdfe wavg_offering_yield_tr wavg_winmargin pop gdp pers_inc if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = -0.408, p = 0.038, adj R2 = 0.668
*Bond controls
reghdfe wavg_offering_yield_tr wavg_winmargin log_issue_size log_max_maturity ///
	if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = -0.269, p = 0.009, adj R2 = 0.869
reghdfe wavg_offering_yield_tr wavg_winmargin log_issue_size log_max_maturity ///
	wavg_callable if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = -0.155, p = 0.122, adj R2 = 0.892
*it's callable that makes a huge difference
*can we make callable an indicator
gen callable_dummy = 1 if wavg_callable > 0
replace callable_dummy = 0 if callable_dummy == .
reghdfe wavg_offering_yield_tr wavg_winmargin log_issue_size log_max_maturity ///
	callable_dummy if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = -0.285, p = 0.007, adj R2 = 0.869
sum callable_dummy, d
*mean = 0.902
*Interesting that Farrell et al use the callable dummy
*Do dummy for insured and sinkable as well
gen insured_dummy = 1 if wavg_insured > 0
replace insured_dummy = 0 if insured_dummy == .
gen sinkable_dummy = 1 if wavg_sinkable > 0
replace sinkable_dummy = 0 if sinkable_dummy == .

reghdfe wavg_offering_yield_tr wavg_winmargin log_issue_size log_max_maturity ///
	wavg_callable wavg_insured wavg_sinkable rated_dummy if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = -0.152, p = 0.135, adj R2 = 0.894
*Both county-level demo and bond controls:
reghdfe wavg_offering_yield_tr wavg_winmargin log_issue_size log_max_maturity ///
	wavg_callable wavg_insured wavg_sinkable rated_dummy pop gdp pers_inc ///
	if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = -0.171, p = 0.140, adj R2 = 0.877

*Look at yield for rev bonds
reghdfe wavg_offering_yield_tr wavg_winmargin if vote_req == 0 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = -1.135, p = 0.321, adj R2 = 0.211, N = 320
reghdfe wavg_offering_yield_tr wavg_winmargin if vote_req == 0 & city == 1 ///
	, absorb(year_issue month_issue fips) vce(cluster seed_issuer)
*coeff = -0.844, p = 0.478, adj R2 = 0.384, N = 313
reghdfe wavg_offering_yield_tr wavg_winmargin log_issue_size log_max_maturity ///
	wavg_callable wavg_insured wavg_sinkable rated_dummy pop gdp pers_inc ///
	if vote_req == 0 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = -0.251, p = 0.563, adj R2 = 0.726, N = 310

*Look at MSRB outcomes with the yearFE, monthFE for GO bonds
reghdfe markup wavg_winmargin if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = -19.055, p = 0.099, adj R2 = 0.183
reghdfe markup_retail wavg_winmargin if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = -18.024, p = 0.176, adj R2 = 0.216
reghdfe markup_inst wavg_winmargin if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = -21.787, p = 0.034, adj R2 = 0.141
reghdfe yield_volatility wavg_winmargin if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = 0.057, p = 0.289, adj R2 = 0.423

*Look at MSRB outcomes with the yearFE, monthFE for rev bonds
reghdfe markup wavg_winmargin if vote_req == 0 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = -4.196, p = 0.819, adj R2 = 0.201
reghdfe markup_retail wavg_winmargin if vote_req == 0 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = 8.755, p = 0.666, adj R2 = 0.237
reghdfe markup_inst wavg_winmargin if vote_req == 0 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = -16.755, p = 0.320, adj R2 = 0.183
reghdfe yield_volatility wavg_winmargin if vote_req == 0 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
*coeff = 0.293, p = 0.129, adj R2 = 0.305

***Output***
*Label vars for output
label var wavg_winmargin "Win margin (wavg)"
label var min_winmargin "Win margin (min)"
label var wavg_offering_yield "Yield (raw)"
label var wavg_offering_yield_tr "Yield (trim)"
label var log_issue_size "log(Size)"
label var log_max_maturity "log(Maturity)"
label var callable_dummy "Callable (I)"
label var sinkable_dummy "Sinkable (I)"
label var insured_dummy "Insured (I)"
label var rated_dummy "Rated (I)"
label var wavg_callable "Callable (wavg)"
label var wavg_sinkable "Sinkable (wavg)"
label var wavg_insured "Insured (wavg)"
label var pop "Pop."
label var gdp "GDP"
label var pers_inc "Pers. income"
label var markup "Markup"
label var markup_retail "Markup (retail)"
label var markup_inst "Markup (inst)"
label var yield_volatility "Yield vol"

***Summary stats by city GO, city Rev, county GO, county Rev***
eststo clear
eststo: estpost sum wavg_winmargin min_winmargin wavg_offering_yield wavg_offering_yield_tr ///
	log_issue_size log_max_maturity	callable_dummy wavg_callable sinkable_dummy wavg_sinkable ///
	insured_dummy wavg_insured rated_dummy markup markup_inst yield_volatility ///
	if city == 1 & vote_req == 1, d
esttab using "$DESCRIPT\241121_tx_sumstats_city_go.tex", replace ///
	title("Summary statistics (city GO)") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle

eststo clear
eststo: estpost sum wavg_offering_yield wavg_offering_yield_tr ///
	log_issue_size log_max_maturity	callable_dummy wavg_callable sinkable_dummy wavg_sinkable ///
	insured_dummy wavg_insured rated_dummy markup markup_inst yield_volatility ///
	if city == 1 & vote_req == 0, d
esttab using "$DESCRIPT\241121_tx_sumstats_city_rev.tex", replace ///
	title("Summary statistics (city rev)") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum noobs compress nomtitle
	
eststo clear
eststo: estpost sum wavg_winmargin min_winmargin wavg_offering_yield wavg_offering_yield_tr ///
	log_issue_size log_max_maturity	callable_dummy wavg_callable sinkable_dummy wavg_sinkable ///
	insured_dummy wavg_insured rated_dummy markup markup_inst yield_volatility ///
	if county == 1 & vote_req == 1, d	
esttab using "$DESCRIPT\241121_tx_sumstats_county_go.tex", replace ///
	title("Summary statistics (county GO)") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum noobs compress nomtitle

eststo clear
eststo: estpost sum wavg_offering_yield wavg_offering_yield_tr ///
	log_issue_size log_max_maturity	callable_dummy wavg_callable sinkable_dummy wavg_sinkable ///
	insured_dummy wavg_insured rated_dummy markup markup_inst yield_volatility ///
	if county == 1 & vote_req == 0, d	
esttab using "$DESCRIPT\241121_tx_sumstats_county_rev.tex", replace ///
	title("Summary statistics (county rev)") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum noobs compress nomtitle

***Regressions***
**Table: Build specification for city GO**
eststo clear
/*eststo: qui reg wavg_offering_yield wavg_winmargin if vote_req == 1 & city == 1, vce(robust)
	estadd local yearFE "No"
	estadd local monthFE "No"
	estadd local countyFE "No"
	estadd local SE "Robust"
*/
eststo: qui reg wavg_offering_yield_tr wavg_winmargin if vote_req == 1 & city == 1, vce(robust)
	estadd local yearFE "No"
	estadd local monthFE "No"
	estadd local countyFE "No"
	estadd local SE "Robust"
eststo: qui reghdfe wavg_offering_yield_tr wavg_winmargin if vote_req == 1 & city == 1 ///
	, absorb(year_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "No"
	estadd local countyFE "No"
	estadd local SE "Issuer"
eststo: qui reghdfe wavg_offering_yield_tr wavg_winmargin if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local countyFE "No"
	estadd local SE "Issuer"
eststo: qui reghdfe wavg_offering_yield_tr wavg_winmargin if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue fips) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local countyFE "Yes"
	estadd local SE "Issuer"
eststo: qui reghdfe wavg_offering_yield_tr wavg_winmargin pop gdp pers_inc if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local countyFE "No"
	estadd local SE "Issuer"
eststo: qui reghdfe wavg_offering_yield_tr wavg_winmargin log_issue_size log_max_maturity ///
	wavg_callable wavg_sinkable wavg_insured rated_dummy if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local countyFE "No"
	estadd local SE "Issuer"
eststo: qui reghdfe wavg_offering_yield_tr wavg_winmargin log_issue_size log_max_maturity ///
	callable_dummy sinkable_dummy insured_dummy rated_dummy if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local countyFE "No"
	estadd local SE "Issuer"
eststo: qui reghdfe wavg_offering_yield_tr wavg_winmargin log_issue_size log_max_maturity ///
	callable_dummy sinkable_dummy insured_dummy rated_dummy pop gdp pers_inc ///
	if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local countyFE "No"
	estadd local SE "Issuer"
esttab using "$RESULTS/241121_tx_city_go.tex", replace se noconstant b(3) ///
	title("Win margin and offering yield (city GO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yearFE monthFE countyFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year FE" "Month FE" "County FE" "Cluster")) ///
	label booktabs noobs nonotes 
	
**Table: Show a few preferred specifications for city rev**
eststo clear
eststo: qui reg wavg_offering_yield wavg_winmargin if vote_req == 0 & city == 1, vce(robust)
	estadd local yearFE "No"
	estadd local monthFE "No"
	estadd local countyFE "No"
	estadd local SE "Robust"
eststo: qui reg wavg_offering_yield_tr wavg_winmargin if vote_req == 0 & city == 1, vce(robust)
	estadd local yearFE "No"
	estadd local monthFE "No"
	estadd local countyFE "No"
	estadd local SE "Robust"
eststo: qui reghdfe wavg_offering_yield_tr wavg_winmargin if vote_req == 0 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local countyFE "No"
	estadd local SE "Issuer"
eststo: qui reghdfe wavg_offering_yield_tr wavg_winmargin if vote_req == 0 & city == 1 ///
	, absorb(year_issue month_issue fips) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local countyFE "Yes"
	estadd local SE "Issuer"
eststo: qui reghdfe wavg_offering_yield_tr wavg_winmargin  pop gdp pers_inc ///
	log_issue_size log_max_maturity callable_dummy sinkable_dummy insured_dummy rated_dummy ///
	if vote_req == 0 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local countyFE "No"
	estadd local SE "Issuer"
esttab using "$RESULTS/241121_tx_city_rev.tex", replace se noconstant b(3) ///
	title("Win margin and offering yield (city rev)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yearFE monthFE countyFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year FE" "Month FE" "County FE" "Cluster")) ///
	label booktabs noobs nonotes 
	
**Table: Show a few preferred specifications for county GO and revenue**
*Actually there are only ~23 county rev bonds, so no variation. Only show GO
eststo clear
eststo: qui reghdfe wavg_offering_yield_tr wavg_winmargin if vote_req == 1 & county == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local countyFE "No"
	estadd local SE "Issuer"
eststo: qui reghdfe wavg_offering_yield_tr wavg_winmargin if vote_req == 1 & county == 1  ///
	, absorb(year_issue month_issue fips) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local countyFE "Yes"
	estadd local SE "Issuer"
eststo: qui reghdfe wavg_offering_yield_tr wavg_winmargin  pop gdp pers_inc ///
	log_issue_size log_max_maturity callable_dummy sinkable_dummy insured_dummy rated_dummy ///
	if vote_req == 1 & county == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local countyFE "No"
	estadd local SE "Issuer"
esttab using "$RESULTS/241121_tx_county_go.tex", replace se noconstant b(3) ///
	title("Win margin and offering yield (county GO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yearFE monthFE countyFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year FE" "Month FE" "County FE" "Cluster")) ///
	label booktabs noobs nonotes 
	
**Table: Look at markup for city GO**
eststo clear
eststo: qui reghdfe markup wavg_winmargin pop gdp pers_inc log_issue_size ///
	log_max_maturity callable_dummy sinkable_dummy insured_dummy rated_dummy ///
	if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local SE "Issuer"
eststo: qui reghdfe markup_inst wavg_winmargin pop gdp pers_inc log_issue_size ///
	log_max_maturity callable_dummy sinkable_dummy insured_dummy rated_dummy ///
	if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local SE "Issuer"
eststo: qui reghdfe markup_retail wavg_winmargin pop gdp pers_inc log_issue_size ///
	log_max_maturity callable_dummy sinkable_dummy insured_dummy rated_dummy ///
	if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local SE "Issuer"
esttab using "$RESULTS/241121_tx_city_go_markup.tex", replace se noconstant b(3) ///
	title("Win margin and markup (city GO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yearFE monthFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year FE" "Month FE" "Cluster")) ///
	label booktabs noobs nonotes 

*City Rev
eststo clear
eststo: qui reghdfe markup wavg_winmargin pop gdp pers_inc log_issue_size ///
	log_max_maturity callable_dummy sinkable_dummy insured_dummy rated_dummy ///
	if vote_req == 0 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local SE "Issuer"
eststo: qui reghdfe markup_inst wavg_winmargin pop gdp pers_inc log_issue_size ///
	log_max_maturity callable_dummy sinkable_dummy insured_dummy rated_dummy ///
	if vote_req == 0 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local SE "Issuer"
eststo: qui reghdfe markup_retail wavg_winmargin pop gdp pers_inc log_issue_size ///
	log_max_maturity callable_dummy sinkable_dummy insured_dummy rated_dummy ///
	if vote_req == 0 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local SE "Issuer"
esttab using "$RESULTS/241121_tx_city_rev_markup.tex", replace se noconstant b(3) ///
	title("Win margin and markup (city rev)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yearFE monthFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year FE" "Month FE" "Cluster")) ///
	label booktabs noobs nonotes 

**Table: Look at yield volatility for city GO, rev**
eststo clear
eststo: qui reghdfe yield_volatility wavg_winmargin pop gdp pers_inc log_issue_size ///
	log_max_maturity callable_dummy sinkable_dummy insured_dummy rated_dummy ///
	if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local bondtype "GO"
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local SE "Issuer"

eststo: qui reghdfe yield_volatility wavg_winmargin pop gdp pers_inc log_issue_size ///
	log_max_maturity callable_dummy sinkable_dummy insured_dummy rated_dummy ///
	if vote_req == 0 & city == 1 ///
	, absorb(year_issue month_issue) vce(cluster seed_issuer)
	estadd local bondtype "Revenue"
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local SE "Issuer"
	
esttab using "$RESULTS/241121_tx_city_yieldvol.tex", replace se noconstant b(3) ///
	title("Win margin and yield volatility (city)") star(* .10 ** .05 *** .01) ///
	s(N r2_a bondtype yearFE monthFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Bond type" "Year FE" "Month FE" "Cluster")) ///
	label booktabs noobs nonotes 