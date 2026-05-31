***************************
*Partisan school boards NC*
*Bring in county demos    *
*Last updated: 03/10/26   *
***************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global NC "$DATA\NC School"
global DESCRIPT "$NC\descript"

/*Relevant folders:
- NC School: 260310_countydemos_educ.csv and dta combine county-year economic conditions, demographics, and school enrollment + expenditure data
	- build_countydemos_educ is Python code that creates this data from the two files listed below
- NC School\county demos: 260310_countydemos_combined. This combines county-year economic conditions from BEA and race and sex demographics from ACS. See README_countydemos_ACS5Y and README_combine_ACS_BEA. build_countydemos_combined and build_countydemos_update2324 create 260310_countydemos_combined. build_countydemos_5year cleaned the 5-year ACS data.
	- 2010-2024 (except 2020): both ACS and BEA data present, though no employment for 2023-2024 
	- No ACS data for 2001-2009; only BEA data there (including employment)
- NC School\education data: 260309_county_educdata. This is county-year school enrollment and expenditure data. See README_educdata for data sources and cleaning in Python. build_school_educdata creates 260309_school_educdata. build_county_educdata creates the county-year level data, summing enrollment and expenditures across schools within counties, then calculating new spending per pupil for a county-year
	- Enrollment data for 2001-2025; expenditure data for 2004-2025
*/

/*Goal for this do file:
- Make county-year panel from election data that merges in economic conditions, demographics, and education data
- Merge in region information for counties

- 

- Run a prediction/determinants model to see if these predict if and when a county switches to partisan

- Test difference in means for competitiveness, economic conditions, demographics, education for treat and control
- Test this difference after using a year FE, a region FE, and both
*/

**# Bookmark #1
*Start with county-year school election data for partisanship
use "$NC\260301_schoolboard_countyyrlevel.dta", clear
*Note that avg_vote_margin is missing when candidates ran unopposed 

*Check races in odd years
*list county if mod(year,2) != 0
*Burke, Catawba, Cleveland, Davidson, Halifax, Iredell, Mecklenburg, Orange, Randolph, Wake
*Check these non-partisan races aren't weird fake switches
*br county year partisan_yr
*Iredell has weird fake switches in 2019, 2021, 2023, 2025; check this in the election-level data
*It's because IREDELL has both the IREDELL-STATESVILLE BOE and the MOORESVILLE Graded School District BOE. Mooresville Graded School District is never partisan

*Drop all county-years in odd years because these are usually singular, weird, always non-partisan elections that will throw off summary stats when we filled in across odd years
drop if mod(year,2) != 0

*Now merge in 260310_countydemos_educ
mmerge county year using "$NC\260310_countydemos_educ.dta", ///
	type(1:1) missing(nomatch) 
