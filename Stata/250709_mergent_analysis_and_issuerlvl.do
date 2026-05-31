**************************
*Voting on bonds         *
*Issuer-level analysis   *
*Last updated: 07/07/25  *
**************************

***Goals***
/*
- Issuer-level tests
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

**Start with main city file with yield spreads**
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

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

pwcorr city_go_vote glm_proactive state_ltgo_allowed state_go_vote if city_rev_vote == 0 & go_unlim == 1, star(0.01)
/*
             | city_g~e glm_pr~e s~ltgo~d state~te
-------------+------------------------------------
city_go_vote |   1.0000 
glm_proact~e |   0.0187*  1.0000 
state_ltgo~d |   0.5707* -0.0771*  1.0000 
state_go_v~e |   0.5841*  0.4449*  0.2587*  1.0000 
*/

**Output versions with state clustering**
*Outcome var = offering yield*
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
	
**Output versions with issue clustering**
eststo clear
*Exclude fidelity vars
eststo: qui reghdfe offering_yield_tr city_go_vote ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo /*state_go_vote glm_proactive state_ltgo_allowed*/ ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*Include index
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo glm_proactive state_ltgo_allowed state_go_vote  ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
esttab using "$RESULTS/250707_yield_UTGO_issueclus.tex", ///
	replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield") ///
	star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $countydemo glm_proactive state_ltgo_allowed state_go_vote)		
	
label var offering_yield_spread "Offering Yield Spread"	
	
**Output issue clustering**
eststo clear
*Include proactive, etc
eststo: qui reghdfe offering_yield_spread city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo glm_proactive state_ltgo_allowed state_go_vote  ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo glm_proactive state_ltgo_allowed state_go_vote  ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
esttab using "$RESULTS/250707_yield_UTGO_issueclus.tex", ///
	replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield") ///
	star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $countydemo glm_proactive state_ltgo_allowed state_go_vote)	
	
	
	
**Output county clustering**
eststo clear
*Include proactive, etc
eststo: qui reghdfe offering_yield_spread city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo glm_proactive state_ltgo_allowed state_go_vote  ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster fips)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "County"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo glm_proactive state_ltgo_allowed state_go_vote  ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster fips)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "County"	
esttab using "$RESULTS/250709_yield_UTGO_countyclus.tex", ///
	replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield") ///
	star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $countydemo glm_proactive state_ltgo_allowed state_go_vote)		
	
*Try state-purpose*
gegen statepurp = group(state purp_broad_id)
gegen countypurp = group(fips purp_broad_id)

*output state-purpose
eststo clear
*Include proactive, etc
eststo: qui reghdfe offering_yield_spread city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo glm_proactive state_ltgo_allowed state_go_vote  ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster countypurp)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "County-Purp"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo glm_proactive state_ltgo_allowed state_go_vote  ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster countypurp)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "County-Purp"	
esttab using "$RESULTS/250709_yield_UTGO_countypurpclus.tex", ///
	replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield") ///
	star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $State-Purpdemo glm_proactive state_ltgo_allowed state_go_vote)	
	
	
	
	
 reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo /*state_go_vote*/ glm_proactive state_ltgo_allowed ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)	
	
	
	
	

**Output versions with state clustering**
*Outcome var = yield spread, raw*
eststo clear
*Exclude fidelity vars, cluster by state
eststo: qui reghdfe offering_yield_spread city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
*Include index
eststo: qui reghdfe offering_yield_spread city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	invest_prot_scaled ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
*Include index components separately 
eststo: qui reghdfe offering_yield_spread city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
*Include sepfund_statlien and debt service only
eststo: qui reghdfe offering_yield_spread city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	/*state_fullfaith*/ state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250707_yieldspread_UTGO_stateclus.tex", ///
	replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield spread (cluster by state)") ///
	star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $countydemo state_go_vote glm_proactive state_ltgo_allowed)		
	
**Output versions with issue clustering**
eststo clear
*Exclude fidelity vars
eststo: qui reghdfe offering_yield_spread city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*Include index
eststo: qui reghdfe offering_yield_spread city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	invest_prot_scaled ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*Include index components separately 
eststo: qui reghdfe offering_yield_spread city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*Include sepfund_statlien and debt service only
eststo: qui reghdfe offering_yield_spread city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	/*state_fullfaith*/ state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
esttab using "$RESULTS/250707_yieldspread_UTGO_issueclus.tex", ///
	replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield spread (cluster by issue)") ///
	star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $countydemo state_go_vote glm_proactive state_ltgo_allowed)	
	
