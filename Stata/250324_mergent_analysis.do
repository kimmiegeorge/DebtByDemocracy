**************************
*Voting on bonds         *
*Broad sample tests      *
*Last updated: 03/13/25  *
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
use "$MERGENT\Clean\250313_citycountyschool_cusiplevel_statereq_purpose.dta", clear

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

*fix NJ, where seed_issuer is sometimes "WEEHAWKEN TWP N J" but issuer_long_name is "WEEHAWKEN TWP N J BRD ED"
count if state == "NJ"
*14,396
*br seed_issuer issuer_long_name issue_description cusip if state == "NJ" & purp_broad == "educ"
*get indicator if "BRD ED" is in the name
gen temp1 = 1 if strpos(issuer_long_name, "BRD ED") > 0 & state == "NJ"
count if temp1 == 1
*br seed_issuer issuer_long_name issue_description cusip if temp1 == 1
drop if temp1 == 1
drop temp1

*number of issuers
gunique seed_issuer
*N = 328,201; 5,900 unbalanced groups of sizes 1 to 1,681
count if go_unlim == 1 
*196,760

tab city_go_vote
/*
    City GO |
       vote |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |     72,555       35.27       35.27
          1 |    133,157       64.73      100.00
------------+-----------------------------------
      Total |    205,712      100.00
*/

tab city_rev_vote
/*
   City rev |
       vote |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    239,012       93.89       93.89
          1 |     15,557        6.11      100.00
------------+-----------------------------------
      Total |    254,569      100.00
*/

*Gen year+quarter FE
gegen yrqtr = group(year qtr)

*States that have a clear revenue bond voting requirement are fundamentally different from states that do not
*Throughout analyses, focus on the states that do NOT have a clear revenue bond voting requirement
*When using city_rev_vote == 0 as a filter: vote_req turns on if the bond is GO and in a state with GO requirement. city_go_vote will turn on for both GO and rev bonds if the state has a GO requirement


**Quick descriptives**
**High-level table with how much each state law type contributes to the sample
gunique seed_issuer if city_go_vote == 1 & city_rev_vote == 0
count if city_go_vote == 1 & city_rev_vote == 0
count if city_go_vote == 1 & city_rev_vote == 0 & go_unlim == 1
*38,969
gunique seed_issuer if city_go_vote == 1 & city_rev_vote == 0 & go_unlim == 1
*1,173 seed issuers; 38,969 obs
count if city_go_vote == 1 & city_rev_vote == 0 & go_lim == 1
count if city_go_vote == 1 & city_rev_vote == 0 & bond_type == "rev"

*UTGO vote only
gunique seed_issuer if inlist(state, "WA", "MI", "OH")
count if inlist(state, "WA", "MI", "OH") 
count if inlist(state, "WA", "MI", "OH") & go_unlim == 1
count if inlist(state, "WA", "MI", "OH") & go_lim == 1
count if inlist(state, "WA", "MI", "OH") & bond_type == "rev"
gen utgo_only = 1 if inlist(state, "WA", "MI", "OH") 

*GO vote required but rev vote required or depends
gen temp1 = 1 if inlist(state,"CA","AZ","CO","ID","ND","SD")
replace temp1 = 1 if inlist(state,"OK","AL","VT","ME","RI")
gunique seed_issuer if temp1 == 1
count if temp1 == 1
count if temp1 == 1 & go_unlim == 1
count if temp1 == 1 & go_lim == 1
count if temp1 == 1 & bond_type == "rev"
drop temp1
*another way to count this group
gunique seed_issuer if city_go_vote == 1 & city_rev_vote != 0
*577 issuers
list state if city_go_vote == 1 & city_rev_vote != 0 & temp1 != 1
br if state == "AR"
count if go_unlim == 1 & city_go_vote == 1 & city_rev_vote != 0
*12,347
count if rev == 1 & city_go_vote == 1 & city_rev_vote != 0

*no GO vote and no rev vote
gunique seed_issuer if city_go_vote == 0 & city_rev_vote == 0
count if city_go_vote == 0 & city_rev_vote == 0
count if city_go_vote == 0 & city_rev_vote == 0 & go_unlim == 1
gunique seed_issuer if city_go_vote == 0 & city_rev_vote == 0 & go_unlim == 1
*1,011 seed issuers; 45,027 obs
count if city_go_vote == 0 & city_rev_vote == 0 & go_lim == 1
count if city_go_vote == 0 & city_rev_vote == 0 & bond_type == "rev"

*Total UTGO vote and no vote sample:
*Vote: 1,173 issuers; 38,969 obs
*No vote: 1,011 issuers, 45,027 bonds
*Total: 2,184 issuers; 

*light purple: GO vote req varies within state
gen temp1 = 1 if inlist(state,"NV","KS","MN","IL","SC","VA")
replace temp1 = 1 if inlist(state,"PA", "NY","MD","DE","CT")
gunique seed_issuer if temp1 == 1
count if temp1 == 1
count if temp1 == 1 & go_unlim == 1
count if temp1 == 1 & go_lim == 1
count if temp1 == 1 & bond_type == "rev"
tab state if go_unlim == 1 & temp1 == 1
/*It's coming from MN, NY, CT and IL

      state |      Freq.     Percent        Cum.
------------+-----------------------------------
         CT |     14,995       14.93       14.93
         DE |        136        0.14       15.07
         IL |     12,388       12.34       27.40
         KS |      9,320        9.28       36.69
         MD |        947        0.94       37.63
         MN |     26,419       26.31       63.94
         NV |         99        0.10       64.04
         NY |     24,905       24.80       88.84
         PA |      7,153        7.12       95.96
         SC |        911        0.91       96.87
         VA |      3,144        3.13      100.00
------------+-----------------------------------
      Total |    100,417      100.00


*/
drop temp1


