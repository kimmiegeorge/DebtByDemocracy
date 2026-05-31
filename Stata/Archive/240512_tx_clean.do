*********************************************
*Voting on bonds                            *
*Clean TX data for election-Mergent matching*
*Last updated 05/12/2024                    *  
*********************************************

***Define globals***
global MAIN "C:/Users/juneh/Dropbox (Personal)/Voting on Bonds"
global DATA "$MAIN/Data"
global TX "$DATA/TX"
global MERGENT "$DATA/Mergent"

**Data source: https://data.texas.gov/stories/s/Texas-Bond-Review-Board-Datasets/3wup-mcbk 
*Downloaded 05/11/2024; all raw files last updated 05/10/2024 except for debt outstanding file
*Bond-related data only goes back to 2014; debt outstanding data (taxable value, pop, etc) goes back to 2007; election data goes back to 1950s

***Get superset of issuer names from TX election and debt data***

**# Bookmark #1

**Start with election data**
*Convert csv to dta
import delimited "$TX/20240510_TX_local_election.csv", varn(1) clear
*save as dta
save "$TX/240510_TX_local_election.dta", replace
*save list of unique government names
gcollapse (count) temp1 = amount, by(governmentname governmenttype county)
drop temp1
*2,035 unique government names
tab governmenttype
/*
GovernmentT |
        ype |      Freq.     Percent        Cum.
------------+-----------------------------------
        CCD |         30        1.47        1.47
       CITY |        279       13.71       15.18
     COUNTY |         86        4.23       19.41
        HHD |         30        1.47       20.88
        ISD |        942       46.29       67.17
        OSD |         11        0.54       67.71
         WD |        657       32.29      100.00
------------+-----------------------------------
      Total |      2,035      100.00
*/

*For now, only focus on cities and counties. Dynamics for school districts are different
keep if inlist(governmenttype, "CITY", "COUNTY")
*365 obs

*look through by hand to see if obvious typos
replace governmentname = "Fairview" if governmentname == "Fairview (a)"
*save list
save "$TX/240510_TX_uniquegovt_election.dta", replace

**Now do issuance data**
*Convert csv to dta
import delimited "$TX/20240510_TX_local_issuance.csv", varn(1) clear
*make issuancename str# rather than strL for later merges
gen temp1 = issuancename
drop issuancename
rename temp1 issuancename
order issuancename, after(issuername)
*save as dta
save "$TX/240510_TX_local_issuance.dta", replace

/*gov name, issuer name, closing date does NOT uniquely identify. diff bonds can have same closing date
duplicates report governmentname issuername closingdate
*nope
duplicates tag governmentname issuername closingdate, gen(dup)
*gen gov identifier if there's a dup at any time
gegen temp1 = max(dup), by(governmentname)
br if temp1 > 0
*/
*does gov name, issuer name, closing date, issuance name uniquely identify?
duplicates report governmentname issuername issuancename
*yes

*recall no TX vote for revenue bond or refunding GO bond
tab pledgetype
/*
 PledgeType |      Freq.     Percent        Cum.
------------+-----------------------------------
         GO |     13,362       85.70       85.70
         LP |         15        0.10       85.80
        REV |      2,214       14.20      100.00
------------+-----------------------------------
      Total |     15,591      100.00
*/
tab issuepurpose if pledgetype == "GO"
/*
                  IssuePurpose |      Freq.     Percent        Cum.
-------------------------------+-----------------------------------
                      Commerce |         18        0.13        0.13
            ComputerTechnology |          7        0.05        0.19
           EconomicDevelopment |         29        0.22        0.40
EducationalFacilitiesEquipment |      2,130       15.94       16.34
                          Fire |         45        0.34       16.68
                GeneralPurpose |      1,962       14.68       31.37
                 HealthRelated |         38        0.28       31.65
                   HousingLand |          7        0.05       31.70
            PensionObligations |          8        0.06       31.76
                         Power |          6        0.04       31.81
              PrisonsDetention |         28        0.21       32.02
                  PublicSafety |        105        0.79       32.80
                    Recreation |        271        2.03       34.83
                        Refund |      4,454       33.33       68.16
             SelfInsuranceFund |          1        0.01       68.17
                    SolidWaste |         13        0.10       68.27
                      TollRoad |          2        0.01       68.28
                Transportation |        885        6.62       74.91
         UtilitySystemCombined |         90        0.67       75.58
                  WaterRelated |      3,263       24.42      100.00
-------------------------------+-----------------------------------
                         Total |     13,362      100.00
*/
*1/3 of the GO bonds are refunding

*save list of unique government names
gcollapse (count) temp1 = fiscalyearissuance, by(governmentname governmenttype issuername)
drop temp1
*2,998 obs

