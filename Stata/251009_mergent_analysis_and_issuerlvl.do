**************************
*Voting on bonds         *
*Issuer-level analysis   *
*Last updated: 10/09/25  *
**************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global DESCRIPT "$MAIN\Descriptives"
global RESULTS "$MAIN\Results\2025-10_results"

**# Bookmark #2
***Issuer-level analysis***
*Go back to version before dropping WI promissory notes

use "$MERGENT\Clean\250827_city_issuerlevel_yieldspread.dta", clear

*Make Missouri revenue bonds depends
replace city_rev_vote = 1 if state == "MO"
replace insample_allgo = 0 if state == "MO"

*Descriptives*
*do GO Vote Required and Only UTGO Vote Required separately because it's the same variable, but different samples
sum city_go_vote if insample_utgo_only == 1, d
*1,758 obs
sum city_go_vote if insample_allgo == 1, d
*2,104 obs
*But what proportion of cities in the sample have UTGO Only?
gen temp1 = 1 if inlist(state,"WA","MI","OH")
replace temp1 = 0 if temp1 == . & city_go_vote != .
sum temp1
*3,476 obs
sum temp1 if insample_allgo == 1 | insample_utgo_only == 1, d
/*
                            temp1
-------------------------------------------------------------
      Percentiles      Smallest
 1%            0              0
 5%            0              0
10%            0              0       Obs               2,803
25%            0              0       Sum of wgt.       2,803

50%            0                      Mean           .2493757
                        Largest       Std. dev.      .4327288
75%            0              1
90%            1              1       Variance       .1872542
95%            1              1       Skewness        1.15855
99%            1              1       Kurtosis       2.342239
*/
gen temp2 = city_go_vote if temp1 != 1
replace temp2 = 0 if temp1 == 1
sum temp2
*3,476 obs
sum temp2 if insample_allgo == 1 | insample_utgo_only == 1, d
/*
                            temp2
-------------------------------------------------------------
      Percentiles      Smallest
 1%            0              0
 5%            0              0
10%            0              0       Obs               2,803
25%            0              0       Sum of wgt.       2,803

50%            0                      Mean           .3728148
                        Largest       Std. dev.      .4836397
75%            1              1
90%            1              1       Variance       .2339074
95%            1              1       Skewness       .5260439
99%            1              1       Kurtosis       1.276722
*/
count if insample_allgo == 1 | insample_utgo_only == 1
*2,803


eststo clear
eststo: estpost sum ///
	frac_utgo frac_ltgo frac_rev issuer_yield_spread ///
	ln_gdp ln_pop ln_pers_inc ln_emp ///
	state_go_vote glm_proactive state_ltgo_allowed ///	
	if insample_allgo == 1 | insample_utgo_only == 1 ///
	, detail
esttab using "$DESCRIPT/251009sumstats.tex", replace label ///
	title(Summary statistics) noobs  ///
	cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) p1(fmt(2)) p50(fmt(2)) p99(fmt(2)) max(fmt(2)) count(fmt(%9.0fc))")	
	

*Set global for regressions

global countydemo ln_gdp ln_pop ln_pers_inc ln_emp

*how many cities in sample?
count if insample_utgo_only != 1 & insample_allgo != 1
*3,055 not in sample
*6,049 cities - 3,055 = 2,994

**Debt choice tests**
*Output: benchmark vs. UTGO vote only states (WI, MA, OH)*
label var city_go_vote "\rowcolor{ltblue} Only UTGO Vote Required"
*Outcome var: % UTGO, % LTGO, % Rev*
*Cluster by county
eststo clear
eststo: qui reg frac_utgo city_go_vote ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
eststo: qui reg frac_utgo city_go_vote $countydemo /*ln_county_debt_other*/ ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
eststo: qui reg frac_utgo city_go_vote $countydemo /*ln_county_debt_other*/ ///
	glm_proactive state_ltgo_allowed state_go_vote ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
*% LTGO
eststo: qui reg frac_ltgo city_go_vote $countydemo /*ln_county_debt_other*/ ///
	glm_proactive state_ltgo_allowed state_go_vote ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
