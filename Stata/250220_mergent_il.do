**************************
*Voting on bonds         *
*IL home rule tests      *
*Last updated: 02/20/25  *
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
*drop hawaii because no city concept
drop if state == "HI"

*make go indicator for go_lim and go_unlim
gen go_all = 1 if go_lim == 1 | go_unlim == 1
replace go_all = 0 if go_all == .
label var go_all "GO bond"

***Merge in IL home rule***
mmerge seed_issuer year using "$IL\250220_homeruletimeseries.dta", ///
	type(n:1) missing(nomatch)
/*
                 obs | 335792
                vars |    170  (including _merge)
         ------------+---------------------------------------------------------
              _merge | 322190  obs only in master data                (code==1)
                     |   3168  obs only in using data                 (code==2)
                     |  10434  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
tab state if _merge == 3
*all in IL, good
*br if _merge == 2
*These obs are where years are not matched because no bond was issued
*br seed_issuer issuer_long_name homerule homerule_begyr if state == "IL" 
*Looks like unmatched cities are just not in the HR time series data
*Hand-checked a few, this means they never have home rule
*br seed_issuer issuer_long_name homerule  if state == "IL" & _merge == 1
replace homerule = 0 if _merge == 1 & state == "IL"
*create indicator for ever having home rule
gen homerule_ever = 0 if _merge == 1 & state == "IL"
replace homerule_ever = 1 if _merge == 3 & state == "IL"

*gen IL-specific vote indicator based on home rule
*Reminder that home rule = NO vote for UTGO; non-home rule = vote for UTGO
*IL law: Cities are not requred to get voter approvl for limited tax GO bonds within a certain limit
gen vote_req_il = 1 if state == "IL" & go_unlim == 1 & homerule == 0
replace vote_req_il = 0 if state == "IL" & vote_req_il == .
*br seed_issuer year go_lim go_unlim rev homerule vote_req_il offering_yield_tr if state == "IL"

*label vars
label var homerule "Home Rule"
label var vote_req_il "Vote Req"


***Descriptives for IL***
*how many rev, go_lim, go_unlim?
count if go_lim == 1 & state == "IL"
*545
count if go_unlim == 1 & state == "IL"
*12,388
count if rev == 1 & state == "IL"
*5,199

eststo clear
eststo: estpost sum homerule vote_req_il go_lim go_unlim rev offering_yield_tr ln_amount ln_maturity ///
	callable sinkable insured rated ///
	ln_pop ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if state == "IL" , d
esttab using "$DESCRIPT\IL\250220_il_sumstats.tex", replace ///
	title("Summary statistics for Illinois") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	
	
*get sum stats for county-level raw pop
sum pop if state == "IL" , d
*mean = 2,120,707, median = 684,419, p25 = 182,338, p75 = 5,207,615, max = 5,360,562, min = 5,640

tab month if state == "IL"
/*
      month |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      1,138        6.28        6.28
          2 |        941        5.19       11.47
          3 |      1,438        7.93       19.40
          4 |      1,521        8.39       27.79
          5 |      1,582        8.72       36.51
          6 |      1,851       10.21       46.72
          7 |      1,516        8.36       55.08
          8 |      1,782        9.83       64.91
          9 |      1,402        7.73       72.64
         10 |      1,298        7.16       79.80
         11 |      1,608        8.87       88.67
         12 |      2,055       11.33      100.00
------------+-----------------------------------
      Total |     18,132      100.00
*/

tab year if state == "IL"
/*
       year |      Freq.     Percent        Cum.
------------+-----------------------------------
       2000 |      1,053        5.81        5.81
       2001 |      1,265        6.98       12.78
       2002 |      1,252        6.90       19.69
       2003 |      1,178        6.50       26.19
       2004 |      1,403        7.74       33.92
       2005 |      1,022        5.64       39.56
       2006 |      1,338        7.38       46.94
       2007 |      1,116        6.15       53.09
       2008 |      1,110        6.12       59.22
       2009 |        620        3.42       62.64
       2010 |        473        2.61       65.24
       2011 |        464        2.56       67.80
       2012 |        841        4.64       72.44
       2013 |        779        4.30       76.74
       2014 |        568        3.13       79.87
       2015 |        674        3.72       83.59
       2016 |        729        4.02       87.61
       2017 |        648        3.57       91.18
       2018 |        666        3.67       94.85
       2019 |        599        3.30       98.16
       2020 |        334        1.84      100.00
------------+-----------------------------------
      Total |     18,132      100.00
*/
*big drop-off after 2008 due to fin crisis and folding of muni bond insurers?;
*a relatively larger drop-off in IL than in the broader sample

