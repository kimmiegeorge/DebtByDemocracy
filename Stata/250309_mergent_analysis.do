**************************
*Voting on bonds         *
*Broad sample tests      *
*Last updated: 03/06/25  *
**************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global DESCRIPT "$MAIN\Descriptives"
global RESULTS "$MAIN\Results\2025-03_bondlevel"

***Start with bond-level Mergent data with state voting requirements***
use "$MERGENT\Clean\250307_citycountyschool_cusiplevel_statereq_purpose.dta", clear

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

*Gen year+quarter FE
gegen yrqtr = group(year qtr)

*States that have a clear revenue bond voting requirement are fundamentally different from states that do not
*Throughout analyses, focus on the states that do NOT have a clear revenue bond voting requirement
*When using city_rev_vote == 0 as a filter: vote_req turns on if the bond is GO and in a state with GO requirement. city_go_vote will turn on for both GO and rev bonds if the state has a GO requirement


**Quick descriptives**
*UPDATE 3/7 JH
**High-level table with how much each state law type contributes to the sample
gunique seed_issuer if city_go_vote == 1 & city_rev_vote == 0
count if city_go_vote == 1 & city_rev_vote == 0
count if city_go_vote == 1 & city_rev_vote == 0 & bond_type == "go"
count if city_go_vote == 1 & city_rev_vote == 0 & bond_type == "rev"

*UTGO vote only
gunique seed_issuer if inlist(state, "WA", "MI", "OH")
count if inlist(state, "WA", "MI", "OH") 
count if inlist(state, "WA", "MI", "OH") & bond_type == "go"
count if inlist(state, "WA", "MI", "OH") & bond_type == "rev"
gen utgo_only = 1 if inlist(state, "WA", "MI", "OH") 

*GO vote required but rev vote required or depends
gen temp1 = 1 if inlist(state,"CA","AZ","CO","ID","ND","SD")
replace temp1 = 1 if inlist(state,"OK","AL","VT","ME","RI")
gunique seed_issuer if temp1 == 1
count if temp1 == 1
count if temp1 == 1 & bond_type == "go"
count if temp1 == 1 & bond_type == "rev"
drop temp1

*no GO vote and no rev vote
gunique seed_issuer if city_go_vote == 0 & city_rev_vote == 0
count if city_go_vote == 0 & city_rev_vote == 0
count if city_go_vote == 0 & city_rev_vote == 0 & bond_type == "go"
count if city_go_vote == 0 & city_rev_vote == 0 & bond_type == "rev"

*light purple: GO vote req varies within state
gen temp1 = 1 if inlist(state,"NV","KS","MN","IL","SC","VA")
replace temp1 = 1 if inlist(state,"PA", "NY","MD","DE","CT")
gunique seed_issuer if temp1 == 1
count if temp1 == 1
count if temp1 == 1 & bond_type == "go"
count if temp1 == 1 & bond_type == "rev"
drop temp1

***Bring in indicator for matched to RavenPack***
*Note in original mapping, there are some dups by seed_issuer because there are multiple RP entity IDs that get matched
*This is fine, just after converting mapping from CSV to DTA, gen rp_match indicator and duplicates drop
mmerge seed_issuer_id using "$DATA\News\RP_Mergent_Mapping.dta", type(n:1) missing(nomatch)
/*
                 obs | 332624
                vars |    227  (including _merge)
         ------------+---------------------------------------------------------
              _merge |  92080  obs only in master data                (code==1)
                     | 240544  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
drop _merge

sort state seed_issuer year issue_id cusip
replace rp_match = 0 if rp_match == .


**# Bookmark #1
***New outputs***
*3/6 KM and JH call: look just at UTGO
*Use city_go_vote because it's the cleanest and easiest to explain
*Show flexes for bond controls, state controls, and county controls 

**Build up to specification**
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 & go_unlim == 1 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if city_rev_vote == 0 & go_unlim == 1 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state purp_broad_id)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State, Purpose"		

esttab using "$RESULTS/250307_city_yield_UTGO.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (UTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 

**Flex full sample UTGO with the following permutations**
/* 3 columns: FEs, clustering
(1) yrmonth together, state cluster
(2) yrmonth together, state and yrmonth twoway cluster
(3) yrmonth together, issue and yrmonth twoway cluster
*/
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state yrmonth)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State, YM"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id yrmonth)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue, YM"	
esttab using "$RESULTS/250307_city_yield_UTGO_clustering.tex", replace t noconstant b(3) ///
	title("Yield tests: UTGO bonds, clustering options") star(* .10 ** .05 *** .01) ///
	s(N r2_a sample timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Sample" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 	

*state year
gegen stateyr = group(state year)
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state year)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State, Y"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster stateyr)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "S-Y"	
esttab using "$RESULTS/250309_city_yield_UTGO_stateyr.tex", replace t noconstant b(3) ///
	title("Yield tests: UTGO bonds, clustering options") star(* .10 ** .05 *** .01) ///
	s(N r2_a sample timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Sample" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 		
	
	
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)	
	
	
	
	
	
	
	
	
**Flex RP sample UTGO with the following permutations**
/* 3 columns: FEs, clustering
(1) yrmonth together, state cluster
(2) yrmonth together, state and yrmonth twoway cluster
(3) yrmonth together, issue and yrmonth twoway cluster
*/
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1 & rp_match == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local sample "RP"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1 & rp_match == 1 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state yrmonth)
	estadd local sample "RP"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State, YM"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1 & rp_match == 1 ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id yrmonth)
	estadd local sample "RP"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue, YM"	
