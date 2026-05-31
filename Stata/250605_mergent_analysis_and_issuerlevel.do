***************************************
*Voting on bonds                      *
*Broad sample tests + issuer-level %GO*
*Last updated: 06/05/25               *
***************************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global DESCRIPT "$MAIN\Descriptives"
global RESULTS "$MAIN\Results\2025-06_bondlevel"

***Start with bond-level Mergent data with state voting requirements***
use "$MERGENT\Clean\250605_citycountyschool_cusiplevel_statereq_purpose.dta", clear

*drop schools and counties
tab issuer_type
/*
Issuer type |      Freq.     Percent        Cum.
------------+-----------------------------------
       city |    328,206       44.93       44.93
     county |     91,232       12.49       57.42
     school |    311,019       42.58      100.00
------------+-----------------------------------
      Total |    730,457      100.00
*/

*given cities are most of the sample (besides schools), keep just cities for now
keep if issuer_type == "city"
*drop hawaii because no city concept
drop if state == "HI"

*number of issuers
gunique seed_issuer
*N = 328,201; 5,900 unbalanced groups of sizes 1 to 1,681
count if go_unlim == 1 
*196,760

tab city_go_vote
/*
    City GO |
       vote |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |     72,555       35.27       35.27
          1 |    133,157       64.73      100.00
------------+-----------------------------------
      Total |    205,712      100.00
*/

tab city_rev_vote
/*
   City rev |
       vote |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    239,012       93.89       93.89
          1 |     15,557        6.11      100.00
------------+-----------------------------------
      Total |    254,569      100.00
*/

*States that have a clear revenue bond voting requirement are fundamentally different from states that do not
*Throughout analyses, focus on the states that do NOT have a clear revenue bond voting requirement
*When using city_rev_vote == 0 as a filter: vote_req turns on if the bond is GO and in a state with GO requirement. city_go_vote will turn on for both GO and rev bonds if the state has a GO requirement


**Quick descriptives**
**High-level table with how much each state law type contributes to the sample
gunique seed_issuer if city_go_vote == 1 & city_rev_vote == 0
count if city_go_vote == 1 & city_rev_vote == 0
count if city_go_vote == 1 & city_rev_vote == 0 & go_unlim == 1
*38,969
gunique seed_issuer if city_go_vote == 1 & city_rev_vote == 0 & go_unlim == 1
*1,173 seed issuers; 38,969 obs
count if city_go_vote == 1 & city_rev_vote == 0 & go_lim == 1
count if city_go_vote == 1 & city_rev_vote == 0 & bond_type == "rev"

*UTGO vote only
gunique seed_issuer if inlist(state, "WA", "MI", "OH")
count if inlist(state, "WA", "MI", "OH") 
count if inlist(state, "WA", "MI", "OH") & go_unlim == 1
count if inlist(state, "WA", "MI", "OH") & go_lim == 1
count if inlist(state, "WA", "MI", "OH") & bond_type == "rev"
gen utgo_only = 1 if inlist(state, "WA", "MI", "OH") 

*GO vote required but rev vote required or depends
gen temp1 = 1 if inlist(state,"CA","AZ","CO","ID","ND","SD")
replace temp1 = 1 if inlist(state,"OK","AL","VT","ME","RI")
gunique seed_issuer if temp1 == 1
count if temp1 == 1
count if temp1 == 1 & go_unlim == 1
count if temp1 == 1 & go_lim == 1
count if temp1 == 1 & bond_type == "rev"
drop temp1
*another way to count this group
gunique seed_issuer if city_go_vote == 1 & city_rev_vote != 0
*577 issuers
list state if city_go_vote == 1 & city_rev_vote != 0 & temp1 != 1
br if state == "AR"
count if go_unlim == 1 & city_go_vote == 1 & city_rev_vote != 0
*12,347
count if rev == 1 & city_go_vote == 1 & city_rev_vote != 0

*no GO vote and no rev vote
gunique seed_issuer if city_go_vote == 0 & city_rev_vote == 0
count if city_go_vote == 0 & city_rev_vote == 0
count if city_go_vote == 0 & city_rev_vote == 0 & go_unlim == 1
gunique seed_issuer if city_go_vote == 0 & city_rev_vote == 0 & go_unlim == 1
*1,011 seed issuers; 45,027 obs
count if city_go_vote == 0 & city_rev_vote == 0 & go_lim == 1
count if city_go_vote == 0 & city_rev_vote == 0 & bond_type == "rev"

*Total UTGO vote and no vote sample:
*Vote: 1,173 issuers; 38,969 obs
*No vote: 1,011 issuers, 45,027 bonds
*Total: 2,184 issuers; 

*light purple: GO vote req varies within state
gen temp1 = 1 if inlist(state,"NV","KS","MN","IL","SC","VA")
replace temp1 = 1 if inlist(state,"PA", "NY","MD","DE","CT")
gunique seed_issuer if temp1 == 1
count if temp1 == 1
count if temp1 == 1 & go_unlim == 1
count if temp1 == 1 & go_lim == 1
count if temp1 == 1 & bond_type == "rev"
tab state if go_unlim == 1 & temp1 == 1
/*It's coming from MN, NY, CT and IL

      state |      Freq.     Percent        Cum.
------------+-----------------------------------
         CT |     14,995       14.93       14.93
         DE |        136        0.14       15.07
         IL |     12,388       12.34       27.40
         KS |      9,320        9.28       36.69
         MD |        947        0.94       37.63
         MN |     26,419       26.31       63.94
         NV |         99        0.10       64.04
         NY |     24,905       24.80       88.84
         PA |      7,153        7.12       95.96
         SC |        911        0.91       96.87
         VA |      3,144        3.13      100.00
------------+-----------------------------------
      Total |    100,417      100.00


*/
drop temp1


