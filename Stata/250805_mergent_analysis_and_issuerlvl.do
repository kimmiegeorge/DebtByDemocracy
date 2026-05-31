**************************
*Voting on bonds         *
*Issuer-level analysis   *
*Last updated: 08/05/25  *
**************************

***Goals***
/*
- Issuer-level tests
- Explore different combinations of state laws
- Get cusips to check for states with unclear laws
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

*Make histograms by state of pct bonds*
/*
preserve
gcollapse (sum) go_unlim go_lim rev, by(state)
gen n_bonds_total = go_unlim + go_lim + rev
restore
*copied and pasted results into Excel
*/

/*
*7/30: get categories of IA bonds by purpose, size, bond issuance names to look at with KM
keep if state == "IA" & go_unlim == 1
*collapse to issuance-level, keep one cusip
*gegen cusip_id = group(cusip)
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*1,146 issuances
sum amt_issue, d
*mean = 4,138,708; median = 2,290,000, p25 = 1M, p75 = 5M
tab num_use_proceeds
*84% are code 14; 2% are code 11; 2% are code 31; 5.5% are code 56
*of 150 to sample, get 8 that are code 56; 4 that are code 31 and 11
br if num_use_proceeds == 11
*now drop codes 56, 31, 11
drop if num_use_proceeds == 56
drop if num_use_proceeds == 11
drop if num_use_proceeds == 31
sum amt_issue, d
*gen indicator for below 1M, between 1M-5M, above 5M
gen strat = 1 if amt_issue <= 1000000
replace strat = 2 if inrange(amt_issue,1000001,4000000)
replace strat = 3 if amt_issue > 4000000
sample 45, count by(strat)
*pasted these into Excel

*/
*Merge in list of issue id from Iowa random sample
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

mmerge issue_id using "$DATA\Other\2025-07-30_IA_sample150_issue_id.dta", type(n:1) missing(nomatch)
keep if _merge == 3
gunique issue_id
*keep one cusip
sort issue_id
by issue_id: egen temp1 = rank(amount), unique
count if temp1 == 1
*151, good
keep if temp1 == 1
keep seed_issuer seed_issuer_id year issue_id cusip issue_description security_code use_proceeds amount
sort seed_issuer year

*save
save "$DATA\Other\250730_IA_sample150.dta", replace
export delimited using "$DATA\Other\250730_IA_sample150.csv", replace

/*
**Get random samples of cusips to check for: KY, MN, NV, SC, VA, WI**
*8/5: get categories of bonds by purpose, size, bond issuance names to look at with KM
*KY
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
keep if state == "KY" & go_unlim == 1
*collapse to issuance-level
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*88 issuances
sum amt_issue, d
*mean = 6,746,648; median = 4,477,500, p25 = 2.9M, p75 = 8.8M
*paste all into Excel

*MN
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
keep if state == "MN" & go_unlim == 1
*collapse to issuance-level
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*2,496 issuances
sum amt_issue, d
*mean = 3.2M; median = 1.7M, p25 = 0.9M, p75 = 3.4M
tab num_use_proceeds
*85% are code 14; 2% are code 11; 2% are code 31; 5% are code 56
sample 50, count 
*pasted these into Excel


*NV
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
keep if state == "NV" & go_unlim == 1
*collapse to issuance-level
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*4 issuances
*paste all into Excel

*SC
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
keep if state == "SC" & go_unlim == 1
*collapse to issuance-level
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*55 issuances
sum amt_issue, d
*mean = 9.2M; median = 7.0M, p25 = 3.9M, p75 = 15M
tab num_use_proceeds
*76% are code 14 
*pasted all into Excel

*VA
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
keep if state == "VA" & go_unlim == 1
*collapse to issuance-level
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*171 issuances
sum amt_issue, d
tab num_use_proceeds
*89% code 14
sample 50, count 
*paste into Excel

*WI
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
keep if state == "WI" & go_unlim == 1
*collapse to issuance-level
gcollapse (sum) amt_issue = amount (mean) num_use_proceeds  ///
	, by(issue_id issue_description security_code seed_issuer year)
sort seed_issuer year
*1,332 issuances
sum amt_issue, d
*Mean = 4.8M, median = 3M
tab num_use_proceeds
*93% code 14
sample 50, count 
*paste into Excel
*/