*% Rev
eststo: qui reg frac_rev city_go_vote $countydemo /*ln_county_debt_other*/ ///
	glm_proactive state_ltgo_allowed state_go_vote ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
esttab using "$RESULTS/250917_issuerlvl_debtchoice_utgoonly.tex", replace t noconstant b(3) ///
	title("GO bond referendum requirements and debt choice (UTGO Vote Only)") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote $countydemo glm_proactive state_ltgo_allowed state_go_vote)
	
*Output for All GO Vote sample
label var city_go_vote "\rowcolor{ltblue} GO Vote Required"
*Outcome var: % UTGO, % LTGO, % Rev*
*Cluster by county
eststo clear
eststo: qui reg frac_utgo city_go_vote ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
eststo: qui reg frac_utgo city_go_vote $countydemo /*ln_county_debt_other*/ ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
eststo: qui reg frac_utgo city_go_vote $countydemo /*ln_county_debt_other*/ ///
	glm_proactive state_ltgo_allowed state_go_vote ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
*% LTGO
eststo: qui reg frac_ltgo city_go_vote $countydemo /*ln_county_debt_other*/ ///
	glm_proactive state_ltgo_allowed state_go_vote ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
*% Rev
eststo: qui reg frac_rev city_go_vote $countydemo /*ln_county_debt_other*/ ///
	glm_proactive state_ltgo_allowed state_go_vote ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
esttab using "$RESULTS/251004_issuerlvl_debtchoice_allgo_changeMO.tex", replace t noconstant b(3) ///
	title("GO bond referendum requirements and debt choice (All GO Vote)") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote $countydemo glm_proactive state_ltgo_allowed state_go_vote)
	
**Yield spread tests**

**Debt choice tests**
*Output: benchmark vs. UTGO vote only states (WI, MA, OH)*
label var city_go_vote "\rowcolor{ltblue} Only UTGO Vote Required"
*Outcome var: % UTGO, % LTGO, % Rev*
*Cluster by county
eststo clear
eststo: qui reg issuer_yield_spread city_go_vote ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
eststo: qui reg issuer_yield_spread city_go_vote $countydemo /*ln_county_debt_other*/ ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
eststo: qui reg issuer_yield_spread city_go_vote $countydemo /*ln_county_debt_other*/ ///
	glm_proactive state_ltgo_allowed state_go_vote ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
esttab using "$RESULTS/250917_issuerlvl_yieldspread_utgoonly.tex", replace t noconstant b(3) ///
	title("GO bond referendum requirements and yield spread (UTGO Vote Only)") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote $countydemo glm_proactive state_ltgo_allowed state_go_vote)
	
	
*Output for All GO Vote sample
label var city_go_vote "\rowcolor{ltblue} GO Vote Required"
*Outcome var: % UTGO, % LTGO, % Rev*
*Cluster by county
eststo clear
eststo: qui reg issuer_yield_spread city_go_vote ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
eststo: qui reg issuer_yield_spread city_go_vote $countydemo /*ln_county_debt_other*/ ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
eststo: qui reg issuer_yield_spread city_go_vote $countydemo /*ln_county_debt_other*/ ///
	glm_proactive state_ltgo_allowed state_go_vote ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
esttab using "$RESULTS/251004_issuerlvl_yieldspread_allgo_changeMO.tex", replace t noconstant b(3) ///
	title("GO bond referendum requirements and yield spread (All GO Vote)") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote $countydemo glm_proactive state_ltgo_allowed state_go_vote)

	
*Run version where Louisiana is LTGO Allowed = 0
/*
label var city_go_vote "GO Vote Required"
*Outcome var: % UTGO, % LTGO, % Rev*
*Cluster by county
eststo clear
eststo: qui reg issuer_yield_spread city_go_vote ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
eststo: qui reg issuer_yield_spread city_go_vote $countydemo /*ln_county_debt_other*/ ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
eststo: qui reg issuer_yield_spread city_go_vote $countydemo /*ln_county_debt_other*/ ///
	glm_proactive state_ltgo_allowed state_go_vote ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"
