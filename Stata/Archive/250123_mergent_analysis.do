**************************
*Voting on bonds         *
*Broad sample tests      *
*Last updated: 01/23/25  *
**************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global DESCRIPT "$MAIN\Descriptives"
global RESULTS "$MAIN\Results\2025-01_bondlevel"

***Start with bond-level Mergent data with state voting requirements***
use "$MERGENT\Clean\250123_citycountyschool_cusiplevel_statereq.dta", clear

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

tab city_go_vote
/*
    City GO |
       vote |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |     76,978       36.63       36.63
          1 |    133,157       63.37      100.00
------------+-----------------------------------
      Total |    210,135      100.00
*/

tab city_rev_vote
/*
   City rev |
       vote |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    243,435       93.99       93.99
          1 |     15,557        6.01      100.00
------------+-----------------------------------
      Total |    258,992      100.00
*/

*States that have a clear revenue bond voting requirement are fundamentally different from states that do not
*Throughout analyses, focus on the states that do NOT have a clear revenue bond voting requirement
*When using city_rev_vote == 0 as a filter: vote_req turns on if the bond is GO and in a state with GO requirement. city_go_vote will turn on for both GO and rev bonds if the state has a GO requirement

*Look at how correlated the state-level debt considerations are with vote
*Fundamentally, whether the state has a debt limit + whether limited tax or unlimited tax GO is allowed is different from the additional restrictions on GO bonds. The fidelity report treats these separately too
pwcorr city_go_vote state_utgo_allowed state_ltgo_allowed state_godebt_limit ///
	if city_rev_vote == 0 ///
	, bonferroni star(0.01) 
/*
             | city_g~e s~utgo~d s~ltgo~d state_~t
-------------+------------------------------------
city_go_vote |   1.0000 
state_utgo~d |        .   1.0000 
state_ltgo~d |   0.5005* -0.0542*  1.0000 
state_gode~t |   0.3928*  0.0525*  0.3344*  1.0000 
*/
*If unlim tax GO allowed, then less likely that GO vote required (or vice versa)
*If lim tax GO allowed, then more likely that GO vote required (or vice versa)
*Institutionally, this is a little surprising
*If state has a GO debt limit, then more likely that GO vote required (this makes sense). More likely UTGO allowed, more likely LTGO allowed

pwcorr city_go_vote state_utgo_allowed /*state_ltgo_allowed state_godebt_limit*/  ///
	if city_rev_vote == 0 ///
	, bonferroni star(0.01) 
 
*how much does the restriction to no-rev-vote states matter?
pwcorr city_go_vote state_utgo_allowed state_ltgo_allowed state_godebt_limit  ///
	, bonferroni star(0.01) 
/*
             | city_g~e s~utgo~d s~ltgo~d state_~t
-------------+------------------------------------
city_go_vote |   1.0000 
state_utgo~d |  -0.1425*  1.0000 
state_ltgo~d |   0.4008* -0.1753*  1.0000 
state_gode~t |   0.3929* -0.0767*  0.1532*  1.0000 
*/
*only a little: if state has GO debt limit, then less likely UTGO allowed
*this makes sense including states with revenue bond votes because those will be quite restrictive

*Now look at other state-level restrictions on city GO bonds
pwcorr city_go_vote state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if city_rev_vote == 0 ///
	, bonferroni star(0.01) 
/*
*Strong pos corr w/city_go_vote: state_sep_debtservice_levy, state_sep_pledgerev, state_statutorylien
*Neg corr w/city_go_vote: state_fullfaith pledge 

             | city_g~e state_~h state_~y state_~v state_~n
-------------+---------------------------------------------
city_go_vote |   1.0000 
state_full~h |  -0.3185*  1.0000 
state_sep_~y |   0.5898* -0.2683*  1.0000 
state_sep_~v |   0.1599* -0.0588*  0.2931*  1.0000 
state_stat~n |   0.4882* -0.1659*  0.3904*  0.1362*  1.0000 

*/

