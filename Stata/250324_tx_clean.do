****************************
*Voting on bonds           *
*Clean data for Texas pilot*
*Last updated: 03/24/25    *
****************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA/TX"
global RESULTS "$MAIN\RESULTS\TX"
global DESCRIPT "$MAIN\Descriptives\TX"

***Start with issue-level file of merged Mergent + MSRB***
use "$MERGENT\Clean\241120_issue_level.dta", clear

*Get unique seed issuer names for TX cities and counties
keep if state == "TX" & inlist(issuer_type,"city","county")
*1,758 issuances
*make seed_issuer not strL for later rangejoin
gen temp1 = seed_issuer
drop seed_issuer
rename temp1 seed_issuer
order seed_issuer, after(state)
*save file
save "$TX\241120_tx_issue_level.dta", replace
*get list of unique seed issuer names to match to TX voting data
preserve
keep seed_issuer seed_issuer_id
duplicates drop
count
*357 seed issuers
export delimited using "$TX\241120_tx_seedissuer_formatch.csv", replace
restore

*Fuzzy matched these names, then merge in crosswalk to TX BRB names
use "$TX/240512_TX_uniquegovt_election_issuance.dta", clear
*make uppercase names
gen muni_upper = upper(muni_formatch)
*merge in fuzzy matched crosswalk to get governmentname (TX BRB identifier)
mmerge muni_upper using "$TX\241120_tx_uniquegovt_fuzzymatch_crosswalk.dta", ///
	type(1:n) missing(nomatch)
/*
                 obs |    939
                vars |     11  (including _merge)
         ------------+---------------------------------------------------------
              _merge |    606  obs only in master data                (code==1)
                     |    333  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
keep if _merge == 3
drop _merge match
sort muni_id_formatch
order governmentname muni_upper seed_issuer county
drop governmenttype issuername muni_formatch muni_id_formatch
duplicates tag governmentname, gen(dup)
*br if dup > 0
*2 dups, fix these
drop if governmentname == "Burkburnett" & seed_issuer == "BURNET TEX"
drop if governmentname == "El Paso" & seed_issuer == "EL PA"
drop dup
*save, then merge into voting data 
save "$TX\241120_tx_uniquegovt_fuzzymatch_crosswalk_step2.dta", replace

*Start with voting data, then merge in
use "$TX/240510_TX_local_election.dta", clear
*What about keeping not just ones in Mergent? We can use all cities for the pure voting descriptives
*If we do this, then we have very similar number of observations to keeping seed issuers, so don't do this

mmerge governmentname using "$TX\241120_tx_uniquegovt_fuzzymatch_crosswalk_step2.dta", ///
	type(n:1) missing(nomatch)
/*
                 obs |   9082
                vars |     16  (including _merge)
         ------------+---------------------------------------------------------
              _merge |   7187  obs only in master data                (code==1)
                     |     81  obs only in using data                 (code==2)
                     |   1814  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
sort seed_issuer
*not matched are typically school districts and special districts
keep if _merge == 3
drop _merge
order seed_issuer electiondate amount votesfor votesagainst result purpose, before(governmentname)

*clean election date
gen temp1 = date(electiondate, "MDY")
format temp1 %td 
gen year = year(temp1)
gen month = month(temp1)
rename temp1 date_election
order date_election year month, after(seed_issuer)
drop electiondate

*clean result
tab result
/*
     Result |      Freq.     Percent        Cum.
------------+-----------------------------------
  Cancelled |         20        1.10        1.10
    Carried |      1,601       88.26       89.36
   Defeated |        187       10.31       99.67
         NR |          6        0.33      100.00
------------+-----------------------------------
      Total |      1,814      100.00
*/

*gen winning margin
gen votestotal = votesfor + votesagainst
gen votemargin = (votesfor - votesagainst) / votestotal if result == "Carried"
replace votemargin = (votesagainst - votesfor) / votestotal if result == "Defeated"
*br if votemargin == .
*missing if cancelled or too old, makes sense
order votemargin votestotal votesfor votesagainst purpose purposedescription, after(result)