*try trimming the yield spread
winsor2 offering_yield_spread , suffix(_tr) trim cuts(1 99)
sum offering_yield_spread, d
/*
                    offering_yield_spread
-------------------------------------------------------------
      Percentiles      Smallest
 1%        .0731        -5.3165
 5%       .39325        -5.3158
10%       .57025        -5.3121       Obs             323,907
25%        .9936        -5.3104       Sum of wgt.     323,907

50%      1.45675                      Mean           1.422517
                        Largest       Std. dev.      .6593334
75%      1.81755         9.9066
90%      2.15415       12.06981       Variance       .4347206
95%      2.41035       12.24367       Skewness       .3375677
99%      3.15745        12.6359       Kurtosis       7.236129
*/
sum offering_yield_spread_tr, d
/*                    offering_yield_spread
-------------------------------------------------------------
      Percentiles      Smallest
 1%        .2203          .0731
 5%        .4309          .0732
10%       .59505          .0732       Obs             317,429
25%        1.007         .07325       Sum of wgt.     317,429

50%      1.45675                      Mean           1.417568
                        Largest       Std. dev.      .5789112
75%      1.80935          3.157
90%       2.1274       3.157141       Variance       .3351382
95%      2.34725        3.15735       Skewness      -.0069183
99%      2.78475        3.15745       Kurtosis       2.651179
*/
label var offering_yield_spread "Yield spread"
label var offering_yield_spread_tr "Yield spread (trim)"

**Output versions with state clustering**
*Outcome var = yield spread, truncated*
eststo clear
*Exclude fidelity vars, cluster by state
eststo: qui reghdfe offering_yield_spread_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
*Include index
eststo: qui reghdfe offering_yield_spread_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	invest_prot_scaled ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
*Include index components separately 
eststo: qui reghdfe offering_yield_spread_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
*Include sepfund_statlien and debt service only
eststo: qui reghdfe offering_yield_spread_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	/*state_fullfaith*/ state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250707_yieldspread_UTGO_stateclus_trim.tex", ///
	replace t noconstant b(3) ///
	title("GO bond referendum requirements and trimmed offering yield spread (cluster by state)") ///
	star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $countydemo state_go_vote glm_proactive state_ltgo_allowed)		
	
**Output versions with issue clustering**
eststo clear
*Exclude fidelity vars
eststo: qui reghdfe offering_yield_spread_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*Include index
eststo: qui reghdfe offering_yield_spread_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	invest_prot_scaled ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*Include index components separately 
eststo: qui reghdfe offering_yield_spread_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
*Include sepfund_statlien and debt service only
eststo: qui reghdfe offering_yield_spread_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo state_go_vote glm_proactive state_ltgo_allowed ///
	/*state_fullfaith*/ state_sep_debtservice_levy sepfund_statlien ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
esttab using "$RESULTS/250707_yieldspread_UTGO_issueclus_trim.tex", ///
	replace t noconstant b(3) ///
	title("GO bond referendum requirements and trimmed offering yield spread (cluster by issue)") ///
	star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $countydemo state_go_vote glm_proactive state_ltgo_allowed)	

	
**# Bookmark #2
***Issuer-level analysis***

use "$MERGENT\Clean\250701_city_issuerlevel_yieldspread.dta", clear

global countydemo ln_gdp ln_pop ln_pers_inc ln_emp

*Output: benchmark vs. All GO*
*Outcome var: % Rev*
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
	
	
*Output: benchmark vs. All GO*
*Outcome var: WAvg yield spread*
eststo clear
*Reg without fidelity vars; clustered by county 
eststo: qui reg issuer_yield_spread city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
*cluster by state
eststo: qui reg issuer_yield_spread city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	if insample_allgo == 1, vce(cluster state)
	estadd local SE "State"	
*Include fidelity index
eststo: qui reg issuer_yield_spread city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed invest_prot_scaled ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
*Include index components separately 
eststo: qui reg issuer_yield_spread city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed  ///
	state_fullfaith state_sep_debtservice_levy sepfund_statlien ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
*Include debt service levy + sepfund_statlien only
eststo: qui reg issuer_yield_spread city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed sepfund_statlien state_sep_debtservice_levy ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
esttab using "$RESULTS/250701_allgo_yieldspread_v1.tex", replace t noconstant b(3) ///
	title("Aggregate cost of debt: Only compare control states with all GO only states (i.e, drop OH, MI, WA) ") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_county_debt_other $countydemo state_go_vote glm_proactive state_ltgo_allowed)


*Output: benchmark vs. UTGO vote only states (WI, MA, OH)*
*Outcome var: % LTGO*
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
	


*Output: benchmark vs. UTGO vote only states (WI, MA, OH)*
*Outcome var: WAvg yield spread*
eststo clear
*Reg without fidelity vars; clustered by county 
eststo: qui reg issuer_yield_spread city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
*cluster by state
eststo: qui reg issuer_yield_spread  city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed ///
	if insample_utgo_only == 1, vce(cluster state)
	estadd local SE "State"	
*Include fidelity index
eststo: qui reg issuer_yield_spread  city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed invest_prot_scaled ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
*Include index components separately 
eststo: qui reg issuer_yield_spread  city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed  ///
	state_fullfaith state_sep_debtservice_levy sepfund_statlien ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
*Include debt service levy + sepfund_statlien only
eststo: qui reg issuer_yield_spread  city_go_vote ///
	$countydemo ln_county_debt_other ///
	state_go_vote glm_proactive state_ltgo_allowed sepfund_statlien state_sep_debtservice_levy ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
esttab using "$RESULTS/250701_utgoonly_yieldspread_v1.tex", replace t noconstant b(3) ///
	title("Aggregate cost of debt: Only compare control states with UTGO-vote-only states (OH, MI, WA) ") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_county_debt_other $countydemo state_go_vote glm_proactive state_ltgo_allowed)

