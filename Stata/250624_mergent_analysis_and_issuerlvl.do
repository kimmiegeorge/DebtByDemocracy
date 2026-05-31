**************************
*Voting on bonds         *
*State law cleaning      *
*Last updated: 06/24/25  *
**************************

***Goals***
/*
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

**Explore**
*Explore dropping full faith and credit pledge
*Explore a combo of separate debt service levy; pledged revenues held separately; statutory lien

**# Bookmark #1

*Bond-level: UTGO yield test*
use "$MERGENT\Clean\250624_city_cusiplevel_statereq_purpose.dta", clear

*Original specification in outputted table
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	state_go_vote state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.106, p=0.082

*Drop full faith and credit
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	state_go_vote state_ltgo_allowed state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.095, p=0.117

*Drop LTGO allowed
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	state_go_vote state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.074, p=0.194

*Bring in GLM proactive, drop full faith and credit
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	state_go_vote glm_proactive state_ltgo_allowed state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.095, p=0.118

*With GLM proactive, drop fidelity vars
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	/*state_sep_debtservice_levy state_sep_pledgerev state_statutorylien*/ ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.034, p=0.546
*Cluster by issue
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	/*state_sep_debtservice_levy state_sep_pledgerev state_statutorylien*/ ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
*coeff = -0.034, p=0.012

	
*Make an index for state_sep_debtservice_levy, state_sep_pledgerev, state_statutorylien
gen temp1 = state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien
tab temp1
  /* 
   temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      1,506        0.46        0.46
          1 |    118,054       35.97       36.43
          2 |     45,605       13.90       50.32
          3 |    127,233       38.77       89.09
          4 |     35,803       10.91      100.00
------------+-----------------------------------
      Total |    328,201      100.00
*/

*Normalize
gen temp1_normal = 0 if temp1 == 0
replace temp1_normal = 0.25 if temp1 == 1
replace temp1_normal = 0.5 if temp1 == 2
replace temp1_normal = 0.75 if temp1 == 3
replace temp1_normal = 1 if temp1 == 4

pwcorr glm_proactive city_go_vote state_go_vote temp1_normal if city_rev_vote == 0 , star(0.01)
/*
             | glm_pr~e city_g~e state~te temp1_~l
-------------+------------------------------------
glm_proact~e |   1.0000 
city_go_vote |   0.1610*  1.0000 
state_go_v~e |   0.2575*  0.5549*  1.0000 
temp1_normal |   0.0086*  0.3766* -0.1723*  1.0000 
*/

pwcorr glm_proactive state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien  if city_rev_vote == 0 , star(0.01) 
/*
             | glm_pr~e state_~h state_~y state_~v state_~n
-------------+---------------------------------------------
glm_proact~e |   1.0000 
state_full~h |   0.2194*  1.0000 
state_sep_~y |  -0.1669* -0.2606*  1.0000 
state_sep_~v |  -0.0499* -0.0513*  0.2735*  1.0000 
state_stat~n |   0.0329* -0.1607*  0.3801*  0.1260*  1.0000 
*/

*Include population, drop per capita personal income
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	state_go_vote glm_proactive state_ltgo_allowed temp2_normal ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.094, p=0.113
*Cluster by issue
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	state_go_vote glm_proactive state_ltgo_allowed temp2_normal ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
*coeff = -0.094, p=0

*The thing with the indices is that they don't reflect which measures are stronger. E.g., the statutory lien is really strict whereas the full faith and credit pledge doesn't have much teeth

*Go back to no index
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
tab state_sep_debtservice_levy state_sep_pledgerev 
/*
Debt-servi | Fund for pledged prop
   ce prop |          tax
       tax |         0          1 |     Total
-----------+----------------------+----------
         0 |    99,627     10,253 |   109,880 
         1 |    92,550    125,771 |   218,321 
-----------+----------------------+----------
     Total |   192,177    136,024 |   328,201 
*/
*Almost never happens that there's a separate fund and NOT a separate levy for debt service
*Make indicator for either of these
gen state_sep_levyfund = 1 if state_sep_debtservice_levy == 1
replace state_sep_levyfund = 1 if state_sep_levyfund == . & state_sep_pledgerev == 1

reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith /*state_sep_levyfund*/ state_statutorylien ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*weirdly, state_sep_levyfund is omitted and p-value goes to 0.389

tab state_sep_debtservice_levy state_statutorylien
*almost never have statutory lien without debt service levy

reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	ln_gdp ln_pop ln_pers_inc ln_emp /// 
	state_go_vote /*glm_proactive*/ state_ltgo_allowed ///
	temp2_normal /*state_fullfaith /*state_sep_levyfund*/ state_statutorylien */ ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.094, p=0.115
sum temp2, d

reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	ln_gdp ln_pop ln_pers_inc ln_emp /// 
	state_go_vote glm_proactive state_ltgo_allowed ///
	temp2_normal /*state_fullfaith /*state_sep_levyfund*/ state_statutorylien */ ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.094, p=0.113

reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	ln_gdp ln_pop ln_pers_inc ln_emp /// 
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_statutorylien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.109, p=0.072

reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	ln_gdp ln_pop ln_pers_inc ln_emp /// 
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_pledgerev state_statutorylien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.071, p=0.258

sum state_fullfaith
*most common, avg = 0.817
sum state_sep_debtservice_levy
*more common, avg = 0.665
sum state_sep_pledgerev 
*less common, avg = 0.414
sum state_statutorylien
*least common, avg = 0.340

reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	ln_gdp ln_pop ln_pers_inc ln_emp /// 
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.096, p=0.096

reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	ln_gdp ln_pop ln_pers_inc ln_emp /// 
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_sep_debtservice_levy state_sep_pledgerev ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = 0.086, p=0.135

*gen avg of state_sep_debtservice_levy and state_sep_pledgerev
drop state_sep_levyfund
gen state_sep_levyfund = (state_sep_debtservice_levy + state_sep_pledgerev) / 2

reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	ln_gdp ln_pop ln_pers_inc ln_emp /// 
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_levyfund state_statutorylien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.093, p=0.115

pwcorr offering_yield_tr city_go_vote state_go_vote glm_proactive state_ltgo_allowed if city_rev_vote == 0 & go_unlim == 1 , star(0.01)
/*
             | offeri~r city_g~e state~te glm_pr~e s~ltgo~d
-------------+---------------------------------------------
offering_y~r |   1.0000 
city_go_vote |   0.0848*  1.0000 
state_go_v~e |   0.0540*  0.5841*  1.0000 
glm_proact~e |   0.0750*  0.0187*  0.4449*  1.0000 
state_ltgo~d |   0.1348*  0.5707*  0.2587* -0.0771*  1.0000 
*/

pwcorr offering_yield_tr state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien if city_rev_vote == 0 & go_unlim == 1 , star(0.01)
/*
             | offeri~r state_~h state_~y state_~v state_~n
-------------+---------------------------------------------
offering_y~r |   1.0000 
state_full~h |   0.0244*  1.0000 
state_sep_~y |  -0.0360* -0.2329*  1.0000 
state_sep_~v |   0.0157*  0.1815*  0.2475*  1.0000 
state_stat~n |   0.0240*  0.1178*  0.3703* -0.1600*  1.0000 
*/

*gen indicator for both statutory lien and separate fund for pledged revenues
gen sepfund_statlien = 1 if state_sep_pledgerev == 1 & state_statutorylien == 1
replace sepfund_statlien = 0 if sepfund_statlien == .

*Reg without full faith or debt service levy, just this combined one
*cluster by state
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	/*state_fullfaith state_sep_debtservice_levy*/ sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.058, p=0.355
*cluster by issue
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	/*state_fullfaith state_sep_debtservice_levy*/ sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
*coeff = -0.058, p=0
*Include separate debt service levy as well
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	/*state_fullfaith*/ state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.093, p=0.116
*cluster by issue
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	/*state_fullfaith*/ state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
*coeff = -0.093, p=0

