**************************
*Voting on bonds         *
*Update data for RI, MO  *
*Last updated: 10/27/25  *
**************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global DESCRIPT "$MAIN\Descriptives"
global RESULTS "$MAIN\Results\2025-10_results"

**# Bookmark #1
*Start with main city file with yield spreads and update state law classifications*
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

*Rename old city_go_vote and city_rev_vote
rename (city_go_vote city_rev_vote) (city_go_vote_old city_rev_vote_old)

*Merge in updated classification
mmerge state using "$DATA\Bond Elections\251027_election_requirements_by_state.dta", ///
	type(n:1) missing(nomatch)
*all matched except Hawaii
drop if _merge == 2
drop _merge

*Drop old classifications, move in new ones
drop city_go_vote_old city_rev_vote_old
order city_go_vote city_rev_vote, after(bond_type)

save "$MERGENT\Clean\251027_city_cusiplevel_statereq_purpose_yieldspread.dta", replace

**# Bookmark #2
**Make new issuer-level version**
use "$MERGENT\Clean\250827_city_issuerlevel_yieldspread.dta", clear

*Make Missouri revenue bonds requires vote
replace city_rev_vote = 1 if state == "MO"
replace insample_allgo = 0 if state == "MO"
tab insample if state == "MO"
tab insample_utgo_only if state == "MO"
tab insample_allgo if state == "MO"
replace insample = 0 if state == "MO"

*Make RI depends for both
replace city_go_vote = . if state == "RI"
replace city_rev_vote = . if state == "RI"
tab insample if state == "RI"
tab insample_allgo if state == "RI"
*already 0, good

*Save file
save "$MERGENT\Clean\251027_city_issuerlevel_yieldspread.dta", replace

**Descriptives**
*How many cities in sample?
*6,049 total obs
count if insample_utgo_only != 1 & insample_allgo != 1
*3,246 not in sample (note this restricts based on rev vote)
*6,049 - 3,246 = 2,803 cities in the sample (note this restricts based on rev vote)

**How many cities are vote-requiring; how many are not vote-requiring?**

*Have the vote:
count if city_go_vote == 1
*2,386 cities have GO vote
count if city_go_vote == 1 & city_rev_vote == 0
*1,744 cities have GO vote and no rev vote
count if city_go_vote == 1 & city_rev_vote != 0
*642 cities have GO vote and rev vote exists or depends

*Don't have the vote:
count if city_go_vote == 0
*1,059 cities
count if city_go_vote == 0 & city_rev_vote == 0
*All 1,059 cities without GO vote don't have rev vote

**Within types of debt, how many come from vote-requiring vs. not?**
*Need to go to bond-level here
use "$MERGENT\Clean\251027_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

*Check Figure 4:
count if city_go_vote == 0
*65,525
gunique state if city_go_vote == 0
*7 states
gen utgo_only = 1 if inlist(state,"MI","WA","OH")
replace utgo_only = 0 if utgo_only == .
count if city_go_vote == 1 & utgo_only == 0 & city_rev_vote == 0
*59,926
gunique state if city_go_vote == 1 & utgo_only == 0 & city_rev_vote == 0
*14 states
count if utgo_only == 1
*30,379

tab state


*Within UTGO bonds, how many come from vote-requiring:
*Don't filter based on revenue bond requirement
count if go_unlim == 1
*196,760 UTGO
count if go_unlim == 1 & city_go_vote == 1
*36,412 UTGO bonds when vote required
count if go_unlim == 1 & city_go_vote == 0
*43,263 UTGO bonds when vote not required
*Where GO vote does NOT depend, 79,675 UTGO bonds

*Within Revenue bonds, how many come from GO vote-requiring:
count if rev == 1
*88,986
count if rev == 1 & city_go_vote == 1
*50,298
count if rev == 1 & city_go_vote == 0
*10,701
*Where GO vote does NOT depend, 60,999 revenue bonds

*Filtering on revenue bond requirement
*UTGO count
count if go_unlim == 1 & city_rev_vote == 0
*126,534 UTGO
count if go_unlim == 1 & city_go_vote == 1 & city_rev_vote == 0
*25,703 UTGO bonds when vote required
count if go_unlim == 1 & city_go_vote == 0 & city_rev_vote == 0
*43,263

*Revenue bond count
count if rev == 1 & city_rev_vote == 0
*72,441 rev
count if rev == 1 & city_go_vote == 1 & city_rev_vote == 0
*37,970 rev bonds when vote required
count if rev == 1 & city_go_vote == 0 & city_rev_vote == 0
*10,701 

*All bonds: what # and what amount come from vote, no vote; only in states without revenue bond vote
*Count
count if city_go_vote == 1 & city_rev_vote == 0
*90,305 bonds
count if city_go_vote == 0 & city_rev_vote == 0
*65,525 bonds

*Amounts
preserve
keep if city_rev_vote == 0 & city_go_vote != .
gcollapse (sum) amount, by(city_go_vote)
list
/*
     +------------------------+
     | city_g~e        amount |
     |------------------------|
  1. |        0   4.12934e+10 |
  2. |        1   1.39066e+11 |
     +------------------------+
*/
*Vote: 139,066,000,000 ~ 139.1 billion
*No vote: 41,293,400,000 ~ 41.3 billion
restore

*Why is there so much more debt raised when city_go_vote == 1 when the # of bonds isn't so far off?
preserve
keep if city_rev_vote == 0 & city_go_vote != .
gcollapse (sum) amount, by(city_go_vote bond_type)
list
/*
     +-----------------------------------+
     | city_g~e   bond_t~e        amount |
     |-----------------------------------|
  1. |        0         go   3.18973e+10 |
  2. |        0        rev    9396092000 |
  3. |        1         go   4.02798e+10 |
  4. |        1        rev   9.87862e+10 |
     +-----------------------------------+
*/
*Vote, GO: 40,279,800,000 ~ 40.2 bn
*Vote, Rev: 98,786,200,000 ~ 98.9 bn
*No Vote, GO: 31,897,300,000 ~ 31.9 bn
*No Vote, Rev: 9,396,092,000 ~ 9.4 bn
restore

**Get CUSIPs for DPC data**
/*
- All issuances for if city_go_vote != .
- Then separately, all CUSIPs for IL, RI, KS where city_go_vote == .
*/

gen temp1 = 1 if inlist(state,"IL","RI","KS")
keep if city_go_vote != . | temp1 == 1

gunique issue_id
*15,378 issuances

*keep one cusip from each issuance
gegen temp2 = max(amount), by(issue_id)
gen temp3 = 1 if amount == temp2
keep if temp3 == 1
drop temp*

*how many duplicates by seed_issuer and offering date?
*br seed_issuer issue_id offering_date cusip issue_description dup if dup > 0
*some duplicates because sometimes multiple have the same amount
duplicates drop seed_issuer issue_id issue_description offering_date amount, force
duplicates tag seed_issuer_id offering_date issue_description, gen(dup)
br seed_issuer issue_id offering_date cusip issue_description dup 
*still some dups because of different series, same official statement

*gen temporary unique_os_id
gegen os_id = group(seed_issuer issue_description offering_date)
drop dup
*save file
keep state seed_issuer seed_issuer_id issue_id year offering_date cusip issue_description os_id amount 
save "$DATA\Other\251027_issue_osid_map.dta", replace
*drop duplicate OS IDs
duplicates drop os_id, force
*15,065 obs
save "$DATA\Other\251027_issue_osid_unique.dta", replace
*Export cusip list to csv