esttab using "$RESULTS/250307_city_yield_UTGO_RP_clustering.tex", replace t noconstant b(3) ///
	title("Yield tests: UTGO bonds, RavenPack-matched sample, clustering options") star(* .10 ** .05 *** .01) ///
	s(N r2_a sample timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Sample" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 	

/*3/7 old


/*8 columns: FEs, clustering
(1) year month separate, state cluster
(2) year month separate, twoway cluster state and purpose
(3) yrmonth together, state cluster
(4) yrmonth together, twoway cluster state and purpose
(5) year qtr separate, state cluster
(6) year qtr separate, twoway cluster state and purpose
(7) yrqtr together, state cluster
(8) yrqtr together, twoway cluster state and purpose
*/
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(year month purp_broad_id) vce(cluster state)
	estadd local sample "Full"
	estadd local timeFE "Y, M"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(year month purp_broad_id) vce(cluster state purp_broad_id)
	estadd local sample "Full"
	estadd local timeFE "Y, M"
	estadd local purposeFE "Yes"
	estadd local SE "State, Purp"		
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state purp_broad_id)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State, Purp"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(year qtr purp_broad_id) vce(cluster state)
	estadd local sample "Full"
	estadd local timeFE "Y, Q"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(year qtr purp_broad_id) vce(cluster state purp_broad_id)
	estadd local sample "Full"
	estadd local timeFE "Y, Q"
	estadd local purposeFE "Yes"
	estadd local SE "State, Purp"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrqtr purp_broad_id) vce(cluster state)
	estadd local sample "Full"
	estadd local timeFE "YQ"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrqtr purp_broad_id) vce(cluster state purp_broad_id)
	estadd local sample "Full"
	estadd local timeFE "YQ"
	estadd local purposeFE "Yes"
	estadd local SE "State, Purp"	

esttab using "$RESULTS/250307_city_yield_UTGO_timeFE_statepurpclus.tex", replace t noconstant b(3) ///
	title("Yield tests: UTGO bonds, flex time FEs and state and purpose cluster") star(* .10 ** .05 *** .01) ///
	s(N r2_a sample timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Sample" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 	
	
**Flex full sample with the following permutations**
/*4 columns:
(1) twoway cluster state and year, year month separate
(2) twoway cluster state and year, yrmonth together
(3) twoway cluster state and year, year qtr separate
(4) twoway cluster state and year, yrqtr together
*/
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(year month purp_broad_id) vce(cluster state year)
	estadd local sample "Full"
	estadd local timeFE "Y, M"
	estadd local purposeFE "Yes"
	estadd local SE "State, Yr"		
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state year)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State, Yr"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(year qtr purp_broad_id) vce(cluster state year)
	estadd local sample "Full"
	estadd local timeFE "Y, Q"
	estadd local purposeFE "Yes"
	estadd local SE "State, Yr"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrqtr purp_broad_id) vce(cluster state year)
	estadd local sample "Full"
	estadd local timeFE "YQ"
	estadd local purposeFE "Yes"
	estadd local SE "State, Yr"	
esttab using "$RESULTS/250307_city_yield_UTGO_timeFE_stateyrclus.tex", replace t noconstant b(3) ///
	title("Yield tests: UTGO bonds, flex time FEs and state and year cluster") star(* .10 ** .05 *** .01) ///
	s(N r2_a sample timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Sample" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 	
	
	
**Flex full sample with the following permutations**
/*4 columns:
(1) twoway cluster issue and year, year month separate
(2) twoway cluster issue and year, yrmonth together
(3) twoway cluster issue and year, year qtr separate
(4) twoway cluster issue and year, yrqtr together
*/
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(year month purp_broad_id) vce(cluster issue_id year)
	estadd local sample "Full"
	estadd local timeFE "Y, M"
	estadd local purposeFE "Yes"
	estadd local SE "Issue, Yr"		
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id year)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue, Yr"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(year qtr purp_broad_id) vce(cluster issue_id year)
	estadd local sample "Full"
	estadd local timeFE "Y, Q"
	estadd local purposeFE "Yes"
	estadd local SE "Issue, Yr"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrqtr purp_broad_id) vce(cluster issue_id year)
	estadd local sample "Full"
	estadd local timeFE "YQ"
	estadd local purposeFE "Yes"
	estadd local SE "Issue, Yr"	