tab use_proceeds if state == "IL"
*similar proportions as in broad sample

***Regression: When a vote is required, is offering yield different?***
*output*
*can't cluster by state because only 1 state

eststo clear
eststo: qui reg offering_yield_tr vote_req_il ///
	if state == "IL" & go_unlim == 1 ///
	, vce(robust)
	estadd local timeFE "No"
	estadd local purposeFE "No"
	estadd local countyFE "No"
	estadd local SE "Robust"

eststo: qui reg offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_pop ln_gdp ln_pers_inc /*ln_percap_inc*/ ln_emp ///
	if state == "IL" & go_unlim == 1 ///
	, vce(robust)
	estadd local timeFE "No"
	estadd local purposeFE "No"
	estadd local countyFE "No"
	estadd local SE "Robust"

/*
eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_pop ln_gdp ln_pers_inc /*ln_percap_inc*/ ln_emp ///
	if state == "IL" & go_unlim == 1 ///
	, absorb(year month) vce(un)
	estadd local timeFE "Yes"
	estadd local purposeFE "No"
	estadd local countyFE "No"
	estadd local SE "None"
*/

eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_pop ln_gdp ln_pers_inc /*ln_percap_inc*/ ln_emp ///
	if state == "IL" & go_unlim == 1 ///
	, absorb(year month num_use_proceeds) vce(un)
	estadd local timeFE "Yes"
	estadd local purposeFE "Yes"
	estadd local countyFE "No"
	estadd local SE "None"
	
eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	if state == "IL" & go_unlim == 1 ///
	, absorb(year month num_use_proceeds fips) vce(robust)
	estadd local timeFE "Yes"
	estadd local purposeFE "Yes"
	estadd local countyFE "Yes"
	estadd local SE "Robust"
	
eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	if state == "IL" & go_unlim == 1 ///
	, absorb(year month num_use_proceeds fips) vce(cluster fips)
	estadd local timeFE "Yes"
	estadd local purposeFE "Yes"
	estadd local countyFE "Yes"
	estadd local SE "County"
	
eststo: qui reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	if state == "IL" & go_unlim == 1 ///
	, absorb(year month num_use_proceeds fips) vce(cluster seed_issuer)
	estadd local timeFE "Yes"
	estadd local purposeFE "Yes"
	estadd local countyFE "Yes"
	estadd local SE "Issuer"
	
esttab using "$RESULTS/250220_il_homerule.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (IL)") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE countyFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FEs" "Bond Purpose FE" "County FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 

reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	if state == "IL" & go_unlim == 1 ///
	, absorb(year month num_use_proceeds seed_issuer) vce(cluster seed_issuer)
	estadd local timeFE "Yes"
	estadd local purposeFE "Yes"
	estadd local countyFE "Yes"
	estadd local SE "Issuer"








*follow same specification as in broad test, but cluster by county. Can't cluster by state, and also can't by issuer because many issuers have few obs
*use year and month FE separately rather than ym together because of the smaller sample
reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated  ///
	ln_pop ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if state == "IL" ///
	, absorb(year month num_use_proceeds) vce(cluster fips)

reg offering_yield_tr vote_req_il if state == "IL"  
/*
      Source |       SS           df       MS      Number of obs   =    17,724
-------------+----------------------------------   F(1, 17722)     =     41.54
       Model |  54.0771316         1  54.0771316   Prob > F        =    0.0000
    Residual |  23067.8838    17,722   1.3016524   R-squared       =    0.0023
-------------+----------------------------------   Adj R-squared   =    0.0023
       Total |  23121.9609    17,723  1.30463019   Root MSE        =    1.1409

------------------------------------------------------------------------------
offering_y~r | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]
-------------+----------------------------------------------------------------
 vote_req_il |    .127544   .0197879     6.45   0.000     .0887577    .1663303
       _cons |   3.354434   .0098962   338.96   0.000     3.335037    3.373832
------------------------------------------------------------------------------
*/

