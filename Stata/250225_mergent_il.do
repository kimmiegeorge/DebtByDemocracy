**************************
*Voting on bonds         *
*IL home rule tests      *
*Last updated: 02/25/25  *
**************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global IL "$DATA\Home Rule"
global DESCRIPT "$MAIN\Descriptives"
global RESULTS "$MAIN\Results\2025-02_IL"

***Start with bond-level Mergent data with state voting requirements***
use "$MERGENT\Clean\250124_citycountyschool_cusiplevel_statereq.dta", clear

*drop schools and counties
tab issuer_type
/*
Issuer type |      Freq.     Percent        Cum.
------------+-----------------------------------
       city |    332,629       45.54       45.54
     county |     91,753       12.56       58.10
     school |    306,075       41.90      100.00
------------+-----------------------------------
      Total |    730,457      100.00
*/
*given cities are most of the sample (besides schools), keep just cities for now
keep if issuer_type == "city"
*only keep IL
keep if state == "IL"

*make go indicator for go_lim and go_unlim
gen go_all = 1 if go_lim == 1 | go_unlim == 1
replace go_all = 0 if go_all == .
label var go_all "GO bond"

***Merge in IL home rule***
mmerge seed_issuer year using "$IL\250227_homeruletimeseries.dta", ///
	type(n:1) missing(nomatch)
