**************************
*Voting on bonds         *
*Main test: border issuer*
*Last updated: 02/28/25  *
**************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global IL "$DATA\Home Rule"
global BORDER "$DATA\Border States"
global DESCRIPT "$MAIN\Descriptives"
global RESULTS "$MAIN\Results\2025-02_border"

***Start with KM list of border issuers, get to unique***
use "$BORDER\Border Matches Issuers 20250227.dta", clear
duplicates tag seed_issuer_id, gen(dup)
tab dup
/*
        dup |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |        231       72.87       72.87
          1 |         86       27.13      100.00
------------+-----------------------------------
      Total |        317      100.00
*/
*br if dup > 0
sort seed_issuer_id
*create 2 versions of the state group FE to account for some issuers being near multiple borders
gegen stategroup = group(group)
gen stategroup1 = stategroup if dup == 0
gegen temp1 = min(stategroup), by(seed_issuer_id)
replace stategroup1 = temp1 if stategroup1 == .
count if stategroup1 == .
*0, good

drop temp1
gegen temp1 = max(stategroup), by(seed_issuer_id)
gen stategroup2 = stategroup if dup == 0
replace stategroup2 = temp1 if stategroup2 == .
count if stategroup2 == .
*0, good

drop temp dup

*get correspondence between group and stategroup number
preserve
keep group stategroup
duplicates drop
sort stategroup
list
restore
/*
     +------------------------------------+
     |                   group   stateg~p |
     |------------------------------------|
  1. |     Alabama/Mississippi          1 |
  2. |       Alabama/Tennessee          2 |
  3. |    Arkansas/Mississippi          3 |
  4. |  Georgia/South Carolina          4 |
  5. |       Kentucky/Missouri          5 |
     |------------------------------------|
  6. |   Louisiana/Mississippi          6 |
  7. |        Michigan/Indiana          7 |
  8. |      Michigan/Wisconsin          8 |
  9. |     New Hampshire/Maine          9 |
 10. |   New Hampshire/Vermont         10 |
     |------------------------------------|
 11. |            Ohio/Indiana         11 |
 12. |           Ohio/Kentucky         12 |
 13. |       Tennesee/Arkansas         13 |
 14. |        Tennesee/Georgia         14 |
 15. | Tennesee/North Carolina         15 |
     |------------------------------------|
 16. |      Tennessee/Missouri         16 |
 17. |  West Virginia/Kentucky         17 |
 18. |          Wisconsin/Iowa         18 |
     +------------------------------------+
*/

*now drop to drop dups
drop group stategroup
duplicates drop

*save
save "$BORDER\250228_border_uniqueissuer.dta", replace

*make version where dups are just dropped
use "$BORDER\Border Matches Issuers 20250227.dta", clear
duplicates tag seed_issuer_id, gen(dup)
drop if dup > 0
drop dup
gegen stategroup = group(group)
*save
save "$BORDER\250228_border_uniqueissuer_nodup.dta", replace

***Use bond-level Mergent data with state voting requirements***
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
*drop hawaii because no city concept
drop if state == "HI"

***Bring in KM list of border issuers***
*Flex this to swap out which set of border issuers to bring in 
mmerge seed_issuer_id using "$BORDER\250228_border_uniqueissuer_nodup.dta", ///
	type(n:1) missing(nomatch)
/*
                 obs | 332624
                vars |    169  (including _merge)
         ------------+---------------------------------------------------------
              _merge | 317914  obs only in master data                (code==1)
                     |  14710  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*only keep obs that are matched
keep if _merge == 3
drop _merge

tab city_go_vote
/*
    City GO |
       vote |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      9,712       67.57       67.57
          1 |      4,661       32.43      100.00
------------+-----------------------------------
      Total |     14,373      100.00
*/
*note that by construction, city_rev_vote == 0 in this sample always