esttab using "$RESULTS/250307_city_yield_UTGO_timeFE_issueyrclus.tex", replace t noconstant b(3) ///
	title("Yield tests: UTGO bonds, flex time FEs and issue and year cluster") star(* .10 ** .05 *** .01) ///
	s(N r2_a sample timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Sample" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 		
	
**Flex full sample with the following permutations**
/*4 columns:
(1) twoway cluster issue and yrmonth, year month separate
(2) twoway cluster issue and yrmonth, yrmonth together
(3) twoway cluster issue and yrmonth, year qtr separate
(4) twoway cluster issue and yrmonth, yrqtr together
*/
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(year month purp_broad_id) vce(cluster issue_id yrmonth)
	estadd local sample "Full"
	estadd local timeFE "Y, M"
	estadd local purposeFE "Yes"
	estadd local SE "Issue, YM"		
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id yrmonth)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue, YM"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(year qtr purp_broad_id) vce(cluster issue_id yrmonth)
	estadd local sample "Full"
	estadd local timeFE "Y, Q"
	estadd local purposeFE "Yes"
	estadd local SE "Issue, YM"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrqtr purp_broad_id) vce(cluster issue_id yrmonth)
	estadd local sample "Full"
	estadd local timeFE "YQ"
	estadd local purposeFE "Yes"
	estadd local SE "Issue, YM"	
esttab using "$RESULTS/250307_city_yield_UTGO_timeFE_issueyrmthclus.tex", replace t noconstant b(3) ///
	title("Yield tests: UTGO bonds, flex time FEs and issue and year cluster") star(* .10 ** .05 *** .01) ///
	s(N r2_a sample timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Sample" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 			
	
**Flex full sample with the following permutations**
/*4 columns:
(1) twoway cluster state and YM, year month separate
(2) twoway cluster state and YM, yrmonth together
(3) twoway cluster state and YM, year qtr separate
(4) twoway cluster state and YM, yrqtr together
*/
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(year month purp_broad_id) vce(cluster state yrmonth)
	estadd local sample "Full"
	estadd local timeFE "Y, M"
	estadd local purposeFE "Yes"
	estadd local SE "State, YM"		
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state yrmonth)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State, YM"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(year qtr purp_broad_id) vce(cluster state yrmonth)
	estadd local sample "Full"
	estadd local timeFE "Y, Q"
	estadd local purposeFE "Yes"
	estadd local SE "State, YM"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrqtr purp_broad_id) vce(cluster state yrmonth)
	estadd local sample "Full"
	estadd local timeFE "YQ"
	estadd local purposeFE "Yes"
	estadd local SE "State, YM"	
esttab using "$RESULTS/250307_city_yield_UTGO_timeFE_stateymclus.tex", replace t noconstant b(3) ///
	title("Yield tests: UTGO bonds, flex time FEs and state and YM cluster") star(* .10 ** .05 *** .01) ///
	s(N r2_a sample timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Sample" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 		
*/	
	
/*3/6 old	
	
***Just UTGO with issuers matched to RP***
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 & go_unlim == 1 & rp_match == 1 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if city_rev_vote == 0 & go_unlim == 1 & rp_match == 1 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1 & rp_match == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1 & rp_match == 1 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state purp_broad_id)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State, Purpose"		

esttab using "$RESULTS/250306_city_yield_UTGO_rpsample.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (UTGO, RP sample)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 	
	
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1 & rp_match == 1  ///
	, absorb(year month purp_broad_id) vce(cluster state)	
*still pretty sensitive to year and month separately
	
*/	
	
**# Bookmark #2
***Purpose tests with UTGO only***
tab purp_broad if city_rev_vote == 0 & go_unlim == 1 
/*
  purp_broad |      Freq.     Percent        Cum.
-------------+-----------------------------------
        arts |      2,415        1.84        1.84
     econdev |        415        0.32        2.15
        educ |      7,291        5.54        7.70
genpubimprov |    100,586       76.48       84.18
      health |        268        0.20       84.38
     housing |        124        0.09       84.48
     justice |         39        0.03       84.51
       other |        709        0.54       85.05
    parksrec |      3,314        2.52       87.56
     pubbldg |      1,731        1.32       88.88
      safety |      2,740        2.08       90.96
   transport |      2,138        1.63       92.59
   utilities |      1,161        0.88       93.47
      wtrswr |      8,584        6.53      100.00
-------------+-----------------------------------
       Total |    131,515      100.00
*/

*When there's a UTGO vote requirement, are UTGO bonds less likely?*
*regression form for full sample and RP sample	
*don't control for purpose because purpose and form of the bond are likely decided jointly
eststo clear
eststo: qui reghdfe go_unlim city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
eststo: qui reghdfe go_unlim city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state yrmonth)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State, YM"	
eststo: qui reghdfe go_unlim city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & rp_match == 1 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local sample "RP"
	estadd local timeFE "YM"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
eststo: qui reghdfe go_unlim city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0  ///
	, absorb(yrmonth) vce(cluster state yrmonth)
	estadd local sample "RP"
	estadd local timeFE "YM"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State, YM"	