/*
                 obs |   2500
                vars |    118  (including _merge)
         ------------+---------------------------------------------------------
              _merge |   1731  obs only in using data                 (code==2)
                     |    769  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
sort county year

*Do a little cleaning of demos_educ variables before filling in election-related vars
count if funds_federal_unidentified != 0
count if funds_state_unidentified != 0
count if funds_local_unidentified != 0
*2 and 6; fine to drop
drop *unidentified
*make missing expenditure data before 2004
local temp empbenefits equip other salaries services supplies total
foreach x of local temp{
	replace funds_federal_`x' = . if year < 2004
	replace funds_state_`x' = . if year < 2004
	replace funds_local_`x' = . if year < 2004
	replace funds_total_`x' = . if year < 2004
	replace spendpp_state_`x' = . if year < 2004
	replace spendpp_federal_`x' = . if year < 2004
	replace spendpp_local_`x' = . if year < 2004
	replace spendpp_total_`x' = . if year < 2004
}
local temp empbenefits equip other salaries services supplies
foreach x of local temp{
	replace spendpp_pct_`x' = . if year < 2004
}

*Use pop_bea rather than pop_total, which is from education data
drop pop_total
rename pop_bea pop

*Make logged versions of: pop, gdp, personal income, enrollment, expenditures
local temp gdp pop pers_inc enroll_total funds_federal_total funds_state_total funds_local_total funds_total_total spendpp_total_total
foreach x of local temp{
	gen ln_`x' = ln(1+`x')
}
*br if enroll_total == .
*Weirdly no schools data for Yancey in 2002, okay


*Fill in election data for missing years
br county year partisan_yr avg_cand partisan_ever year_to_partisan county_switch switch_pre2010

*fill in partisan_ever through switch_pre2010 at the county level
local temp switch_pre2010 county_switch year_to_partisan partisan_ever 
foreach x of local temp{
	gegen `x'_new = max(`x'), by(county)
	drop `x'
	rename `x'_new `x'
	order `x', after(year)
}

*fill in fips at county level
local temp fips 
foreach x of local temp{
	gegen `x'_new = max(`x'), by(county)
	drop `x'
	rename `x'_new `x'
	order `x', after(county)
}

*Now fill in race-level data: partisan_yr n_races avg_vote_margin avg_cand avg_oneparty... pctclose
sort county year
*fill in partisan_yr separately; once partisan turns on, partisan_yr always is on
gen partisan_yr_new = 1 if switch_pre2010 == 1 & inrange(year,2010,2025)
replace partisan_yr_new = 0 if partisan_ever == 0 & inrange(year,2010,2025)
replace partisan_yr_new = 1 if year >= year_to_partisan & partisan_yr_new == . & year_to_partisan != .
replace partisan_yr_new = 0 if year < year_to_partisan & partisan_yr_new == . & year_to_partisan != .
tab year if partisan_yr_new == .
*just pre-2010, good
drop partisan_yr
rename partisan_yr_new partisan
order partisan, after(year)

*When testing whether a partisan switch is predicted by previous election characteristics, create lagged election vars (basically lagged 2 years)
by county: gen temp1 = n_races[_n-2]
rename temp1 n_races_lagelec
*now do in a loop
local temp avg_vote_margin avg_cand avg_oneparty n_win_rep n_close n_close_nonpartisan n_close_partisan n_close_win_rep n_close_win_dem pct_close
foreach x of local temp{
	by county: gen `x'_lagelec = `x'[_n-2]
}

*gen lagged vars of pct_female-pct_white, ln_gdp-lnspendpp_total_total
*first rename total_total vars for length
local temp funds spendpp ln_funds ln_spendpp
foreach x of local temp{
	rename `x'_total_total `x'_tt
}

local temp pct_female pct_18over pct_65over pct_white ln_gdp ln_pop ln_pers_inc ln_enroll_total ln_funds_federal_total ln_funds_state_total ln_funds_local_total ln_funds_tt ln_spendpp_tt
foreach x of local temp{
	by county: gen `x'_lg1 = `x'[_n-1]
} 

drop _merge

*save file
save "$NC\260310_countyyr_elec_demo_educ.dta", replace

/*Only need to run this once
*Merge in region information
import delimited using "$NC\county geos\260310_county_regions.csv", varnames(1) clear
*gen numeric id for border_county_region
gegen border_county_region_id = group(border_county_region)
*save file
save "$NC\county geos\260310_county_regions.dta", replace
*/

*Go back to main file and merge in region info

use "$NC\260310_countyyr_elec_demo_educ.dta", clear
mmerge county using "$NC\county geos\260310_county_regions.dta", type(n:1) missing(nomatch)
drop _merge