tab state
*16 states
/*
      state |      Freq.     Percent        Cum.
------------+-----------------------------------
         GA |        144        0.98        0.98
         IA |        990        6.73        7.71
         IN |      2,081       14.15       21.86
         KY |        478        3.25       25.11
         LA |        542        3.68       28.79
         ME |        533        3.62       32.41
         MI |        634        4.31       36.72
         MO |         48        0.33       37.05
         MS |      1,381        9.39       46.44
         NC |        351        2.39       48.82
         NH |      2,140       14.55       63.37
         OH |      1,405        9.55       72.92
         SC |        337        2.29       75.21
         TN |      3,208       21.81       97.02
         WI |        424        2.88       99.90
         WV |         14        0.10      100.00
------------+-----------------------------------
      Total |     14,710      100.00
*/

**# Bookmark #1
***Test tightest version of each type of broad sample test**
*(1) When there's a city GO vote requirement, is offering yield different?
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth num_use_proceeds stategroup1) vce(cluster state)
/*

                                                  R-squared       =     0.7863
                                                  Adj R-squared   =     0.7814
                                                  Within R-sq.    =     0.5582
Number of clusters (state)   =         15         Root MSE        =     0.5343

                                               (Std. err. adjusted for 15 clusters in state)
--------------------------------------------------------------------------------------------
                           |               Robust
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.1227853   .0661575    -1.86   0.085     -.264679    .0191085


*/

*15 states is too few clusters, try clustering by issuer
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth num_use_proceeds stategroup1) vce(cluster seed_issuer)
/*
                                                  R-squared       =     0.7863
                                                  Adj R-squared   =     0.7814
                                                  Within R-sq.    =     0.5582
Number of clusters (seed_issuer) =        249     Root MSE        =     0.5343

                                        (Std. err. adjusted for 249 clusters in seed_issuer)
--------------------------------------------------------------------------------------------
                           |               Robust
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.1227853   .0724967    -1.69   0.092     -.265573    .0200024
*/

reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth num_use_proceeds stategroup2) vce(cluster state)
/*
                                                  R-squared       =     0.7853
                                                  Adj R-squared   =     0.7804
                                                  Within R-sq.    =     0.5566
Number of clusters (state)   =         15         Root MSE        =     0.5357

                                               (Std. err. adjusted for 15 clusters in state)
--------------------------------------------------------------------------------------------
                           |               Robust
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |   .0827594   .0826582     1.00   0.334    -.0945248    .2600435
*/
*would not expect stategroup1 or stategroup2 to make a difference, but it does
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth num_use_proceeds stategroup2) vce(cluster seed_issuer)
/*
                                                  R-squared       =     0.7853
                                                  Adj R-squared   =     0.7804
                                                  Within R-sq.    =     0.5566
Number of clusters (seed_issuer) =        249     Root MSE        =     0.5357

                                        (Std. err. adjusted for 249 clusters in seed_issuer)
--------------------------------------------------------------------------------------------
                           |               Robust
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |   .0827594    .072443     1.14   0.254    -.0599226    .2254413
*/


*(1a) What about for just GO bonds?
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if bond_type == "go" ///
	, absorb(yrmonth num_use_proceeds stategroup1) vce(cluster seed_issuer)
/*

--------------------------------------------------------------------------------------------
                           |               Robust
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |   -.216042   .0853891    -2.53   0.012    -.3844307   -.0476533

*/

*(1b) What about for just rev bonds?
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if bond_type == "rev" ///
	, absorb(yrmonth num_use_proceeds stategroup1) vce(cluster seed_issuer)
/*
                                                  R-squared       =     0.8216
                                                  Adj R-squared   =     0.8124
                                                  Within R-sq.    =     0.6008
Number of clusters (seed_issuer) =        108     Root MSE        =     0.4918

                                        (Std. err. adjusted for 108 clusters in seed_issuer)
--------------------------------------------------------------------------------------------
                           |               Robust
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.2238806   .2773141    -0.81   0.421    -.7736235    .3258622
*/