sort seed_issuer date_election

*Mergent data has 2000-2020; only keep voting years from 1995 (not clear how long it takes to issue) to 2020
sum year
*voting data goes from 1953 to 2024
keep if inrange(year,1995,2024)

*Note that the voting data is at the proposition level. One bond issuance is made up of multiple propositions

*Before we match to Mergent, which will only have approved proposals, is there any correlation between passing and other characteristics?
*Look at corr between: passage, amount, purpose
gen passed = 1 if result == "Carried"
replace passed = 0 if passed == .
pwcorr passed amount, star(0.1)
*almost zero correlation, r = 0.0022, no significance at 10% level
sum votemargin if passed == 1
*max 1 = data errors
sum votemargin if passed == 0
*max 1, min 0 = data errors

pwcorr votemargin amount if passed == 1 & votemargin != 1, star(0.01)
*positive corr = 0.0892, significant at the 1% level. larger bonds are more likely to pass by more, conditional on passing
pwcorr votemargin amount if passed == 0 & votemargin != 1 & votemargin != 0, star(0.01)
*negative corr = -0.07888, not significant at 10% level
*so conditional on failing, size of bond doesn't matter
*but conditional on passing, larger bonds pass with more support (a bit counterintuitive)

*what about log of amount
*hist amount
gen ln_amount = ln(1+amount)
*hist ln_amount
pwcorr passed ln_amount, star(0.01)
*corr = 0.0491, only sig at 10% level
pwcorr votemargin ln_amount if passed == 1 & votemargin != 1, star(0.01)
*corr = 0.1171, sig at 1% level
pwcorr votemargin ln_amount if passed == 0 & votemargin != 1 & votemargin != 0, star(0.1)
*pos corr = 0.0136, but not sig at 10% level
*with logs, takeaway is the same: weak pos corr between amount and getting passed
*if passed, then larger bonds pass more strongly

*purpose is "other" 76% of the time; purposedescription is more detailed, but no consistent categories
*KM went by hand to match purposes to Mergent purp_broad categories
*Merge in
mmerge purposedescription using "$TX\2025-03-24_texasbondpurpose_classify.dta", type(n:1) missing(nomatch)
*all matched
drop _merge

tab purp_broad
/*
  purp_broad |      Freq.     Percent        Cum.
-------------+-----------------------------------
        arts |        133        7.81        7.81
     econdev |         20        1.18        8.99
        educ |          3        0.18        9.17
       envir |         21        1.23       10.40
        fire |         91        5.35       15.75
genpubimprov |         37        2.17       17.92
      health |         31        1.82       19.74
     housing |         11        0.65       20.39
     justice |         63        3.70       24.09
       other |         75        4.41       28.50
    parksrec |        373       21.92       50.41
     pension |          2        0.12       50.53
      police |        161        9.46       59.99
     pubbldg |        109        6.40       66.39
   transport |        494       29.02       95.42
   utilities |         39        2.29       97.71
      wtrswr |         39        2.29      100.00
-------------+-----------------------------------
       Total |      1,702      100.00
*/

*put educ, pension into other
*group street into transport
replace purp_broad = "other" if purp_broad == "educ"
replace purp_broad = "other" if purp_broad == "pension"

local temp arts econdev envir fire genpubimprov health housing justice other parksrec police pubbldg transport utilities wtrswr
foreach x of local temp{
	gen purp_broad_`x' = 1 if purp_broad == "`x'"
	replace purp_broad_`x' = 0 if purp_broad_`x' == .
}

label var purp_broad_arts "Arts" 
label var purp_broad_econdev "Econ dev"
label var purp_broad_envir "Environment"
label var purp_broad_fire "Fire"
label var purp_broad_genpubimprov "Gen pub improv"
label var purp_broad_health "Healthcare" 
label var purp_broad_housing "Housing"
label var purp_broad_justice "Courts"
label var purp_broad_other "Other"
label var purp_broad_parksrec "Parks \& rec"
label var purp_broad_police "Police"
label var purp_broad_pubbldg "Pub building" 
label var purp_broad_transport "Transport"
label var purp_broad_utilities "Utilities"
label var purp_broad_wtrswr "Water \& sewer"
label var ln_amount "Bond amount"