*label vars
label var region_name "Region"
gen region_id = 1 if region_name == "mountains"
replace region_id = 2 if region_name == "piedmont"
replace region_id = 3 if region_name == "coastalplains"
label var region_id "Region"
label var partisan "Partisan"
label var partisan_ever "Treat"
label var county_switch "County switches post-2010"
label var avg_vote_margin_lagelec "Vote Margin"
label var avg_cand_lagelec "Num Candidates"
label var n_close_lagelec "Num Close Races"
label var pct_female_lg1 "Pct Female"
label var pct_18over_lg1 "Pct 18-over"
label var pct_65over_lg1 "Pct 65-over"
label var pct_white_lg1 "Pct White"
label var ln_gdp_lg1 "Ln(GDP)"
label var ln_pop_lg1 "Ln(Pop)"
label var ln_pers_inc_lg1 "Ln(Pers Inc)"
label var ln_enroll_total_lg1 "Ln(Pupils)"
label var ln_funds_federal_total_lg1 "Ln(School FedExp)"
label var ln_funds_state_total_lg1 "Ln(School StateExp)"
label var ln_funds_local_total_lg1 "Ln(School LocalExp)"
label var ln_funds_tt_lg1 "Ln(School Expenditures)"
label var ln_spendpp_tt_lg1 "Ln(Exp per Pupil)"
/*
label var 
label var 
label var 
label var 
label var 
label var 
label var 
label var 
label var 
label var 
label var 
*/
save "$NC\260310_countyyr_elec_demo_educ.dta", replace
export delimited using "$NC\260310_countyyr_elec_demo_educ.csv", replace

**# Bookmark #2
use "$NC\260310_countyyr_elec_demo_educ.dta", clear
**Regress Treat on lagged county characteristics**
reg partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	, vce(robust)
/*Quick takeaways, including pre2010 switching counties
- Counties are more likely to be partisan if:
	- Further east region
	- More competitive elections
	- More male
	- Higher % under 18
	- Higher % of over 65
	- Higher % White
	- Higher GDP
	- Larger population
	- Lower personal income
	- Higher spend per student
	
- Characterisics that are unrelated:
	- Num close elections
	- Funds to schools

- R2 of 0.267
*/

*What about just for counties that switch after 2010 vs. never switch?
reg partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1  ///
	if switch_pre2010 == 0 ///
	, vce(robust)
*Much weaker on the extensive margin:
/*Quick takeaways, excluding pre2010 switching counties
- Counties are more likely to be partisan if:
	- Further east region
	- More male
	- Higher % under 18
	- Higher % of over 65
	- Higher % White
	- Higher GDP
	- Larger population
	- Lower personal income
	- Higher spend per student
	
- Characterisics that are unrelated:
	- Avg vote margin
	- Num candidates
	- Num close
	- Funds to schools
- R2 of 0.308
*/

*What happens if you control for year?
reghdfe partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1  ///
	, absorb(year) vce(robust)
*Looks similar
reghdfe partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1  ///
	if switch_pre2010 == 0 ///
	, absorb(year) vce(robust)
*Looks similar

*Within region?
reghdfe partisan_ever avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1  ///
	, absorb(region_id) vce(robust)
*similar

*With region and year FEs?
reghdfe partisan_ever avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1  ///
	, absorb(region_id year) vce(robust)
*still pretty similar

*What about border counties?
reg partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1  ///
	if border_county == 1 & switch_pre2010 == 0 ///
	, vce(robust)
*Still pretty similar

*Output differences in treat:
eststo clear
eststo: qui reg partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	, vce(robust)
	estadd local sample "All"
	estadd local FE "None"
	estadd local SE "Robust"
eststo: qui reg partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	if switch_pre2010 == 0 ///
	, vce(robust)
	estadd local sample "Excl. counties treated pre-2010"
	estadd local FE "None"
	estadd local SE "Robust"
eststo: qui reghdfe partisan_ever avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	if switch_pre2010 == 0 ///
	, absorb(region_id year) vce(robust)
	estadd local sample "Excl. counties treated pre-2010"
	estadd local FE "Year, Region"
	estadd local SE "Robust"