esttab using "$RESULTS\250308_city_likelihood_utgo_samples.tex", replace t noconstant b(3) ///
	title("Likelihood of UTGO bond when city GO vote required") star(* .10 ** .05 *** .01) ///
	s(N r2_a sample timeFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Sample" "Time FE" "State Controls" "County Controls" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 	
*No association with likelihood of UTGO bond. In plan reg with go_unlim and city_go_vote, very negative and significant. But not with all the controls
*reg go_unlim city_go_vote, vce(robust)
*Even though LTGO allowed control loads a lot, the main coeff is not significant if we drop that control

eststo clear
eststo: qui reghdfe go_lim city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
eststo: qui reghdfe go_lim city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state yrmonth)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State, YM"	
eststo: qui reghdfe go_lim city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & rp_match == 1 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local sample "RP"
	estadd local timeFE "YM"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
eststo: qui reghdfe go_lim city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0  ///
	, absorb(yrmonth) vce(cluster state yrmonth)
	estadd local sample "RP"
	estadd local timeFE "YM"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State, YM"	
esttab using "$RESULTS\250309_city_likelihood_ltgo_samples.tex", replace t noconstant b(3) ///
	title("Likelihood of LTGO bond when city GO vote required") star(* .10 ** .05 *** .01) ///
	s(N r2_a sample timeFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Sample" "Time FE" "State Controls" "County Controls" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 	


eststo clear
eststo: qui reghdfe rev city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
eststo: qui reghdfe rev city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state yrmonth)
	estadd local sample "Full"
	estadd local timeFE "YM"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State, YM"	
eststo: qui reghdfe rev city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & rp_match == 1 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local sample "RP"
	estadd local timeFE "YM"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
eststo: qui reghdfe rev city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0  ///
	, absorb(yrmonth) vce(cluster state yrmonth)
	estadd local sample "RP"
	estadd local timeFE "YM"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State, YM"	