tab purp_broad
/*
  purp_broad |      Freq.     Percent        Cum.
-------------+-----------------------------------
        arts |        133        7.81        7.81
     econdev |         20        1.18        8.99
       envir |         21        1.23       10.22
        fire |         91        5.35       15.57
genpubimprov |         37        2.17       17.74
      health |         31        1.82       19.57
     housing |         11        0.65       20.21
     justice |         63        3.70       23.91
       other |         80        4.70       28.61
    parksrec |        373       21.92       50.53
      police |        161        9.46       59.99
     pubbldg |        109        6.40       66.39
   transport |        494       29.02       95.42
   utilities |         39        2.29       97.71
      wtrswr |         39        2.29      100.00
-------------+-----------------------------------
       Total |      1,702      100.00
*/

*Output

sort seed_issuer date_election ln_amount

*Look at average amounts and compare to WA
sum amount, d
*mean = 36,200,000; median = 9,839,250
sum ln_amount, d
*mean = 16.10708; median = 16.10189
/*Avg bond is higher in TX than WA; median is similar
sum amount if state == "WA", d
*mean = 24,000,000, median = 10,500,000
sum ln_amount if state == "WA", d
*mean = 15.95939, median = 16.16689
*/


**Descriptive table about approval rates based on purpose, amount**
reg passed ln_amount
/*
      Source |       SS           df       MS      Number of obs   =     1,702
-------------+----------------------------------   F(1, 1700)      =      6.32
       Model |  .687827075         1  .687827075   Prob > F        =    0.0120
    Residual |  184.905592     1,700  .108767996   R-squared       =    0.0037
-------------+----------------------------------   Adj R-squared   =    0.0031
       Total |   185.59342     1,701  .109108418   Root MSE        =     .3298

------------------------------------------------------------------------------
      passed | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]
-------------+----------------------------------------------------------------
   ln_amount |   .0117071   .0046554     2.51   0.012     .0025761    .0208381
       _cons |   .6868738   .0754103     9.11   0.000     .5389671    .8347805
------------------------------------------------------------------------------
*/
reghdfe passed ln_amount ///
	, absorb(county year month) vce(cluster county)
/*
                                                  Adj R-squared   =     0.2048
                                                  Within R-sq.    =     0.0096
Number of clusters (county)  =         80         Root MSE        =     0.2942

                                (Std. err. adjusted for 80 clusters in county)
------------------------------------------------------------------------------
             |               Robust
      passed | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-------------+----------------------------------------------------------------
   ln_amount |   .0189434   .0059737     3.17   0.002     .0070529    .0308338
*/
gegen purp_broad_id = group(purp_broad)
reghdfe passed ln_amount ///
	, absorb(county year month purp_broad_id) vce(cluster county)
/*
                                                  Adj R-squared   =     0.2256
                                                  Within R-sq.    =     0.0076
Number of clusters (county)  =         80         Root MSE        =     0.2904

                                (Std. err. adjusted for 80 clusters in county)
------------------------------------------------------------------------------
             |               Robust
      passed | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-------------+----------------------------------------------------------------
   ln_amount |   .0175785    .006572     2.67   0.009     .0044972    .0306598

*/
*a puzzle that larger bonds are more likely to be approved. Maybe because there's more city persuasion effort?

*Look at avg vote margin depending on purpose
*Make graph
local temp genpubimprov pubbldg justice transport health arts parksrec envir econdev housing fire police utilities wtrswr other
foreach x of local temp{
	sum votemargin if purp_broad == "`x'" & passed == 1 & votemargin != 1
	sum votemargin if purp_broad == "`x'" & passed == 0 & votemargin != 1
}


gen failed = 1 if passed == 0
replace failed = 0 if passed == 1

