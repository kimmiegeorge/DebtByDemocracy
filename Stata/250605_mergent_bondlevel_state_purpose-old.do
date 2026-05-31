************************
*Voting on bonds       *
*Fix maturity          *
*Last updated: 06/05/25*
************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"

**# Bookmark #1
***Start with main file***
use "$MERGENT\Clean\250313_citycountyschool_cusiplevel_statereq_purpose.dta", clear

*Drop old maturity mths
drop maturity_mths ln_maturity_mths maturity_mths_tr ln_maturity_tr
*br issue_id cusip offering_date maturity_date maturity_days
*maturity_days is done correctly
gen maturity_mths = floor(maturity_days/30.437)
sum maturity_mths, d
*avg is 108 months ~ 9 years; p75 is 171 months ~14.25 years
*30.437 = avg month length in days
*make ln and trimmed
*note that trimmed amount and trimmed yield are done at the 1, 99 pctiles and ln_x_tr = ln(1+x_tr)
gen ln_maturity_mths = ln(1+maturity_mths)
winsor2 maturity_mths, trim cuts(1 99) suffix(_tr)
gen ln_maturity_tr = ln(1+maturity_mths_tr)
sum maturity_mths_tr, d

*label var
label var ln_maturity_mths "ln(Maturity)"
label var ln_maturity_tr "ln(Maturity)"
label var maturity_mths "Maturity (months)"

**Other cleaning**

*fix NJ, where seed_issuer is sometimes "WEEHAWKEN TWP N J" but issuer_long_name is "WEEHAWKEN TWP N J BRD ED"
count if state == "NJ"
*br seed_issuer issuer_long_name issue_description cusip if state == "NJ" & purp_broad == "educ"
*get indicator if "BRD ED" is in the name
gen temp1 = 1 if strpos(issuer_long_name, "BRD ED") > 0 & state == "NJ"
count if temp1 == 1
*br seed_issuer issuer_long_name issue_description cusip if temp1 == 1
replace issuer_type = "school" if temp1 == 1
replace school = 1 if temp1 == 1
replace city = 0 if temp1 == 1
replace county = 0 if temp1 == 1
drop temp1

*Gen year+quarter FE
gegen yrqtr = group(year qtr)

*save file
save "$MERGENT\Clean\250605_citycountyschool_cusiplevel_statereq_purpose.dta", replace