*Include full faith
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.105, p=0.079

reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith /*state_sep_debtservice_levy*/ sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.064, p=0.314

*Try making an index out of these two
gen temp2 = 1 if state_sep_debtservice_levy == 1 & sepfund_statlien == 1
replace temp2 = 0.5 if temp2 == . & state_sep_debtservice_levy == 1 | sepfund_statlien == 1
replace temp2 = 0 if temp2 == . & state_sep_debtservice_levy == 0 & sepfund_statlien == 0

*make index out of fullfaith, sep debt service, sepfund_statlien
gen temp3 = state_fullfaith +state_sep_debtservice_levy +sepfund_statlien
tab temp3
gen temp3_normal = 0 if temp3 == 0
replace temp3_normal = 0.33 if temp3 == 1
replace temp3_normal = 0.67 if temp3 == 2
replace temp3_normal = 1 if temp3 == 3

*Use index that includes full faith and combo sepfund_statlien
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	temp3_normal ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.103, p=0.088
*NOTE THIS FOR LATER OUTPUT

*Just use this index, cluster by state
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	temp2 ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
*coeff = -0.081, p=0.149
*similar as without index

reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	temp2 ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
*coeff = -0.081, p=0


*Output for Kimmie*
label var glm_proactive "State Proactive"
label var temp1_normal "Fidelity Index"
label var sepfund_statlien "PledgedFund + StatLien"
label var temp2 "(PledgedFund + StatLien) + SepLevy Index"
label var state_sep_debtservice_levy "SepLevy"
global countydemo ln_gdp ln_pop ln_pers_inc ln_emp

*Output, state clustering
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
*Include sepfund_statlien, cluster by state
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
*Include sepfund_statlien and sep debt service levy, cluster by state
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	sepfund_statlien state_sep_debtservice_levy ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
*Include sepfund_statlien and sep debt service levy as index, cluster by state
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	temp2 ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250625_yield_UTGO_statecontrols_v2_stateclus.tex", replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield (cluster by state)") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $countydemo state_go_vote glm_proactive state_ltgo_allowed)	

	
*Output all of these, clustered by issue
eststo clear
*Exclude fidelity vars, cluster by issue
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*Include sepfund_statlien, cluster by issue
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*Include sepfund_statlien + debt service levy, cluster by issue
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	sepfund_statlien state_sep_debtservice_levy ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*Include sepfund_statlien and sep debt service levy as index, cluster by issue
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	temp2 ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
esttab using "$RESULTS/250625_yield_UTGO_statecontrols_v2_issueclus.tex", replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield (cluster by issue)") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $countydemo state_go_vote glm_proactive state_ltgo_allowed)	
	

/*
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
*Exclude fidelity vars, cluster by issue
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*Fidelity index, state cluster
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed temp1_normal ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
*Fidelity index, issue cluster
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed temp1_normal ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*All fidelity vars, state cluster
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
*Exclude statutory lien, state cluster
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev /*state_statutorylien*/ ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250625_yield_UTGO_statecontrols.tex", replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $countydemo state_go_vote glm_proactive state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien temp1_normal)
*/


**# Bookmark #2
**Explore issuer-level**
use "$MERGENT\Clean\250625_city_issuerlevel.dta", clear

**# Bookmark #3
*Look at comparison between benchmark and UTGO+LTGO states (excluding UTGO only)

*Try regressions
reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other ln_city_debt if insample_allgo == 1, vce(cluster state)
*coeff = 0.016, p=0.097

reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other ln_city_debt ///
	state_go_vote ///
	if insample_allgo == 1, vce(cluster state)
*coeff = 0.138, p=0.290

reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other ln_city_debt ///
	state_go_vote glm_proactive ///
	if insample_allgo == 1, vce(cluster state)
*coeff = 0.084, p=0.518

reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other ln_city_debt ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	if insample_allgo == 1, vce(cluster state)
*coeff = 0.099, p=0.507

reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other ln_city_debt ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy  ///
	if insample_allgo == 1, vce(cluster state)
