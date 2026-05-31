**************************
*Voting on bonds         *
*Broad sample tests      *
*Last updated: 01/16/25  *
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
use "$MERGENT\Clean\250115_citycountyschool_cusiplevel_statereq.dta", clear

*drop schools and counties
tab issuer_type
/*
Issuer type |      Freq.     Percent        Cum.
------------+-----------------------------------
       city |    334,728       45.82       45.82
     county |     89,654       12.27       58.10
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
          0 |     55,955       29.13       29.13
          1 |    136,139       70.87      100.00
------------+-----------------------------------
      Total |    192,094      100.00
*/

tab city_rev_vote
/*
   City rev |
       vote |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    224,511       93.52       93.52
          1 |     15,557        6.48      100.00
------------+-----------------------------------
      Total |    240,068      100.00
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
state_utgo~d |  -0.0526*  1.0000 
state_ltgo~d |   0.3722* -0.0506*  1.0000 
state_gode~t |   0.2531*  0.0592*  0.2587*  1.0000 
*/
*If unlim tax GO allowed, then less likely that GO vote required (or vice versa)
*If lim tax GO allowed, then more likely that GO vote required (or vice versa)
*Institutionally, this is a little surprising
*If state has a GO debt limit, then more likely that GO vote required (this makes sense). More likely UTGO allowed, more likely LTGO allowed
 
*how much does the restriction to no-rev-vote states matter?
pwcorr city_go_vote state_utgo_allowed state_ltgo_allowed state_godebt_limit  ///
	, bonferroni star(0.01) 
/*
             | city_g~e s~utgo~d s~ltgo~d state_~t
-------------+------------------------------------
city_go_vote |   1.0000 
state_utgo~d |  -0.1337*  1.0000 
state_ltgo~d |   0.2666* -0.1743*  1.0000 
state_gode~t |   0.2580* -0.0769*  0.1465*  1.0000 
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
state_full~h |  -0.2487*  1.0000 
state_sep_~y |   0.7675* -0.3004*  1.0000 
state_sep_~v |   0.3729* -0.1221*  0.2531*  1.0000 
state_stat~n |   0.4493* -0.1346*  0.4478*  0.2239*  1.0000 
*/

pwcorr city_go_vote state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	, bonferroni star(0.01) 
*very little difference when including states with city rev votes

*So, state_sep_debtservice_levy, state_sep_pledgerev, and state_statutorylien are all quite correlated
*While state_fullfaith is negatively correlated with those
*So, include state_fullfaith on its own, and include an average of the other three? Or just one of them?
reg city_go_vote state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien if offering_yield_tr != .
estat vif
/*
      Source |       SS           df       MS      Number of obs   =   187,785
-------------+----------------------------------   F(4, 187780)    =  58847.79
       Model |  21596.4632         4  5399.11581   Prob > F        =    0.0000
    Residual |  17228.2768   187,780  .091747134   R-squared       =    0.5563
-------------+----------------------------------   Adj R-squared   =    0.5562
       Total |    38824.74   187,784  .206752119   Root MSE        =     .3029

--------------------------------------------------------------------------------------------
              city_go_vote | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
           state_fullfaith |   .1312975   .0017429    75.33   0.000     .1278815    .1347134
state_sep_debtservice_levy |   .6670162   .0018116   368.19   0.000     .6634654    .6705669
       state_sep_pledgerev |  -.0594259   .0018472   -32.17   0.000    -.0630465   -.0558054
       state_statutorylien |    .290075   .0019275   150.50   0.000     .2862972    .2938527
                     _cons |   .0844056     .00216    39.08   0.000     .0801719    .0886392
--------------------------------------------------------------------------------------------

. estat vif

    Variable |       VIF       1/VIF  
-------------+----------------------
state_sep_~v |      1.71    0.584142
state_stat~n |      1.70    0.588764
state_sep_~y |      1.44    0.695185
state_full~h |      1.31    0.762477
-------------+----------------------
    Mean VIF |      1.54
*/
*seems okay on multicollinearity

