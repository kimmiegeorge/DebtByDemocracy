**************************
*Voting on bonds         *
*Update state laws       *
*Last updated: 08/27/25  *
**************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global DESCRIPT "$MAIN\Descriptives"

**# Bookmark #1
*Start with main city file with yield spreads and update state law classifications*
use "$MERGENT\Clean\250707_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

*Rename old city_go_vote and city_rev_vote
rename (city_go_vote city_rev_vote) (city_go_vote_old city_rev_vote_old)

*Merge in updated classification
mmerge state using "$DATA\Bond Elections\250827_election_requirements_by_state.dta", ///
	type(n:1) missing(nomatch)
*all matched except Hawaii
drop if _merge == 2
drop _merge

*check which states have changes in GO vote
preserve
keep state city_go_vote city_go_vote_old
duplicates drop
list state if city_go_vote != city_go_vote_old
restore
*Iowa and Indiana
*check which states have changes in rev vote
preserve
keep state city_rev_vote city_rev_vote_old
duplicates drop
list state if city_rev_vote != city_rev_vote_old
restore
*California

*Drop old classifications, move in new ones
drop city_go_vote_old city_rev_vote_old
order city_go_vote city_rev_vote, after(bond_type)

*save file
save "$MERGENT\Clean\250827_city_cusiplevel_statereq_purpose_yieldspread.dta", replace

**# Bookmark #2
**Update issuer-level version**
use "$MERGENT\Clean\250701_city_issuerlevel_yieldspread.dta", clear
drop city_go_vote city_rev_vote

*Merge in updated classification
mmerge state using "$DATA\Bond Elections\250827_election_requirements_by_state.dta", ///
	type(n:1) missing(nomatch)
*all matched except Hawaii
drop if _merge == 2
drop _merge
order city_go_vote city_rev_vote, after(state_name)

*re-gen insample
drop insample*
*gen insample for controls
gen insample = 1 if city_go_vote == 0 & city_rev_vote == 0
*include UTGO only for sample
replace insample = 1 if inlist(state,"WA","MI","OH")
*include All GO Vote for sample
replace insample = 1 if city_go_vote == 1 & city_rev_vote == 0
replace insample = 0 if insample == .

*Make insample_utgo_only
gen insample_utgo_only = 1 if city_go_vote == 0 & city_rev_vote == 0
replace insample_utgo_only = 1 if inlist(state,"WA","MI","OH")
replace insample_utgo_only == . if insample_utgo_only == .

*Make insample_allgo
gen insample_allgo = 1 if city_go_vote == 0 & city_rev_vote == 0
replace insample_allgo = 1 if city_go_vote == 1 & city_rev_vote == 0
replace insample_allgo = 0 if inlist(state,"WA","MI","OH")
replace insample_allgo = 0 if insample_allgo == .

*save file
save "$MERGENT\Clean\250827_city_issuerlevel_yieldspread.dta", replace