local temp genpubimprov pubbldg justice transport health arts parksrec envir econdev housing fire police utilities wtrswr other
foreach x of local temp{
	sum failed if purp_broad == "`x'" 
}
*means are generally super high




sum passed, d

*gen indicator of close vote: 5%, 10% on either side
gen close5 = 1 if votemargin <= 0.05
replace close5 = 0 if close5 == .
gen close10 = 1 if votemargin <= 0.1
replace close10 = 0 if close10 == .
sum close5 close10, d
/*
    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
      close5 |      1,702     .059342     .236333          0          1
     close10 |      1,702    .1145711    .3185972          0          1
*/
count if close5 == 1
*101 propositions
count if close10 == 1
*195 propositions

*average votemargin if passed? average votemargin if defeated
sum votemargin if passed == 1 & votemargin != 1, d
*if it passes, it does so by 36%
/*
    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
  votemargin |      1,269    .3580573    .1928687   .0001714   .8521376
*/
sum votemargin if passed == 0  & votemargin != 1 , d
*if it fails, it does so by 20%
/*
                         votemargin
-------------------------------------------------------------
      Percentiles      Smallest
 1%     .0003611              0
 5%      .010846       .0003611
10%     .0221626       .0006956       Obs                 185
25%      .066909       .0009801       Sum of wgt.         185

50%     .1455665                      Mean           .1956326
                        Largest       Std. dev.      .1631963
75%     .3119861       .5805195
90%     .4501702       .6435046       Variance        .026633
95%      .501016       .6981132       Skewness       .9442272
99%     .6981132       .7284813       Kurtosis       3.204987
*/

*Have a Panel A with sum stats and then a panel B with summary of passage likelihood depending on purpose
eststo clear
eststo: estpost sum passed close5 close10 ln_amount purp_broad_genpubimprov purp_broad_pubbldg ///
	purp_broad_transport purp_broad_health purp_broad_arts purp_broad_parksrec ///
	purp_broad_envir purp_broad_econdev purp_broad_housing purp_broad_safety ///
	purp_broad_justice purp_broad_utilities purp_broad_wtrswr purp_broad_other, d
eststo: estpost sum votemargin if passed == 1 & votemargin != 1, d
eststo: estpost sum votemargin if passed == 0 & votemargin != 1, d
esttab using "$DESCRIPT\250312_tx_sumstats.tex", replace ///
	title("Summary statistics for Texas bond propositions") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	
	

eststo clear
local temp genpubimprov pubbldg justice transport health arts parksrec envir econdev housing safety utilities wtrswr other
foreach x of local temp{
	eststo: estpost sum failed if purp_broad == "`x'", d
}
esttab using "$DESCRIPT\250318_tx_purposefailrates.tex", replace ///
	title("Failure rates for Texas bond propositions by purpose") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	
	


**Table about likelihood of passage based on purpose**
eststo clear
local temp genpubimprov pubbldg transport health arts parksrec 
foreach x of local temp{
	eststo: qui reghdfe passed purp_broad_`x' ln_amount ///
	, absorb(county year month) vce(cluster county)
	estadd local countyFE "Yes"
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local SE "County"	
}
esttab using "$RESULTS\250309_tx_passed_purpose_pt1.tex", replace t noconstant b(3) ///
	title("Likelihood of passage for projects in TX") star(* .10 ** .05 *** .01) ///
	s(N r2_a countyFE yearFE monthFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "County FE" "Year FE" "Month FE" "Cluster")) ///
	label booktabs noobs nonotes 
	
reghdfe passed purp_broad_envir ln_amount ///
	, absorb(county year month) vce(cluster county)
	
eststo clear
local temp econdev housing safety justice utilities wtrswr other
foreach x of local temp{
	eststo: qui reghdfe passed purp_broad_`x' ln_amount ///
	, absorb(county year month) vce(cluster county)
	estadd local countyFE "Yes"
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local SE "County"	
}
esttab using "$RESULTS\250309_tx_passed_purpose_pt2.tex", replace t noconstant b(3) ///
	title("Likelihood of passage for projects in TX") star(* .10 ** .05 *** .01) ///
	s(N r2_a countyFE yearFE monthFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "County FE" "Year FE" "Month FE" "Cluster")) ///
	label booktabs noobs nonotes 
	
