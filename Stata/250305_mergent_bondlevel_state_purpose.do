*********************************
*Voting on bonds                *
*Create broader purpose category*
*Last updated: 03/05/25         *
*********************************

***Set up globals***
*global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"

**# Bookmark #1
***Start with bondlevel file that has state referendum requirements***
use "$MERGENT\Clean\250124_citycountyschool_cusiplevel_statereq.dta", clear

*bring in broader purpose classification
*Converted from Excel to Stata using StatTransfer, then did minimal variable name cleaning
mmerge use_proceeds using "$MERGENT\Clean\2025-01-25_bondpurpose_classify.dta", type(n:1) missing(nomatch)
/*
                 obs | 730461
                vars |    168  (including _merge)
         ------------+---------------------------------------------------------
              _merge |    175  obs only in master data                (code==1)
                     |      4  obs only in using data                 (code==2)
                     | 730282  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*br state seed_issuer year issue_description use_proceeds num_use_proceeds if _merge == 1
*fix manually
replace purp_broad = "educ" if use_proceeds == "CSED"
*make purpose other for NAs
replace purp_broad = "other" if use_proceeds == "NA"
*br state seed_issuer year issue_description use_proceeds num_use_proceeds if _merge == 2
*never used codes in sample: AIL (airlines), CMOH (CMO-backed housing), NPHG (new public housing), TUNN (tunnels)
drop if _merge == 2
br state seed_issuer year issue_description use_proceeds num_use_proceeds purp_broad

*Clean and make new vars for broader purpose variable
tab purp_broad
*16 categories
/*
  purp_broad |      Freq.     Percent        Cum.
-------------+-----------------------------------
        arts |      7,249        0.99        0.99
     econdev |      2,142        0.29        1.29
        educ |    322,094       44.09       45.38
       envir |        916        0.13       45.51
genpubimprov |    256,316       35.09       80.60
      health |      8,960        1.23       81.82
     housing |      1,760        0.24       82.06
     justice |      5,777        0.79       82.85
       other |      1,502        0.21       83.06
    parksrec |      7,693        1.05       84.11
     pension |         20        0.00       84.12
     pubbldg |     12,165        1.67       85.78
      safety |      5,923        0.81       86.59
   transport |     10,504        1.44       88.03
   utilities |     18,595        2.55       90.58
      wtrswr |     68,841        9.42      100.00
-------------+-----------------------------------
       Total |    730,457      100.00
*/
*pension and envir are so small, put that into other
replace purp_broad = "other" if inlist(purp_broad, "pension","envir")
tab purp_broad /*now 14 categories*/
/*
  purp_broad |      Freq.     Percent        Cum.
-------------+-----------------------------------
        arts |      7,249        0.99        0.99
     econdev |      2,142        0.29        1.29
        educ |    322,094       44.09       45.38
genpubimprov |    256,316       35.09       80.47
      health |      8,960        1.23       81.70
     housing |      1,760        0.24       81.94
     justice |      5,777        0.79       82.73
       other |      2,438        0.33       83.06
    parksrec |      7,693        1.05       84.12
     pubbldg |     12,165        1.67       85.78
      safety |      5,923        0.81       86.59
   transport |     10,504        1.44       88.03
   utilities |     18,595        2.55       90.58
      wtrswr |     68,841        9.42      100.00
-------------+-----------------------------------
       Total |    730,457      100.00
*/

gegen purp_broad_id = group(purp_broad)
label var purp_broad_id "Purpose ID"

*gen indicator var for each broad purpose
local temp arts econdev educ genpubimprov health housing justice other parksrec pubbldg safety transport utilities wtrswr
foreach x of local temp{
	gen purp_broad_`x' = 1 if purp_broad == "`x'"
	replace purp_broad_`x' = 0 if purp_broad_`x' == .
}

*does the broad purpose ever vary within an issuance?
gegen temp1 = min(purp_broad_id), by(issue_id)
gegen temp2 = max(purp_broad_id), by(issue_id)
count if temp1 != temp2
*336 where the purpose varies within issuance - very rare, but don't seem like data errors
*br state seed_issuer year issue_id issue_description purp_broad if temp1 != temp2

drop temp*

*for gegen, gen temp numeric ID per cusip
sort state seed_issuer year issue_id cusip
gegen cusip_id = group(cusip)

*for each issuer-year and purpose, gen # of bonds, amount for each bond 
local temp arts econdev educ genpubimprov health housing justice other parksrec pubbldg safety transport utilities wtrswr
foreach x of local temp{
	*# of bonds for issuer-year
	gegen `x'_nbonds = count(cusip_id) if purp_broad == "`x'", by(seed_issuer year)
	replace `x'_nbonds = 0 if `x'_nbonds == .
	*amount of $ raised for issuer-year
	gegen `x'_amt = sum(amount) if purp_broad == "`x'", by(seed_issuer year)
	replace `x'_amt = 0 if `x'_amt == .
	*gen ln of amount
	gen `x'_amt_ln = ln(1+`x'_amt)
}

*drop cusip numeric
drop cusip_id

*save file
save "$MERGENT\Clean\250305_citycountyschool_cusiplevel_statereq_purpose.dta", replace