***Bring in indicator for matched to RavenPack***
*Note in original mapping, there are some dups by seed_issuer because there are multiple RP entity IDs that get matched
*This is fine, just after converting mapping from CSV to DTA, gen rp_match indicator and duplicates drop
mmerge seed_issuer_id using "$DATA\News\RP_Mergent_Mapping.dta", type(n:1) missing(nomatch)
/*
                 obs | 328230
                vars |    225  (including _merge)
         ------------+---------------------------------------------------------
              _merge |  90033  obs only in master data                (code==1)
                     |     29  obs only in using data                 (code==2)
                     | 238168  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
drop if _merge == 2
drop _merge

sort state seed_issuer year issue_id cusip
replace rp_match = 0 if rp_match == .

**Summary stats**
*label purpose vars
label var purp_broad_arts "Arts" 
label var purp_broad_econdev "Econ dev"
label var purp_broad_educ "Education" 
label var purp_broad_genpubimprov "Gen pub improv"
label var purp_broad_health "Healthcare" 
label var purp_broad_housing "Housing"
label var purp_broad_justice "Justice"
label var purp_broad_other "Other"
label var purp_broad_parksrec "Parks \& rec"
label var purp_broad_pubbldg "Public building" 
label var purp_broad_safety "Safety"
label var purp_broad_transport "Transport"
label var purp_broad_utilities "Utilities"
label var purp_broad_wtrswr "Water \& sewer"
label var go_unlim "GO bond"

**Bond-level summary stats**
*gen temp var for having non-missing controls
gen hascontrols = 1 if offering_yield_tr != . & ln_amount_tr != . & ln_maturity_tr != .

eststo clear
eststo: estpost sum city_go_vote offering_yield_tr ln_amount_tr ln_maturity_tr callable sinkable insured rated ///
	state_go_vote state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	/* purp_broad_genpubimprov purp_broad_pubbldg purp_broad_transport ///
	purp_broad_educ purp_broad_health purp_broad_arts purp_broad_parksrec ///
	purp_broad_econdev	purp_broad_housing purp_broad_safety purp_broad_justice	///
	purp_broad_utilities purp_broad_wtrswr purp_broad_other */ ///
	if city_rev_vote == 0 & city_go_vote != . & go_unlim == 1 & hascontrols == 1 , d
esttab using "$DESCRIPT\Bondlevel\250605_bondlevel_sumstats.tex", replace ///
	title("Summary statistics") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	

sum amount_tr if city_rev_vote == 0 & city_go_vote != . & go_unlim == 1 & hascontrols == 1
*560,104
sum maturity_mths_tr if city_rev_vote == 0 & city_go_vote != . & go_unlim == 1 & hascontrols == 1
*109 months

	
**# Bookmark #1
***New outputs***
*Look just at UTGO
*Use city_go_vote because it's the cleanest and easiest to explain
*Show all controls
*Flex no FEs or all FEs 
*Cluster by state or issuance

**Build up to specification**
eststo clear
eststo: qui reg offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated ///
	state_go_vote state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	,  vce(cluster state)
	estadd local timeFE "No"
	estadd local purposeFE "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated ///
	state_go_vote state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated ///
	state_go_vote state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"		

esttab using "$RESULTS/250605_city_yield_UTGO.tex", replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 

**# Bookmark #2
***At issuer-level, think about proportion of UTGO, LTGO, REV bonds***
*Want to control for all the debt issued within that county. Go back to main sample, gen that var, then drop county/school again*

use "$MERGENT\Clean\250605_citycountyschool_cusiplevel_statereq_purpose.dta", clear
drop if state == "HI"

*gen var for total debt raised within a county 2000-2020
br seed_issuer offering_date amount fips
tab year
gegen county_debt = sum(amount), by(fips)
*gen additional vars for total UTGO debt, LTGO debt, and REV debt raised in a county
gegen county_utgo = sum(amount) if go_unlim == 1, by(fips)
gegen county_ltgo = sum(amount) if go_lim == 1, by(fips)
gegen county_rev = sum(amount) if rev == 1, by(fips)

*make lns
local temp debt utgo ltgo rev
foreach x of local temp{
	replace county_`x' = 0 if county_`x' == .
	gen ln_county_`x' = ln(1+county_`x')
}

*then drop to cities only
keep if issuer_type == "city"	

*gen total amounts by cities
gegen city_debt = sum(amount), by(seed_issuer)
gegen city_utgo = sum(amount) if go_unlim == 1, by(seed_issuer)
gegen city_ltgo = sum(amount) if go_lim == 1, by(seed_issuer)
gegen city_rev = sum(amount) if rev == 1, by(seed_issuer)
*make lns
local temp debt utgo ltgo rev
foreach x of local temp{
	replace city_`x' = 0 if city_`x' == .
	gen ln_city_`x' = ln(1+city_`x')
}

*for collapse, don't include county and state demos for now
*don't want the county/state demos to be weighted based on # or timing of issuances
*merge in beginning-period county/state demos separately after collapse

*collapse to issuer level, getting avg of the county demos
gcollapse (max) county_debt county_utgo county_ltgo county_rev ln_county_debt ///
	ln_county_utgo ln_county_ltgo ln_county_rev city_debt city_utgo city_ltgo city_rev ///
	ln_city_debt ln_city_utgo ln_city_ltgo ln_city_rev ///
	, by(seed_issuer seed_issuer_id fips state state_name city_go_vote city_rev_vote state_go_vote state_utgo_allowed state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien)