reg offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated if state == "IL"  
/*
      Source |       SS           df       MS      Number of obs   =    17,723
-------------+----------------------------------   F(7, 17715)     =   1223.88
       Model |  7536.81061         7  1076.68723   Prob > F        =    0.0000
    Residual |  15584.4043    17,715  .879729288   R-squared       =    0.3260
-------------+----------------------------------   Adj R-squared   =    0.3257
       Total |  23121.2149    17,722  1.30466172   Root MSE        =    .93794

------------------------------------------------------------------------------
offering_y~r | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]
-------------+----------------------------------------------------------------
 vote_req_il |   .0623303   .0168113     3.71   0.000     .0293786    .0952821
   ln_amount |   -.044907   .0065442    -6.86   0.000    -.0577342   -.0320798
 ln_maturity |   .2495813   .0226494    11.02   0.000     .2051862    .2939764
    callable |   .9846404   .0156801    62.80   0.000      .953906    1.015375
    sinkable |   .2643122   .0237094    11.15   0.000     .2178394    .3107849
     insured |   .5154453   .0146019    35.30   0.000     .4868241    .5440665
       rated |  -.3988147   .0163295   -24.42   0.000    -.4308221   -.3668072
       _cons |   1.966992   .1375889    14.30   0.000     1.697305     2.23668
------------------------------------------------------------------------------
*/

reg offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_pop ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if state == "IL"  
/*
      Source |       SS           df       MS      Number of obs   =    15,194
-------------+----------------------------------   F(12, 15181)    =   1174.67
       Model |  8716.66985        12  726.389154   Prob > F        =    0.0000
    Residual |  9387.58807    15,181   .61837745   R-squared       =    0.4815
-------------+----------------------------------   Adj R-squared   =    0.4811
       Total |  18104.2579    15,193  1.19161837   Root MSE        =    .78637

-------------------------------------------------------------------------------
offering_yi~r | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]
--------------+----------------------------------------------------------------
  vote_req_il |   .0009381    .015489     0.06   0.952    -.0294222    .0312984
    ln_amount |   .0211676   .0064209     3.30   0.001      .008582    .0337533
  ln_maturity |   .3384987   .0205583    16.47   0.000      .298202    .3787954
     callable |   1.006688   .0142559    70.62   0.000      .978745    1.034631
     sinkable |   .3321198   .0211266    15.72   0.000     .2907091    .3735305
      insured |   .2569046   .0145975    17.60   0.000     .2282917    .2855175
        rated |  -.2070087   .0144202   -14.36   0.000    -.2352739   -.1787434
       ln_pop |   1105.462   804.8345     1.37   0.170    -472.1104    2683.034
       ln_gdp |   .2630302   .0566094     4.65   0.000     .1520689    .3739914
  ln_pers_inc |   -1106.05   804.8365    -1.37   0.169    -2683.626    471.5268
ln_percap_inc |   1104.121   804.8369     1.37   0.170    -473.4559    2681.698
       ln_emp |   .3932994   .0713198     5.51   0.000      .253504    .5330949
        _cons |  -7621.041   5559.616    -1.37   0.170    -18518.56    3276.475
-------------------------------------------------------------------------------
*/

reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	ln_pop ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if state == "IL" ///
	, absorb(year month) vce(un)
/*
warning: missing F statistic; dropped variables due to collinearity or too few clusters

HDFE Linear regression                            Number of obs   =     15,194
Absorbing 2 HDFE groups                           F(  12,  15152) =          .
                                                  Prob > F        =          .
                                                  R-squared       =     0.6846
                                                  Adj R-squared   =     0.6838
                                                  Within R-sq.    =     0.4844
                                                  Root MSE        =     0.6138

-------------------------------------------------------------------------------
offering_yi~r | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]
--------------+----------------------------------------------------------------
  vote_req_il |  -.0414336   .0123856    -3.35   0.001    -.0657108   -.0171564
    ln_amount |   .0656492    .005128    12.80   0.000     .0555977    .0757007
*/

reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	if state == "IL" ///
	, absorb(year month fips) vce(cluster fips)
*if the standard errors are adjusted at all with the county-level demos in there, it doesn't estimate 

reghdfe offering_yield_tr vote_req_il  ///
	if state == "IL" ///
	, absorb(year month) vce(cluster fips)	
reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated  ///
	if state == "IL" ///
	, absorb(yrmonth fips) vce(cluster fips)	
	
reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated  ///
	if state == "IL" ///
	, absorb(year month fips) vce(cluster seed_issuer)	
	
reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	if state == "IL" ///
	, absorb(year month fips) vce(cluster seed_issuer)	
/*
                                                  R-squared       =     0.7407
                                                  Adj R-squared   =     0.7386
                                                  Within R-sq.    =     0.4805
Number of clusters (seed_issuer) =        368     Root MSE        =     0.5840

                          (Std. err. adjusted for 368 clusters in seed_issuer)
------------------------------------------------------------------------------
             |               Robust
offering_y~r | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-------------+----------------------------------------------------------------
 vote_req_il |  -.0186439   .0350366    -0.53   0.595    -.0875415    .0502537
   ln_amount |   .0707578   .0161274     4.39   0.000     .0390441    .1024714
 ln_maturity |   .2777325   .0475626     5.84   0.000     .1842031    .3712619
*/
	
reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	if state == "IL" & go_unlim == 1 ///
	, absorb(year month fips) vce(cluster seed_issuer)	
/*
                                                  R-squared       =     0.7515
                                                  Adj R-squared   =     0.7492
                                                  Within R-sq.    =     0.4927
Number of clusters (seed_issuer) =        271     Root MSE        =     0.5685

                          (Std. err. adjusted for 271 clusters in seed_issuer)
------------------------------------------------------------------------------
             |               Robust
offering_y~r | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-------------+----------------------------------------------------------------
 vote_req_il |   .0640448   .0439323     1.46   0.146    -.0224487    .1505383
   ln_amount |   .0867566   .0155761     5.57   0.000     .0560906    .1174227
*/
	
reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	if state == "IL" & go_unlim == 1 ///
	, absorb(yrmonth fips) vce(cluster seed_issuer)
	
reghdfe offering_yield_tr vote_req_il ln_amount ln_maturity callable sinkable insured rated ///
	if state == "IL" & go_unlim == 1 ///
	, absorb(yrmonth num_use_proceeds fips) vce(cluster seed_issuer)
	
hist offering_yield_tr if vote_req_il == 1 & go_unlim == 1 & state == "IL"	
hist offering_yield_tr if vote_req_il == 0 & go_unlim == 1 & state == "IL"	
	
br seed_issuer year issue_description vote_req_il offering_yield_tr ln_amount ln_maturity callable sinkable insured rated if state == "IL" & go_unlim == 1 
	
*download list of seed issuers
preserve
keep if state == "IL"
keep seed_issuer homerule_ever
duplicates drop
duplicates report seed_issuer homerule_ever
export delimited "$IL\250220_issuer_list.csv", replace
restore

	

**# Bookmark #1
***Test tightest version of each type of broad sample test**
*(1) When there's a city GO vote requirement, is offering yield different?
*Note that with WI change, UTGO is omitted b/c perfectly corr with city_go_vote
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
/*
                                                  Adj R-squared   =     0.7530
                                                  Within R-sq.    =     0.5286
Number of clusters (state)   =         26         Root MSE        =     0.5766

                                               (Std. err. adjusted for 26 clusters in state)
--------------------------------------------------------------------------------------------
                           |               Robust
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.0924408   .0492345    -1.88   0.072    -.1938411    .0089595

*/

*(1a) What about for just GO bonds?
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & bond_type == "go" ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
/*

         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.1073506   .0560104    -1.92   0.067    -.2227062     .008005
*/

*(1b) What about for just rev bonds?
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & rev == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
/*

         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.1016643   .0391429    -2.60   0.016    -.1822805    -.021048
*/