reghdfe passed purp_broad_utilities ln_amount ///
	, absorb(county year month) vce(cluster county)
	
*run with failed instead
gen failed = 1 if passed == 0
replace failed = 0 if passed == 1	

eststo clear
local temp genpubimprov pubbldg justice transport health arts parksrec envir
foreach x of local temp{
	eststo: qui reghdfe failed purp_broad_`x' ln_amount ///
	, absorb(county year month) vce(cluster county)
	estadd local countyFE "Yes"
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local SE "County"	
}
esttab using "$RESULTS\250312_tx_failed_purpose_pt1.tex", replace t noconstant b(3) ///
	title("Likelihood of passage for projects in TX") star(* .10 ** .05 *** .01) ///
	s(N r2_a countyFE yearFE monthFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "County FE" "Year FE" "Month FE" "Cluster")) ///
	label booktabs noobs nonotes 
	
eststo clear
local temp econdev housing safety utilities wtrswr other
foreach x of local temp{
	eststo: qui reghdfe failed purp_broad_`x' ln_amount ///
	, absorb(county year month) vce(cluster county)
	estadd local countyFE "Yes"
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local SE "County"	
}
esttab using "$RESULTS\250312_tx_failed_purpose_pt2.tex", replace t noconstant b(3) ///
	title("Likelihood of failure for projects in TX") star(* .10 ** .05 *** .01) ///
	s(N r2_a countyFE yearFE monthFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "County FE" "Year FE" "Month FE" "Cluster")) ///
	label booktabs noobs nonotes 
	
	
	

*Also, defeated proposals won't have bonds issued, so won't be in the Mergent data at all
replace votemargin = . if result == "Defeated"
rename votemargin winmargin
sum winmargin, d
*browse if winmargin == 1
*br if winmargin == 1
*data errors, make these missing
replace winmargin = . if winmargin == 1
sum winmargin, d
/*
                          winmargin
-------------------------------------------------------------
      Percentiles      Smallest
 1%     .0108857       .0001714
 5%     .0528071       .0014202
10%     .1078787           .002       Obs               1,031
25%     .2173913       .0020346       Sum of wgt.       1,031

50%     .3692308                      Mean           .3685374
                        Largest       Std. dev.      .1961786
75%     .5066148       .8372093
90%     .6380978       .8387097       Variance       .0384861
95%     .7079466       .8464079       Skewness       .1448413
99%     .7876033       .8521376       Kurtosis       2.301582
*/
*hist winmargin
count if winmargin < 0.05 & winmargin != .
*if they pass, they pass comfortably, but ~5% are within a 5% margin


*Later, realized a typo in San Antonio's date for the May 12, 2007 election. Fix:
replace date_election = date("05/12/2007", "MDY") if seed_issuer == "SAN ANTONIO TEX" & year == 2007

*Later, realized typo in Corpus Christi's Nov 2004 election dates. Fix:
replace date_election = date("11/02/2004", "MDY") if seed_issuer == "CORPUS CHRISTI TEX" & year == 2004

sort seed_issuer date_election propnumber

*save data
save "$TX/250310_txmerge_election_proposallevel.dta", replace

use "$TX/250310_txmerge_election_proposallevel.dta", clear

*Conditional on the proposal passing:
local temp arts econdev genpubimprov health housing justice other parksrec pubbldg safety transport utilities wtrswr
foreach x of local temp{
	reg winmargin purp_broad_`x', vce(robust)
	reg winmargin purp_broad_`x' ln_amount, vce(robust)
	reghdfe winmargin purp_broad_`x' ln_amount, absorb(county) vce(cluster county)
	reghdfe winmargin purp_broad_`x' ln_amount, absorb(county year) vce(cluster county)
}
/*Conditional on the proposal passing:
- Less support for genpubimprov, econdev, housing, maybe health, justice, parksrec, pubbldg
- More support for safety, transport, utilities, wtrswr
*/

