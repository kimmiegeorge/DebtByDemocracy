****************************
*Voting on bonds           *
*Clean data for Texas pilot*
*Last updated: 01/24/25    *
****************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA/TX"
global RESULTS "$MAIN\RESULTS\TX"

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
pwcorr passed amount, star(0.01)
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
pwcorr passed ln_amount, star(0.1)
*corr = 0.0491, only sig at 10% level
pwcorr votemargin ln_amount if passed == 1 & votemargin != 1, star(0.01)
*corr = 0.1171, sig at 1% level
pwcorr votemargin ln_amount if passed == 0 & votemargin != 1 & votemargin != 0, star(0.1)
*pos corr = 0.0136, but not sig at 10% level
*with logs, takeaway is the same: weak pos corr between amount and getting passed
*if passed, then larger bonds pass more strongly

*purpose is "other" 76% of the time; purposedescription is more detailed, but no consistent categories
*tab purposedescription
*tons of variation
*group into buckets
gen temp1 = lower(purposedescription)
*tab temp1 /*if temp2 == ""*/
gen temp2 = "wtrswr" if strpos(temp1,"water") > 0 
replace temp2 = "wtrswr" if strpos(temp1,"sewer") > 0 & temp2 == ""
replace temp2 = "street" if strpos(temp1,"street") > 0 & temp2 == ""
replace temp2 = "street" if strpos(temp1,"road") > 0 & temp2 == ""
replace temp2 = "street" if strpos(temp1,"drain") > 0 & temp2 == ""
replace temp2 = "street" if strpos(temp1,"sidewalk") > 0 & temp2 == ""
replace temp2 = "street" if strpos(temp1,"traffic") > 0 & temp2 == ""
replace temp2 = "street" if strpos(temp1,"transpor") > 0 & temp2 == ""
replace temp2 = "street" if strpos(temp1,"alley") > 0 & temp2 == ""
replace temp2 = "arts" if strpos(temp1,"art") > 0 & temp2 == ""
replace temp2 = "arts" if strpos(temp1,"museum") > 0 & temp2 == ""
replace temp2 = "parksrec" if strpos(temp1,"athletic") > 0 & temp2 == ""
replace temp2 = "parksrec" if strpos(temp1,"aquatic") > 0 & temp2 == ""
replace temp2 = "parksrec" if strpos(temp1,"expo") > 0 & temp2 == ""
replace temp2 = "parksrec" if strpos(temp1,"golf") > 0 & temp2 == ""
replace temp2 = "parksrec" if strpos(temp1,"recreation") > 0 & temp2 == ""
replace temp2 = "parksrec" if strpos(temp1,"park") > 0 & temp2 == ""
replace temp2 = "parksrec" if strpos(temp1,"sports") > 0 & temp2 == ""
replace temp2 = "parksrec" if strpos(temp1,"zoo") > 0 & temp2 == ""
replace temp2 = "parksrec" if strpos(temp1,"senior") > 0 & temp2 == ""
replace temp2 = "parksrec" if strpos(temp1,"pool") > 0 & temp2 == ""
replace temp2 = "parksrec" if strpos(temp1,"community") > 0 & temp2 == ""
replace temp2 = "parksrec" if strpos(temp1,"entertain") > 0 & temp2 == ""
replace temp2 = "safety" if strpos(temp1,"jail") > 0 & temp2 == ""
replace temp2 = "safety" if strpos(temp1,"criminal") > 0 & temp2 == ""
replace temp2 = "safety" if strpos(temp1,"detention") > 0 & temp2 == ""
replace temp2 = "safety" if strpos(temp1,"fire") > 0 & temp2 == ""
replace temp2 = "safety" if strpos(temp1,"justice") > 0 & temp2 == ""
replace temp2 = "safety" if strpos(temp1,"law") > 0 & temp2 == ""
replace temp2 = "safety" if strpos(temp1,"police") > 0 & temp2 == ""
replace temp2 = "safety" if strpos(temp1,"safety") > 0 & temp2 == ""
replace temp2 = "safety" if strpos(temp1,"public saftey") > 0 & temp2 == ""
replace temp2 = "library" if strpos(temp1,"library") > 0 & temp2 == ""
replace temp2 = "other" if temp2 == ""
tab temp2
/*
      temp2 |      Freq.     Percent        Cum.
------------+-----------------------------------
       arts |         35        2.06        2.06
    library |        100        5.88        7.93
      other |        366       21.50       29.44
   parksrec |        378       22.21       51.65
     safety |        291       17.10       68.74
     street |        492       28.91       97.65
     wtrswr |         40        2.35      100.00
------------+-----------------------------------
      Total |      1,702      100.00
*/
local temp arts library parksrec safety street wtrswr other
foreach x of local temp{
	gen purpose_`x' = 1 if temp2 == "`x'"
	replace purpose_`x' = 0 if purpose_`x' == .
}

rename temp2 purpose_broad
rename temp1 purposedescription_lower

local temp arts library parksrec safety street wtrswr other
foreach x of local temp{
	reg passed purpose_`x', vce(robust)
	reg passed purpose_`x' ln_amount, vce(robust)
	reghdfe passed purpose_`x' amount, absorb(county) vce(cluster county)
	reghdfe passed purpose_`x' ln_amount, absorb(county year) vce(cluster county)
}