esttab using "$RESULTS\250309_city_likelihood_rev_samples.tex", replace t noconstant b(3) ///
	title("Likelihood of rev bond when city GO vote required") star(* .10 ** .05 *** .01) ///
	s(N r2_a sample timeFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Sample" "Time FE" "State Controls" "County Controls" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 		
	

	
	
*Difference in means with purposes
*label purpose vars
label var purp_broad_arts "Arts" 
label var purp_broad_econdev "Econ dev"
label var purp_broad_educ "Education" 
label var purp_broad_genpubimprov "Gen pub improv"
label var purp_broad_health "Healthcare" 
label var purp_broad_housing "Housing"
label var purp_broad_justice "Justice"
label var purp_broad_other "Other"
label var purp_broad_parksrec "Parks \& rec"
label var purp_broad_pubbldg "Public building" 
label var purp_broad_safety "Safety"
label var purp_broad_transport "Transport"
label var purp_broad_utilities "Utilities"
label var purp_broad_wtrswr "Water \& sewer"
label var go_unlim "UT GO bond"
label var go_lim "LT GO bond"


label var arts_nbonds "Arts nbonds" 
label var econdev_nbonds "Econ dev nbonds"
label var educ_nbonds "Education nbonds"
label var genpubimprov_nbonds "Gen pub improv nbonds"
label var health_nbonds "Healthcare nbonds" 
label var housing_nbonds "Housing nbonds"
label var justice_nbonds "Justice nbonds"
label var other_nbonds "Other nbonds"
label var parksrec_nbonds "Parks \& rec nbonds"
label var pubbldg_nbonds "Public building nbonds"
label var safety_nbonds "Safety nbonds"
label var transport_nbonds "Transport nbonds"
label var utilities_nbonds "Utilities nbonds"
label var wtrswr_nbonds "Water \& sewer nbonds"

label var arts_amt_ln "Arts amt"
label var econdev_amt_ln "Econ dev amt"
label var educ_amt_ln "Education amt"
label var genpubimprov_amt_ln "Gen pub improv amt"
label var health_amt_ln "Healthcare amt" 
label var housing_amt_ln "Housing amt"
label var justice_amt_ln "Justice amt"
label var other_amt_ln "Other amt"
label var parksrec_amt_ln "Parks \& rec amt"
label var pubbldg_amt_ln "Public building amt"
label var safety_amt_ln "Safety amt"
label var transport_amt_ln "Transport amt"
label var utilities_amt_ln "Utilities amt"
label var wtrswr_amt_ln "Water \& sewer amt"

*Diff means, UTGO
eststo clear
eststo novote: estpost sum ///
	purp_broad_genpubimprov purp_broad_pubbldg purp_broad_transport ///
	purp_broad_educ purp_broad_health purp_broad_arts purp_broad_parksrec ///
	purp_broad_econdev	purp_broad_housing purp_broad_safety purp_broad_justice	///
	purp_broad_utilities purp_broad_wtrswr purp_broad_other ///
	if city_go_vote == 0 & city_rev_vote == 0 & go_unlim == 1, d
eststo yesvote: estpost sum ///
	purp_broad_genpubimprov purp_broad_pubbldg purp_broad_transport ///
	purp_broad_educ purp_broad_health purp_broad_arts purp_broad_parksrec ///
	purp_broad_econdev	purp_broad_housing purp_broad_safety purp_broad_justice	///
	purp_broad_utilities purp_broad_wtrswr purp_broad_other ///
	if city_go_vote == 1 & city_rev_vote == 0 & go_unlim == 1, d
eststo diff: estpost ttest ///
	purp_broad_genpubimprov purp_broad_pubbldg purp_broad_transport ///
	purp_broad_educ purp_broad_health purp_broad_arts purp_broad_parksrec ///
	purp_broad_econdev	purp_broad_housing purp_broad_safety purp_broad_justice	///
	purp_broad_utilities purp_broad_wtrswr purp_broad_other ///
	if city_rev_vote == 0 & go_unlim == 1, by(city_go_vote) welch
esttab novote yesvote diff using "$RESULTS\250308_city_UTGO_projselect_diffmeans.tex", ///
	replace title(Difference in means for bond types and purposes (within UTGO)) ///
	cells("mean(pattern(1 1 0) fmt(%9.2fc)) b(star pattern(0 0 1) fmt(%9.2fc)) t(pattern(0 0 1) par fmt(2))") ///
	collabels("Mean" "Difference" "t-stat") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	
*Note diff = no vote - yes vote
*When there's no vote, there are more: genpubimprov, education; less: pubblg, transport, arts, parks and rec, safety, water and sewer

*Diff means, all bonds
eststo clear
eststo novote: estpost sum ///
	go_unlim go_lim rev purp_broad_genpubimprov purp_broad_pubbldg purp_broad_transport ///
	purp_broad_educ purp_broad_health purp_broad_arts purp_broad_parksrec ///
	purp_broad_econdev	purp_broad_housing purp_broad_safety purp_broad_justice	///
	purp_broad_utilities purp_broad_wtrswr purp_broad_other ///
	if city_go_vote == 0 & city_rev_vote == 0 , d
eststo yesvote: estpost sum ///
	go_unlim go_lim rev purp_broad_genpubimprov purp_broad_pubbldg purp_broad_transport ///
	purp_broad_educ purp_broad_health purp_broad_arts purp_broad_parksrec ///
	purp_broad_econdev	purp_broad_housing purp_broad_safety purp_broad_justice	///
	purp_broad_utilities purp_broad_wtrswr purp_broad_other ///
	if city_go_vote == 1 & city_rev_vote == 0 , d
eststo diff: estpost ttest ///
	go_unlim go_lim rev purp_broad_genpubimprov purp_broad_pubbldg purp_broad_transport ///
	purp_broad_educ purp_broad_health purp_broad_arts purp_broad_parksrec ///
	purp_broad_econdev	purp_broad_housing purp_broad_safety purp_broad_justice	///
	purp_broad_utilities purp_broad_wtrswr purp_broad_other ///
	if city_rev_vote == 0 , by(city_go_vote) welch
esttab novote yesvote diff using "$RESULTS\250309_city_allbonds_projselect_diffmeans.tex", ///
	replace title(Difference in means for bond types and purposes (all bonds)) ///
	cells("mean(pattern(1 1 0) fmt(%9.2fc)) b(star pattern(0 0 1) fmt(%9.2fc)) t(pattern(0 0 1) par fmt(2))") ///
	collabels("Mean" "Difference" "t-stat") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle
*Note diff = no vote - yes vote
*When there's no vote, there are more UTGO, less LTGO, less revenue
*When there's no vote, there are more: genpubimprov, education; less: pubblg, transport, healthcare, arts, parks and rec, safety, justice, utilities, water and sewer, other

*Regression for purpose indicators
*just UTGO

eststo clear
local temp genpubimprov pubbldg transport educ health arts parksrec 
foreach x of local temp{
	eststo: qui reghdfe purp_broad_`x' city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
}
esttab using "$RESULTS\250308_city_UTGO_projselect_reg_pt1_state.tex", replace t noconstant b(3) ///
	title("Likelihood of projects when city GO vote required (UTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 
	
eststo clear
local temp genpubimprov pubbldg transport educ health arts parksrec 
foreach x of local temp{
	eststo: qui reghdfe purp_broad_`x' city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1 ///
	, absorb(yrmonth) vce(cluster state yrmonth)
	estadd local yrmonthFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State, YM"	
}
esttab using "$RESULTS\250308_city_UTGO_projselect_reg_pt1_stateym.tex", replace t noconstant b(3) ///
	title("Likelihood of projects when city GO vote required (UTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 
*no sig differences. Changing the clustering doesn't make a difference here, so just cluster by state
	
eststo clear
local temp econdev housing safety justice utilities wtrswr other
foreach x of local temp{
	eststo: qui reghdfe purp_broad_`x' city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1 ///
	, absorb(yrmonth) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
}
esttab using "$RESULTS\250308_city_UTGO_projselect_reg_pt2.tex", replace t noconstant b(3) ///
	title("Likelihood of projects when city GO vote required (UTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 	
*only sig is increase in other
	
*Regression for purpose indicators, all bonds

eststo clear
local temp genpubimprov pubbldg transport educ health arts parksrec 
foreach x of local temp{
	eststo: qui reghdfe purp_broad_`x' city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0  ///
	, absorb(yrmonth) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
}
esttab using "$RESULTS\250309_city_allbonds_projselect_reg_pt1_state.tex", replace t noconstant b(3) ///
	title("Likelihood of projects when city GO vote required (all bonds)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 	
	
eststo clear
local temp genpubimprov pubbldg transport educ health arts parksrec 
foreach x of local temp{
	eststo: qui reghdfe purp_broad_`x' city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state yrmonth)
	estadd local yrmonthFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State, YM"	
}
esttab using "$RESULTS\250309_city_allbonds_projselect_reg_pt1_stateym.tex", replace t noconstant b(3) ///
	title("Likelihood of projects when city GO vote required (allbonds)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 	
	
eststo clear
local temp econdev housing safety justice utilities wtrswr other
foreach x of local temp{
	eststo: qui reghdfe purp_broad_`x' city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0  ///
	, absorb(yrmonth) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
}
esttab using "$RESULTS\250309_city_allbonds_projselect_reg_pt2_state.tex", replace t noconstant b(3) ///
	title("Likelihood of projects when city GO vote required (all bonds)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 	
*Across all bonds, when there's a vote, there's more: public building, transport, healthcare, arts	
*This is consistent with the difference in means, but somewhat hard to explain
	
*Regression for n_bonds, amt for all bonds
*collapse at the issuer-year level	
preserve
gcollapse *_nbonds *_amt *_amt_ln, by(state seed_issuer seed_issuer_id year /*qtr yrqtr*/ city_go_vote city_rev_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp rp_match)
	
*number of bonds
eststo clear
local temp genpubimprov pubbldg transport educ health arts parksrec 
foreach x of local temp{
	eststo: qui reghdfe `x'_nbonds city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(year) vce(cluster state)
	estadd local timeFE "Year"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
}
esttab using "$RESULTS\250309_city_allbonds_projselect_nbonds_pt1.tex", replace t noconstant b(3) ///
	title("Number of bonds for purposes when city GO vote required (all bonds)") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 	
*Note: At quarterly level, whether time FE is at Y, YQ separate, or YQ together, doesn't make a difference	
*Nothing significant
	
eststo clear
local temp econdev housing safety justice utilities wtrswr other
foreach x of local temp{
	eststo: qui reghdfe `x'_nbonds city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(year) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
}
esttab using "$RESULTS\250309_city_allbonds_projselect_nbonds_pt2.tex", replace t noconstant b(3) ///
	title("Number of bonds for purposes when city GO vote required (all bonds)") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 	
	
*ln of amount
eststo clear
local temp genpubimprov pubbldg transport educ health arts parksrec 
foreach x of local temp{
	eststo: qui reghdfe `x'_amt_ln city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(year) vce(cluster state)
	estadd local timeFE "Year"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
}
esttab using "$RESULTS\250309_city_allbonds_projselect_amt_pt1.tex", replace t noconstant b(3) ///
	title("Amount raised for purposes when city GO vote required (all bonds)") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 	
*Note: At quarterly level, whether time FE is at Y, YQ separate, or YQ together, doesn't make a difference	
*Nothing significant
	
eststo clear
local temp econdev housing safety justice utilities wtrswr other
foreach x of local temp{
	eststo: qui reghdfe `x'_amt_ln city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(year) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
}
esttab using "$RESULTS\250309_city_allbonds_projselect_amt_pt2.tex", replace t noconstant b(3) ///
	title("Amount raised for purposes when city GO vote required (all bonds)") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 		
	
restore
	
	
	
	
	
	
	
	
	
	
*Regression for n_bonds, amt for UTGO only
*collapse at the issuer-year level
keep if go_unlim == 1
gcollapse *_nbonds *_amt *_amt_ln, by(state seed_issuer seed_issuer_id year /*qtr yrqtr*/ city_go_vote city_rev_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp rp_match)


*regression for number of bonds
*note these are automatically within go_unlim == 1
*time FE can't have month b/c data is at yrqtr level
eststo clear
local temp genpubimprov pubbldg transport educ health arts parksrec 
foreach x of local temp{
	eststo: qui reghdfe `x'_nbonds city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(year) vce(cluster state)
	estadd local timeFE "Year"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
}
esttab using "$RESULTS\250308_city_purpose_nbonds_pt1.tex", replace t noconstant b(3) ///
	title("Number of bonds for purposes when city GO vote required (UTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 	
*Note: At quarterly level, whether time FE is at Y, YQ separate, or YQ together, doesn't make a difference	
*Nothing significant
	
eststo clear
local temp econdev housing safety justice utilities wtrswr other
foreach x of local temp{
	eststo: qui reghdfe `x'_nbonds city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(year) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
}
esttab using "$RESULTS\250308_city_purpose_nbonds_pt2.tex", replace t noconstant b(3) ///
	title("Number of bonds for purposes when city GO vote required (UTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yearFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 	
*Nothing significant except more other

*regression for amount raised
eststo clear
local temp genpubimprov pubbldg transport educ health arts parksrec 
foreach x of local temp{
	eststo: qui reghdfe `x'_amt_ln city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(year) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
}
esttab using "$RESULTS\250305_city_purpose_amt_pt1.tex", replace t noconstant b(3) ///
	title("Amount raised for purposes when city GO vote required") star(* .10 ** .05 *** .01) ///
	s(N r2_a yearFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 
	
eststo clear
local temp econdev housing safety justice utilities wtrswr other
foreach x of local temp{
	eststo: qui reghdfe `x'_amt_ln city_go_vote state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(year) vce(cluster state)
	estadd local yearFE "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
}
esttab using "$RESULTS\250305_city_purpose_amt_pt2.tex", replace t noconstant b(3) ///
	title("Amount raised for purposes when city GO vote required") star(* .10 ** .05 *** .01) ///
	s(N r2_a yearFE statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year FE" "State Controls" "County Controls" "Cluster")) ///
	keep(city_go_vote) label booktabs noobs nonotes 
	
*Note that when we included all bonds, these results were pretty consistent:
*Consistently: with GO vote, more in public building, transport, healthcare
*with GO vote, less in arts, econ dev
	
*Maybe going with all bonds makes sense? We want to see what the vote requirement does to other bond choices - could see them trying to "avoid" by using other types of bonds
	
	
	
	
	
	
	
	
	
	
	
	
	
	


**# Bookmark #1
***Test tightest version of each type of broad sample test**
*(1) When there's a city GO vote requirement, is offering yield different?
*Note that with WI correction, UTGO is omitted b/c perfectly corr with city_go_vote
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth purp_broad_id /*num_use_proceeds*/) vce(cluster state)
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

reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth purp_broad_id /*num_use_proceeds*/) vce(cluster state)
/*
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.0895379   .0515942    -1.74   0.095    -.1957981    .0167224
*/

*(1a) What about for just GO bonds?
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & bond_type == "go" ///
	, absorb(yrmonth purp_broad_id /*num_use_proceeds*/) vce(cluster state)
/*

         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |  -.1073506   .0560104    -1.92   0.067    -.2227062     .008005
*/

*with broader purpose FE:
/*
         offering_yield_tr | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
              city_go_vote |   -.107501   .0576704    -1.86   0.074    -.2262753    .0112733
*/

*just GO, drop dark blue
gen temp1 = 1 if inlist("WA", "MI", "OH")
reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & bond_type == "go" & temp1 != 1 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)

reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated /*i.num_use_proceeds*/ ///
	state_godebt_limit state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_lim == 1 & temp1 != 1 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	
count if go_lim == 1 & city_rev_vote == 0 & temp1 != 1
count if go_lim == 1 & city_rev_vote == 0 & temp1 != 1 & city_go_vote == 1
count if go_lim == 1 & city_rev_vote == 0 & temp1 != 1 & city_go_vote == 0


count if go_unlim == 1 & city_rev_vote == 0 & temp1 != 1

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
reghdfe purp_broad_genpubimprov city_go_vote state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth) vce(cluster state)	

*run regressions for all
local temp arts econdev educ genpubimprov health housing justice other parksrec pubbldg safety transport utilities wtrswr
foreach x of local temp{
	reghdfe purp_broad_`x' city_go_vote state_godebt_limit   state_ltgo_allowed ///
		state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
		ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
		if city_rev_vote == 0 ///
		, absorb(yrmonth) vce(cluster state)
}
*takeaway: less arts, marginally less econdev and wtrswr; more health, pubbldg, transport
/*
- arts: city_go_vote | -.0165366   .0078547    -2.11   0.045 
- econdev: city_go_vote |  -.0111362   .0073582    -1.51   0.143 
- educ: city_go_vote |  -.0042722   .0382463    -0.11   0.912 
- genpubimprov: city_go_vote | -.0102417   .0730604    -0.14   0.890 
- health: city_go_vote |    .0282945   .0137822     2.05   0.051  
- housing: city_go_vote |   -.0004668   .0019541    -0.24   0.813 
- justice:  city_go_vote |    .001939    .001305     1.49   0.150 
- other: city_go_vote |   .0028011   .0020888     1.34   0.192 
- parksrec:  city_go_vote |   .0142277   .0098683     1.44   0.162    
- pubbldg: city_go_vote |   .0144955   .0069022     2.10   0.046 
- safety: city_go_vote |     .00501   .0062651     0.80   0.431 
- transport: city_go_vote |   .0227237   .0065417     3.47   0.002 
- utilities: city_go_vote |   .0263192   .0176958     1.49   0.149  
- wtrswr: city_go_vote |  -.0731571   .0482795    -1.52   0.142 
*/

*(4b): Differences in means
tab purp_broad
/*
  purp_broad |      Freq.     Percent        Cum.
-------------+-----------------------------------
        arts |      4,936        1.48        1.48
     econdev |      1,650        0.50        1.98
        educ |     12,359        3.72        5.70
genpubimprov |    205,619       61.82       67.51
      health |      4,240        1.27       68.79
     housing |      1,235        0.37       69.16
     justice |        300        0.09       69.25
       other |      1,973        0.59       69.84
    parksrec |      6,363        1.91       71.76
     pubbldg |      4,871        1.46       73.22
      safety |      4,883        1.47       74.69
   transport |      6,604        1.99       76.67
   utilities |     17,064        5.13       81.80
      wtrswr |     60,527       18.20      100.00
-------------+-----------------------------------
       Total |    332,624      100.00
*/

tab purp_broad if city_rev_vote == 0
/*
  purp_broad |      Freq.     Percent        Cum.
-------------+-----------------------------------
        arts |      3,856        1.58        1.58
     econdev |      1,385        0.57        2.15
        educ |      9,083        3.73        5.88
genpubimprov |    142,121       58.38       64.27
      health |      3,177        1.31       65.57
     housing |        901        0.37       65.94
     justice |        254        0.10       66.05
       other |      1,435        0.59       66.63
    parksrec |      4,999        2.05       68.69
     pubbldg |      3,638        1.49       70.18
      safety |      4,068        1.67       71.85
   transport |      5,081        2.09       73.94
   utilities |     14,016        5.76       79.70
      wtrswr |     49,421       20.30      100.00
-------------+-----------------------------------
       Total |    243,435      100.00
*/

local temp arts econdev educ genpubimprov health housing justice other parksrec pubbldg safety transport utilities wtrswr
foreach x of local temp{
	ttest purp_broad_`x' if city_rev_vote == 0, by(city_go_vote) welch
}
/*Notes for sig differences: diff = no vote less vote
- arts: diff=-.0050043, p=0, t=-9.0397
- educ: diff=.0719956, p=0, t=66.5954
- genpubimprov: diff= .1378937, p=0, t= 59.7083
- health: diff= -.0115643, p=0, t=-29.2296
- justice: diff= -.0016678 , p=0, t=-11.2154
- other: diff= -.0017942, p=0, t=-5.9816
- parksrec: diff=-.0192763, p=0, t=-30.2159
- pubbldg: diff=-.0119524, p=0, t=-21.7340
- safety: diff=-.0106484, p=0, t=-18.0934
- transport: diff= -.0246085, p=0, t=-39.7847
- utilities: diff=-.0279245, p=0, t=-25.3293
- wtrswr: diff=-.0953701, p=0, t=-50.7806
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
esttab using "$DESCRIPT\Bondlevel\250124_bondlevel_sumstats_city.tex", replace ///
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250305_city_yield_govote_pooled.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	label booktabs noobs nonotes 	
	
*(1.1.a) All GO	
eststo clear
eststo: qui reg offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 & bond_type == "go" ///
	, vce(cluster state)
	estadd local yrmonthFE "No"
	estadd local purposeFE "No"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"

eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 & bond_type == "go" ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	if city_rev_vote == 0 & bond_type == "go" ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	if city_rev_vote == 0 & bond_type == "go" ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250305_city_yield_govote_GO.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (GO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons) label booktabs noobs nonotes 
	
*(1a) GO unlim
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 & go_unlim == 1 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250305_city_yield_govote_UTGO.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (UTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons) label booktabs noobs nonotes 

*(1b) GO lim
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 & go_lim == 1 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250305_city_yield_govote_LTGO.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (LTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons) label booktabs noobs nonotes 
	
*(1c) GO vote and revenue
eststo clear
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 & rev == 1 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250305_city_yield_govote_rev.tex", replace t noconstant b(3) ///
	title("Bond referendum requirements and offering yield (revenue)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "No"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"
eststo: qui reghdfe offering_yield_tr city_rev_vote ln_amount ln_maturity callable sinkable insured rated ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "No"
	estadd local countycon "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_rev_vote ln_amount ln_maturity callable sinkable insured rated ///
	state_godebt_limit   state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS/250305_city_yield_revvote_pooled.tex", replace t noconstant b(3) ///
	title("Revenue bond referendum requirements and offering yield") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	label booktabs noobs nonotes 	
	
**# Bookmark #4
***(2) When a vote is required on a GO bond, is the offering yield different?***
eststo clear
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS\250305_city_yield_votereq.tex", replace t noconstant b(3) ///
	title("Vote required and offering yield") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons) label booktabs noobs nonotes 	

**(2a) GO unlimited tax**
eststo clear
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 & go_unlim == 1 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS\250305_city_yield_votereq_UTGO.tex", replace t noconstant b(3) ///
	title("Vote required and offering yield (UTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons) label booktabs noobs nonotes 	
	
**(2b) GO limited tax**
eststo clear
eststo: qui reghdfe offering_yield_tr vote_req ln_amount ln_maturity callable sinkable insured rated ///
	if city_rev_vote == 0 & go_lim == 1 ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
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
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local yrmonthFE "Yes"
	estadd local purposeFE "Yes"
	estadd local bondcon "Yes"
	estadd local statecon "Yes"
	estadd local countycon "Yes"
	estadd local SE "State"	
esttab using "$RESULTS\250305_city_yield_votereq_LTGO.tex", replace t noconstant b(3) ///
	title("Vote required and offering yield (LTGO)") star(* .10 ** .05 *** .01) ///
	s(N r2_a yrmonthFE purposeFE bondcon statecon countycon SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Year-Month FE" "Purpose FE" "Bond Controls" "State Controls" "County Controls" "Cluster")) ///
	drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons) label booktabs noobs nonotes 	

**# Bookmark #5