esttab using "$DESCRIPT/260310_selection_treat_2.tex", replace t noconstant b(3) ///
	title("Determinants of partisan counties") star(* .10 ** .05 *** .01) ///
	s(N r2_a sample FE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Sample" "Fixed Effects" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps
	/*order(city_go_vote $countydemo glm_proactive state_ltgo_allowed state_go_vote)*/
	
eststo clear
eststo: qui reg partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	, vce(robust)
	estadd local sample "All"
	estadd local FE "None"
	estadd local SE "Robust"
eststo: qui reg partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	if switch_pre2010 == 0 ///
	, vce(robust)
	estadd local sample "Excl. treated pre-2010"
	estadd local FE "None"
	estadd local SE "Robust"
eststo: qui reghdfe partisan_ever avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	if switch_pre2010 == 0 ///
	, absorb(region_id year) vce(robust)
	estadd local sample "Excl. treated pre-2010"
	estadd local FE "Year, Region"
	estadd local SE "Robust"
eststo: qui reghdfe partisan_ever avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	if switch_pre2010 == 0 & border_county == 1 ///
	, absorb(region_id year) vce(robust)
	estadd local sample "Border counties; excl. treated pre-2010"
	estadd local FE "Year, Region"
	estadd local SE "Robust"
esttab using "$DESCRIPT/260310_selection_treat_3.tex", replace t noconstant b(3) ///
	title("Determinants of partisan counties") star(* .10 ** .05 *** .01) ///
	s(N r2_a sample FE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Sample" "Fixed Effects" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps
	/*order(city_go_vote $countydemo glm_proactive state_ltgo_allowed state_go_vote)*/
	
eststo clear
eststo: qui reg partisan_ever region_id /*avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec*/ ///
	pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	, vce(robust)
	estadd local sample "All"
	estadd local n_county "100"
	estadd local FE "None"
	estadd local SE "Robust"
eststo: qui reg partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	, vce(robust)
	estadd local sample "All"
	estadd local n_county "100"
	estadd local FE "None"
	estadd local SE "Robust"
eststo: qui reg partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	if switch_pre2010 == 0 ///
	, vce(robust)
	estadd local sample "Excl. pre-2010"
	estadd local n_county "86"
	estadd local FE "None"
	estadd local SE "Robust"
eststo: qui reghdfe partisan_ever avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	if switch_pre2010 == 0 ///
	, absorb(year region_id) vce(robust)
	estadd local sample "Excl. pre-2010"
	estadd local n_county "86"
	estadd local FE "Year, Region"
	estadd local SE "Robust"
esttab using "$DESCRIPT/260310_selection_treat_4.tex", replace t noconstant b(3) ///
	title("Determinants of partisan counties") star(* .10 ** .05 *** .01) ///
	s(sample n_county N r2_a FE SE, fmt(%9.0fc 3) label ("Sample" "N Counties" "N" "Adj. $ R^2$" "Fixed Effects" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec)
	
*change clustering
eststo clear
eststo: qui reg partisan_ever region_id /*avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec*/ ///
	pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	, vce(cluster fips)
	estadd local sample "All"
	estadd local n_county "100"
	estadd local FE "None"
	estadd local SE "County"
eststo: qui reg partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	,  vce(cluster fips)
	estadd local sample "All"
	estadd local n_county "100"
	estadd local FE "None"
	estadd local SE "County"
eststo: qui reg partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	if switch_pre2010 == 0 ///
	,  vce(cluster fips)
	estadd local sample "Excl. pre-2010"
	estadd local n_county "86"
	estadd local FE "None"
	estadd local SE "County"
eststo: qui reghdfe partisan_ever avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	if switch_pre2010 == 0 ///
	, absorb(year region_id)  vce(cluster fips)
	estadd local sample "Excl. pre-2010"
	estadd local n_county "86"
	estadd local FE "Year, Region"
	estadd local SE "County"
esttab using "$DESCRIPT/260310_selection_treat_5.tex", replace t noconstant b(3) ///
	title("Determinants of partisan counties") star(* .10 ** .05 *** .01) ///
	s(sample n_county N r2_a FE SE, fmt(%9.0fc 3) label ("Sample" "N Counties" "N" "Adj. $ R^2$" "Fixed Effects" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec)
	
**# Bookmark #3	
**Run Cox hazard model to test whether there's selection in timing**
*For this, exclude counties that switched before 2010
use "$NC\260310_countyyr_elec_demo_educ.dta", clear
drop if switch_pre2010 == 1

*Check correlations
pwcorr avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1, star(0.05)
*pick vote margin, # candidates, GDP, population, White, spending per pupil

*gen event indicator
gen switch = 1 if year == year_to_partisan & year_to_partisan != .
replace switch = 0 if switch == .
gen t_enter = year
gen t_exit = year+1

stset t_exit, id(fips) failure(switch==1) enter(t_enter) origin(time 2010) exit(time 2025)

*Don't use more than ~6 covariates because only have 35 switchers
eststo clear
eststo: qui stcox avg_vote_margin_lagelec avg_cand_lagelec ln_gdp_lg1 ln_pop_lg1  pct_white_lg1 ln_spendpp_tt_lg1 ///
	, cluster(fips)
	estadd local SE "County"
esttab using "$DESCRIPT/260310_cox.tex", replace eform t noconstant b(3) ///
	title("Cox hazard model for treatment timing (excluding counties treated pre-2010)") star(* .10 ** .05 *** .01) label booktabs noobs nonotes nogaps ///
	s(N SE, fmt(%9.0fc 3) label ("N" "Cluster"))
/*
Cox regression with Breslow method for ties

No. of subjects =  85                                   Number of obs =    566
No. of failures =  32
Time at risk    = 566
                                                        Wald chi2(6)  =  31.12
Log pseudolikelihood = -131.8451                        Prob > chi2   = 0.0000

                                             (Std. err. adjusted for 85 clusters in fips)
-----------------------------------------------------------------------------------------
                        |               Robust
                     _t | Haz. ratio   std. err.      z    P>|z|     [95% conf. interval]
------------------------+----------------------------------------------------------------
avg_vote_margin_lagelec |   2.752962   1.719225     1.62   0.105     .8095145    9.362151
       avg_cand_lagelec |   1.143955   .0727636     2.11   0.034     1.009872     1.29584
             ln_gdp_lg1 |   1.954447   .9317777     1.41   0.160     .7677427    4.975447
             ln_pop_lg1 |   .4556319   .3070065    -1.17   0.243     .1216386    1.706699
          pct_white_lg1 |   1.054479   .0113901     4.91   0.000     1.032389    1.077041
      ln_spendpp_tt_lg1 |   .7766004   1.686198    -0.12   0.907     .0110159    54.74867
-----------------------------------------------------------------------------------------
*/

*Test proportional hazards assumption
estat phtest, detail
/*
Test of proportional-hazards assumption

Time function: Analysis time
--------------------------------------------------------
             |        rho     chi2       df    Prob>chi2
-------------+------------------------------------------
avg_vote_m~c |    0.24372     0.92        1       0.3374
avg_cand_l~c |    0.30679     1.93        1       0.1649
  ln_gdp_lg1 |    0.00012     0.00        1       0.9996
  ln_pop_lg1 |   -0.03337     0.02        1       0.8884
pct_white_~1 |    0.22941     0.75        1       0.3875
ln_spendpp~1 |   -0.08309     0.33        1       0.5632
-------------+------------------------------------------
 Global test |                2.84        6       0.8290
--------------------------------------------------------
Note: Robust variance–covariance matrix used.

*/

*Run Cox just on border 
use "$NC\260310_countyyr_elec_demo_educ.dta", clear
gunique county if switch_pre2010 == 0
*86 counties
gunique county if switch_pre2010 == 0 & border_county == 1

drop if switch_pre2010 == 1
keep if border_county == 1

gunique county if partisan_ever == 1
*only 7 counties switch, too few