**# Bookmark #1
***Test tightest version of each type of broad sample test**
*(1) When there's a city GO vote requirement, is offering yield different?
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
/*
                                                  Adj R-squared   =     0.7437
                                                  Within R-sq.    =     0.5294
Number of clusters (state)   =         26         Root MSE        =     0.5859

                                               (Std. err. adjusted for 26 clusters in state)
--------------------------------------------------------------------------------------------
                           |               Robust
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.1204383   .0619584    -1.94   0.063    -.2480441    .0071674

*/
reghdfe offering_yield_tr city_go_vote /*ln_amount ln_maturity callable sinkable insured rated i.num_use_proceeds*/ ///
	/*ln_gdp ln_pers_inc ln_percap_inc ln_emp*/ ///
	state_godebt_limit state_utgo_allowed state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien /// 
	if city_rev_vote == 0 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)

*(1a) What about for just GO bonds?
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & bond_type == "go" ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
/*
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.1156487   .0662649    -1.75   0.093    -.2521238    .0208264
*/

*(1b) What about for just rev bonds?
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & rev == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
/*
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.1120099    .044652    -2.51   0.019    -.2039724   -.0200474
*/
*surprising and weird

*(2) When a vote is required on a GO bond, is the offering yield different?
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
/*
                                                  Adj R-squared   =     0.7420
                                                  Within R-sq.    =     0.5240
Number of clusters (state)   =         31         Root MSE        =     0.5890

                                               (Std. err. adjusted for 31 clusters in state)
--------------------------------------------------------------------------------------------
                           |               Robust
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
                  vote_req |  -.1153743   .0417918    -2.76   0.010    -.2007244   -.0300241
*/


*(2a) What about just looking at GO bonds? 
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & bond_type == "go" ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
/*
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
                  vote_req |  -.0793483   .0479276    -1.66   0.110    -.1780571    .0193605
*/

*(2b) What about just looking at GO unlim tax bonds? 
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
/*
                                                  Adj R-squared   =     0.7565
                                                  Within R-sq.    =     0.5411
Number of clusters (state)   =         26         Root MSE        =     0.5621

                                               (Std. err. adjusted for 26 clusters in state)
--------------------------------------------------------------------------------------------
                           |               Robust
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
                  vote_req |  -.1178868   .0571188    -2.06   0.050    -.2355252   -.0002483
*/
*(2c) What about just looking at GO lim tax bonds? 
reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_lim == 1 ///
	, absorb(yrmonth num_use_proceeds) vce(cluster state)
/*
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
                  vote_req |  -.1646807   .0693479    -2.37   0.030    -.3116916   -.0176698
*/
	
*Note that we can't look at rev bonds because there's no variation in vote_req if we set city_rev_vote == 0
	
*(3) When there's a GO vote requirement, are GO bonds less likely?**	
gen go_all = 1 if go_lim == 1 | go_unlim == 1
replace go_all = 0 if go_all == .
label var go_all "GO bond"
	
reghdfe go_all city_go_vote state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
*here, not controlling for use of proceeds because the purposes might change if the GO bond choice changes
/*
                                                  Adj R-squared   =     0.1545
                                                  Within R-sq.    =     0.1282
Number of clusters (state)   =         26         Root MSE        =     0.4259

                                               (Std. err. adjusted for 26 clusters in state)
--------------------------------------------------------------------------------------------
                           |               Robust
                    go_all | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |   .0194487   .1180555     0.16   0.870    -.2236912    .2625885
*/

*(3a) GO unlimited tax
reghdfe go_unlim city_go_vote state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
/*                                               Adj R-squared   =     0.2723
                                                  Within R-sq.    =     0.2368
Number of clusters (state)   =         26         Root MSE        =     0.4226

                                               (Std. err. adjusted for 26 clusters in state)
--------------------------------------------------------------------------------------------
                           |               Robust
                  go_unlim | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |   .0577263   .1364993     0.42   0.676    -.2233992    .3388518
*/

*(3b) GO limited tax	
reghdfe go_lim city_go_vote state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
/*
                                                  Adj R-squared   =     0.3150
                                                  Within R-sq.    =     0.2817
Number of clusters (state)   =         26         Root MSE        =     0.3613

                                               (Std. err. adjusted for 26 clusters in state)
--------------------------------------------------------------------------------------------
                           |               Robust
                    go_lim | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.0382776    .060056    -0.64   0.530    -.1619652    .0854101
*/
	