*is governmentname different from issuername?
gen temp1 = 1 if governmentname == issuername
*17 obs with differences
replace temp1 = 0 if temp1 == .
*if there's a difference for a governmentname, look at all entries for the governmentname
gegen temp2 = min(temp1), by(governmentname)
*br if temp2 == 0
*24 obs
*some of these differences are typos, but some look legitimately different
*did some googling on legitimate differences, seems like change in ownership over the years
*manually drop clear duplicates based on typos; want to keep the legitimate differences to get the correct match to Mergent over time
drop if governmentname == "Rio Grande City Grulla ISD" & issuername == "Rio Grande City ISD"
replace governmentname = "Reno" if governmentname == "Reno (b)"
*for Mergent match, use issuername

*focus on cities and counties
drop temp*
keep if inlist(governmenttype, "CITY", "COUNTY")
*911 obs
*this is more than the election list, probably b/c of revenue bonds and refunding GO bonds

*check for dups
duplicates tag governmentname, gen(dup)
gegen temp1 = max(dup), by(governmentname)
*br if temp1 > 0
*Harris County toll road, okay
drop temp* dup
*save
save "$TX/240510_TX_uniquegovt_issuance.dta", replace

**# Bookmark #2
/*Notes for name matching
- Election data: have government names
- Issuance data: have government and issuer names
- Ratings data: have different list of government and issuer names
- Debt outstanding data: have government names

- For the eventual test, sample will be restricted to those in Mergent and those with voting data
	- Want to make sure the names in Mergent have the best possible chance of finding a match in the TX election data

- Step 1: Check why Ratings data has more obs than Issuance data (done: b/c each row is a diff rating agency observation)
- Step 2: Depending on which list of issuers seems more "accurate," match government names to election data (done)
- Step 3: Isolate the issuer names of matched government names (done)
- Step 4: Match those issuer names to Mergent 
*/

**Step 1: Import ratings data and see why observations are different**
*See why ratings file has more observations than issuance file
*If ratings file only has bonds that are rated, would expect there to be fewer obs than issuance file
*Convert csv to dta
import delimited "$TX/20240510_TX_local_rating.csv", varn(1) clear
*make issuancename str# rather than strL for later merges
gen temp1 = issuancename
drop issuancename
rename temp1 issuancename
order issuancename, after(issuername)
*save as dta
save "$TX/240510_TX_local_rating.dta", replace

tab pledgetype
/*
 PledgeType |      Freq.     Percent        Cum.
------------+-----------------------------------
         GO |     15,799       88.10       88.10
         LP |         12        0.07       88.17
        REV |      2,122       11.83      100.00
------------+-----------------------------------
      Total |     17,933      100.00
*/
*fewer revenue, more GO than issuance file

/*does gov name, issuer name, issuancename uniquely identify?
duplicates report governmentname issuername issuancename
*nope, look into this
duplicates tag governmentname issuername issuancename, gen(dup)
*gen gov identifier if there's a dup at any time
gegen temp1 = max(dup), by(governmentname)
br if temp1 > 0
*/
*governmentname issuername issuancename doesn't uniquely identify because some have multiple ratings and each row is a rating
*now makes sense why ratings file has more obs than issuance file
*given this, can use issuance file obs if they're all matched into ratings

*merge with issuance file to see the difference
mmerge governmentname issuername issuancename using "$TX/240510_TX_local_issuance.dta", ///
	type(n:1) missing(nomatch)
*everything is matched, hooray! So can just use list from issuance file

**# Bookmark #3
**Step 2: Merge election data government names with issuance file government names**
use "$TX/240510_TX_uniquegovt_election.dta", clear
mmerge governmentname using "$TX/240510_TX_uniquegovt_issuance.dta", ///
	type(1:n) missing(nomatch)