*So, state_sep_debtservice_levy, state_sep_pledgerev, and state_statutorylien are all quite correlated
*While state_fullfaith is negatively correlated with those
*So, include state_fullfaith on its own, and include an average of the other three? Or just one of them?
reg city_go_vote state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien if offering_yield_tr != .
estat vif
/*

      Source |       SS           df       MS      Number of obs   =   205,437
-------------+----------------------------------   F(4, 205432)    =  47661.18
       Model |  22972.5888         4  5743.14721   Prob > F        =    0.0000
    Residual |   24754.447   205,432   .12049947   R-squared       =    0.4813
-------------+----------------------------------   Adj R-squared   =    0.4813
       Total |  47727.0359   205,436  .232320703   Root MSE        =    .34713

--------------------------------------------------------------------------------------------
              city_go_vote | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
           state_fullfaith |    .053627   .0019949    26.88   0.000     .0497171     .057537
state_sep_debtservice_levy |   .5814103   .0020636   281.74   0.000     .5773657    .5854549
       state_sep_pledgerev |  -.3188788   .0019574  -162.91   0.000    -.3227152   -.3150424
       state_statutorylien |   .5553948   .0020609   269.49   0.000     .5513554    .5594341
                     _cons |   .1642696   .0024711    66.48   0.000     .1594262     .169113
--------------------------------------------------------------------------------------------


    Variable |       VIF       1/VIF  
-------------+----------------------
state_sep_~v |      1.63    0.612687
state_stat~n |      1.52    0.655783
state_sep_~y |      1.46    0.682631
state_full~h |      1.36    0.736922
-------------+----------------------
    Mean VIF |      1.49
*/
*seems okay on multicollinearity

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
esttab using "$DESCRIPT\250123_bondlevel_sumstats_city.tex", replace ///
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
esttab using "$RESULTS/250116_city_yield_govote_rev.tex", replace t noconstant b(3) ///
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
esttab using "$RESULTS\250123_city_yield_votereq.tex", replace t noconstant b(3) ///
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
esttab using "$RESULTS\250123_city_yield_votereq_UTGO.tex", replace t noconstant b(3) ///
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
esttab using "$RESULTS\250123_city_yield_votereq_LTGO.tex", replace t noconstant b(3) ///
	title("Vote required and offering yield (LTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Bond Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons) label booktabs noobs nonotes 	
	
*(2c) Revenue bonds
eststo clear
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	if rev == 1 ///
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
	if rev == 1 ///
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
	if rev == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS\250123_city_yield_votereq_rev.tex", replace t noconstant b(3) ///
	title("Vote required and offering yield (Revenue)") star(* .10 ** .05 *** .01) ///
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
esttab using "$RESULTS\250123_city_likelihood_go_reg.tex", replace t noconstant b(3) ///
	title("Likelihood of GO bond when city GO vote required") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "State Controls" "County Controls" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 	

*difference of means with purposes as well
*label purpose vars
label var purpose_cuti "Purpose: Utilities" 
label var purpose_elec "Purpose: Power"
label var purpose_fise "Purpose: Fire stations" 
label var purpose_gppi "Purpose: General"
label var purpose_gvpb "Purpose: Public buildings"
label var purpose_limu "Purpose: Libraries and museums"
label var purpose_orec "Purpose: Recreation" 
label var purpose_psed "Purpose: Prim/second education"
label var purpose_wtr "Purpose: Water and sewer"
label var go_unlim "Unlimited tax GO bond"
label var go_lim "Limited tax GO bond"

eststo clear
eststo novote: estpost sum ///
	go_all go_unlim go_lim purpose_cuti purpose_elec purpose_fise purpose_gppi ///
	purpose_gvpb purpose_limu purpose_orec purpose_psed purpose_wtr ///
	if city_go_vote == 0 & city_rev_vote == 0, d
eststo yesvote: estpost sum ///
	go_all go_unlim go_lim purpose_cuti purpose_elec purpose_fise purpose_gppi ///
	purpose_gvpb purpose_limu purpose_orec purpose_psed purpose_wtr ///
	if city_go_vote == 1 & city_rev_vote == 0, d
eststo diff: estpost ttest ///
	go_all go_unlim go_lim purpose_cuti purpose_elec purpose_fise purpose_gppi ///
	purpose_gvpb purpose_limu purpose_orec purpose_psed purpose_wtr ///
	if city_rev_vote == 0, by(city_go_vote) welch
esttab novote yesvote diff using "$RESULTS\250123_city_bondselection_diffmeans.tex", ///
	replace title(Difference in means for bond types and purposes) ///
	cells("mean(pattern(1 1 0) fmt(%9.2fc)) b(star pattern(0 0 1) fmt(%9.2fc)) t(pattern(0 0 1) par fmt(2))") ///
	collabels("Mean" "Difference" "t-stat") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	