/*Notes
- arts: with county and year FEs, coeff=-0.107, p=0.039
- library: pos but not sig
- parksrec: with countyFE alone, neg and sig; add yearFE, neg and not sig
- safety: with county and year FEs, coeff=0.045, p=0.009
- street: with county and year FEs, coeff=0.076, p=0.003
- wtrswr: neg but not sig
- other (general building): with county and year FEs, coeff=-0.95, p=0.003
- takeaways: voters are more likely to approve bonds for safety, streets
	- voters are less likely to approve bonds for arts, general construction (like city halls)
*/

*Output

label var purpose_arts "Arts"
label var purpose_library "Library"
label var purpose_parksrec "Parks\&Rec"
label var purpose_safety "Safety"
label var purpose_street "Streets"
label var purpose_wtrswr "Wtr\&Swr"
label var purpose_other "Other"
label var ln_amount "Bond amount"

eststo clear
local temp arts library parksrec safety street wtrswr other
foreach x of local temp{
	eststo: qui reghdfe passed purpose_`x' ln_amount ///
	, absorb(county year month) vce(cluster county)
	estadd local countyFE "Yes"
	estadd local yearFE "Yes"
	estadd local monthFE "Yes"
	estadd local SE "County"	
}
esttab using "$RESULTS\250124_tx_passed_purpose.tex", replace t noconstant b(3) ///
	title("Likelihood of passage for projects in TX") star(* .10 ** .05 *** .01) ///
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

*save data
save "$TX/250124_txmerge_election_proposallevel.dta", replace

*Conditional on the proposal passing:
local temp arts library parksrec safety street wtrswr other
foreach x of local temp{
	reg winmargin purpose_`x', vce(robust)
	reg winmargin purpose_`x' ln_amount, vce(robust)
	reghdfe winmargin purpose_`x' ln_amount, absorb(county) vce(cluster county)
	reghdfe winmargin purpose_`x' ln_amount, absorb(county year) vce(cluster county)
}
/*Conditional on the proposal passing:
- arts: neg, not sig
- library: pos, not sig
- parksrec: neg and sig. with countyFE, yearFE: coeff=-0.093, p=0.000
- safety: pos and sig. with countyFE, yearFE: coeff=0.043, p=0.091
- street: pos and sig. with countyFE, yearFE: coeff=0.093, p=0.000
- wtrswr: pos and sig. with countyFE, yearFE: coeff=0.149, p=0.002
- other (general building): neg and sig. with countyFE, yearFE: coeff=-0.067, p=0.000
- takeaways: among proposals that passed, more support if the bond is for safety, street, or wtrswr
	- less support if the bond is for parksrec or other
*/

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
order seed_issuer date_election year month amount winmargin temp2

*How to aggregate purpose? Grab the purpose of the largest amount? 
drop purpose
rename temp1 purpose_raw
rename temp2 purpose_new
*Maybe don't do this for now because Mergent data should have bond-level purpose

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
*collapse
gcollapse (mean) amount_total wavg_winmargin, by(seed_issuer date_election year month)

*To use rangejoin, need a var for each election date that has the last range
*gen running var for each date_election in an issuer
by seed_issuer: gen date_id = _n
*gen total dates
gegen n_dates = count(date_election), by(seed_issuer)
tab n_dates
/*
    n_dates |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |        117       30.00       30.00
          2 |         98       25.13       55.13
          3 |         81       20.77       75.90
          4 |         28        7.18       83.08
          5 |         15        3.85       86.92
          6 |         18        4.62       91.54
          7 |          7        1.79       93.33
          8 |         16        4.10       97.44
         10 |         10        2.56      100.00
------------+-----------------------------------
      Total |        390      100.00
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

*For an issuer with 10 elections:
gen temp1 = date_election if n_dates == 10 & date_id == 2
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 1
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 3
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 2
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 4
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 3
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 5
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 4
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 6
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 5
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 7
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 6
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 8
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 7
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 9
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 8
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 10
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 9
drop temp*
replace date_last = date("12/31/2020", "MDY") if date_last == . & n_dates == 10 & date_id == 10

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
 5%     .0550928       .0020346
10%      .116698       .0037807       Obs                 390
25%     .2135688       .0105672       Sum of wgt.         390

50%     .3574213                      Mean           .3534201
                        Largest       Std. dev.       .182396
75%     .4682252       .7690783
90%     .6018852       .8269231       Variance       .0332683
95%     .6695714       .8279138       Skewness        .185765
99%     .7690783       .8372092       Kurtosis       2.459186
*/
hist wavg_winmargin
count if wavg_winmargin <= 0.05
*17
count if wavg_winmargin <= 0.10
*30
gen wavg_winmargin_close5 = 1 if wavg_winmargin <= 0.05
replace wavg_winmargin_close5 = 0 if wavg_winmargin_close5 == .
gen wavg_winmargin_close10 = 1 if wavg_winmargin <= 0.10
replace wavg_winmargin_close10 = 0 if wavg_winmargin_close10 == .

*make quartiles
xtile wavg_winmargin_quartile = wavg_winmargin, nq(4)

*save
save "$TX/241216_txbrb_election_issuelevel.dta", replace

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
*68 elections that don't get matched
*drop these
drop if state == ""

*Note that rev bonds get matched to the election period even though the vote isn't required
*Can this help be a falsification test?

*Save file
save "$TX/241216_txmerge_election_issuelevel.dta", replace
