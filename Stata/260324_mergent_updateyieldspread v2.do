************************
*Voting on bonds       *
*Update yield spread   *
*Last updated: 03/24/26*
************************

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
*Import 3/24/2026 new yield spread file to Stata*
import delimited using "$MERGENT\Clean\260324_bond_level_off_yield_spread.csv", varn(1) clear
*check cusip is unique
duplicates report cusip
*yes, good
save "$MERGENT\Clean\260324_bond_level_off_yield_spread.dta", replace

*Switch to latest city cusip-level file*
use "$MERGENT\Clean\251119_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

*drop old yield spread
drop offering_yield_spread

*bring in new yield spread
mmerge cusip using "$MERGENT\Clean\260324_bond_level_off_yield_spread.dta" ///
	, type(1:1) missing(nomatch)
/*
                 obs | 728114
                vars |    235  (including _merge)
         ------------+---------------------------------------------------------
              _merge |   1645  obs only in master data                (code==1)
                     | 399913  obs only in using data                 (code==2)
                     | 326556  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
drop if _merge == 2
drop _merge

*save bond-level
save "$MERGENT\Clean\260324_city_cusiplevel_statereq_purpose_yieldspread.dta", replace

*Make new issuer-level yield spread
use "$MERGENT\Clean\260324_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

*Make weighted average for an issuance; weighted based on amount
*br state seed_issuer seed_issuer_id issue_id cusip amount offering_yield_spread

*Multiply yield spreads times amounts; sum
gen amt_x_ys = amount * offering_yield_spread
gegen temp1 = sum(amt_x_ys), by(issue_id)
*Gen total amount per issuance
*Omit bonds with missing offering yield spread
gen amount_nonmiss = amount if offering_yield_spread != .
gegen issue_amt_total = sum(amount_nonmiss), by(issue_id)
*Divide numerator by denominator:
gen issue_yield_spread = temp1 / issue_amt_total

drop amt_x_ys temp1 amount_nonmiss

*Now collapse just necessary vars to issuer-level, then make wavg for issuer
keep state seed_issuer seed_issuer_id issue_id issue_amt_total issue_yield_spread
duplicates drop

*Multiple issue_yield_spread * amounts; sum
gen amt_x_ys = issue_amt_total * issue_yield_spread
gegen temp1 = sum(amt_x_ys), by(seed_issuer)
*group by seed_issuer, not seed_issuer_id; note that EL PASO ILL and EL PASO ROBLES... CA have the same seed_issuer_id 
*Gen total amount per issuer
gen issue_amt_total_nonmiss = issue_amt_total if issue_yield_spread != .
gegen issuer_amt_total = sum(issue_amt_total_nonmiss), by(seed_issuer)
*Divide num by denom:
gen issuer_yield_spread = temp1 / issuer_amt_total
*just keep issuer_level

drop temp1 amt_x_ys issue_amt_total_nonmiss
drop issue_amt_total issue_yield_spread issue_id
duplicates drop

*Note there are some issuers where the overall issuer yield == 0; this happens when all that issuer's bonds don't have the yield spread calculated; these are cities with very few bonds
count if issuer_yield_spread == 0
*0
*check for duplicates
duplicates tag seed_issuer, gen(dup)
count if dup > 0
*none, good
drop dup

*save file
save "$MERGENT\Clean\260324_issuers_yieldspread v2.dta", replace

*Go to latest issuer-level file, drop old issuer yield spread, bring in new one
use "$MERGENT\Clean\251027_city_issuerlevel_yieldspread.dta", clear
drop issuer_yield_spread
mmerge seed_issuer using "$MERGENT\Clean\260324_issuers_yieldspread v2.dta", ///
	type(n:1) missing(nomatch)
drop _merge
sort state seed_issuer 

*save
save "$MERGENT\Clean\260324_city_issuerlevel_yieldspread v2.dta", replace

***Below is old***



use "$MERGENT\Clean\251119_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

*Yield spreads in our sample:
gen temp1 = 1 if inlist(state,"MI","OH","WA")
sum offering_yield_spread if city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 1.50
sum offering_yield_spread if bond_type == "go" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 1.42
sum offering_yield_spread if bond_type == "rev" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 1.58
sum offering_yield_spread if bond_type == "go" & rating_num == 16 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 1.36
sum offering_yield_spread if bond_type == "go" & rating_num == 9 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 1.69
sum offering_yield_spread if bond_type == "rev" & rating_num == 16 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 1.83
sum offering_yield_spread if bond_type == "rev" & rating_num == 9 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 2.07

*No vote states:
sum offering_yield_spread if city_go_vote == 0 & city_rev_vote == 0 
*avg = 1.29
sum offering_yield_spread if bond_type == "go" & city_go_vote == 0 & city_rev_vote == 0 
*avg = 1.24
sum offering_yield_spread if bond_type == "rev" & city_go_vote == 0 & city_rev_vote == 0 
*avg = 1.54
sum offering_yield_spread if bond_type == "go" & rating_num == 16 & city_go_vote == 0 & city_rev_vote == 0 
*avg = 1.13
sum offering_yield_spread if bond_type == "go" & rating_num == 9 & city_go_vote == 0 & city_rev_vote == 0 
*avg = 2.12
sum offering_yield_spread if bond_type == "rev" & rating_num == 16 & city_go_vote == 0 & city_rev_vote == 0 
*avg = 1.76
sum offering_yield_spread if bond_type == "rev" & rating_num == 9 & city_go_vote == 0 & city_rev_vote == 0 
*avg = 1.89

*average credit rating?
sum rating_num if bond_type == "go" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1 
*4.63
sum rating_num if bond_type == "rev" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*4.98
sum rating_num if bond_type == "go" & city_go_vote == 0 & city_rev_vote == 0 
*4.36
sum rating_num if bond_type == "rev" & city_go_vote == 0 & city_rev_vote == 0 
*3.73

sum rating_num if bond_type == "go" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1 & rating_num > 1
*14.2
sum rating_num if bond_type == "rev" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1 & rating_num > 1
*13.6
sum rating_num if bond_type == "go" & city_go_vote == 0 & city_rev_vote == 0 & rating_num > 1
*13.9
sum rating_num if bond_type == "rev" & city_go_vote == 0 & city_rev_vote == 0 & rating_num > 1
*12.96

/*
Yield spreads
GO vote = 1 (light green): 1.50 
	GO bonds: 1.42
		Aaa: 1.36
		Baa1: 1.69
		Diff = 33 bp
	Rev bonds: 1.58
		Aaa: 1.83
		Baa1: 2.07
		Diff = 24 bp
	Rev - GO = 16 bp
GO vote = 0 (white): 1.29
	GO bonds: 1.24
		Aaa: 1.13
		Baa1: 2.12
		Diff = 0.99 bps
	Rev bonds: 1.54
		Aaa: 1.76
		Baa1: 1.89
		Diff = 0.13 bps
	Rev - GO = 30 bps
*/

sum offering_yield if city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*average is 3.27
sum offering_yield if bond_type == "go" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 3.15
sum offering_yield if bond_type == "rev" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 3.38
sum offering_yield if bond_type == "go" & rating_num == 16 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 3.14
sum offering_yield if bond_type == "go" & rating_num == 9 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 3.06
sum offering_yield if bond_type == "rev" & rating_num == 16 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 4.16
sum offering_yield if bond_type == "rev" & rating_num == 9 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 3.49

/*
Offering yields
GO vote = 1 (light green): 3.27
	GO bonds: 3.15
		Aaa: 3.14
		Baa3: 3.06
	Rev bonds: 3.38
		Aaa: 4.16
		Baa3: 3.49
	Rev - GO = 23 bp
GO vote = 0 (white)
	GO bonds
		Aaa:
		Ba1:
	Rev bonds
		Aaa:
		Ba1:
*/
*Why are the yields weirder for Baa3 revenue bonds?

forvalues x = 0(1)16{
	sum offering_yield_spread if bond_type == "go" & rating_num == `x' & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
}

forvalues x = 0(1)16{
	sum offering_yield_spread if bond_type == "rev" & rating_num == `x' & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
}
*Obs start to drop off after rating_num = 9, which is Baa1