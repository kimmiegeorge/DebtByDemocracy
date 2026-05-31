***************************
*Partisan school boards NC*
*Bring in county demos    *
*Last updated: 03/17/26   *
***************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global NC "$DATA\NC School"
global NCElec "$NC\school election data"
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
- Merge in county vote history 

- Run a prediction/determinants model to see if these predict if and when a county switches to partisan
*/

**# Bookmark #1

*First, import county vote history
import delimited using "$NCElec\260312_county_vote_history.csv", clear varn(1)

*save file
save "$NCElec\260312_county_vote_history.dta", replace

*Start with county-year school election data for partisanship
use "$NCElec\260317_schoolboard_countyyrlevel.dta", clear
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
local temp avg_vote_margin avg_cand avg_oneparty n_win_rep n_close n_close_nonpartisan n_close_partisan n_close_win_rep n_close_win_dem pct_close n_unopp pct_unopp
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
save "$NC\260317_countyyr_elec_demo_educ.dta", replace

/*Only need to run this once
*Merge in region information
import delimited using "$NC\county geos\260310_county_regions.csv", varnames(1) clear
*gen numeric id for border_county_region
gegen border_county_region_id = group(border_county_region)
*save file
save "$NC\county geos\260310_county_regions.dta", replace
*/

*Go back to main file and merge in region info

use "$NC\260317_countyyr_elec_demo_educ.dta", clear
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
label var n_unopp_lagelec "Num Unopposed"
label var pct_unopp_lagelec "Pct Unopposed" 

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
save "$NC\260317_countyyr_elec_demo_educ.dta", replace

*Merge in county vote history
use "$NC\260317_countyyr_elec_demo_educ.dta", clear
mmerge county year using "$NCElec\260312_county_vote_history.dta", type(1:1) missing(nomatch)
drop _merge
sort county year
label var pres_pct_rep "Pct Rep (Pres)"
label var us_senate_pct_rep "Pct Rep (US Senate)"
label var us_house_pct_rep "Pct Rep (US House)"
label var state_senate_pct_rep "Pct Rep (NC Senate)"
label var state_house_pct_rep "Pct Rep (NC House)"

label var avg_vote_margin  "Vote Margin"
label var avg_cand  "Num Candidates"
label var n_close  "Num Close Races"
label var pct_female  "Pct Female"
label var pct_18over  "Pct 18-over"
label var pct_65over  "Pct 65-over"
label var pct_white  "Pct White"
label var ln_gdp  "Ln(GDP)"
label var ln_pop  "Ln(Pop)"
label var ln_pers_inc  "Ln(Pers Inc)"
label var ln_enroll_total  "Ln(Pupils)"
label var ln_funds_federal_total  "Ln(School FedExp)"
label var ln_funds_state_total  "Ln(School StateExp)"
label var ln_funds_local_total  "Ln(School LocalExp)"
label var ln_funds_tt  "Ln(School Expenditures)"
label var ln_spendpp_tt  "Ln(Exp per Pupil)"

*correlations
pwcorr pres_pct_rep us_senate_pct_rep us_house_pct_rep state_senate_pct_rep state_house_pct_rep, star(0.01)
/*
             | pres_p~p us_sen~p us_hou~p state_.. state_..
-------------+---------------------------------------------
pres_pct_rep |   1.0000 
us_senate_~p |   0.9930*  1.0000 
us_house_p~p |   0.9432*  0.9308*  1.0000 
state_sena~p |   0.7910*  0.7383*  0.6572*  1.0000 
state_hous~p |   0.8373*  0.7975*  0.6843*  0.7169*  1.0000 
*/
*Super high correlation between US pres, senate, and house
*Slightly lower corr between state senate and state house; and federal vs. state. But still high

*Make 2-year lagged versions
*Could use U.S. senate because everyone's voting on the same candidates in a year, higher turnout race, not going to have an unopposed race. However, doesn't happen on a regular cycle
*Use U.S. house, every two years
by county: gen us_house_pct_rep_lagelec = us_house_pct_rep[_n-2]
label var us_house_pct_rep_lagelec "Pct Rep (US House)"