*(2) When a vote is required on a GO bond, is the offering yield different?
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
/*
                                                  Adj R-squared   =     0.7510
                                                  Within R-sq.    =     0.5235
Number of clusters (state)   =         32         Root MSE        =     0.5803

                                               (Std. err. adjusted for 32 clusters in state)
--------------------------------------------------------------------------------------------
                           |               Robust
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
                  vote_req |  -.0930816   .0432746    -2.15   0.039    -.1813408   -.0048225
*/


*(2a) What about just looking at GO bonds? 
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & bond_type == "go" ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
/*

         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
                  vote_req |  -.0833911   .0479826    -1.74   0.095     -.182213    .0154309
*/

*(2b) What about just looking at GO unlim tax bonds? 
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
/*
                                                  Adj R-squared   =     0.7723
                                                  Within R-sq.    =     0.5404
Number of clusters (state)   =         26         Root MSE        =     0.5456

                                               (Std. err. adjusted for 26 clusters in state)
--------------------------------------------------------------------------------------------
                           |               Robust
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
                  vote_req |  -.1099221   .0536778    -2.05   0.051    -.2204735    .0006294

*/
*(2c) What about just looking at GO lim tax bonds? 
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_lim == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
/*
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
                  vote_req |  -.1858671   .0734196    -2.53   0.022    -.3415096   -.0302246
*/
	
*Note that we can't look at rev bonds because there's no variation in vote_req if we set city_rev_vote == 0
	
*(3) When there's a GO vote requirement, are GO bonds less likely?**	
gen go_all = 1 if go_lim == 1 | go_unlim == 1
replace go_all = 0 if go_all == .
label var go_all "GO bond"
	
reghdfe go_all city_go_vote state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
*here, not controlling for use of proceeds because the purposes might change if the GO bond choice changes
/*
                                                  Adj R-squared   =     0.1375
                                                  Within R-sq.    =     0.1119
Number of clusters (state)   =         26         Root MSE        =     0.4272

                                               (Std. err. adjusted for 26 clusters in state)
--------------------------------------------------------------------------------------------
                           |               Robust
                    go_all | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.0700333   .0967567    -0.72   0.476    -.2693075    .1292409
*/

*(3a) GO unlimited tax
reghdfe go_unlim city_go_vote state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
/*                                          
                           |               Robust
                  go_unlim | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.0478418   .1211459    -0.39   0.696    -.2973464    .2016629
*/

*(3b) GO limited tax	
reghdfe go_lim city_go_vote state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
/*

                    go_lim | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.0221915   .0549418    -0.40   0.690    -.1353463    .0909633

*/
	
*(3c) Difference in means
ttest go_all if city_rev_vote == 0, by(city_go_vote) welch	
/*
Two-sample t test with unequal variances
------------------------------------------------------------------------------
   Group |     Obs        Mean    Std. err.   Std. dev.   [95% conf. interval]
---------+--------------------------------------------------------------------
       0 |  76,978    .8010471    .0014389    .3992152    .7982269    .8038672
       1 | 105,961    .6188881     .001492    .4856623    .6159638    .6218123
---------+--------------------------------------------------------------------
Combined | 182,939    .6955379    .0010759    .4601805    .6934291    .6976466
---------+--------------------------------------------------------------------
    diff |             .182159    .0020728                .1780964    .1862215
------------------------------------------------------------------------------
    diff = mean(0) - mean(1)                                      t =  87.8821
H0: diff = 0                             Welch's degrees of freedom =   180179

    Ha: diff < 0                 Ha: diff != 0                 Ha: diff > 0
 Pr(T < t) = 1.0000         Pr(|T| > |t|) = 0.0000          Pr(T > t) = 0.0000
*/
	
