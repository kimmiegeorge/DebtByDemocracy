************************
*Voting on bonds       *
*WA, NC election data  *
*Last updated: 03/24/25*
************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global ELEC "$DATA\Bond Elections"
global RESULTS "$MAIN\RESULTS\2025-03_elections"

***Import WA, NC data***
*Import and save WA
import delimited using "$ELEC\250324_wa_electiondata.csv", varn(1) clear
*clean month
tab elec_month
*only april, august, feb, nov; most in nov
replace elec_month = "4" if elec_month == "April"
replace elec_month = "8" if elec_month == "August"
replace elec_month = "2" if elec_month == "February"
replace elec_month = "11" if elec_month == "November"
destring elec_month, replace
gen state = "WA"
*save
save "$ELEC\250324_wa_electiondata_clean.dta", replace

*Import and save NC
import delimited using "$ELEC\250324_nc_electiondata.csv", varn(1) clear
rename purpose purpose_raw
gen date_new = date(date,"MDY")
format date_new %td
gen elec_month = month(date_new)
gen elec_yr = year(date_new)
drop date
rename date_new date
gen state = "NC"
*save
save "$ELEC\250324_nc_electiondata_clean.dta", replace

**Append the two**
append using "$ELEC\250324_wa_electiondata_clean.dta"
gen ln_amount = ln(1+amount)
gen fail = 1 if pass == 0
replace fail = 0 if pass == 1
order state seed_issuer elec_month elec_yr purp_broad fail pass votepct_yes votepct_no amount ln_amount , before(issuer_type)
order purpose_raw, after(county)
*save
save "$ELEC\250324_wa_nc_electiondata_clean.dta", replace

**Descriptives**
tab purp_broad if state == "WA" 
/*
  purp_broad |      Freq.     Percent        Cum.
-------------+-----------------------------------
        arts |          4        6.15        6.15
        fire |         14       21.54       27.69
    parksrec |         20       30.77       58.46
      police |         10       15.38       73.85
     pubbldg |         11       16.92       90.77
   transport |          4        6.15       96.92
      wtrswr |          2        3.08      100.00
-------------+-----------------------------------
       Total |         65      100.00
*/
tab purp_broad if state == "NC" & issuer_type == "city"
/*
  purp_broad |      Freq.     Percent        Cum.
-------------+-----------------------------------
        arts |          2        1.40        1.40
       envir |          3        2.10        3.50
        fire |          2        1.40        4.90
genpubimprov |         10        6.99       11.89
     housing |         15       10.49       22.38
    parksrec |         45       31.47       53.85
      police |          6        4.20       58.04
     pubbldg |          2        1.40       59.44
   transport |         48       33.57       93.01
   utilities |          1        0.70       93.71
      wtrswr |          9        6.29      100.00
-------------+-----------------------------------
       Total |        143      100.00
*/
*Pretty different categorizations because WA has more granular data on bond purpose than NC 

*Look at corr between size of bond and passage in each state*
pwcorr ln_amount pass if state == "WA", star(0.01)
/*
             | ln_amo~t     pass
-------------+------------------
   ln_amount |   1.0000 
        pass |  -0.3195*  1.0000 
*/
reg pass ln_amount if state == "WA"
/*
        pass | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]
-------------+----------------------------------------------------------------
   ln_amount |  -.1008649   .0376929    -2.68   0.009    -.1761882   -.0255415
*/
*very neg corr in WA; interesting because they're very pos corr in TX
*could be because in WA, many services can theoretically be funded through LTGO, so the UTGO are "extra" and viewed more negatively. By definition, LTGO proj require less prop tax increase, so are likely smaller in $
*while in TX, services have to be voted on to be funded
sum ln_amount if state == "WA", d
*mean = 15.95939, median = 16.16689
sum amount if state == "WA", d
*mean = 24,000,000, median = 10,500,000
sum pass if state == "WA", d
*mean = 0.523
sum votepct_no if state == "WA", d
*mean = 0.4154, median = 0.3846

pwcorr ln_amount pass if state == "NC" & issuer_type == "city", star(0.01)
/*
             | ln_amo~t     pass
-------------+------------------
   ln_amount |   1.0000 
        pass |   0.1128   1.0000 
*/
*makes sense no corr in NC because almost always pass
sum ln_amount if state == "NC" & issuer_type == "city", d
*mean = 16.5910, median = 16.64872
sum amount if state == "NC" & issuer_type == "city", d
*mean = 30,100,000, median = 17,000,000
sum pass if state == "NC" & issuer_type == "city", d
*mean = 0.937
*NC bonds tend to be bigger than WA UTGO bonds

*At a high level, suggests that if the city has more options for funding (like LTGO w/o vote), then it's harder for vote to pass
*But if the city has fewer options for funding (like NC, TX), then it's easier for the vote to pass

local temp pubbldg transport arts parksrec fire police wtrswr 
foreach x of local temp{
	sum fail if purp_broad == "`x'" & state == "WA"
	sum votepct_no if purp_broad == "`x'" & state == "WA"
}
/*purp_broad / fail avg / votepct_no avg
pubbldg / 0.545 / 0.450
transport / 0.5 / 0.4923
arts / 0.5 / 0.440
parksrec / 0.55 / 0.398
fire / 0.071 / 0.325
police / 0.8 / 0.497
wtrswr / 0.5 / 0.4216
*/

/*Old:
*think we have to somehow differentiate between fire/EMS, police, and justice
*In Mergent data, justice is only courts and jails
*Mergent groups police station + equipment together; groups fire station + equipment together
*/
local temp genpubimprov pubbldg transport arts parksrec envir housing fire police utilities wtrswr 
foreach x of local temp{
	sum fail if purp_broad == "`x'" & state == "NC" & issuer_type == "city"
}
/*purp_broad / fail avg 
gepubimprov / 0
pubbldg / 0.5  
transport / 0
arts / 0.5
parksrec / 0.133
envir / 0 
housing / 0  
fire / 0
police / 0
utilities / 1
wtrswr / 0
*/
*I think we can't use the NC data. There's too little variation in passage and the data's purposes are too coarse

**make vote margin and close vars for WA**
use "$ELEC\250324_wa_nc_electiondata_clean.dta", clear
keep if state == "WA"

*For vote margin vars, note that WA requires 60% - that's why there's so much more variation than in NC or TX
gen votemargin = votepct_yes - 0.6 if pass == 1
replace votemargin = 0.6 - votepct_yes if pass == 0

*Gen close var if vote margin is within 10
gen close10 = 1 if votemargin <= 0.1
replace close10 = 0 if close10 == .

sum fail
/*
    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
        fail |         65    .4769231    .5033541          0          1
*/
sum votepct_no
/*
    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
  votepct_no |         65    .4154046    .1567893      .1774      .8944
*/
sum votepct_yes
/*
    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
 votepct_yes |         65    .5845954    .1567893      .1056      .8226
*/

*If we want to make a similar graph to TX data
local temp pubbldg transport arts parksrec fire police wtrswr 
foreach x of local temp{
	sum votemargin if purp_broad == "`x'" & pass == 1
	sum votemargin if purp_broad == "`x'" & pass == 0 
}
/*Means only
- pubbldg: passed = 0.0703; failed = 0.149
- transport: passed = 0.0626; failed = 0.2472
- arts: passed = 0.03305; failed = 0.1136
- parksrec: passed = 0.1054; failed = 0.0825
- fire: passed = 0.0881; failed = 0.0973
- police: passed = 0.063; failed = 0.1369
- wtrswr: passed = 0.1985; failed = 0.2417
*/