esttab using "$RESULTS/250917_issuerlvl_yieldspread_allgo_LALTGO.tex", replace t noconstant b(3) ///
	title("GO bond referendum requirements and yield spread (All GO Vote)") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote $countydemo glm_proactive state_ltgo_allowed state_go_vote)
*/
	
**# Bookmark #1
***Bond-level analysis: yields***

**Start with main city file with yield spreads**
use "$MERGENT\Clean\250827_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

*Make Missouri revenue bonds required
replace city_rev_vote = 1 if state == "MO"
*Make RI GO vote depends
replace city_go_vote = . if state == "RI"

*Make pie charts for bond type*
gen temp1 = inlist(state,"WA","MI","OH")
*GO Vote Required states
gen bond_type2 = bond_type
replace bond_type2 = "ltgo" if go_lim == 1
replace bond_type2 = "utgo" if go_unlim == 1

*GO Vote Required states
tab bond_type2 if city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
/*
 bond_type2 |      Freq.     Percent        Cum.
------------+-----------------------------------
       ltgo |     10,215       17.05       17.05
        rev |     31,111       51.92       68.96
       utgo |     18,600       31.04      100.00
------------+-----------------------------------
      Total |     59,926      100.00
*/
*Only UTGO Vote Req states
tab bond_type2 if temp1 == 1
/*
 bond_type2 |      Freq.     Percent        Cum.
------------+-----------------------------------
       ltgo |     16,417       54.04       54.04
        rev |      6,859       22.58       76.62
       utgo |      7,103       23.38      100.00
------------+-----------------------------------
      Total |     30,379      100.00
*/
tab bond_type2 if city_go_vote == 0 & city_rev_vote == 0
/*
 bond_type2 |      Freq.     Percent        Cum.
------------+-----------------------------------
       ltgo |     11,561       17.64       17.64
        rev |     10,701       16.33       33.97
       utgo |     43,263       66.03      100.00
------------+-----------------------------------
      Total |     65,525      100.00

*/

*Are there other states like Louisiana where LTGO Allowed == 1 but very few LTGO bonds?
br state seed_issuer year cusip issue_description security_code if state_ltgo_allowed == 1 & bond_type2 == "ltgo"
tab bond_type2 if state == "LA"
tab security_code if state == "AR" & go_unlim == 1
/*
Alabama: 28 LTGO bonds (2%), 97 UTGO bonds (7%), 1,340 revenue bonds (91%); mainly based on Mergent coding. I think most AL cities issue GO warrants instead of bonds
Arkansas: 168 LTGO (7%), 27 UTGO (1%), 2,186 revenue (92%)
Florida: 149 LTGO (2%), 1,203 UTGO (19%), 4,977 Rev (79%) 
Iowa: 56 LTGO (0.35%), 79.68 UTGO (80%), 3,184 rev (20%)
Louisiana: 27 LTGO (1.9%), 478 UTGO (33%), 954 rev (65%)
*/


*Make histograms by state of pct bonds*
/*
preserve
gcollapse (sum) go_unlim go_lim rev, by(state)
gen n_bonds_total = go_unlim + go_lim + rev
restore
*copied and pasted results into Excel
*/



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
label var offering_yield_spread "Yield Spread"	

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

*KM ran the XS yield test with media	
	
	
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
esttab using "$RESULTS/251008_bondlvl_yield_changeMO.tex", ///
	replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield") ///
	star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $countydemo glm_proactive state_ltgo_allowed state_go_vote)	

*Cluster by state - lose significance
reghdfe offering_yield_spread city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo glm_proactive state_ltgo_allowed state_go_vote  ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	
*Try with IN as none
replace city_go_vote = 0 if state == "IN"
replace city_go_vote = . if state == "IN"
reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr ///
	callable sinkable insured rated ///
	$countydemo glm_proactive state_ltgo_allowed state_go_vote  ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	
	
	
*Try state-purpose*
gegen statepurp = group(state purp_broad_id)
gegen countypurp = group(fips purp_broad_id)

	
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

	