/*
                 obs |  21993
                vars |    171  (including _merge)
         ------------+---------------------------------------------------------
              _merge |   7698  obs only in master data                (code==1)
                     |   3861  obs only in using data                 (code==2)
                     |  10434  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*Hand-check only in master
br seed_issuer homerule if _merge == 1
*fix
replace homerule = 1 if seed_issuer == "BEDFORD PK VLG ILL"
replace homerule_begyr = 1972 if seed_issuer == "BEDFORD PK VLG ILL"
replace homerule_method = "R" if seed_issuer == "BEDFORD PK VLG ILL"
replace homerule = 1 if seed_issuer == "ELMWOOD PA"
replace homerule_begyr = 1980 if seed_issuer == "ELMWOOD PA"
replace homerule_method = "R" if seed_issuer == "ELMWOOD PA"
replace homerule = 1 if seed_issuer == "EVERGREEN PA"
replace homerule_begyr = 1982 if seed_issuer == "EVERGREEN PA"
replace homerule_method = "R" if seed_issuer == "EVERGREEN PA"
replace homerule = 1 if seed_issuer == "HANOVER PA"
replace homerule_begyr = 1972 if seed_issuer == "HANOVER PA"
replace homerule_method = "R" if seed_issuer == "HANOVER PA"
replace homerule = 1 if seed_issuer == "HIGHLAND PA"
replace homerule_begyr = 1980 if seed_issuer == "HIGHLAND PA"
replace homerule_method = "R" if seed_issuer == "HIGHLAND PA"
replace homerule = 1 if seed_issuer == "MELROSE PA" & year >= 2011
replace homerule = 0 if seed_issuer == "MELROSE PA" & year < 2011
replace homerule_begyr = 2011 if seed_issuer == "MELROSE PA"
replace homerule_method = "C" if seed_issuer == "MELROSE PA"
replace homerule = 1 if seed_issuer == "OAK LA"
replace homerule_begyr = 1972 if seed_issuer == "OAK LA"
replace homerule_method = "C" if seed_issuer == "OAK LA"
replace homerule = 1 if seed_issuer == "ORLAND PA"
replace homerule_begyr = 1984 if seed_issuer == "ORLAND PA"
replace homerule_method = "C" if seed_issuer == "ORLAND PA"
replace homerule = 1 if seed_issuer == "ROLLING ME"
replace homerule_begyr = 1985 if seed_issuer == "ROLLING ME"
replace homerule_method = "R" if seed_issuer == "ROLLING ME"
replace homerule = 1 if seed_issuer == "ROUND LA"
replace homerule_begyr = 1972 if seed_issuer == "ROUND LA"
replace homerule_method = "C" if seed_issuer == "ROUND LA"
replace homerule = 1 if seed_issuer == "SCHILLER PA"
replace homerule_begyr = 1994 if seed_issuer == "SCHILLER PA"
replace homerule_method = "R" if seed_issuer == "SCHILLER PA"
replace homerule = 1 if seed_issuer == "STONE PA"
replace homerule_begyr = 1972 if seed_issuer == "STONE PA"
replace homerule_method = "R" if seed_issuer == "STONE PA"
replace homerule = 1 if seed_issuer == "UNIVERSITY PA"
replace homerule_begyr = 1975 if seed_issuer == "UNIVERSITY PA"
replace homerule_method = "R" if seed_issuer == "UNIVERSITY PA"

*br if _merge == 2
*These obs are where years are not matched because no bond was issued
drop if _merge == 2
drop _merge

*clean home rule vars
replace homerule = 0 if homerule == .
*create indicator for ever having home rule
gegen homerule_ever = max(homerule), by(seed_issuer)
gunique seed_issuer if homerule_ever == 1
*154 issuers 

*gen IL-specific vote indicator based on home rule
*Reminder that home rule = NO vote for UTGO; non-home rule = vote for UTGO
*IL law: Cities are not requred to get voter approvl for limited tax GO bonds within a certain limit
gen vote_req_il = 1 if go_unlim == 1 & homerule == 0
replace vote_req_il = 0 if vote_req_il == .
*br seed_issuer year go_lim go_unlim rev homerule vote_req_il offering_yield_tr if state == "IL"

*label vars
label var homerule "Home Rule"
label var vote_req_il "Vote Req"

*before merging in issuer-level population data, set year "1 year back" for lag issuer pop
rename year year_actual
gen year = year_actual - 1 
*rename pop
rename pop county_pop
rename ln_pop ln_county_pop

mmerge seed_issuer year using "$IL\250225_il_issuerpop_clean.dta", type(n:1) missing(nomatch)
/*
                obs |  24898
			   vars |    182  (including _merge)
         ------------+---------------------------------------------------------
              _merge |   1165  obs only in master data                (code==1)
                     |   6766  obs only in using data                 (code==2)
                     |  16967  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*br if _merge == 1
*nothing in 2000 with lag year 1999 is matched, fine
*br if _merge == 1 & year != 1999
*these are a few seed issuers that genuinely weren't matched
drop if _merge == 1
*br if _merge == 2
*these are years without issuances
drop if _merge == 2

*fix year back
drop year
rename year_actual year
rename pop lag_issuer_pop
label var lag_issuer_pop "Lag issuer population"

drop _merge

**# Bookmark #1

***Descriptives for IL***
*how many rev, go_lim, go_unlim?
count if go_lim == 1 
*442
count if go_unlim == 1 
*11,633
count if rev == 1 
*4,892

*how many in different bands?
*br seed_issuer year homerule homerule_method go_unlim lag_issuer_pop band* if go_unlim == 1

*later, consider whether to drop cities that get home rule via referendum
count if go_unlim == 1 & band2500 == 1 & homerule_method != "R"
*826 bonds; 451 w/o HR ref
count if go_unlim == 1 & band5000 == 1 & homerule_method != "R"
*1,898 bonds; 1,092 w/o HR ref
count if go_unlim == 1 & band7500 == 1 & homerule_method != "R"
*2,908 bonds; 1,591 w/o HR ref
count if go_unlim == 1 & band10000 == 1 & homerule_method != "R"
*3,779 bonds; 2,278 w/o HR ref

gunique seed_issuer if go_unlim == 1 & band2500 == 1 & homerule_method != "R"
*25 issuers; 15 w/o HR ref
gunique seed_issuer if go_unlim == 1 & band5000 == 1 & homerule_method != "R"
*46 issuers; 30 w/o HR ref
gunique seed_issuer if go_unlim == 1 & band7500 == 1 & homerule_method != "R"
*61 issuers; 40 w/o HR ref
gunique seed_issuer if go_unlim == 1 & band10000 == 1 & homerule_method != "R"
*79 issuers; 52 w/o HR ref

*sum stats within different issuer pop bands
*all issuers
eststo clear
eststo: estpost sum lag_issuer_pop homerule vote_req_il go_lim go_unlim rev offering_yield_tr ln_amount ln_maturity ///
	callable sinkable insured rated ///
	ln_county_pop ln_gdp ln_pers_inc ln_percap_inc ln_emp , d
esttab using "$DESCRIPT\IL\250227_il_sumstats.tex", replace ///
	title("Summary statistics for Illinois") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	

*2500
eststo clear
eststo: estpost sum lag_issuer_pop homerule vote_req_il go_lim go_unlim rev offering_yield_tr ln_amount ln_maturity ///
	callable sinkable insured rated ///
	ln_county_pop ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if band2500 == 1, d
esttab using "$DESCRIPT\IL\250227_il_sumstats_band2500.tex", replace ///
	title("Summary statistics for Illinois (Band 2500)") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	
	
*5000
eststo clear
eststo: estpost sum lag_issuer_pop homerule vote_req_il go_lim go_unlim rev offering_yield_tr ln_amount ln_maturity ///
	callable sinkable insured rated ///
	ln_county_pop ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if band5000 == 1, d
esttab using "$DESCRIPT\IL\250227_il_sumstats_band5000.tex", replace ///
	title("Summary statistics for Illinois (Band 5000)") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	
	
*7500
eststo clear
eststo: estpost sum lag_issuer_pop homerule vote_req_il go_lim go_unlim rev offering_yield_tr ln_amount ln_maturity ///
	callable sinkable insured rated ///
	ln_county_pop ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if band7500 == 1, d
esttab using "$DESCRIPT\IL\250227_il_sumstats_band7500.tex", replace ///
	title("Summary statistics for Illinois (Band 7500)") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	
	
	
*10000
eststo clear
eststo: estpost sum lag_issuer_pop homerule vote_req_il go_lim go_unlim rev offering_yield_tr ln_amount ln_maturity ///
	callable sinkable insured rated ///
	ln_county_pop ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if band10000 == 1, d
esttab using "$DESCRIPT\IL\250227_il_sumstats_band10k.tex", replace ///
	title("Summary statistics for Illinois (Band 10k)") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	

**# Bookmark #2

***Regression: When a vote is required, is offering yield different?***
*output*
*can't cluster by state because only 1 state
*do within bands

**2500 band**
eststo clear
eststo: qui reg offering_yield_tr vote_req_il ///
	if go_unlim == 1 & band2500 == 1 & homerule_method != "R" ///
	, vce(robust)
	estadd local timeFE "No"
	estadd local purposeFE "No"
	estadd local SE "Robust"

eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	if go_unlim == 1 & band2500 == 1 & homerule_method != "R" ///
	, absorb(year month) vce(cluster seed_issuer)
	estadd local timeFE "Year, Month"
	estadd local purposeFE "No"
	estadd local SE "Issuer"
	
eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ///
	if go_unlim == 1 & band2500 == 1 & homerule_method != "R" ///
	, absorb(year month) vce(cluster seed_issuer)
	estadd local timeFE "Year, Month"
	estadd local purposeFE "No"
	estadd local SE "Issuer"
	
eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc /*ln_percap_inc*/ ln_emp ///
	if go_unlim == 1 & band2500 == 1 & homerule_method != "R" ///
	, absorb(year month) vce(cluster seed_issuer)
	estadd local timeFE "Year, Month"
	estadd local purposeFE "No"
	estadd local SE "Issuer"
	
eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc /*ln_percap_inc*/ ln_emp ///
	if go_unlim == 1 & band2500 == 1 & homerule_method != "R" ///
	, absorb(year month num_use_proceeds) vce(cluster seed_issuer)
	estadd local timeFE "Year, Month"
	estadd local purposeFE "Yes"
	estadd local SE "Issuer"
	
esttab using "$RESULTS/250227_il_homerule_2500.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (IL)") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FEs" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 
	
**5000 band**

eststo clear
eststo: qui reg offering_yield_tr vote_req_il ///
	if go_unlim == 1 & band5000 == 1 & homerule_method != "R" ///
	, vce(robust)
	estadd local timeFE "No"
	estadd local purposeFE "No"
	estadd local SE "Robust"

eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	if go_unlim == 1 & band5000 == 1 & homerule_method != "R" ///
	, absorb(year month) vce(cluster seed_issuer)
	estadd local timeFE "Year, Month"
	estadd local purposeFE "No"
	estadd local SE "Issuer"
	
eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc /*ln_percap_inc*/ ln_emp ///
	if go_unlim == 1 & band5000 == 1 & homerule_method != "R" ///
	, absorb(year month) vce(cluster seed_issuer)
	estadd local timeFE "Year, Month"
	estadd local purposeFE "No"
	estadd local SE "Issuer"
	
eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc /*ln_percap_inc*/ ln_emp ///
	if go_unlim == 1 & band5000 == 1 & homerule_method != "R" ///
	, absorb(year month num_use_proceeds) vce(cluster seed_issuer)
	estadd local timeFE "Year, Month"
	estadd local purposeFE "Yes"
	estadd local SE "Issuer"
	