*(2) When a vote is required on a GO bond, is the offering yield different?
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth num_use_proceeds stategroup1) vce(cluster seed_issuer)
/*

                           |               Robust
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
                  vote_req |  -.0601118   .0543035    -1.11   0.269    -.1670563    .0468327

*/


**# Bookmark #2
***Outputs***

**(1): When there's a city GO vote requirement, is offering yield different?**
eststo clear

eststo: qui reghdfe offering_yield_tr city_go_vote  ///
	, absorb(yrmonth) vce(cluster seed_issuer)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "No"
	estadd local borderFE "No"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "Issuer"
eststo: qui reghdfe offering_yield_tr city_go_vote ///
	, absorb(yrmonth num_use_proceeds) vce(cluster seed_issuer)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local borderFE "No"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "Issuer"
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	, absorb(yrmonth num_use_proceeds) vce(cluster seed_issuer)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local borderFE "No"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "Issuer"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	, absorb(yrmonth num_use_proceeds stategroup) vce(cluster seed_issuer)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local borderFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "Issuer"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	, absorb(yrmonth num_use_proceeds stategroup) vce(cluster seed_issuer)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local borderFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "Issuer"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth num_use_proceeds stategroup) vce(cluster seed_issuer)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local borderFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "Issuer"	
esttab using "$RESULTS/250228_border_stategroup_nodup.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (border issuers)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE borderFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Purpose FE" "Border group FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	label booktabs noobs nonotes 	
	
	
***2/28/2025: JH hasn't updated below this point***	
	
*(1a) GO unlim
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 & go_unlim == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if city_rev_vote == 0 & go_unlim == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250123_city_yield_govote_UTGO.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (UTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Bond Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons) label booktabs noobs nonotes 

*(1b) GO lim
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 & go_lim == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if city_rev_vote == 0 & go_lim == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_lim == 1  ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250123_city_yield_govote_LTGO.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (LTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Bond Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons) label booktabs noobs nonotes 
	
*(1c) GO vote and revenue
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 & rev == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if city_rev_vote == 0 & rev == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & rev == 1  ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250123_city_yield_govote_rev.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (revenue)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Bond Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons) label booktabs noobs nonotes 
		
*Note that the reg with rev vote and rev bonds is the same as the reg with vote_req and rev bonds

*(1d) Revenue vote and general
eststo clear
eststo: qui reg offering_yield_tr city_rev_vote , vce(cluster state)
	estadd local yrmonthFE "No"
	estadd local purposeFE "No"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr city_rev_vote  ///
	, absorb(yrmonth) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "No"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr city_rev_vote  ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr city_rev_vote ln_amount ln_maturity callable sinkable insured rated ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_rev_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_rev_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250123_city_yield_revvote_pooled.tex", replace t noconstant b(3) ///
	title("Revenue bond referendum requirements and offering yield") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Bond Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	label booktabs noobs nonotes 	
	
**# Bookmark #4
***(2) When a vote is required on a GO bond, is the offering yield different?***
eststo clear
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS\250124_city_yield_votereq.tex", replace t noconstant b(3) ///
	title("Vote required and offering yield") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Bond Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons) label booktabs noobs nonotes 	