sort state seed_issuer

*make LTGO, UTGO, REV percentages
gen frac_utgo = city_utgo / city_debt
gen frac_ltgo = city_ltgo / city_debt
gen frac_rev = city_rev / city_debt

sum frac_utgo frac_ltgo frac_rev
/*
    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
   frac_utgo |      6,049    .5724917    .4449643          0          1
   frac_ltgo |      6,049    .1190781      .29188          0          1
    frac_rev |      6,049    .2949129    .4067944          0          1
*/
*only between 0 and 1, good

*make indicators for categories of states in the map
*only want to compare control (no vote) with UTGO vote only OR all GO vote only
gen control = 1 if city_go_vote == 0 & city_rev_vote == 0
gen utgo_only = 1 if inlist(state, "WA", "MI", "OH") 
gen allgo_only = 1 if inlist(state, "OR","MT","WY","UT","NM","AK","TX","NE")
replace allgo_only = 1 if inlist(state,"IA","MO","LA","GA","FL","NC","WV")

local temp control utgo_only allgo_only
foreach x of local temp{
	replace `x' = 0 if `x' == .
}

gen insample = 1 if control == 1 | utgo_only == 1 | allgo_only == 1
replace insample = 0 if insample == .

tab control
*20.5% control; 1,242 issuers
tab utgo_only
*11.6% UTGO only; 699 issuers
tab allgo_only
*23.5% all GO only; 1,422 issuers
tab insample
*55.58% in sample; 3,363 issuers

*make vars for other debt raised in the same county, but not by the issuer
gen county_debt_other = county_debt - city_debt
gen ln_county_debt_other = ln(1+county_debt_other)
*br if ln_county_debt_other == .
*sometimes these are negative because a few issuers are in multiple fips, annoying, but ignore for now

*is it the case that the % debt are similar to in the graphs?
sum frac_utgo frac_ltgo frac_rev if control == 1
/*
    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
   frac_utgo |      1,242    .6665012    .4082024          0          1
   frac_ltgo |      1,242    .1099341    .2681741          0          1
    frac_rev |      1,242    .2064491    .3596099          0          1
*/
*benchmark: 21% rev, 11% LTGO, 67% UTGO
sum frac_utgo frac_ltgo frac_rev if utgo_only == 1
/*
    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
   frac_utgo |        699    .2772935    .3955166          0          1
   frac_ltgo |        699    .5412233    .4303219          0          1
    frac_rev |        699    .1736446    .3268017          0          1
*/
*UTGO only: LTGO jumps to 54%, that takes from UTGO, which falls to 28%
sum frac_utgo frac_ltgo frac_rev if allgo_only == 1
/*
    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
   frac_utgo |      1,422    .4624045    .4505339          0          1
   frac_ltgo |      1,422    .1028385    .2712557          0          1
    frac_rev |      1,422    .4124344    .4351927          0          1
*/
*All GO: Rev jumps to 41%, LTGO doesn't change compared to benchmark; UTGO falls to 46%
*So this is all consistent with the pie charts

*merge in beginning-period (2002 earliest) county and state demos
/*Only have to run once
*county vars
use "$BEA\employment_2001_2022.dta", clear


*state demos
use "$BEA\state_gdp_2001_2022.dta", clear
mmerge state_name year using "$BEA\state_persinc_2001_2022.dta", type(1:1) missing(nomatch)
drop _merge
mmerge state_name year using "$BEA\state_percap_inc_2001_2022.dta", type(1:1) missing(nomatch)
drop _merge
mmerge state_name year using "$BEA\state_employment_2001_2022.dta", type(1:1) missing(nomatch)
drop _merge
save "$BEA\state_demos_2001_2022.dta", replace
keep if year == 2001
save "$BEA\state_demos_2001.dta", replace
	
*county demos
use "$BEA\employment_2001_2022.dta", clear
mmerge fips year using "$BEA\gdp_2001_2022.dta", type(1:1) missing(nomatch)
keep if _merge == 3
drop _merge
mmerge fips year using "$BEA\percap_inc_2001_2022.dta", type(1:1) missing(nomatch)
keep if _merge == 3
drop _merge
mmerge fips year using "$BEA\pers_inc_2001_2022.dta", type(1:1) missing(nomatch)
keep if _merge == 3
drop _merge	
mmerge fips year using "$BEA\pop_2001_2022.dta", type(1:1) missing(nomatch)
keep if _merge == 3
drop _merge	
*save
save "$BEA\countydemos_2001_2022.dta", replace
keep if year == 2001
save "$BEA\countydemos_2001.dta", replace
*/

*merge in county demos from 2001
mmerge fips using "$BEA\countydemos_2001.dta", type(n:1) missing(nomatch)
/*
                vars |     47  (including _merge)
         ------------+---------------------------------------------------------
              _merge |     21  obs only in master data                (code==1)
                     |   1447  obs only in using data                 (code==2)
                     |   6028  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*browse if only in master
*br if _merge == 1
*these seem to be cities in virginia that don't have county governments
*ignore for now

/*Before, with incorrect fips:
*some of these fips are just incorrect, which is really annoying
*it's like the original digits were scrambled
*save list of incorrect FIPS; hand-fix
preserve
keep if _merge == 1
keep seed_issuer seed_issuer_id fips state 
save "$BEA\250605_fips_tofix.dta", replace
restore
*/

drop if _merge == 2
drop _merge