*(3c) Difference in means
ttest go_all if city_rev_vote == 0, by(city_go_vote) welch	
/*
Two-sample t test with unequal variances
------------------------------------------------------------------------------
   Group |     Obs        Mean    Std. err.   Std. dev.   [95% conf. interval]
---------+--------------------------------------------------------------------
       0 |  55,955    .8221964    .0016164    .3823507    .8190283    .8253645
       1 | 108,943    .6226742    .0014686    .4847197    .6197959    .6255526
---------+--------------------------------------------------------------------
Combined | 164,898    .6903783    .0011386    .4623391    .6881468    .6926098
---------+--------------------------------------------------------------------
    diff |            .1995222    .0021839                .1952418    .2038025
------------------------------------------------------------------------------
    diff = mean(0) - mean(1)                                      t =  91.3613
H0: diff = 0                             Welch's degrees of freedom =   138121

    Ha: diff < 0                 Ha: diff != 0                 Ha: diff > 0
 Pr(T < t) = 1.0000         Pr(|T| > |t|) = 0.0000          Pr(T > t) = 0.0000
*/
	
ttest go_unlim if city_rev_vote == 0, by(city_go_vote) welch	
/*

Two-sample t test with unequal variances
------------------------------------------------------------------------------
   Group |     Obs        Mean    Std. err.   Std. dev.   [95% conf. interval]
---------+--------------------------------------------------------------------
       0 |  55,955    .6045572     .002067      .48895    .6005059    .6086086
       1 | 108,943    .3700926    .0014628    .4828315    .3672255    .3729598
---------+--------------------------------------------------------------------
Combined | 164,898    .4496537     .001225    .4974603    .4472527    .4520548
---------+--------------------------------------------------------------------
    diff |            .2344646    .0025323                .2295014    .2394279
------------------------------------------------------------------------------
    diff = mean(0) - mean(1)                                      t =  92.5901
H0: diff = 0                             Welch's degrees of freedom =   111655

    Ha: diff < 0                 Ha: diff != 0                 Ha: diff > 0
 Pr(T < t) = 1.0000         Pr(|T| > |t|) = 0.0000          Pr(T > t) = 0.0000
*/

ttest go_lim if city_rev_vote == 0, by(city_go_vote) welch	
/*
Two-sample t test with unequal variances
------------------------------------------------------------------------------
   Group |     Obs        Mean    Std. err.   Std. dev.   [95% conf. interval]
---------+--------------------------------------------------------------------
       0 |  55,955    .2176392    .0017444    .4126444    .2142201    .2210583
       1 | 108,943    .2525816    .0013164     .434495    .2500015    .2551617
---------+--------------------------------------------------------------------
Combined | 164,898    .2407246    .0010528    .4275247    .2386611    .2427881
---------+--------------------------------------------------------------------
    diff |           -.0349425    .0021854               -.0392258   -.0306591
------------------------------------------------------------------------------
    diff = mean(0) - mean(1)                                      t = -15.9891
H0: diff = 0                             Welch's degrees of freedom =   118149

    Ha: diff < 0                 Ha: diff != 0                 Ha: diff > 0
 Pr(T < t) = 0.0000         Pr(|T| > |t|) = 0.0000          Pr(T > t) = 1.0000
*/
	
*(4) What about purposes?
*(4a) Regression form:
reghdfe purpose_gppi city_go_vote state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)	
/*                                                  Adj R-squared   =     0.1005
                                                  Within R-sq.    =     0.0710
Number of clusters (state)   =         26         Root MSE        =     0.4708

                                               (Std. err. adjusted for 26 clusters in state)
--------------------------------------------------------------------------------------------
                           |               Robust
              purpose_gppi | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |   .0490489   .0870176     0.56   0.578    -.1301671    .2282649
*/
*run regressions for all
local temp agri air brdg cfct civc corr csed cuti edev elec fise flod gas gppi gvpb hied hoeq hosp idev ///
	irrg limu mall mass mfhg na nurs offb ohca ondv  