**3/10 JH to make table here too**

*only keep if carried
keep if result == "Carried"
*only keep if winmargin isn't missing 
drop if winmargin == .


/*How to deal with the dates:
- Suppose there is an earlier vote, A, and a later vote, B
- If the offering_date is after date_A but before date_B, then match it to A's voting data
- How to use Stata to merge in this way? I think there's a way in SAS
- Try rangejoin
*/
*ssc install rangejoin

*First issue is how to aggregate voting data to the date_election-level
*Need to aggregate margin and purpose
order seed_issuer date_election year month amount winmargin 

*grab purpose of largest amount
gegen temp1 = max(amount), by(seed_issuer date_election)
gen temp2 = purp_broad if amount == temp1
gegen purp_largest = mode(temp2), by(seed_issuer date_election)
*br if purp_largest == ""
*these have the same amount, fix manually
replace purp_largest = "wtrswr" if seed_issuer == "KATY TEX" & year == 2000 & month == 1
replace purp_largest = "transport" if seed_issuer == "DUNCANVILLE TEX" & year == 2018 & month == 11
replace purp_largest = "transport" if seed_issuer == "DE SOTO TEX" & year == 2014 & month == 11
drop temp*

*How to aggregate margin?
*Simplest way is to sum votesfor and votesagainst and calc new winmargin, though it isn't really accurate
*Other way is to calculate weighted average margin to get at "how competitive were these really"
*Maybe that better reflects overall sentiment
*gen weighted avg win margin based on amount
*Calc total amount
gegen amount_total = sum(amount), by(seed_issuer date_election)
gen temp1 = winmargin * amount
gegen temp2 = sum(temp1), by(seed_issuer date_election)
gen temp3 = temp2 / amount_total
rename temp3 wavg_winmargin
drop temp*

drop amount result winmargin votestotal votesfor votesagainst purposedescription propnumber source
order amount_total wavg_winmargin, after(month)
drop governmentname governmenttype county muni_upper

*drop elections after end of 2020
drop if year > 2020

*collapse
gcollapse (mean) amount_total wavg_winmargin, by(seed_issuer date_election year month purp_largest)
*check dups by issuer month
duplicates tag seed_issuer year month, gen(dup)
tab dup
*no dups, good
drop dup

*To use rangejoin, need a var for each election date that has the last range
*gen running var for each date_election in an issuer
by seed_issuer: gen date_id = _n
*gen total dates
gegen n_dates = count(date_election), by(seed_issuer)
tab n_dates
/*
    n_dates |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |        117       30.31       30.31
          2 |         98       25.39       55.70
          3 |         81       20.98       76.68
          4 |         28        7.25       83.94
          5 |         15        3.89       87.82
          6 |         24        6.22       94.04
          7 |          7        1.81       95.85
          8 |         16        4.15      100.00
------------+-----------------------------------
      Total |        386      100.00
*/
*For n_dates = 1, can make last day of range by 12/31/2020
gen date_last = date("12/31/2020", "MDY") if n_dates == 1
format date_last %td

*For an issuer with 2 elections, make the date_last of the FIRST election = date of second election
gegen temp1 = max(date_election) if n_dates == 2, by(seed_issuer)
replace temp1 = . if date_id == 2
format temp1 %td
*make the date_last of the SECOND election = 12/31/2020
replace temp1 = date("12/31/2020", "MDY") if n_dates == 2 & date_id == 2
replace date_last = temp1 if date_last == . & temp1 != .
drop temp1

*For an issuer with 3 elections:
*Make date_last of FIRST election = date of second election
gen temp1 = date_election if n_dates == 3 & date_id == 2
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 3 & date_id == 1
drop temp*
*Make date_last of SECOND election = date of third election
gen temp1 = date_election if n_dates == 3 & date_id == 3
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 3 & date_id == 2
drop temp*
*Make date_last of THIRD election = 12/31/2020
replace date_last = date("12/31/2020", "MDY") if date_last == . & n_dates == 3 & date_id == 3