*merge in state demos from 2001
mmerge state_name using "$BEA\state_demos_2001.dta", type(n:1) missing(nomatch)
*DC and HI not matched, as expected
drop if _merge == 2
drop _merge

*make ln's of state and county demos
rename state_persinc state_pers_inc
rename (employment state_employment) (emp state_emp)
local temp emp gdp percap_inc pers_inc
foreach x of local temp{
	gen ln_`x' = ln(1+`x')
}
local temp emp gdp percap_inc pers_inc
foreach x of local temp{
	gen ln_state_`x' = ln(1+state_`x')
}

gen ln_pop = ln(1+pop)

**# Bookmark #1
*Now explore regs where outcome var is % of GO or Rev

*Make globals for controls
global statedemo ln_state_gdp ln_state_emp ln_state_percap_inc ln_state_pers_inc
global countydemo ln_pop ln_gdp ln_emp /*ln_percap_inc*/ ln_pers_inc
global statecitydebt state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien

*first check city_go_vote for UTGO only
tab city_go_vote if utgo_only == 1
*these are set to 1, good

*Kimmie's code regresses % GO or Rev on: city_go_vote, state GO vote, state regulations, amount raised, county demos
**# Bookmark #2
**First compare between benchmark and UTGO only**
gen insample_utgo_only = 1 if control == 1 | utgo_only == 1
replace insample_utgo_only = 0 if insample_utgo_only == .

*Simplest reg
reg frac_ltgo city_go_vote if insample_utgo_only == 1, vce(cluster state)
*coeff=0.431, p=0.001
reg frac_ltgo city_go_vote if insample_utgo_only == 1, vce(cluster fips)
*coeff=0.431, p=0
	
*Add state demo controls
reg frac_ltgo city_go_vote $statedemo ///
	if insample_utgo_only == 1, vce(cluster state)
*coeff = 0.478, p=0

*Add county demo controls
reg frac_ltgo city_go_vote $statedemo $countydemo ///
	if insample_utgo_only == 1, vce(cluster state)
*coeff = 0.452, p=0

*Control for other debt raised in the county
reg frac_ltgo city_go_vote ///
	ln_county_debt_other $statedemo $countydemo ///
	if insample_utgo_only == 1, vce(cluster state)	
*coeff = 0.464, p=0

*Control for state go vote
reg frac_ltgo city_go_vote ///
	state_go_vote ln_county_debt_other ///
	$statedemo $countydemo ///
	if insample_utgo_only == 1, vce(cluster state)	
*coeff = 0.472, p=0
	
*Control for other state vars	
reg frac_ltgo city_go_vote ///
	state_go_vote $statecitydebt ln_county_debt_other ///
	$statedemo $countydemo ///
	if insample_utgo_only == 1, vce(cluster state)	
/*
Linear regression                               Number of obs     =      1,927
                                                F(4, 10)          =          .
                                                Prob > F          =          .
                                                R-squared         =     0.4200
                                                Root MSE          =     .30223

                                               (Std. err. adjusted for 11 clusters in state)
--------------------------------------------------------------------------------------------
                           |               Robust
                 frac_ltgo | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |    .112413    .006541    17.19   0.000     .0978388    .1269871
             state_go_vote |    .082717   .0099175     8.34   0.000     .0606195    .1048145
        state_ltgo_allowed |   .4264949   .0081396    52.40   0.000     .4083587    .4446311
           state_fullfaith |   .4427989   .0146272    30.27   0.000     .4102076    .4753903
state_sep_debtservice_levy |  -.0377555   .0029694   -12.71   0.000    -.0443718   -.0311393
       state_sep_pledgerev |  -.0959799   .0046481   -20.65   0.000    -.1063364   -.0856233
       state_statutorylien |   -.078028   .0074254   -10.51   0.000    -.0945728   -.0614833
      ln_county_debt_other |   .0025739   .0016731     1.54   0.155     -.001154    .0063019
              ln_state_gdp |  -1.145451   .1379615    -8.30   0.000    -1.452848   -.8380533
              ln_state_emp |   1.261408   .1439732     8.76   0.000     .9406159    1.582201
       ln_state_percap_inc |   .5410821   .0864878     6.26   0.000     .3483754    .7337888
         ln_state_pers_inc |          0  (omitted)
                    ln_gdp |  -.0231147   .0668909    -0.35   0.737    -.1721569    .1259275
                    ln_emp |  -.0213829   .0994286    -0.22   0.834    -.2429237    .2001578
             ln_percap_inc |  -.0971424   .0695524    -1.40   0.193    -.2521147    .0578299
               ln_pers_inc |   .0637234   .0460098     1.38   0.196    -.0387929    .1662396
                     _cons |  -10.03148   .9936612   -10.10   0.000     -12.2455   -7.817465
--------------------------------------------------------------------------------------------
*/

reg frac_ltgo city_go_vote ///
	state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	/*state_go_vote*/ ln_county_debt_other ///
	$statedemo $countydemo ///
	if insample_utgo_only == 1, vce(cluster state)	
*sensitive to whether state_go_vote and state_ltgo_allowed are included together or separately
*coeff is negative and significant when state_ltgo_allowed is excluded but state_go_vote is included
*coeff is pos and sig when both are included
*coeff is pos and sig when state_go_vote and state_ltgo_allowed are both excluded
*coeff is pos and sig when state_ltgo_allowed is included but state_go_vote is excluded