foreach x of local temp{
	reghdfe purpose_`x' city_go_vote state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
		state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
		ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
		if city_rev_vote == 0 ///
		, absorb(yrmonth) vce(cluster state)
}
*many purposes aren't populated enough, don't have enough variation
/*
- edev: city_go_vote |  -.0137863   .0083488    -1.65   0.111 
- hosp: city_go_vote |   .0222157   .0073546     3.02   0.006
- limu: city_go_vote |  -.0234705   .0104592    -2.24   0.034
- mfhg: city_go_vote |  -.0034915   .0020167    -1.73   0.096
- nurs: city_go_vote |   .0010936   .0007029     1.56   0.132
- ohca: city_go_vote |   .0117298   .0062464     1.88   0.072
*/

local temp opub orec oted oths otrn outi park pfr pkg pole poll ///
	pres psed redv sani seap sfhg smhg spor stln tele thtr toll vets wast wtr 
foreach x of local temp{
	reghdfe purpose_`x' city_go_vote state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
		state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
		ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
		if city_rev_vote == 0 ///
		, absorb(yrmonth) vce(cluster state)
}
/*
- orec: city_go_vote |   .0147627   .0050903     2.90   0.008 
- tele: city_go_vote |   .0001959   .0000934     2.10   0.046
- wtr: city_go_vote |  -.1073231    .062687    -1.71   0.099
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
        AK |     1,517        129 |     1,646 
        FL |     1,342      4,977 |     6,319 
        GA |       834        672 |     1,506 
        IA |    12,763      3,184 |    15,947 
        LA |     1,304      1,495 |     2,799 
        MI |    12,343      2,529 |    14,872 
        MO |     2,446      2,361 |     4,807 
        MT |       475        347 |       822 
        NC |     3,014      1,900 |     4,914 
        NE |     5,352      2,366 |     7,718 
        NM |       603      1,215 |     1,818 
        NV |       758        125 |       883 
        OH |     7,231      1,887 |     9,118 
        OR |     1,751      1,500 |     3,251 
        TX |    11,587     11,367 |    22,954 
        UT |       490      2,160 |     2,650 
        WA |     3,946      2,443 |     6,389 
        WV |        37        415 |       452 
        WY |        43         35 |        78 
-----------+----------------------+----------
     Total |    67,836     41,107 |   108,943 

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
-----------+----------------------+----------
     Total |    46,006      9,949 |    55,955 
*/			
	
**Bond-level summary stats**
eststo clear
eststo: estpost sum city_go_vote vote_req go_all offering_yield_tr ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & city_go_vote != . , d
esttab using "$DESCRIPT\250115_bondlevel_sumstats_city.tex", replace ///
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
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
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
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
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
esttab using "$RESULTS/250115_city_yield_govote_pooled.tex", replace t noconstant b(3) ///
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
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
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
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
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
esttab using "$RESULTS/250115_city_yield_govote_UTGO.tex", replace t noconstant b(3) ///
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
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
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
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
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
esttab using "$RESULTS/250115_city_yield_govote_LTGO.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (LTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Bond Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons) label booktabs noobs nonotes 
	
*(1c) Revenue
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
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
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
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
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
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
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
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
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
esttab using "$RESULTS\250115_city_yield_votereq.tex", replace t noconstant b(3) ///
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
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
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
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
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
esttab using "$RESULTS\250115_city_yield_votereq_UTGO.tex", replace t noconstant b(3) ///
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
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
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
	state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
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
esttab using "$RESULTS\250115_city_yield_votereq_LTGO.tex", replace t noconstant b(3) ///
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
eststo: qui reghdfe go_all city_go_vote state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe go_all city_go_vote state_godebt_limit state_utgo_allowed state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS\250115_city_likelihood_go_reg.tex", replace t noconstant b(3) ///
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
esttab novote yesvote diff using "$RESULTS\250115_city_bondselection_diffmeans.tex", ///
	replace title(Difference in means for bond types and purposes) ///
	cells("mean(pattern(1 1 0) fmt(%9.2fc)) b(star pattern(0 0 1) fmt(%9.2fc)) t(pattern(0 0 1) par fmt(2))") ///
	collabels("Mean" "Difference" "t-stat") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	