*For an issuer with 4 elections, repeat prior steps but add an iteration:
gen temp1 = date_election if n_dates == 4 & date_id == 2
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 4 & date_id == 1
drop temp*
gen temp1 = date_election if n_dates == 4 & date_id == 3
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 4 & date_id == 2
drop temp*
gen temp1 = date_election if n_dates == 4 & date_id == 4
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 4 & date_id == 3
drop temp*
replace date_last = date("12/31/2020", "MDY") if date_last == . & n_dates == 4 & date_id == 4

*For an issuer with 5 elections:
gen temp1 = date_election if n_dates == 5 & date_id == 2
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 5 & date_id == 1
drop temp*
gen temp1 = date_election if n_dates == 5 & date_id == 3
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 5 & date_id == 2
drop temp*
gen temp1 = date_election if n_dates == 5 & date_id == 4
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 5 & date_id == 3
drop temp*
gen temp1 = date_election if n_dates == 5 & date_id == 5
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 5 & date_id == 4
drop temp*
replace date_last = date("12/31/2020", "MDY") if date_last == . & n_dates == 5 & date_id == 5

*For an issuer with 6 elections:
gen temp1 = date_election if n_dates == 6 & date_id == 2
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 6 & date_id == 1
drop temp*
gen temp1 = date_election if n_dates == 6 & date_id == 3
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 6 & date_id == 2
drop temp*
gen temp1 = date_election if n_dates == 6 & date_id == 4
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 6 & date_id == 3
drop temp*
gen temp1 = date_election if n_dates == 6 & date_id == 5
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 6 & date_id == 4
drop temp*
gen temp1 = date_election if n_dates == 6 & date_id == 6
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 6 & date_id == 5
drop temp*
replace date_last = date("12/31/2020", "MDY") if date_last == . & n_dates == 6 & date_id == 6

*For an issuer with 7 elections:
gen temp1 = date_election if n_dates == 7 & date_id == 2
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 7 & date_id == 1
drop temp*
gen temp1 = date_election if n_dates == 7 & date_id == 3
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 7 & date_id == 2
drop temp*
gen temp1 = date_election if n_dates == 7 & date_id == 4
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 7 & date_id == 3
drop temp*
gen temp1 = date_election if n_dates == 7 & date_id == 5
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 7 & date_id == 4
drop temp*
gen temp1 = date_election if n_dates == 7 & date_id == 6
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 7 & date_id == 5
drop temp*
gen temp1 = date_election if n_dates == 7 & date_id == 7
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 7 & date_id == 6
drop temp*
replace date_last = date("12/31/2020", "MDY") if date_last == . & n_dates == 7 & date_id == 7

*For an issuer with 8 elections:
gen temp1 = date_election if n_dates == 8 & date_id == 2
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 8 & date_id == 1
drop temp*
gen temp1 = date_election if n_dates == 8 & date_id == 3
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 8 & date_id == 2
drop temp*
gen temp1 = date_election if n_dates == 8 & date_id == 4
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 8 & date_id == 3
drop temp*
gen temp1 = date_election if n_dates == 8 & date_id == 5
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 8 & date_id == 4
drop temp*
gen temp1 = date_election if n_dates == 8 & date_id == 6
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 8 & date_id == 5
drop temp*
gen temp1 = date_election if n_dates == 8 & date_id == 7
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 8 & date_id == 6
drop temp*
gen temp1 = date_election if n_dates == 8 & date_id == 8
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 8 & date_id == 7
drop temp*
replace date_last = date("12/31/2020", "MDY") if date_last == . & n_dates == 8 & date_id == 8

*check if date_last is missing
count if date_last == .
*0, good
drop date_id
order year date_election date_last, after(seed_issuer)