*Change Pct demographics to be divided by 100 (so using decimal places)
local temp female 18over 65over white black hispanic
foreach x of local temp{
	replace pct_`x' = pct_`x' / 100
}

local temp female 18over 65over white 
foreach x of local temp{
	replace pct_`x'_lg1 = pct_`x'_lg1 / 100
}

*test
sum pct_female
sum pct_female_lg1

*save this
save "$NC\260317_countyyr_elec_demo_educ_votehist.dta", replace

**# Bookmark #2
use "$NC\260312_countyyr_elec_demo_educ_votehist.dta", clear

**Regress Treat on lagged county characteristics**

*Output differences in treat:

*Cluster by county
eststo clear
eststo: qui reg partisan_ever region_id /*avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec us_house_pct_rep_lagelec */ ///
	pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 /*ln_funds_federal_total_lg1 ln_funds_state_total_lg1*/ ///
	/*ln_funds_local_total_lg1*/ ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	, vce(cluster fips)
	estadd local sample "All"
	estadd local n_county "100"
	estadd local FE "None"
	estadd local SE "County"
eststo: qui reg partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	us_house_pct_rep_lagelec /*pct_18over_lg1 pct_65over_lg1*/ pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 /*ln_funds_federal_total_lg1 ln_funds_state_total_lg1*/ ///
	/*ln_funds_local_total_lg1*/ ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	,  vce(cluster fips)
	estadd local sample "All"
	estadd local n_county "100"
	estadd local FE "None"
	estadd local SE "County"
eststo: qui reg partisan_ever region_id avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	us_house_pct_rep_lagelec /*pct_18over_lg1 pct_65over_lg1*/ pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 /*ln_funds_federal_total_lg1 ln_funds_state_total_lg1*/ ///
	/*ln_funds_local_total_lg1*/ ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	if switch_pre2010 == 0 ///
	,  vce(cluster fips)
	estadd local sample "Excl. pre-2010"
	estadd local n_county "86"
	estadd local FE "None"
	estadd local SE "County"
eststo: qui reghdfe partisan_ever avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec ///
	us_house_pct_rep_lagelec /*pct_18over_lg1 pct_65over_lg1*/ pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 /*ln_funds_federal_total_lg1 ln_funds_state_total_lg1*/ ///
	/*ln_funds_local_total_lg1*/ ln_funds_tt_lg1 ln_spendpp_tt_lg1 ///
	if switch_pre2010 == 0 ///
	, absorb(year region_id)  vce(cluster fips)
	estadd local sample "Excl. pre-2010"
	estadd local n_county "86"
	estadd local FE "Year, Region"
	estadd local SE "County"
