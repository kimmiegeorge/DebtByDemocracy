*****************************
*Voting on bonds            *
*Clean merged Mergent + MSRB*
*Last updated: 01/14/25     *
*****************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"

**# Bookmark #1
***Start with issuance-level aka issue-level file by KM*** 
*Fhis file was created in Python, merges Mergent and MSRB, and was imported to Stata using StatTransfer
use "$MERGENT\Clean\241117_issue_level_aggregation.dta", clear

*Rename variables and re-order/sort
rename (log_weighted_avg_maturity weighted_avg_callable weighted_avg_insured weighted_avg_sinkable weighted_avg_rated at_least_one_bond_rated weighted_avg_offering_yield Negotiated is_bank_qualified number_of_trades markup_institutional markup_small_institutional markup_large_institutional City_GO_Vote City_Rev_Vote County_GO_Vote County_Rev_Vote vote_required) ///
	(log_wavg_maturity wavg_callable wavg_insured wavg_sinkable wavg_rated rated_dummy wavg_offering_yield negotiated bank_qual n_trades markup_inst markup_small_inst markup_large_inst city_go_vote city_rev_vote county_go_vote county_rev_vote vote_req)

sort state seed_issuer_id year issue_id 
order state city_go_vote city_rev_vote county_go_vote county_rev_vote seed_issuer seed_issuer_id year city county school issue_id vote_req go_unlim go_lim rev
*order demos after fips and county name
order pop gdp pers_inc percap_inc, after(county_name)
*order all the issue-level vars together
order negotiated bank_qual, after(rated_dummy) 
*this leaves the MSRB variables ordered together

*drop unneeded variables like cusip because now we're at the issue-level
drop cusip
*check whether we can drop offering type
*is offering type just negotiated or comp
tab offering_type
/*
offering_ty |
         pe |      Freq.     Percent        Cum.
------------+-----------------------------------
       COMP |     30,145       67.12       67.12
        LTD |        231        0.51       67.63
       NEGO |     14,310       31.86       99.50
       PPLC |        224        0.50      100.00
       REMK |          2        0.00      100.00
------------+-----------------------------------
      Total |     44,912      100.00
*/
tab negotiated
*negotiated = 1 if offering_type is NEGO; the main alternative is if it was a competitive offering (i.e., underwriters had to bid)
*feels like it makes more sense to have competitive be the indicator; then negotiated gets grouped with private placement, which feels more intuitive
*br if offering_type == "" & negotiated != .
*11,306 have missing offering_type; want the indicator var to reflect that
*we would lose observations if we include this as a control, but we should check how different things are with or without it
drop negotiated
gen comp_offering = 1 if offering_type == "COMP"
replace comp_offering = 0 if comp_offering == . & offering_type != ""
drop offering_type
order comp_offering, after(bank_qual)

*Make comprehensive categorical vars for city/county/school and type of bond
gen issuer_type = "city" if city == 1
replace issuer_type = "county" if county == 1
replace issuer_type = "school" if school == 1
count if issuer_type == ""
*0, good

gen bond_type = "go" if go_unlim == 1 | go_lim == 1
replace bond_type = "rev" if bond_type == "" & rev == 1
count if bond_type == ""
*0, good
order issuer_type, after(year)
order bond_type, after(issue_id)
order city county school, before(fips)
order go_unlim go_lim rev, after(offering_date)
order n_trades markup markup_retail markup_small_retail markup_large_retail markup_inst markup_small_inst markup_large_inst yield_volatility, before(offering_date)
order city_go_vote city_rev_vote county_go_vote county_rev_vote, after(percap_inc)

*bring back in other vars from prior Mergent file: offering date in date format, cusip6, etc
drop offering_date
mmerge issue_id using "$MERGENT\Clean\241112_citycountyschool_cusiplevel.dta", ///
	type(1:n) missing(nomatch) ukeep(offering_date qtr)
drop if _merge == 2
duplicates drop
sort state seed_issuer_id year issue_id 
duplicates report issue_id
*good, no dups
drop _merge

order offering_date, after(year)

*label vars*
label var offering_date "Issue date"
label var seed_issuer_id "Unique issuer ID"
label var seed_issuer "Unique issuer name"
label var vote_req "Bond required vote"
label var issue_id "Issue ID"
label var ln_num_cusip "ln(# bonds in issuance)"
label var county_name "Issuer county"
label var fips "County FIPS"
label var gdp "Lag GDP"
label var pop "Lag population"
label var pers_inc "Lag personal income"
label var percap_inc "Lag per capita income"
label var city "City issuer"
label var county "County issuer"
label var school "School issuer"
label var issuer_type "Issuer type"
label var bond_type "Bond type"
label var go_unlim "GO bond (unlim tax)"
label var go_lim "GO bond(lim tax)"
label var rev "Rev bond"

*save file
save "$MERGENT\Clean\241120_issue_level.dta", replace
export delimited using "$MERGENT\Clean\241120_issue_level.csv", replace

*From issue-level, make file with just issuer and state-level vars
use "$MERGENT\Clean\241120_issue_level.dta", clear
keep state seed_issuer seed_issuer_id issue_id year offering_date issuer_type issue_id ///
	bond_type vote_req comp_offering city_go_vote city_rev_vote county_go_vote county_rev_vote
*double check how the vote vars are being generated
br state seed_issuer year bond_type vote_req city_go_vote city_rev_vote county_go_vote county_rev_vote if inlist(issuer_type,"city","county")
*city_go_vote, city_rev_vote, county_go_vote, county_rev_vote are state-level
*vote_req is based on state, issuer type, and bond type
*for places where it's unclear (e.g., IL home rule), city_go_vote is missing, so vote_req is missing
*save file
save "$MERGENT\Clean\250114_issue_level_votereq.dta", replace