pwcorr state_go_vote state_ltgo_allowed, star(0.01)
*0.1715*
pwcorr state_go_vote state_ltgo_allowed if insample_utgo_only == 1, star(0.01)
*0.1129*
pwcorr state_go_vote $statecitydebt if insample_utgo_only == 1, star(0.01) 
/*
             | state~te s~ltgo~d state_~h state_~y state_~v state_~n
-------------+------------------------------------------------------
state_go_v~e |   1.0000 
state_ltgo~d |   0.1129*  1.0000 
state_full~h |  -0.3098* -0.2728*  1.0000 
state_sep_~y |   0.0097   0.3606* -0.2461*  1.0000 
state_sep_~v |   0.1295* -0.1154*  0.2947*  0.4008*  1.0000 
state_stat~n |   0.4353*  0.3833*  0.1463*  0.3459*  0.4963*  1.0000 
*/
tab state_go_vote if insample_utgo_only == 1
*50/50
tab state_ltgo_allowed if insample_utgo_only == 1
*58% yes

tab state_go_vote if utgo_only == 1
*65% yes
tab state_ltgo_allowed if utgo_only == 1
*100%, as expected

	
*control for issuer overall debt
reg frac_ltgo city_go_vote ///
	state_go_vote $statecitydebt ln_city_debt ln_county_debt_other ///
	/*$statedemo*/ $countydemo ///
	if insample_utgo_only == 1, vce(cluster state)		
/*
                           |               Robust
                 frac_ltgo | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |   .1930093   .0396498     4.87   0.001      .104664    .2813545
             state_go_vote |  -.0763973   .0268939    -2.84   0.018    -.1363207   -.0164739
        state_ltgo_allowed |   .3655397   .0263399    13.88   0.000     .3068507    .4242287
           state_fullfaith |   .2288228   .0587704     3.89   0.003     .0978742    .3597714
state_sep_debtservice_levy |  -.0313506   .0369905    -0.85   0.417    -.1137706    .0510695
       state_sep_pledgerev |  -.0466108   .0234478    -1.99   0.075    -.0988557     .005634
       state_statutorylien |   .0179911   .0300531     0.60   0.563    -.0489714    .0849536
              ln_city_debt |   .0055552   .0104619     0.53   0.607    -.0177553    .0288657
      ln_county_debt_other |   .0009162   .0020287     0.45   0.661     -.003604    .0054364
                    ln_gdp |  -.0318897   .0670334    -0.48   0.644    -.1812494      .11747
                    ln_emp |  -.0046734    .102532    -0.05   0.965    -.2331291    .2237822
             ln_percap_inc |  -.0878868    .071657    -1.23   0.248    -.2475486     .071775
               ln_pers_inc |   .0550117   .0481612     1.14   0.280    -.0522982    .1623215
                     _cons |   .3595142   .4100399     0.88   0.401    -.5541115     1.27314
--------------------------------------------------------------------------------------------

*/

*label vars for output*
label var frac_ltgo "Pct LTGO"
label var frac_rev "Pct Rev"
label var frac_utgo "Pct UTGO"
label var state_go_vote "State GO vote"
label var ln_gdp "County ln(GDP)"
label var ln_emp "County ln(Emp)"
label var ln_percap_inc "County ln(Percap Inc)"
label var ln_pers_inc "County ln(Pers. Inc)"
label var ln_city_debt "ln(Issuer debt)"
label var ln_county_debt_other "ln(Non-issuer debt in county)"

*make table
eststo clear
eststo: qui reg frac_ltgo city_go_vote ln_city_debt ln_county_debt_other ///
	if insample_utgo_only == 1, vce(cluster state)
	estadd local SE "State"	
eststo: qui reg frac_ltgo city_go_vote ln_city_debt ln_county_debt_other ///
	$countydemo if insample_utgo_only == 1, vce(cluster state)
	estadd local SE "State"	
eststo: qui reg frac_ltgo city_go_vote ln_city_debt ln_county_debt_other ///
	$countydemo state_go_vote if insample_utgo_only == 1, vce(cluster state)
	estadd local SE "State"
eststo: qui reg frac_ltgo city_go_vote ln_city_debt ln_county_debt_other ///
	$countydemo state_go_vote state_sep_pledgerev ///
	if insample_utgo_only == 1, vce(cluster state)
	estadd local SE "State"
eststo: qui reg frac_ltgo city_go_vote ln_city_debt ln_county_debt_other ///
	$countydemo /*state_go_vote*/ state_sep_pledgerev ///
	if insample_utgo_only == 1, vce(cluster state)
	estadd local SE "State"
eststo: qui reg frac_ltgo city_go_vote ln_city_debt ln_county_debt_other ///
	$countydemo state_go_vote state_sep_pledgerev state_ltgo_allowed state_fullfaith ///
	state_sep_debtservice_levy ///
	if insample_utgo_only == 1, vce(cluster state)
	estadd local SE "State"			
esttab using "$RESULTS/250605_utgoonly_fracltgo_stateclus.tex", replace t noconstant b(3) ///
	title("LTGO debt: Only compare control states with UTGO only states (OH, MI, WA) ") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 
	
*output with county clustering
eststo clear
eststo: qui reg frac_ltgo city_go_vote ln_city_debt ln_county_debt_other ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"	
eststo: qui reg frac_ltgo city_go_vote ln_city_debt ln_county_debt_other ///
	$countydemo if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"	
eststo: qui reg frac_ltgo city_go_vote ln_city_debt ln_county_debt_other ///
	$countydemo state_go_vote if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
eststo: qui reg frac_ltgo city_go_vote ln_city_debt ln_county_debt_other ///
	$countydemo state_go_vote state_sep_pledgerev ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