*coeff = 0.040, p=0.792

reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other ln_city_debt ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_statutorylien ///
	if insample_allgo == 1, vce(cluster state)
*coeff = -0.026, p=0.868

reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other ln_city_debt ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev /*state_statutorylien*/ ///
	if insample_allgo == 1, vce(cluster state)
*coeff = 0.031, p=0.845

*make index
gen temp1 = state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien
tab temp1
/*
      temp1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |         17        0.28        0.28
          1 |      2,131       35.23       35.51
          2 |        951       15.72       51.23
          3 |      2,182       36.07       87.30
          4 |        768       12.70      100.00
------------+-----------------------------------
      Total |      6,049      100.00
*/

*Normalize
gen temp1_normal = 0 if temp1 == 0
replace temp1_normal = 0.25 if temp1 == 1
replace temp1_normal = 0.5 if temp1 == 2
replace temp1_normal = 0.75 if temp1 == 3
replace temp1_normal = 1 if temp1 == 4

*Make combo for sep fund and statlien
gen sepfund_statlien = 1 if state_sep_pledgerev == 1 & state_statutorylien == 1
replace sepfund_statlien = 0 if sepfund_statlien == .
*make index out of fullfaith, sep debt service, sepfund_statlien
gen temp3 = state_fullfaith +state_sep_debtservice_levy +sepfund_statlien
tab temp3
gen temp3_normal = 0 if temp3 == 0
replace temp3_normal = 0.33 if temp3 == 1
replace temp3_normal = 0.67 if temp3 == 2
replace temp3_normal = 1 if temp3 == 3

*Try reg
reg frac_rev city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed state_fullfaith /*state_sep_debtservice_levy*/ sepfund_statlien ///
	if insample_allgo == 1, vce(cluster state)



*Try reg with index
reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other ln_city_debt ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	temp1_normal ///
	if insample_allgo == 1, vce(cluster state)
*coeff = 0.017, p=0.918
reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other ln_city_debt ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	temp1_normal ///
	if insample_allgo == 1, vce(cluster fips)
*coeff = 0.017, p=0.668
*cluster by issuer
reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other ln_city_debt ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	temp1_normal ///
	if insample_allgo == 1, vce(cluster seed_issuer_id)
*coeff = 0.017, p=0.552
*cluster by issuer, exclude issuer's debt
reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other /*ln_city_debt*/ ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	temp1_normal ///
	if insample_allgo == 1, vce(cluster seed_issuer_id)
*coeff = 0.040, p=0.168
*cluster by county, exclude issuer's debt
reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other /*ln_city_debt*/ ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	temp1_normal ///
	if insample_allgo == 1, vce(cluster fips)
*coeff = 0.040, p=0.315

*Exclude issuer's debt, exclude separate fund for pledged rev 
reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other /*ln_city_debt */ ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy /*state_sep_pledgerev*/ /*state_statutorylien*/ ///
	if insample_allgo == 1, vce(cluster fips)
*coeff = 0.070, p=0.067
reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other /*ln_city_debt */ ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy /*state_sep_pledgerev*/ state_statutorylien ///
	if insample_allgo == 1, vce(cluster fips)
*coeff = 0.004, p=0.925

reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other /*ln_city_debt */ ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev /*state_statutorylien*/ ///
	if insample_allgo == 1, vce(cluster fips)
*coeff = 0.062, p=0.125

*Exclude all fidelity variables
reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other /*ln_city_debt */ ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	/*state_fullfaith state_sep_debtservice_levy state_sep_pledgerev /*state_statutorylien*/ */ ///
	if insample_allgo == 1, vce(cluster fips)
*coeff = 0.113, p=0.002

*Cluster by state
reg frac_rev city_go_vote ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	ln_county_debt_other /*ln_city_debt */ ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	/*state_fullfaith state_sep_debtservice_levy state_sep_pledgerev /*state_statutorylien*/ */ ///
	if insample_allgo == 1, vce(cluster state)