/*
                 obs |    937
                vars |      8  (including _merge)
         ------------+---------------------------------------------------------
              _merge |     26  obs only in master data                (code==1)
                     |    571  obs only in using data                 (code==2)
                     |    340  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*could be only in master if the election data is from pre-2014
*thus want to keep names that are only in master
*a lot are only in using; it's possible these are munis that only do refunding or revenue bonds, so don't need votes. these would still be in Mergent though and would be good to match as all the rest get matched
*so basically, want a superset list of these names
sort governmentname governmenttype issuername

*(1) want to gen new issuername for Mergent match that = issuername if _merge == 3
gen temp1 = issuername if _merge == 3
sort _merge governmentname
*(2) if _merge == 1, want to try to match governmentname to Mergent still in case pre-2014
replace temp1 = governmentname if _merge == 1
*(3) if _merge == 2, want to match issuername to Mergent in case useful later even if no new-money GO bonds
replace temp1 = issuername if _merge == 2
*is governmenttype always filled?
count if governmenttype == ""
rename temp1 muni_formatch

*check for dups
duplicates report governmentname issuername muni_formatch
*no dups, good
*check for dups by muni_formatch
duplicates report muni_formatch
*incredibly, no dups

*gen numeric id for muni_formatch
gegen muni_id_formatch = group(muni_formatch)
*save this file to create crosswalk after Mergent matching
save "$TX/240512_TX_uniquegovt_election_issuance.dta", replace

*just keep certain vars for fuzzy matching
order muni_formatch muni_id_formatch, before(governmenttype)
keep muni_formatch governmenttype _merge muni_id_formatch
rename governmenttype govtype

*save
save "$TX/240512_TXBRB_uniquegovt_formatch.dta", replace
export delimited using "$TX/240512_TXBRB_uniquegovt_formatch.csv", replace

**# Bookmark #4
***Mergent data***
*For now, use data from other project just for TX:\Voting on Bonds\Data\Mergent\TX_mergent_2000_2020
use "$MERGENT/TX_mergent_2000_2020.dta", clear
*314,288 obs
*only want to keep cities and counties for now
tab issuer_type
/*
issuer_type |      Freq.     Percent        Cum.
------------+-----------------------------------
       CITY |     35,891       62.20       62.20
     COUNTY |     21,564       37.37       99.58
      STATE |        244        0.42      100.00
------------+-----------------------------------
      Total |     57,699      100.00
*/
*many issuer_types are missing
*try to do short-hand with issuer name
count if issuer_long_name == ""
*0 missing
count if issuer_short_name == ""
*0 missing
*br issue_id year offering_date issuer_short_name issuer_long_name issue_description
count if ISSUER_ID == .
*often missing
*drop and gen new id
drop ISSUER_ID
gegen issuer_id = group(issuer_long_name)

*Exclude: school districts, municipal utility districts (MUDs)
*gen temp var for what to keep
*IGNORE issuer_type because it is often wrong
gen temp1 = 1 if strpos(issuer_long_name,"INDPT SCH") > 0
replace temp1 = 1 if strpos(issuer_long_name,"MUN UTIL") > 0
count if temp1 == 1
*177,179
replace temp1 = 1 if strpos(issuer_long_name,"MUN DIST") > 0
*get water districts, airport, colleges, etc
replace temp1 = 1 if strpos(issuer_long_name,"SYS REV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"COLLEGE DIST") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"REV") > 0 & temp1 == .
count if temp1 == 1
*235,704 out of 314,288 (75%)
*br issue_id year offering_date issuer_short_name issuer_long_name issue_description if temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"WTR AUTH") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"DIST") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"HOSP") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"CTR") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"CAMPUS") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"CMNTY") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"HEALTH FAC DEV") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"SALES TAX") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"DEV CORP") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"TAX INCREMENT") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"ARPT") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"DEPT ED") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"POLLUTION CTL") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"UNIVERSITY TEX") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"AUTH") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"WTR SYS") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"PUB UTIL") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"HSG CORP") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"USE TAX") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"FIN CORP") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"CORP STUDENT") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"UNIV FD") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"TEXAS ST") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"MUN GAS") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"UNIV SPL") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"SPL ASSMT") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"SPL OBLIG") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"OCCUPANCY TAX") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"CUSTODIAL ACCOUNT") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"COMMUNITY MHMR") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"SCHS") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"HEALTHCARE") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"LONE STAR COLLEGE SYS TEX") > 0 & temp1 == .
replace temp1 = 1 if strpos(issuer_long_name,"SOUTH TEXAS COLLEGE TEX") > 0 & temp1 == .

count if temp1 == .
*~48,000
keep if temp1 == .
drop temp*

*collapse to issuer-level and only keep certain vars
gcollapse (min) min_yr = year, by(issuer_id issuer_long_name)
*555 issuers

*make version of issuer_long_name that doesn't have "TEX" in it for match
use "$MERGENT/TX_mergent_uniquegovt_formatch.dta", clear
gen temp1 = strlen(issuer_long_name)
gen temp2 = strpos(issuer_long_name," TEX")
gen temp3 = substr(issuer_long_name,1,temp2)
*br if temp3 == ""
drop if issuer_long_name == "TEXAS TRANSN COMMN"
replace temp3 = "WALLER COUNTY" if issuer_long_name == "WALLER COUNTY"
rename temp3 issuer_formatch
drop temp*
order issuer_formatch, before(issuer_long_name)

*save
save "$MERGENT/TX_mergent_uniquegovt_formatch.dta", replace
export delimited using "$MERGENT/TX_mergent_uniquegovt_formatch.csv", replace