ttest go_unlim if city_rev_vote == 0, by(city_go_vote) welch	
/*
Two-sample t test with unequal variances
------------------------------------------------------------------------------
   Group |     Obs        Mean    Std. err.   Std. dev.   [95% conf. interval]
---------+--------------------------------------------------------------------
       0 |  76,978    .6423783    .0017275     .479303    .6389924    .6457643
       1 | 105,961    .3677674    .0014813    .4821999     .364864    .3706708
---------+--------------------------------------------------------------------
Combined | 182,939    .4833196    .0011684    .4997231    .4810296    .4856095
---------+--------------------------------------------------------------------
    diff |             .274611    .0022757                .2701507    .2790712
------------------------------------------------------------------------------
    diff = mean(0) - mean(1)                                      t = 120.6718
H0: diff = 0                             Welch's degrees of freedom =   166429

    Ha: diff < 0                 Ha: diff != 0                 Ha: diff > 0
 Pr(T < t) = 1.0000         Pr(|T| > |t|) = 0.0000          Pr(T > t) = 0.0000
*/

ttest go_lim if city_rev_vote == 0, by(city_go_vote) welch	
/*
Two-sample t test with unequal variances
------------------------------------------------------------------------------
   Group |     Obs        Mean    Std. err.   Std. dev.   [95% conf. interval]
---------+--------------------------------------------------------------------
       0 |  76,978    .1586687    .0013169    .3653692    .1560876    .1612498
       1 | 105,961    .2511207    .0013322    .4336599    .2485096    .2537318
---------+--------------------------------------------------------------------
Combined | 182,939    .2122183     .000956    .4088797    .2103446     .214092
---------+--------------------------------------------------------------------
    diff |            -.092452    .0018732               -.0961235   -.0887805
------------------------------------------------------------------------------
    diff = mean(0) - mean(1)                                      t = -49.3542
H0: diff = 0                             Welch's degrees of freedom =   178980

    Ha: diff < 0                 Ha: diff != 0                 Ha: diff > 0
 Pr(T < t) = 0.0000         Pr(|T| > |t|) = 0.0000          Pr(T > t) = 1.0000
*/
	
*(4) What about purposes?
*(4a) Regression form:
reghdfe purpose_gppi city_go_vote state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)	
/*                                                 

              purpose_gppi | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.0098344   .0732708    -0.13   0.894    -.1607385    .1410697

*/
*run regressions for all
local temp agri air brdg cfct civc corr csed cuti edev elec fise flod gas gppi gvpb hied hoeq hosp idev ///
	irrg limu mall mass mfhg na nurs offb ohca ondv  
foreach x of local temp{
	reghdfe purpose_`x' city_go_vote state_godebt_limit   state_ltgo_allowed ///
		state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
		ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
		if city_rev_vote == 0 ///
		, absorb(yrmonth) vce(cluster state)
}
*many purposes aren't populated enough, don't have enough variation
/*
- air: city_go_vote |   .0104161   .0055454     1.88   0.072 
- civc: city_go_vote |    .004045   .0022761     1.78   0.088 
- edev: city_go_vote |  -.0111553   .0067804    -1.65   0.112 
- gvpb: city_go_vote |   .0104505   .0053365     1.96   0.061 
- hosp: city_go_vote |   .0158448   .0060278     2.63   0.014
- limu: city_go_vote |  -.0197513   .0080484    -2.45   0.021 
*/

local temp opub orec oted oths otrn outi park pfr pkg pole poll ///
	pres psed redv sani seap sfhg smhg spor stln tele thtr toll vets wast wtr 
foreach x of local temp{
	reghdfe purpose_`x' city_go_vote state_godebt_limit   state_ltgo_allowed ///
		state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
		ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
		if city_rev_vote == 0 ///
		, absorb(yrmonth) vce(cluster state)
}
/*
- orec: city_go_vote |   .0154713   .0042139     3.67   0.001
- spor: city_go_vote |   .0029829   .0016628     1.79   0.085
- tele: city_go_vote |   .0001591   .0000746     2.13   0.043
- wtr: city_go_vote |   -.075303   .0506877    -1.49   0.150
*/

*(4b): Differences in means
tab use_proceeds if city_rev_vote == 0
*only do purposes that appear over 1% (~2,000 bonds): cuti, elec, fise, gppi, gvpb, limu, orec, psed, wtr

