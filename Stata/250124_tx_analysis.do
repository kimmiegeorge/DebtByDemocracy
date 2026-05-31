**************************
*Voting on bonds         *
*Analysis for Texas pilot*
*Last updated: 12/17/24  *
**************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global DESCRIPT "$MAIN\Descriptives"
global RESULTS "$MAIN\Results"

***Start with issue-level matched Mergent + MSRB + voting data for TX***
use "$TX/241216_txmerge_election_issuelevel.dta", clear

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
reg wavg_offering_yield wavg_winmargin if vote_req == 1 & city == 1, vce(robust)
*coeff = 0.493, p = 0.063

reg wavg_offering_yield wavg_winmargin if vote_req == 0 & city == 1, vce(robust)
*coeff = -1.176, p = 0.044
*Weird that for revenue bonds, we kind of see what we would've expected to see with GO bonds
*Note R2 through all of these is super small, so can't interpret these much

*Try with truncated yield
reg wavg_offering_yield_tr wavg_winmargin if vote_req == 1 & city == 1, vce(robust)
*similar to non-truncated
reg wavg_offering_yield_tr wavg_winmargin if vote_req == 0 & city == 1, vce(robust)
*coeff = -0.274, p = 0.592

*So, the truncation makes a big difference for revenue bonds. While the coeff is negative, nothing is statistically significant

sum wavg_winmargin, d
*wavg: mean = 0.39, median = 0.38

*Descriptively, what factors lead to lower borrowing cost? (This should be done on the full Mergent sample)

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
	
*Run countyFE with bond controls for city GO	
reghdfe wavg_offering_yield_tr wavg_winmargin log_issue_size log_max_maturity ///
	callable_dummy sinkable_dummy insured_dummy rated_dummy ///
	if vote_req == 1 & city == 1 ///
	, absorb(year_issue month_issue fips) vce(cluster seed_issuer)	
	
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