**(2a) GO unlimited tax**
eststo clear
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 & go_unlim == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if city_rev_vote == 0 & go_unlim == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS\250124_city_yield_votereq_UTGO.tex", replace t noconstant b(3) ///
	title("Vote required and offering yield (UTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Bond Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons) label booktabs noobs nonotes 	
	
**(2b) GO limited tax**
eststo clear
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 & go_lim == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if city_rev_vote == 0 & go_lim == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_lim == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS\250124_city_yield_votereq_LTGO.tex", replace t noconstant b(3) ///
	title("Vote required and offering yield (LTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Bond Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons) label booktabs noobs nonotes 	

**# Bookmark #5
*(3) When there's a GO vote requirement, are GO bonds less likely?**
*regression form	
eststo clear
eststo: qui reghdfe go_all city_go_vote  ///
	if city_rev_vote == 0  ///
	, absorb(yrmonth) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe go_all city_go_vote state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe go_all city_go_vote state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS\250124_city_likelihood_go_reg.tex", replace t noconstant b(3) ///
	title("Likelihood of GO bond when city GO vote required") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "State Controls" "County Controls" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 	

*difference of means with purposes as well
*label purpose vars
label var purpose_air "Purpose: Airports" 
label var purpose_civc "Purpose: Convention Ctrs"
label var purpose_cuti "Purpose: Utilities" 
label var purpose_elec "Purpose: Power"
label var purpose_fise "Purpose: Fire stations" 
label var purpose_gppi "Purpose: General"
label var purpose_gvpb "Purpose: Public buildings"
label var purpose_hosp "Purpose: Hospitals"
label var purpose_limu "Purpose: Libraries and museums"
label var purpose_orec "Purpose: Recreation" 
label var purpose_psed "Purpose: Prim/second education"
label var purpose_spor "Purpose: Sports buildings"
label var purpose_tele "Purpose: Telephone"
label var purpose_wtr "Purpose: Water and sewer"
label var go_unlim "Unlimited tax GO bond"
label var go_lim "Limited tax GO bond"

eststo clear
eststo novote: estpost sum ///
	go_all go_unlim go_lim purpose_gppi purpose_gvpb purpose_air purpose_civc ///
	purpose_hosp purpose_limu purpose_orec purpose_spor purpose_psed purpose_fise ///
	purpose_cuti purpose_elec purpose_tele purpose_wtr  ///
	if city_go_vote == 0 & city_rev_vote == 0, d
eststo yesvote: estpost sum ///
	go_all go_unlim go_lim purpose_gppi purpose_gvpb purpose_air purpose_civc ///
	purpose_hosp purpose_limu purpose_orec purpose_spor purpose_psed purpose_fise ///
	purpose_cuti purpose_elec purpose_tele purpose_wtr  ///
	if city_go_vote == 1 & city_rev_vote == 0, d
eststo diff: estpost ttest ///
	go_all go_unlim go_lim purpose_gppi purpose_gvpb purpose_air purpose_civc ///
	purpose_hosp purpose_limu purpose_orec purpose_spor purpose_psed purpose_fise ///
	purpose_cuti purpose_elec purpose_tele purpose_wtr  ///
	if city_rev_vote == 0, by(city_go_vote) welch
esttab novote yesvote diff using "$RESULTS\250124_city_bondselection_diffmeans.tex", ///
	replace title(Difference in means for bond types and purposes) ///
	cells("mean(pattern(1 1 0) fmt(%9.2fc)) b(star pattern(0 0 1) fmt(%9.2fc)) t(pattern(0 0 1) par fmt(2))") ///
	collabels("Mean" "Difference" "t-stat") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	

*regression for purposes
label var purpose_air "Airport" 
label var purpose_civc "Conv Ctrs"
label var purpose_cuti "Util" 
label var purpose_elec "Power"
label var purpose_fise "Fire" 
label var purpose_gppi "General"
label var purpose_gvpb "Public Bldg"
label var purpose_hosp "Hospital"
label var purpose_limu "Lib\Mmus"
label var purpose_orec "Rec" 
label var purpose_psed "PS Educ"
label var purpose_spor "Sports"
label var purpose_tele "Tele"
label var purpose_wtr "Wtr\&Swr"

eststo clear
local temp gppi gvpb air civc hosp limu orec
foreach x of local temp{
	eststo: qui reghdfe purpose_`x' city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
}
esttab using "$RESULTS\250124_city_reg_purpose_pt1.tex", replace t noconstant b(3) ///
	title("Likelihood of projects when city GO vote required") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 	
	
eststo clear
local temp spor psed fise cuti elec tele wtr
foreach x of local temp{
	eststo: qui reghdfe purpose_`x' city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
}
esttab using "$RESULTS\250124_city_reg_purpose_pt2.tex", replace t noconstant b(3) ///
	title("Likelihood of projects when city GO vote required") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 	