*Get cusips to check from each of these states

*Merge in list of issue id from Iowa random sample
local states KY MN NV SC VA WI
foreach x of local states{
	use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear
	mmerge issue_id using `"$DATA\Other\2025-08-05_`x'_sample_issue_id.dta"', type(n:1) missing(nomatch)
	keep if _merge == 3
	sort issue_id
	by issue_id: egen temp1 = rank(amount), unique
	keep if temp1 == 1
	keep seed_issuer seed_issuer_id year issue_id cusip issue_description security_code use_proceeds amount
	sort seed_issuer year
	save `"$DATA\Other\250805_`x'_sample.dta"'
	export delimited using `"$DATA\Other\250805_`x'_sample.csv"'
	
}

mmerge issue_id using "$DATA\Other\2025-07-30_IA_sample150_issue_id.dta", type(n:1) missing(nomatch)
keep if _merge == 3
gunique issue_id
*keep one cusip
sort issue_id
by issue_id: egen temp1 = rank(amount), unique
count if temp1 == 1
*151, good
keep if temp1 == 1
keep seed_issuer seed_issuer_id year issue_id cusip issue_description security_code use_proceeds amount
sort seed_issuer year

*save
save "$DATA\Other\250730_IA_sample150.dta", replace
export delimited using "$DATA\Other\250730_IA_sample150.csv", replace



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

/*
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
*/

*Make Iowa vote varies within state
*Make Indiana UTGO only
replace city_go_vote = . if state == "IA"
replace city_go_vote = 1 if state == "IN"
*certain bonds classified as UTGO in Mergent (Security code K) are "non-controlled projects" and don't need votes per the OS
*the non-controlled projects are defined by amount of debt, not how much they can raise the property tax, so it's not a true LTGO
*Also, some of these are library entities
count if state == "IN" & go_unlim == 1
*1,764
count if state == "IN" & go_unlim == 1 & strpos(issuer_long_name,"PUB LIB") > 0
*260
sum offering_yield_tr if state == "IN" & go_unlim == 1
*mean is 3.026
sum offering_yield_tr if state == "IN" & go_unlim == 1 & strpos(issuer_long_name,"PUB LIB") > 0
*mean is 3.35
sum amount if state == "IN" & go_unlim == 1, d
br seed_issuer year issue_description issuer_long_name cusip if state == "IA" & go_unlim == 1


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
esttab using "$RESULTS/250729_yield_UTGO_changeIAIN.tex", ///
	replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield") ///
	star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated $countydemo glm_proactive state_ltgo_allowed state_go_vote)	

*No truncation
eststo clear
*Include proactive, etc
eststo: qui reghdfe offering_yield_spread city_go_vote ln_amount ln_maturity_mths ///
	callable sinkable insured rated ///
	$countydemo glm_proactive state_ltgo_allowed state_go_vote  ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
eststo: qui reghdfe offering_yield city_go_vote ln_amount ln_maturity_mths ///
	callable sinkable insured rated ///
	$countydemo glm_proactive state_ltgo_allowed state_go_vote  ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"	
esttab using "$RESULTS/250729_yield_UTGO_changeIAIN_notrim.tex", ///
	replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield") ///
	star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(city_go_vote ln_amount ln_maturity_mths callable sinkable insured rated $countydemo glm_proactive state_ltgo_allowed state_go_vote)	
	
	
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

*make IA vote varies within state
*make IN UTGO only
replace city_go_vote = . if state == "IA"
tab insample_allgo if state == "IN"
tab insample_utgo_only if state == "IN"
replace city_go_vote = 1 if 

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