*coeff = 0.113, p=0.443


	
pwcorr glm_proactive city_go_vote temp1_normal state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien, star(0.01)
/*
             | glm_pr~e city_g~e temp1_~l state_~h state_~y state_~v state_~n
-------------+---------------------------------------------------------------
glm_proact~e |   1.0000 
city_go_vote |   0.0016   1.0000 
temp1_normal |  -0.2839*  0.4207*  1.0000 
state_full~h |   0.2835* -0.1724*  0.1711*  1.0000 
state_sep_~y |  -0.4764*  0.5514*  0.6958* -0.2856*  1.0000 
state_sep_~v |  -0.2787*  0.1847*  0.7682* -0.0026   0.4423*  1.0000 
state_stat~n |  -0.1217*  0.4243*  0.6812* -0.1283*  0.3887*  0.2872*  1.0000 
*/
*proactive: not corr with city_go_vote, pos corr with full faith, neg corr with separate funds and statutory lien

*Output table for benchmark vs. UTGO+LTGO*
*Show: reg without fidelity vars clustered by county and state; show fidelity vars but exclude state_sep_pledgerev and statutory lien; exclude pledged rev only

*label vars for output*
label var glm_proactive "State Proactive"
label var temp1_normal "Fidelity Index (All)"
label var sepfund_statlien "PledgedFund + StatLien"
label var temp3_normal "Fidelity Index (Adj)"
label var state_sep_debtservice_levy "SepLevy"

global countydemo ln_gdp ln_pop ln_pers_inc ln_emp 

*Regression: benchmark vs. all GO
eststo clear
*Reg without fidelity vars clustered or county and state
eststo: qui reg frac_rev city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"	
eststo: qui reg frac_rev city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	if insample_allgo == 1, vce(cluster state)
	estadd local SE "State"	
*Include fidelity index
eststo: qui reg frac_rev city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed temp1_normal ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
*Include sepfund_statlien only
eststo: qui reg frac_rev city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed sepfund_statlien ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
*Include debt service levy + sepfund_statlien only
eststo: qui reg frac_rev city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed sepfund_statlien state_sep_debtservice_levy ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
*Include full faith + debt service levy + sepfund_statlien as index
eststo: qui reg frac_rev city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed sepfund_statlien state_sep_debtservice_levy ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
*Include all fidelity vars
eststo: qui reg frac_rev city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
esttab using "$RESULTS/250625_allgo_fracrev.tex", replace t noconstant b(3) ///
	title("Revenue debt: Only compare control states with all GO only states (i.e, drop OH, MI, WA) ") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes ///
	order(city_go_vote $countydemo ln_county_debt_other state_go_vote glm_proactive state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien temp1_normal)
	
**Output this table for the benchmark vs. UTGO vote only states**	

gen insample_utgo_only = 1 if control == 1 | utgo_only == 1
replace insample_utgo_only = 0 if insample_utgo_only == .

*Regression: benchmark vs. UTGO only vote
eststo clear
*Reg without fidelity vars clustered or county and state
eststo: qui reg frac_ltgo city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"	
eststo: qui reg frac_ltgo city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	if insample_utgo_only == 1, vce(cluster state)
	estadd local SE "State"	
*Include fidelity index
eststo: qui reg frac_ltgo city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed temp1_normal ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
*Include fidelity vars but exclude stat lien
eststo: qui reg frac_ltgo city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev /*state_statutorylien*/ ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
*Include fidelity vars but exclude fund for pledged prop tax
eststo: qui reg frac_ltgo city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy /*state_sep_pledgerev*/ state_statutorylien ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
*Include all fidelity vars
eststo: qui reg frac_ltgo city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
esttab using "$RESULTS/250625_utgoonly_fracltgo.tex", replace t noconstant b(3) ///
	title("LTGO debt: Only compare control states with UTGO-only vote states (OH, MI, WA) ") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes ///
	order(city_go_vote $countydemo ln_county_debt_other state_go_vote glm_proactive state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien temp1_normal)
	