esttab using "$DESCRIPT/260312_selection_treat_3.tex", replace t noconstant b(3) ///
	title("Determinants of partisan counties") star(* .10 ** .05 *** .01) ///
	s(sample n_county N r2_a FE SE, fmt(%9.0fc 3) label ("Sample" "N Counties" "N" "Adj. $ R^2$" "Fixed Effects" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes nogaps ///
	order(avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec us_house_pct_rep_lagelec)
	
pwcorr avg_vote_margin avg_cand, star(0.01)	
*-0.6325, significant. Makes sense to have negative coefficient - higher vote margin and lower # candidates both mean lower competitiveness.
	
**# Bookmark #3	
**Run Cox hazard model to test whether there's selection in timing**
*For this, exclude counties that switched before 2010
use "$NC\260312_countyyr_elec_demo_educ_votehist.dta", clear
drop if switch_pre2010 == 1

tab partisan if partisan_ever == 0
count if partisan_ever == 0
*1,275
tab year if partisan_ever == 0 & partisan == .
*pre 2010; so, do want the partisan === 0 filter
tab year if partisan_ever == 1 & partisan == .
tab partisan if year == 2008
*Partisan should be 0 in all years for partisan_ever == 0
*br county fips year partisan partisan_ever
replace partisan = 0 if partisan == . & partisan_ever == 0

*Check correlations
pwcorr avg_vote_margin_lagelec avg_cand_lagelec n_close_lagelec us_house_pct_rep_lagelec  ///
	pct_female_lg1 pct_18over_lg1 pct_65over_lg1 pct_white_lg1 ln_gdp_lg1 ln_pop_lg1 ///
	ln_pers_inc_lg1 ln_funds_federal_total_lg1 ln_funds_state_total_lg1 ///
	ln_funds_local_total_lg1 ln_funds_tt_lg1 ln_spendpp_tt_lg1, star(0.01)
*pick vote margin, # candidates, GDP, population, White, spending per pupil

*gen event indicator
gen switch = 1 if year == year_to_partisan & year_to_partisan != .
replace switch = 0 if switch == .
gen t_enter = year
gen t_exit = year+1

stset t_exit, id(fips) failure(switch==1) enter(t_enter) origin(time 2010) exit(time 2025)

*Don't use more than ~6 covariates because only have 35 switchers
eststo clear
eststo: qui stcox avg_vote_margin_lagelec avg_cand_lagelec us_house_pct_rep_lagelec ln_gdp_lg1 ln_pop_lg1 pct_white_lg1 ln_spendpp_tt_lg1 ///
	, cluster(fips)
	estadd local SE "County"
esttab using "$DESCRIPT/260312_cox.tex", replace eform t noconstant b(3) ///
	title("Cox hazard model for treatment timing (excluding counties treated pre-2010)") star(* .10 ** .05 *** .01) label booktabs noobs nonotes nogaps ///
	s(N SE, fmt(%9.0fc 3) label ("N" "Cluster"))
/*
Cox regression with Breslow method for ties

No. of subjects =  85                                   Number of obs =    566
No. of failures =  32
Time at risk    = 566
                                                        Wald chi2(7)  =  41.45
Log pseudolikelihood = -130.83016                       Prob > chi2   = 0.0000

                                              (Std. err. adjusted for 85 clusters in fips)
------------------------------------------------------------------------------------------
                         |               Robust
                      _t | Haz. ratio   std. err.      z    P>|z|     [95% conf. interval]
-------------------------+----------------------------------------------------------------
 avg_vote_margin_lagelec |    3.13461   1.980971     1.81   0.071     .9083479     10.8172
        avg_cand_lagelec |   1.142219    .070965     2.14   0.032     1.011265     1.29013
us_house_pct_rep_lagelec |   14.96176   16.22018     2.50   0.013     1.787259    125.2501
              ln_gdp_lg1 |   2.109959   1.034188     1.52   0.128      .807348     5.51426
              ln_pop_lg1 |   .5031015    .343078    -1.01   0.314     .1321901     1.91475
           pct_white_lg1 |   80.49261   96.31625     3.67   0.000     7.712959    840.0227
       ln_spendpp_tt_lg1 |    2.82842   5.703234     0.52   0.606     .0543474    147.2004
------------------------------------------------------------------------------------------
*/

*Test proportional hazards assumption
estat phtest, detail
/*
Test of proportional-hazards assumption

Time function: Analysis time
--------------------------------------------------------
             |        rho     chi2       df    Prob>chi2
-------------+------------------------------------------
avg_vote_m~c |    0.21622     0.78        1       0.3769
avg_cand_l~c |    0.30180     1.81        1       0.1785
us_house_p~c |   -0.03861     0.01        1       0.9178
  ln_gdp_lg1 |   -0.01177     0.00        1       0.9587
  ln_pop_lg1 |   -0.01047     0.00        1       0.9637
pct_white_~1 |    0.18078     0.55        1       0.4584
ln_spendpp~1 |   -0.05325     0.09        1       0.7657
-------------+------------------------------------------
 Global test |                2.43        7       0.9321
--------------------------------------------------------
Note: Robust variance–covariance matrix used.

*/

*Difference in means, treat vs. control, treated post 2010

*Note that the below groups by county rather than by county-year
eststo clear
eststo treat: estpost sum ///
	avg_vote_margin  avg_cand  n_close  ///
	us_house_pct_rep pct_white  ln_gdp  ln_pop  ///
	ln_pers_inc  ln_funds_federal_total  ln_funds_state_total  ///
	ln_funds_local_total  ln_funds_tt  ln_spendpp_tt  ///
	if partisan_ever == 1, d
eststo control: estpost sum ///
	avg_vote_margin  avg_cand  n_close  ///
	us_house_pct_rep pct_white  ln_gdp  ln_pop  ///
	ln_pers_inc  ln_funds_federal_total  ln_funds_state_total  ///
	ln_funds_local_total  ln_funds_tt  ln_spendpp_tt  ///
	if partisan_ever == 0, d
eststo diff: estpost ttest ///
	avg_vote_margin  avg_cand  n_close  ///
	us_house_pct_rep pct_white  ln_gdp  ln_pop  ///
	ln_pers_inc  ln_funds_federal_total  ln_funds_state_total  ///
	ln_funds_local_total  ln_funds_tt  ln_spendpp_tt  ///
	, by(partisan_ever) unequal
esttab treat control diff using "$DESCRIPT\260312_diffmeans.tex", replace label subs("$ " "$" \_ _) title(Differences in means for partisan and non-partisan counties (excluding treated by 2010)) ///
	cells("mean(pattern(1 1 0) fmt(%9.2fc)) b(star pattern(0 0 1) fmt(%9.2fc)) t(pattern(0 0 1) par fmt(2))") 


/*
	mgroups("Partisan" "Non-partisan", pattern(1 0 1 0 0 0) ///
	prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) 
*/

*To run differences within a FE structure with clustered SE:
*Regress the variable on treat, with the FE structure and clustered SE. The coefficient on treat will be the difference, with resulting t-stats
local temp avg_vote_margin avg_cand n_close	us_house_pct_rep pct_white  ///
	ln_gdp  ln_pop  ln_pers_inc  ln_funds_federal_total  ln_funds_state_total  ///
	ln_funds_local_total  ln_funds_tt  ln_spendpp_tt  
	
foreach x of local temp{
	reghdfe `x' partisan_ever, absorb(region_id year) vce(cluster county)
}

/* var / coeff / t-stat / p-value
- avg_vote_margin / -0.073 / -1.44 / 0.153
- avg_cand / -0.036 / -0.08 / 0.938
- n_close / 0.033 / 0.35 / 0.725
- us_house_pct_rep / 0.126 / 4.64 / 0.000
- pct_white / 0.106 / 4.13 / 0.000
- ln_gdp / 0.003 / 0.01 / 0.991
- ln_pop / -0.022 / -0.10 / 0.918
- ln_pers_inc / 0.019 / 0.08 / 0.935
- ln_funds_federal_total / -0.065 / -0.31 / 0.756
- ln_funds_state_total / 0.003 / 0.01 / 0.990
- ln_funds_local_total / 0.062 / 0.26 / 0.798
- ln_funds_tt / 0.000 / 0.00 / 0.998
- ln_spendpp_tt / -0.008 / -0.22 / 0.823
*/

*Do for partisan county-years
eststo clear
eststo treat: estpost sum ///
	avg_vote_margin  avg_cand  n_close  ///
	us_house_pct_rep pct_white  ln_gdp  ln_pop  ///
	ln_pers_inc  ln_funds_federal_total  ln_funds_state_total  ///
	ln_funds_local_total  ln_funds_tt  ln_spendpp_tt  ///
	if partisan == 1, d
eststo control: estpost sum ///
	avg_vote_margin  avg_cand  n_close  ///
	us_house_pct_rep pct_white  ln_gdp  ln_pop  ///
	ln_pers_inc  ln_funds_federal_total  ln_funds_state_total  ///
	ln_funds_local_total  ln_funds_tt  ln_spendpp_tt  ///
	if partisan == 0, d
eststo diff: estpost ttest ///
	avg_vote_margin  avg_cand  n_close  ///
	us_house_pct_rep pct_white  ln_gdp  ln_pop  ///
	ln_pers_inc  ln_funds_federal_total  ln_funds_state_total  ///
	ln_funds_local_total  ln_funds_tt  ln_spendpp_tt  ///
	, by(partisan) unequal
esttab treat control diff using "$DESCRIPT\260312_diffmeans_partisancountyyr.tex", replace label subs("$ " "$" \_ _) title(Differences in means for partisan and non-partisan county-years (excluding treated by 2010)) ///
	cells("mean(pattern(1 1 0) fmt(%9.2fc)) b(star pattern(0 0 1) fmt(%9.2fc)) t(pattern(0 0 1) par fmt(2))") 

*Do for partisan counties vs. non-partisan counties in NON-partisan election years
eststo clear
eststo treat: estpost sum ///
	avg_vote_margin  avg_cand  n_close  ///
	us_house_pct_rep pct_white  ln_gdp  ln_pop  ///
	ln_pers_inc  ln_funds_federal_total  ln_funds_state_total  ///
	ln_funds_local_total  ln_funds_tt  ln_spendpp_tt  ///
	if partisan_ever == 1 & partisan == 0, d
eststo control: estpost sum ///
	avg_vote_margin  avg_cand  n_close  ///
	us_house_pct_rep pct_white  ln_gdp  ln_pop  ///
	ln_pers_inc  ln_funds_federal_total  ln_funds_state_total  ///
	ln_funds_local_total  ln_funds_tt  ln_spendpp_tt  ///
	if partisan_ever == 0 & partisan == 0, d
eststo diff: estpost ttest ///
	avg_vote_margin  avg_cand  n_close  ///
	us_house_pct_rep pct_white  ln_gdp  ln_pop  ///
	ln_pers_inc  ln_funds_federal_total  ln_funds_state_total  ///
	ln_funds_local_total  ln_funds_tt  ln_spendpp_tt  ///
	if partisan == 0, by(partisan_ever) unequal
esttab treat control diff using "$DESCRIPT\260316_diffmeans_nonpartisanyrs.tex", replace label subs("$ " "$" \_ _) title(Differences in means for partisan and non-partisan counties in 'pre-period' (excluding treated by 2010)) ///
	cells("mean(pattern(1 1 0) fmt(%9.2fc)) b(star pattern(0 0 1) fmt(%9.2fc)) t(pattern(0 0 1) par fmt(2))") 
	

*To run differences within a FE structure with clustered SE:
*Regress the variable on treat, with the FE structure and clustered SE. The coefficient on treat will be the difference, with resulting t-stats
local temp avg_vote_margin avg_cand n_close	us_house_pct_rep pct_white  ///
	ln_gdp  ln_pop  ln_pers_inc  ln_funds_federal_total  ln_funds_state_total  ///
	ln_funds_local_total  ln_funds_tt  ln_spendpp_tt  
	
foreach x of local temp{
	reghdfe `x' partisan_ever if partisan == 0, absorb(region_id year) vce(cluster county)
}

/* var / coeff / t-stat / p-value
- avg_vote_margin / -0.025 / -0.42 / 0.675
- avg_cand / 0.396 / 0.76 / 0.452
- n_close / 0.054 / 0.58 / 0.565
- us_house_pct_rep / 0.127 / 4.93 / 0.000
- pct_white / 0.102 / 4.30 / 0.000
- ln_gdp / -0.015 / -0.06 / 0.955
- ln_pop / -0.031 / -0.15 / 0.881
- ln_pers_inc / 0.008 / 0.04 / 0.971
- ln_funds_federal_total / -0.078 / -0.38 / 0.702
- ln_funds_state_total / -0.003 / -0.02 / 0.987
- ln_funds_local_total / 0.022 / 0.09 / 0.925
- ln_funds_tt / -0.012 / -0.06 / 0.953
- ln_spendpp_tt / -0.007 / -0.22 / 0.824
*/