eststo: qui reg frac_ltgo city_go_vote ln_city_debt ln_county_debt_other ///
	$countydemo /*state_go_vote*/ state_sep_pledgerev ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"
eststo: qui reg frac_ltgo city_go_vote ln_city_debt ln_county_debt_other ///
	$countydemo state_go_vote state_sep_pledgerev state_ltgo_allowed state_fullfaith ///
	state_sep_debtservice_levy ///
	if insample_utgo_only == 1, vce(cluster fips)
	estadd local SE "County"			
esttab using "$RESULTS/250605_utgoonly_fracltgo_countyclus.tex", replace t noconstant b(3) ///
	title("LTGO debt: Only compare control states with UTGO only states (OH, MI, WA) ") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 
	
	
	
	
	
	
**# Bookmark #3
**Next, compare between benchmark and UTGO+LTGO (i.e., excluding UTGO only)**
gen insample_allgo = 1 if control == 1
replace insample_allgo = 1 if allgo_only == 1
replace insample_allgo = 0 if insample_allgo == .

*output table
eststo clear
eststo: qui reg frac_rev city_go_vote if insample_allgo == 1, vce(cluster state)
	estadd local statecontrols "No"
	estadd local countycontrols "No"
	estadd local SE "State"		
eststo: qui reg frac_rev city_go_vote state_go_vote $statecitydebt if insample_allgo == 1, vce(cluster state)
	estadd local statecontrols "Yes"
	estadd local countycontrols "No"
	estadd local SE "State"	
eststo: qui reg frac_rev city_go_vote state_go_vote $statecitydebt $countydemo ln_county_debt_other if insample_allgo == 1, vce(cluster state)
	estadd local statecontrols "Yes"
	estadd local countycontrols "Yes"
	estadd local SE "State"		
eststo: qui reg frac_rev city_go_vote state_go_vote $statecitydebt $countydemo ln_county_debt_other ln_city_debt if insample_allgo == 1, vce(cluster state)
	estadd local statecontrols "Yes"
	estadd local countycontrols "Yes"
	estadd local SE "State"				