local temp cuti elec fise gppi gvpb limu orec psed wtr 
foreach x of local temp{
	ttest purpose_`x' if city_rev_vote == 0, by(city_go_vote) welch
}
/*Notes: diff = no vote less vote
- cuti: diff=-.0169811, p=0, t=-30.2930
- elec: diff=-.0025418, p=0.0029, t=-2.9730
- fise: diff=-.0112132, p=0, t=-21.9866
- gppi: diff=.1276039, p=0, t=50.2101
- gpvb: diff=-.0073876, p=0, t=-13.4986
- limu: diff=.0000436, p=0.9364, t=0.0798
- orec: diff=-.0169249, p=0, t=-35.8191
- psed: diff=.0911586, p=0, t=67.3678
- wtr: diff=-.1061573, p=0, t=-54.5866
*/

local temp cuti elec fise gppi gvpb limu orec psed wtr 
foreach x of local temp{
	ttest purpose_`x' if city_rev_vote == 0, by(go_all) welch
}
/*Notes: diff = rev bond less go bond
- cuti: diff=.0463586, p=0, t=55.2064
- elec: diff=.0812883, p=0, t= 75.4570
- fise: diff=-.0122577, p=0, t=-31.7975
- gppi: diff=-.5920103, p=0, t=huge
- gpvb: diff=-.0089841, p=0, t=-20.7044
- limu: diff= -.0130664, p=0, t=-36.4574
- orec: diff=-.00732, p=0, t=-15.8140
- psed: diff= -.039032, p=0, t=-59.8567
- wtr: diff=.4323981, p=0, t=212.8695
*/


**# Bookmark #2
***Outputs***
**Graph in excel: state and bond_type**
tab state bond_type if city_go_vote == 1 & city_rev_vote == 0		
/*

           |       Bond type
     state |        go        rev |     Total
-----------+----------------------+----------
        AK |       816         71 |       887 
        FL |     1,342      4,977 |     6,319 
        GA |       834        672 |     1,506 
        IA |    12,763      3,184 |    15,947 
        LA |       505        954 |     1,459 
        MI |    12,343      2,529 |    14,872 
        MO |     2,446      2,361 |     4,807 
        MT |       475        347 |       822 
        NC |     3,014      1,900 |     4,914 
        NE |     5,352      2,366 |     7,718 
        NM |       603      1,215 |     1,818 
        OH |     7,231      1,887 |     9,118 
        OR |     1,751      1,500 |     3,251 
        TX |    11,587     11,367 |    22,954 
        UT |       490      2,160 |     2,650 
        WA |     3,946      2,443 |     6,389 
        WV |        37        415 |       452 
        WY |        43         35 |        78 
-----------+----------------------+----------
     Total |    65,578     40,383 |   105,961 
*/

tab state bond_type if city_go_vote == 0 & city_rev_vote == 0
/*

           |       Bond type
     state |        go        rev |     Total
-----------+----------------------+----------
        IN |     2,417      4,613 |     7,030 
        KY |     1,307      1,164 |     2,471 
        MA |    19,569        334 |    19,903 
        MS |     2,692        700 |     3,392 
        NH |     2,442        348 |     2,790 
        NJ |    14,191        205 |    14,396 
        TN |     3,388      2,585 |     5,973 
        WI |    15,657      5,366 |    21,023 
-----------+----------------------+----------
     Total |    61,663     15,315 |    76,978 

*/			
	
**Bond-level summary stats**
eststo clear
eststo: estpost sum city_go_vote vote_req go_all offering_yield_tr ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & city_go_vote != . , d
esttab using "$DESCRIPT\Bondlevel\250124_bondlevel_sumstats_city.tex", replace ///
	title("Summary statistics") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	

**# Bookmark #3
**(1): When there's a city GO vote requirement, is offering yield different?**
eststo clear
eststo: qui reg offering_yield_tr city_go_vote if city_rev_vote == 0, vce(cluster state)
	estadd local yrmonthFE "No"
	estadd local purposeFE "No"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr city_go_vote if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "No"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr city_go_vote if city_rev_vote == 0 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 ///
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
	if city_rev_vote == 0 ///
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
	if city_rev_vote == 0 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250123_city_yield_govote_pooled.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Bond Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	label booktabs noobs nonotes 	
	
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