esttab using "$RESULTS/250227_il_homerule_5000.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (IL)") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FEs" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 	
	
**7500 band**	

eststo clear
eststo: qui reg offering_yield_tr vote_req_il ///
	if go_unlim == 1 & band7500 == 1 & homerule_method != "R" ///
	, vce(robust)
	estadd local timeFE "No"
	estadd local purposeFE "No"
	estadd local SE "Robust"

eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	if go_unlim == 1 & band7500 == 1 & homerule_method != "R" ///
	, absorb(year month) vce(cluster seed_issuer)
	estadd local timeFE "Year, Month"
	estadd local purposeFE "No"
	estadd local SE "Issuer"

eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc /*ln_percap_inc*/ ln_emp ///
	if go_unlim == 1 & band7500 == 1 & homerule_method != "R" ///
	, absorb(year month) vce(cluster seed_issuer)
	estadd local timeFE "Year, Month"
	estadd local purposeFE "No"
	estadd local SE "Issuer"
	
eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc /*ln_percap_inc*/ ln_emp ///
	if go_unlim == 1 & band7500 == 1 & homerule_method != "R" ///
	, absorb(year month num_use_proceeds) vce(cluster seed_issuer)
	estadd local timeFE "Year, Month"
	estadd local purposeFE "Yes"
	estadd local SE "Issuer"
	
esttab using "$RESULTS/250227_il_homerule_7500.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (IL)") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FEs" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 			
	
	
	
	
**10000 band**

eststo clear
eststo: qui reg offering_yield_tr vote_req_il ///
	if go_unlim == 1 & band10000 == 1 & homerule_method != "R" ///
	, vce(robust)
	estadd local timeFE "No"
	estadd local purposeFE "No"
	estadd local SE "Robust"

eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	if go_unlim == 1 & band10000 == 1 & homerule_method != "R" ///
	, absorb(year month) vce(cluster seed_issuer)
	estadd local timeFE "Year, Month"
	estadd local purposeFE "No"
	estadd local SE "Issuer"
	
eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc /*ln_percap_inc*/ ln_emp ///
	if go_unlim == 1 & band10000 == 1 & homerule_method != "R" ///
	, absorb(year month) vce(cluster seed_issuer)
	estadd local timeFE "Year, Month"
	estadd local purposeFE "No"
	estadd local SE "Issuer"
	
eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc /*ln_percap_inc*/ ln_emp ///
	if go_unlim == 1 & band10000 == 1 & homerule_method != "R" ///
	, absorb(year month num_use_proceeds) vce(cluster seed_issuer)
	estadd local timeFE "Year, Month"
	estadd local purposeFE "Yes"
	estadd local SE "Issuer"
	
esttab using "$RESULTS/250227_il_homerule_10000.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (IL)") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FEs" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 		

***Regression not in bands***
*output*

eststo clear
eststo: qui reg offering_yield_tr vote_req_il ///
	if go_unlim == 1 & homerule_method != "R" ///
	, vce(robust)
	estadd local timeFE "No"
	estadd local purposeFE "No"
	estadd local countyFE "No"
	estadd local SE "Robust"

eststo: qui reg offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc /*ln_percap_inc*/ ln_emp ///
	if go_unlim == 1 & homerule_method != "R" ///
	, vce(robust)
	estadd local timeFE "No"
	estadd local purposeFE "No"
	estadd local countyFE "No"
	estadd local SE "Robust"

eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_gdp ln_pers_inc /*ln_percap_inc*/ ln_emp ///
	if go_unlim == 1 & homerule_method != "R" ///
	, absorb(year month num_use_proceeds) vce(cluster seed_issuer)
	estadd local timeFE "Yes"
	estadd local purposeFE "Yes"
	estadd local countyFE "No"
	estadd local SE "Issuer"
	
eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	if go_unlim == 1 & homerule_method != "R" ///
	, absorb(year month num_use_proceeds fips) vce(cluster seed_issuer)
	estadd local timeFE "Yes"
	estadd local purposeFE "Yes"
	estadd local countyFE "Yes"
	estadd local SE "Issuer"
	
esttab using "$RESULTS/250227_il_homerule.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (IL)") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE countyFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FEs" "Purpose FE" "County FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 
	
	
	