esttab using "$RESULTS/250605_allgo_fracrev_stateclus.tex", replace t noconstant b(3) ///
	title("Revenue debt: Only compare control states with all GO only states (i.e, drop OH, MI, WA) ") star(* .10 ** .05 *** .01) ///
	s(N r2_a statecontrols countycontrols SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "State Debt Controls" "County Demographics" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 
	
*output with county clustering
eststo clear
eststo: qui reg frac_rev city_go_vote if insample_allgo == 1, vce(cluster fips)
	estadd local statecontrols "No"
	estadd local countycontrols "No"
	estadd local SE "County"		
eststo: qui reg frac_rev city_go_vote state_go_vote $statecitydebt if insample_allgo == 1, vce(cluster fips)
	estadd local statecontrols "Yes"
	estadd local countycontrols "No"
	estadd local SE "County"	
eststo: qui reg frac_rev city_go_vote state_go_vote $statecitydebt $countydemo ln_county_debt_other if insample_allgo == 1, vce(cluster fips)
	estadd local statecontrols "Yes"
	estadd local countycontrols "Yes"
	estadd local SE "County"		
eststo: qui reg frac_rev city_go_vote state_go_vote $statecitydebt $countydemo ln_county_debt_other ln_city_debt if insample_allgo == 1, vce(cluster fips)
	estadd local statecontrols "Yes"
	estadd local countycontrols "Yes"
	estadd local SE "County"				
esttab using "$RESULTS/250605_allgo_fracrev_countyclus.tex", replace t noconstant b(3) ///
	title("Revenue debt: Only compare control states with all GO only states (i.e, drop OH, MI, WA) ") star(* .10 ** .05 *** .01) ///
	s(N r2_a statecontrols countycontrols SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "State Debt Controls" "County Demographics" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 

*explore
reg frac_rev city_go_vote if insample_allgo == 1, vce(robust)
*coeff = 0.206, p=0
reg frac_rev city_go_vote ln_city_debt if insample_allgo == 1, vce(cluster state)	
*coeff = 0.216, p=0.064
reg frac_rev city_go_vote ln_city_debt if insample_allgo == 1, vce(cluster state)

reg frac_rev city_go_vote if insample_allgo == 1, vce(cluster fips)		
*coeff = 0.206, p=0
reg frac_rev city_go_vote ln_city_debt if insample_allgo == 1, vce(cluster fips)	
*coeff = 0.216, p=0
reg frac_rev city_go_vote ln_city_debt ln_county_debt_other if insample_allgo == 1, vce(cluster fips)	
*coeff = 0.219, p=0
reg frac_rev city_go_vote state_go_vote ln_city_debt ln_county_debt_other if insample_allgo == 1, vce(cluster fips)	
*coeff = 0.214, p=0
reg frac_rev city_go_vote state_go_vote ln_city_debt ln_county_debt_other ///
	$countydemo if insample_allgo == 1, vce(cluster fips)	
*coeff = 0.138, p=0, R2=0.1591
reg frac_rev city_go_vote state_go_vote $statecitydebt ///
	ln_city_debt ln_county_debt_other $countydemo ///
	if insample_allgo == 1, vce(cluster fips)	
*coeff = -0.003, p=0.928, R2=0.2029
reg frac_rev city_go_vote state_go_vote state_ltgo_allowed state_fullfaith ///
	state_sep_debtservice_levy ///
	ln_city_debt ln_county_debt_other if insample_allgo == 1, vce(cluster fips)	
*coeff = 0.078, p=0.047; R2 = 0.1667
*separate debt service levy makes a bigger difference
*with only state LTGO allowed and statefull faith: coeff = 0.234, p=0, R2 = 0.1209
reg frac_rev city_go_vote state_go_vote state_ltgo_allowed state_fullfaith ///
	state_sep_debtservice_levy state_sep_pledgerev /*state_statutorylien*/ ///
	ln_city_debt ln_county_debt_other $countydemo ///
	if insample_allgo == 1, vce(cluster fips)	
*coeff = 0.022, p=0.587; R2 = 0.2007
reg frac_rev city_go_vote state_go_vote state_ltgo_allowed state_fullfaith ///
	state_sep_debtservice_levy /*state_sep_pledgerev*/ state_statutorylien ///
	ln_city_debt ln_county_debt_other $countydemo ///
	if insample_allgo == 1, vce(cluster fips)	
*coeff = -0.002, p=0.965; R2 = 0.2023
reg frac_rev city_go_vote /*state_go_vote*/ state_ltgo_allowed state_fullfaith ///
	state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_city_debt ln_county_debt_other $countydemo ///
	if insample_allgo == 1, vce(cluster fips)	
*coeff = 0.081, p=0.008; R2 = 0.1926
*something about the combination of state_go_vote and a few of the other state laws
reg frac_rev city_go_vote state_go_vote /*state_ltgo_allowed*/ state_fullfaith ///
	state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_city_debt ln_county_debt_other $countydemo ///
	if insample_allgo == 1, vce(cluster fips)	
*coeff=-0.008,p=0.828; R2 = 0.2028
reg frac_rev city_go_vote state_go_vote state_ltgo_allowed /*state_fullfaith*/ ///
	state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_city_debt ln_county_debt_other $countydemo ///
	if insample_allgo == 1, vce(cluster state)	
*coeff = 0.033, p=0.358; R2 = 0.1994
reg frac_rev city_go_vote state_go_vote state_ltgo_allowed state_fullfaith ///
	/*state_sep_debtservice_levy*/ state_sep_pledgerev state_statutorylien ///
	ln_city_debt ln_county_debt_other $countydemo ///
	if insample_allgo == 1, vce(cluster fips)	
*coeff = 0.099, p=0; R2 = 0.1721	
	
pwcorr state_go_vote $statecitydebt if insample_allgo == 1, star(0.01) 
/*
				GO vote  LTGO allow  faith debtlevy sepfund  statlien
             | state~te s~ltgo~d state_~h state_~y state_~v state_~n
-------------+------------------------------------------------------
state_go_v~e |   1.0000 
state_ltgo~d |   0.2102*  1.0000 
state_full~h |  -0.4622* -0.5553*  1.0000 
state_sep_~y |   0.1427*  0.2844* -0.4114*  1.0000 
state_sep_~v |  -0.2684* -0.3588*  0.0289   0.3052*  1.0000 
state_stat~n |  -0.0099   0.2942* -0.3500*  0.2863*  0.4576*  1.0000 
*/

pwcorr state_go_vote $statecitydebt if allgo_only == 1, star(0.01) 
/*
             | state~te s~ltgo~d state_~h state_~y state_~v state_~n
-------------+------------------------------------------------------
state_go_v~e |   1.0000 
state_ltgo~d |   0.1875*  1.0000 
state_full~h |  -0.3604* -0.4742*  1.0000 
state_sep_~y |  -0.0909*  0.3366* -0.1808*  1.0000 
state_sep_~v |  -0.3030* -0.3715* -0.0601   0.2030*  1.0000 
state_stat~n |  -0.3713*  0.2353* -0.3139*  0.1436*  0.5951*  1.0000 
*/
pwcorr state_go_vote $statecitydebt if control == 1, star(0.01) 
/*
             | state~te s~ltgo~d state_~h state_~y state_~v state_~n
-------------+------------------------------------------------------
state_go_v~e |   1.0000 
state_ltgo~d |  -0.0298   1.0000 
state_full~h |  -0.4663* -0.5682*  1.0000 
state_sep_~y |  -0.1666* -0.0037  -0.4834*  1.0000 
state_sep_~v |  -0.4286* -0.5258*  0.2987*  0.3615*  1.0000 
state_stat~n |        .        .        .        .        .        . 
*/
*state statutory lien doesn't vary within control
tab state_statutorylien if control == 1
*only 0
foreach x of global statecitydebt{
	tab `x' if control == 1
	tab `x' if allgo_only == 1
	tab `x' if utgo_only == 1
}
tab state_go_vote if control == 1
tab state_go_vote if allgo_only == 1
tab state_go_vote if utgo_only == 1
*always have variation in these cases

/*No variation cases:
- LTGO allowed for utgo_only - always == 1 (makes sense)
- Full faith pledge for utgo_only - always == 1
- Debt-service prop tax for utgo_only - always == 1
- Statutory lien on pledged prop tax for control - always == 0
*/

*Run reg for UTGO only with just state_sep_pledgerev (the one with variation)
reg frac_ltgo city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote state_sep_pledgerev ///
	if insample_utgo_only == 1, vce(cluster state)
*there's a sense in which state_sep_pledgerev is a more strict version of state_sep_debtservice_levy
*see fidelity report p. 2: "Another important structural element of a local GO bond is the requirement that a separate property tax levy be dedicated for debt service. When such a feature is combined with the requirement that the pledged property tax revenues be held in a separate fund apart from the issuer's general funds, it provides an important structural safeguard to bondholders. For example, when debt-service funds have been segregated with the explicit condition that said funds be solely expended for debt service, these funds may be shielded from potential demands on a local government's general funds, which the government may not be able to satisfy in a timely fashion."
/*
                                                R-squared         =     0.3488
                                                Root MSE          =     .31975

                                         (Std. err. adjusted for 11 clusters in state)
--------------------------------------------------------------------------------------
                     |               Robust
           frac_ltgo | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
        city_go_vote |   .4918992   .0610361     8.06   0.000     .3559023    .6278962
        ln_city_debt |    .010187   .0120024     0.85   0.416    -.0165561    .0369301
ln_county_debt_other |  -.0004027   .0034841    -0.12   0.910    -.0081658    .0073604
              ln_gdp |  -.1563055   .0831307    -1.88   0.089    -.3415322    .0289213
              ln_emp |   .0402686   .1059503     0.38   0.712    -.1958033    .2763404
       ln_percap_inc |  -.0780106   .0711688    -1.10   0.299    -.2365844    .0805633
         ln_pers_inc |   .1606335   .0928005     1.73   0.114    -.0461388    .3674058
       state_go_vote |  -.1193075   .0685737    -1.74   0.113    -.2720992    .0334841
 state_sep_pledgerev |  -.1208134   .0536383    -2.25   0.048     -.240327   -.0012998
               _cons |   .3739582   .6419155     0.58   0.573    -1.056319    1.804235
--------------------------------------------------------------------------------------
*/

*Run for allgo_only 
reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote state_sep_pledgerev ///
	if insample_allgo == 1, vce(cluster fips)
*coeff = 0.113, p=0.001, R2 = 0.1716
*Run all without stat lien, which doesn't have variation in the control
reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev ///
	if insample_allgo == 1, vce(cluster fips)
*coeff = 0.022, p=0.587, R2 = 0.2007
*Add state gdp and employment
reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote state_sep_pledgerev ln_state_gdp ln_state_emp ///
	if insample_allgo == 1, vce(cluster fips)
*coeff = 0.091, p=0.007

*Output with county clustering*
eststo clear
eststo: qui reg frac_rev city_go_vote ln_city_debt ln_county_debt_other ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"	
eststo: qui reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"		
eststo: qui reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"		
eststo: qui reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote state_sep_pledgerev if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"	
eststo: qui reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote state_sep_pledgerev state_ltgo_allowed state_fullfaith ///
	state_sep_debtservice_levy if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"	
eststo: qui reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	/*state_go_vote*/ state_sep_pledgerev state_ltgo_allowed state_fullfaith ///
	state_sep_debtservice_levy if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"	
eststo: qui reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote state_sep_pledgerev state_ltgo_allowed state_fullfaith ///
	/*state_sep_debtservice_levy*/ if insample_allgo == 1, vce(cluster fips)
	estadd local SE "County"	
esttab using "$RESULTS/250605_allgo_fracrev_countyclus.tex", replace t noconstant b(3) ///
	title("Revenue debt: Only compare control states with all GO only states (i.e, drop OH, MI, WA) ") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$"  "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 
	
*Output with state clustering*
eststo clear
eststo: qui reg frac_rev city_go_vote ln_city_debt ln_county_debt_other ///
	if insample_allgo == 1, vce(cluster state)
	estadd local SE "State"	
eststo: qui reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	if insample_allgo == 1, vce(cluster state)
	estadd local SE "State"		
eststo: qui reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote if insample_allgo == 1, vce(cluster state)
	estadd local SE "State"		
eststo: qui reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote state_sep_pledgerev if insample_allgo == 1, vce(cluster state)
	estadd local SE "State"	
eststo: qui reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote state_sep_pledgerev state_ltgo_allowed state_fullfaith ///
	state_sep_debtservice_levy if insample_allgo == 1, vce(cluster state)
	estadd local SE "State"	
eststo: qui reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	/*state_go_vote*/ state_sep_pledgerev state_ltgo_allowed state_fullfaith ///
	state_sep_debtservice_levy if insample_allgo == 1, vce(cluster state)
	estadd local SE "State"		
eststo: qui reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote state_sep_pledgerev state_ltgo_allowed state_fullfaith ///
	/*state_sep_debtservice_levy*/ if insample_allgo == 1, vce(cluster state)
	estadd local SE "State"
esttab using "$RESULTS/250605_allgo_fracrev_stateclus.tex", replace t noconstant b(3) ///
	title("Revenue debt: Only compare control states with all GO only states (i.e, drop OH, MI, WA) ") star(* .10 ** .05 *** .01) ///
	s(N r2_a SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 
	
	
reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote state_sep_pledgerev state_ltgo_allowed state_fullfaith ///
	/*state_sep_debtservice_levy*/ if insample_allgo == 1, vce(cluster state)	
	
	
	
reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote state_sep_pledgerev state_ltgo_allowed state_fullfaith ///
	/*state_sep_debtservice_levy state_statutorylien*/ if insample_allgo == 1, vce(cluster fips)
	
*leave one out with states 
reg frac_rev city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote state_sep_pledgerev state_ltgo_allowed state_fullfaith ///
	state_sep_debtservice_levy ///
	if insample_allgo == 1 & state != "WV", vce(cluster state)
*dropping UT makes coeff = -0.043, p=0.230
*dropping IA makes coeff = 0.148, p=0; p=0.176 with state clustering

reg frac_utgo city_go_vote ln_city_debt ln_county_debt_other $countydemo ///
	state_go_vote state_sep_pledgerev state_ltgo_allowed state_fullfaith ///
	state_sep_debtservice_levy if insample_allgo == 1, vce(cluster fips)