***Bring in indicator for matched to RavenPack***
*Note in original mapping, there are some dups by seed_issuer because there are multiple RP entity IDs that get matched
*This is fine, just after converting mapping from CSV to DTA, gen rp_match indicator and duplicates drop
mmerge seed_issuer_id using "$DATA\News\RP_Mergent_Mapping.dta", type(n:1) missing(nomatch)
/*
                 obs | 328230
                vars |    225  (including _merge)
         ------------+---------------------------------------------------------
              _merge |  90033  obs only in master data                (code==1)
                     |     29  obs only in using data                 (code==2)
                     | 238168  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
drop if _merge == 2
drop _merge

sort state seed_issuer year issue_id cusip
replace rp_match = 0 if rp_match == .

**Summary stats**
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
label var go_unlim "GO bond"

**Bond-level summary stats**
*gen temp var for having non-missing controls
gen hascontrols = 1 if offering_yield_tr != . & ln_amount_tr != . & ln_maturity_tr != .
eststo clear
eststo: estpost sum city_go_vote offering_yield_tr ln_amount_tr ln_maturity_tr callable sinkable insured rated ///
	state_go_vote state_ltgo_allowed ///
	state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	/* purp_broad_genpubimprov purp_broad_pubbldg purp_broad_transport ///
	purp_broad_educ purp_broad_health purp_broad_arts purp_broad_parksrec ///
	purp_broad_econdev	purp_broad_housing purp_broad_safety purp_broad_justice	///
	purp_broad_utilities purp_broad_wtrswr purp_broad_other */ ///
	if city_rev_vote == 0 & city_go_vote != . & go_unlim == 1 & hascontrols == 1 , d
esttab using "$DESCRIPT\Bondlevel\250329_bondlevel_sumstats.tex", replace ///
	title("Summary statistics") ///
	cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc)) min(fmt(%9.2fc)) p1(fmt(%9.2fc)) p50(fmt(%9.2fc)) p99(fmt(%9.2fc)) max(fmt(%10.2fc)) count(fmt(%9.0fc))") ///
	collabels("Mean" "Std" "Min" "p1" "Median""p99" "Max" "N") ///
	label booktabs nonum /*gaps*/ noobs compress nomtitle	

sum amount_tr if city_rev_vote == 0 & city_go_vote != . & go_unlim == 1 & hascontrols == 1
*560,104
sum maturity_mths_tr if city_rev_vote == 0 & city_go_vote != . & go_unlim == 1 & hascontrols == 1
*273 months

	
**# Bookmark #1
***New outputs***
*Look just at UTGO
*Use city_go_vote because it's the cleanest and easiest to explain
*Show all controls
*Flex no FEs or all FEs 
*Cluster by state or issuance

**Build up to specification**
eststo clear
eststo: qui reg offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated ///
	state_go_vote state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	,  vce(cluster state)
	estadd local timeFE "No"
	estadd local purposeFE "No"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated ///
	state_go_vote state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster state)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "State"	
eststo: qui reghdfe offering_yield_tr city_go_vote ln_amount_tr ln_maturity_tr callable sinkable insured rated ///
	state_go_vote state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien ///
	ln_gdp ln_pers_inc ln_percap_inc ln_emp ///
	if city_rev_vote == 0 & go_unlim == 1  ///
	, absorb(yrmonth purp_broad_id) vce(cluster issue_id)
	estadd local timeFE "YM"
	estadd local purposeFE "Yes"
	estadd local SE "Issue"		

esttab using "$RESULTS/250324_city_yield_UTGO.tex", replace t noconstant b(3) ///
	title("GO bond referendum requirements and offering yield") star(* .10 ** .05 *** .01) ///
	s(N r2_a timeFE purposeFE SE, fmt(%9.0fc 3) label ("N" "Adj. $ R^2$" "Time FE" "Purpose FE" "Cluster")) ///
	/*drop(ln_gdp ln_pers_inc ln_percap_inc ln_emp _cons)*/ label booktabs noobs nonotes 

**# Bookmark #2
***Purpose tests with UTGO only***
tab purp_broad if city_rev_vote == 0 & go_unlim == 1 
/*
  purp_broad |      Freq.     Percent        Cum.
-------------+-----------------------------------
        arts |      2,415        1.90        1.90
     econdev |        415        0.33        2.23
        educ |      2,985        2.35        4.58
genpubimprov |    100,486       79.06       83.64
      health |        268        0.21       83.85
     housing |        124        0.10       83.95
     justice |         39        0.03       83.98
       other |        709        0.56       84.54
    parksrec |      3,314        2.61       87.14
     pubbldg |      1,731        1.36       88.51
      safety |      2,740        2.16       90.66
   transport |      2,122        1.67       92.33
   utilities |      1,161        0.91       93.25
      wtrswr |      8,584        6.75      100.00
-------------+-----------------------------------
       Total |    127,093      100.00
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
*No association with likelihood of UTGO bond. In plain reg with go_unlim and city_go_vote, very negative and significant. But not with all the controls
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
	
	