*make indicator for passing by close weighted average winmargin and group into buckets
sum wavg_winmargin, d
/*
                    (mean) wavg_winmargin
-------------------------------------------------------------
      Percentiles      Smallest
 1%     .0105672       .0014202
 5%     .0560345       .0020346
10%     .1186072       .0037807       Obs                 386
25%     .2138292       .0105672       Sum of wgt.         386

50%     .3574213                      Mean            .354792
                        Largest       Std. dev.      .1822005
75%      .469224       .7690783
90%     .6054623       .8269231       Variance        .033197
95%     .6695714       .8279138       Skewness       .1842933
99%     .7690783       .8372092       Kurtosis       2.459332
*/
hist wavg_winmargin
count if wavg_winmargin <= 0.05
*16
count if wavg_winmargin <= 0.10
*29
gen wavg_winmargin_close5 = 1 if wavg_winmargin <= 0.05
replace wavg_winmargin_close5 = 0 if wavg_winmargin_close5 == .
gen wavg_winmargin_close10 = 1 if wavg_winmargin <= 0.10
replace wavg_winmargin_close10 = 0 if wavg_winmargin_close10 == .

*make quartiles
xtile wavg_winmargin_quartile = wavg_winmargin, nq(4)

*save
save "$TX/250310_txbrb_election_issuelevel.dta", replace

*Rangejoin this with Mergent data based on seed_issuer
*ssc install rangestat
rangejoin offering_date date_election date_last using "$TX\241120_tx_issue_level.dta", by(seed_issuer)
*clean
rename year year_election
rename month month_election
rename year_U year_issue
*order
order state seed_issuer seed_issuer_id issuer_type issue_id year_issue offering_date bond_type vote_req date_election wavg_winmargin wavg_winmargin_quartile
order n_dates date_last, before(qtr)
*gen month var for issuance
gen month_issue = month(offering_date)
rename qtr qtr_issue

count if state == ""
*64 elections that don't get matched
*drop these
drop if state == ""

*Note that rev bonds get matched to the election period even though the vote isn't required
*Can this help be a falsification test?

*Save file
save "$TX/250310_txmerge_election_issuelevel.dta", replace

*What's the lag between election date and first date of new issuance?
use "$TX/250310_txmerge_election_issuelevel.dta", clear
keep if bond_type == "go"
br seed_issuer issue_id offering_date date_election 
*For an issuer-election date, get smallest offering date
gegen temp1 = min(offering_date), by(seed_issuer date_election)
format temp1 %td
*only keep one obs
keep if offering_date == temp1
keep seed_issuer offering_date date_election 
duplicates drop
*gen lag
gen diffdate = offering_date - date_election
*this is going to be skewed because it's going to miss GO bonds that have an element of refunding
hist diffdate
sum diffdate, d
/*
                          diffdate
-------------------------------------------------------------
      Percentiles      Smallest
 1%           28              3
 5%           60             17
10%           66             24       Obs                 304
25%         97.5             28       Sum of wgt.         304

50%          203                      Mean           374.8125
                        Largest       Std. dev.      479.6623
75%          471           1865
90%          915           1995       Variance       230075.9
95%         1350           2614       Skewness       3.714027
99%         1865           4689       Kurtosis       25.96255
*/
*trim the top 5% because these are likely due to missing GO bonds that have some refunding
winsor2 diffdate, trim cuts(0 95) suffix(_tr)
hist diffdate_tr
sum diffdate_tr, d
/*
                          diffdate
-------------------------------------------------------------
      Percentiles      Smallest
 1%           24              3
 5%           58             17
10%           66             24       Obs                 289
25%           97             28       Sum of wgt.         289

50%          189                      Mean           296.1938
                        Largest       Std. dev.       287.004
75%          391           1304
90%          737           1317       Variance       82371.31
95%          929           1318       Skewness        1.67596
99%         1317           1350       Kurtosis       5.369937

*/
*median is ~6 months, mean is ~9-10 months

br if diffdate_tr != .

*DS idea to look into later: differences in lag by type of bond or other characteristics
