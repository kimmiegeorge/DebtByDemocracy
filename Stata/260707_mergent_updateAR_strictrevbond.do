**************************
*Voting on bonds         *
*Make two updates*
*Last updated: 07/07/26  *
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

/*
- Two updates: 
	- Switch Arkansas revenue bond to "None"
	- Only classify as revenue bond if security_code == G and source of repayment == G. This excludes sales tax revenue bonds
- Make these updates at the bond-level and issuer-level
*/

**# Bookmark #1
**Start with latest bond-level**
use "$MERGENT\Clean\260610_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

*Make Arkansas change to no rev vote
replace city_rev_vote = 0 if state == "AR"

*Change revenue bond type classification
tab security_code if bond_type == "rev"
/*
security_co |
         de |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |      7,908        8.93        8.93
          B |        210        0.24        9.17
          C |      2,133        2.41       11.58
          G |     66,552       75.15       86.73
          H |      5,454        6.16       92.89
          I |      1,219        1.38       94.26
          J |        290        0.33       94.59
          M |        121        0.14       94.73
          N |      3,721        4.20       98.93
          P |         20        0.02       98.95
          Q |        471        0.53       99.48
          R |        457        0.52      100.00
------------+-----------------------------------
      Total |     88,556      100.00
*/
tab source_of_repayment if bond_type == "rev"
/*
source_of_r |
   epayment |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |      8,099       15.26       15.26
          D |         15        0.03       15.28
          G |     44,973       84.72      100.00
------------+-----------------------------------
      Total |     53,087      100.00

*/
tab source_of_repayment if bond_type == "rev" & security_code == "G"
/*
source_of_r |
   epayment |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |        119        0.32        0.32
          D |         15        0.04        0.36
          G |     37,115       99.64      100.00
------------+-----------------------------------
      Total |     37,249      100.00

*/

gen bond_type_new = "rev" if security_code == "G" & source_of_repayment == "G"
replace bond_type_new = "go" if bond_type == "go" & bond_type_new == ""
tab bond_type_new
*Around 50,000 bonds are no longer classified. These will mostly be the sales tax revenue bonds
gen rev_new = 1 if security_code == "G" & source_of_repayment == "G"
replace rev_new = 0 if bond_type_new == "go"

drop bond_type rev
rename (bond_type_new rev_new) (bond_type rev)
order bond_type, after(issue_id)
order rev, after(go_lim)

*save bond-level file
save "$MERGENT\Clean\260707_city_cusiplevel_statereq_purpose_yieldspread.dta", replace


**Make new issuer-level yield spread **

*Remove the sales tax revenue bonds from this calculation

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
save "$MERGENT\Clean\260610_issuers_yieldspread.dta", replace

**# Bookmark #1

**Make a new issuer-level file. Need to start with city-county-school to get debt by other entities**

use "$MERGENT\Clean\250605_citycountyschool_cusiplevel_statereq_purpose.dta", clear
drop if state == "HI"

*Make 250827 and 251027 state law fixes to this. Fix AR using the 260611 election requirements file

*Rename old city_go_vote and city_rev_vote
rename (city_go_vote city_rev_vote) (city_go_vote_old city_rev_vote_old)

*Merge in updated classification
mmerge state using "$DATA\Bond Elections\260611_election_requirements_by_state.dta", ///
	type(n:1) missing(nomatch)
*all matched except Hawaii
drop if _merge == 2
drop _merge

*Drop old classifications, move in new ones
drop city_go_vote_old city_rev_vote_old
order city_go_vote city_rev_vote, after(bond_type)

*Drop NH bond banks
drop if seed_issuer == "NEW HAMPSHIRE MUN BD BK"
*403 bonds dropped

*Fix a couple seed issuers:
*Londonderry
replace seed_issuer = "LONDONDERRY N H" if strpos(issuer_long_name,"LONDONDERRY") > 0 & state == "NH"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "LONDONDERRY N H"

*Manchester
replace seed_issuer = "MANCHESTER N H" if strpos(issuer_long_name,"MANCHESTER N H") > 0 & state == "NH"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "MANCHESTER N H"

*Rochester
replace seed_issuer = "ROCHESTER N H" if strpos(issuer_long_name,"ROCHESTER N H") > 0 & state == "NH"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "ROCHESTER N H"

*Identify and drop NH towns: 
gen nh_city = 0 if state == "NH"
local temp BERLIN CLAREMONT CONCORD DOVER FRANKLIN KEENE LACONIA LEBANON MANCHESTER NASHUA PORTSMOUTH ROCHESTER SOMERSWORTH
foreach x of local temp{
	replace nh_city = 1 if strpos(seed_issuer,"`x'") > 0 & state == "NH"
}
count if nh_city == 0 & city == 1
drop if nh_city == 0 & city == 1

*Implement FIPS cleaning above
replace fips = "01071" if seed_issuer == "SCOTTSBORO ALA"
replace seed_issuer = "CAMPBELL CALIF" if seed_issuer == "BELL CALIF" & issuer_long_name == "CAMPBELL CALIF"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "CAMPBELL CALIF"
replace fips = "08059" if seed_issuer == "GOLDEN COLO"
replace seed_issuer = "MANCHESTER CONN" if seed_issuer == "CHESTER CONN" & issuer_long_name == "MANCHESTER CONN"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "MANCHESTER CONN"
replace seed_issuer = "NEW HARTFORD CONN" if seed_issuer == "HARTFORD CONN" & issuer_long_name == "NEW HARTFORD CONN"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "NEW HARTFORD CONN"
replace seed_issuer = "NEW MILFORD CONN" if seed_issuer == "MILFORD CONN" & issuer_long_name == "NEW MILFORD CONN"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "NEW MILFORD CONN"
replace fips = "12071" if seed_issuer == "CAPE CORAL FLA"
replace fips = "12011" if seed_issuer == "HOLLYWOOD FLA"
replace fips = "12011" if seed_issuer == "OAKLAND PARK FLA"
replace fips = "12011" if seed_issuer == "PLANTATION FLA"
replace fips = "12011" if seed_issuer == "POMPANO BEACH FLA"
replace fips = "12115" if seed_issuer == "VENICE FLA"
replace fips = "12095" if seed_issuer == "WINTER PARK FLA"
replace fips = "13121" if seed_issuer == "UNION CITY GA"
replace fips = "19013" if seed_issuer == "CEDAR FALLS IOWA"
replace fips = "19113" if seed_issuer == "CEDAR RAPIDS IOWA"
replace fips = "19153" if seed_issuer == "DES MOINES IOWA"
replace fips = "19031" if seed_issuer == "DURANT IOWA"
replace fips = "19069" if seed_issuer == "HAMPTON IOWA"
replace fips = "19103" if seed_issuer == "IOWA CITY IOWA"
replace fips = "19083" if seed_issuer == "IOWA FALLS IOWA"
replace fips = "19001" if seed_issuer == "STUART IOWA"
*Note that Stuart IOWA is split down the middle between two fips codes. I chose one at random
replace fips = "19079" if seed_issuer == "WEBSTER CITY IOWA"
replace fips = "16001" if seed_issuer == "BOISE CITY IDAHO"
replace fips = "17097" if seed_issuer == "BARRINGTON ILL"
*Barrington is split between lake and cook counties
replace fips = "17031" if seed_issuer == "BERKELEY ILL"
replace seed_issuer = "WESTCHESTER ILL" if seed_issuer == "CHESTER ILL" & issuer_long_name == "WESTCHESTER ILL"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "WESTCHESTER ILL"
replace fips = "17031" if seed_issuer == "CHICAGO ILL"
replace seed_issuer = "MC HENRY ILL" if seed_issuer == "HENRY ILL" & issuer_long_name == "MC HENRY ILL"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "MC HENRY ILL"
replace seed_issuer = "EAST PEORIA ILL" if seed_issuer == "PEORIA ILL" & issuer_long_name == "EAST PEORIA ILL"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "EAST PEORIA ILL"
replace seed_issuer = "NORTH RIVERSIDE ILL" if seed_issuer == "RIVERSIDE ILL" & issuer_long_name == "NORTH RIVERSIDE ILL"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "NORTH RIVERSIDE ILL"
replace seed_issuer = "MOUNT ZION ILL" if seed_issuer == "ZION ILL" & issuer_long_name == "MOUNT ZION ILL"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "MOUNT ZION ILL"
replace fips = "18063" if seed_issuer == "BROWNSBURG IND"
replace fips = "18149" if seed_issuer == "KNOX IND"
replace fips = "18089" if seed_issuer == "LOWELL IND"
replace fips = "18053" if seed_issuer == "MARION IND"
replace fips = "18109" if seed_issuer == "MARTINSVILLE IND"
replace fips = "18091" if seed_issuer == "MICHIGAN CITY IND"
replace fips = "18141" if seed_issuer == "NEW CARLISLE IND"
replace fips = "18141" if seed_issuer == "NORTH LIBERTY IND"
replace fips = "20209" if seed_issuer == "EDWARDSVILLE KANS"
replace seed_issuer = "ELLINWOOD KANS" if seed_issuer == "LINWOOD KANS" & issuer_long_name == "ELLINWOOD KANS"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "ELLINWOOD KANS"
replace fips = "20173" if seed_issuer == "PARK CITY KANS"
replace fips = "20173" if seed_issuer == "WICHITA KANS"
replace fips = "21047" if seed_issuer == "HOPKINSVILLE KY"
replace fips = "21059" if seed_issuer == "OWENSBORO KY"
*Drop port new orleans, which is a port authority
drop if inlist(issuer_long_name,"PORT NEW ORLEANS LA BRD COMMRS PORT FAC REV","PORT NEW ORLEANS LA BRD COMMRS REV")
replace seed_issuer = "NEW BEDFORD MASS" if seed_issuer == "BEDFORD MASS" & issuer_long_name == "NEW BEDFORD MASS"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "NEW BEDFORD MASS"
replace seed_issuer = "NORTH ANDOVER MASS" if seed_issuer == "DOVER MASS" & issuer_long_name == "NORTH ANDOVER MASS"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "NORTH ANDOVER MASS"
replace seed_issuer = "HAMILTON MASS" if seed_issuer == "MILTON MASS" & issuer_long_name == "HAMILTON MASS"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "HAMILTON MASS"
*Drop steamship authority
drop if issuer_long_name == "WOODS HOLE MARTHAS VINEYARD & NANTUCKET MASS SS BDS"
replace seed_issuer = "BOXFORD MASS" if seed_issuer == "OXFORD MASS" & issuer_long_name == "BOXFORD MASS"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "BOXFORD MASS"
replace seed_issuer = "LITTLE CANADA MINN" if seed_issuer == "ADA MINN" & issuer_long_name == "LITTLE CANADA MINN"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "LITTLE CANADA MINN"
replace seed_issuer = "LAKE CRYSTAL MINN" if seed_issuer == "CRYSTAL MINN" & issuer_long_name == "LAKE CRYSTAL MINN"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "LAKE CRYSTAL MINN"
replace fips = "27013" if seed_issuer == "LAKE CRYSTAL MINN"
replace seed_issuer = "FOREST LAKE MINN" if seed_issuer == "FOREST LA" & issuer_long_name == "FOREST LAKE TOWN MINN"
replace seed_issuer = "FOREST LAKE MINN" if seed_issuer == "LAKE CITY MINN" & issuer_long_name == "FOREST LAKE CITY MINN"
replace fips = "27163" if seed_issuer == "FOREST LAKE MINN"
replace seed_issuer_id = 15676 if seed_issuer == "FOREST LAKE MINN"
replace seed_issuer = "GREEN ISLE MINN" if seed_issuer == "ISLE MINN" & issuer_long_name == "GREEN ISLE MINN"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "GREEN ISLE MINN"
replace seed_issuer = "GREEN LAKE WIS" if seed_issuer == "GREEN LA" & issuer_long_name == "GREEN LAKE WIS"
replace fips = "55047" if seed_issuer == "GREEN LAKE WIS"
replace seed_issuer = "NORTH MANKATO MINN" if seed_issuer == "MANKATO MINN" & issuer_long_name == "NORTH MANKATO MINN"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "NORTH MANKATO MINN"
replace seed_issuer = "ST STEPHEN MINN" if seed_issuer == "STEPHEN MINN" & issuer_long_name == "ST STEPHEN MINN"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "ST STEPHEN MINN"
replace seed_issuer = "NORTH KANSAS CITY MO" if seed_issuer == "KANSAS CITY MO" & issuer_long_name == "NORTH KANSAS CITY MO HOSP REV"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "NORTH KANSAS CITY MO"
drop if issuer_long_name == "OSAGE SCH LAKE OZARK MO"
replace seed_issuer = "DORCHESTER NEB" if seed_issuer == "CHESTER NEB" & issuer_long_name == "DORCHESTER NEB ELEC SYS REV"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "DORCHESTER NEB"
replace seed_issuer = "MILFORD NEB" if seed_issuer == "ORD NEB" & issuer_long_name == "MILFORD NEB"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "MILFORD NEB"
replace seed_issuer = "OXFORD NEB" if seed_issuer == "ORD NEB" & issuer_long_name == "OXFORD NEB COMB UTIL REV"
replace seed_issuer_id = seed_issuer_id+0.7 if seed_issuer == "OXFORD NEB"
replace seed_issuer = "CRAWFORD NEB" if seed_issuer == "ORD NEB" & issuer_long_name == "CRAWFORD NEB"
replace seed_issuer_id = seed_issuer_id+0.7 if seed_issuer == "CRAWFORD NEB"
replace seed_issuer = "MANCHESTER TWP N J" if seed_issuer == "CHESTER TWP N J" & issuer_long_name == "MANCHESTER TWP N J"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "MANCHESTER TWP N J"
replace seed_issuer = "ANDOVER TWP N J" if seed_issuer == "DOVER TWP N J" & issuer_long_name == "ANDOVER TWP N J"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "ANDOVER TWP N J"
replace seed_issuer = "EAST AURORA N Y" if seed_issuer == "AURORA N Y" & issuer_long_name == "EAST AURORA N Y"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "EAST AURORA N Y"
replace seed_issuer = "EAST ROCHESTER N Y" if seed_issuer == "CHESTER N Y" & issuer_long_name == "EAST ROCHESTER N Y"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "EAST ROCHESTER N Y"
replace seed_issuer = "EASTCHESTER N Y" if seed_issuer == "CHESTER N Y" & issuer_long_name == "EASTCHESTER N Y"
replace seed_issuer_id = seed_issuer_id+0.7 if seed_issuer == "EASTCHESTER N Y"
replace seed_issuer = "MANCHESTER N Y" if seed_issuer == "CHESTER N Y" & issuer_long_name == "MANCHESTER N Y"
replace seed_issuer_id = seed_issuer_id+0.8 if seed_issuer == "MANCHESTER N Y"
replace seed_issuer = "HASTINGS ON HUDSON N Y" if seed_issuer == "HUDSON N Y" & issuer_long_name == "HASTINGS ON HUDSON N Y"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "HASTINGS ON HUDSON N Y"
replace seed_issuer = "CASTLETON-ON-HUDSON N Y" if seed_issuer == "HUDSON N Y" & issuer_long_name == "CASTLETON-ON-HUDSON N Y"
replace seed_issuer_id = seed_issuer_id+0.6 if seed_issuer == "CASTLETON-ON-HUDSON N Y"
replace seed_issuer = "CORNWALL-ON-HUDSON N Y" if seed_issuer == "HUDSON N Y" & issuer_long_name == "CORNWALL-ON-HUDSON N Y"
replace seed_issuer_id = seed_issuer_id+0.7 if seed_issuer == "CORNWALL-ON-HUDSON N Y"
replace seed_issuer = "CROTON ON HUDSON N Y" if seed_issuer == "HUDSON N Y" & issuer_long_name == "CROTON ON HUDSON N Y"
replace seed_issuer_id = seed_issuer_id+0.8 if seed_issuer == "CROTON ON HUDSON N Y"
replace seed_issuer = "NORTH TONAWANDA N Y" if seed_issuer == "TONAWANDA N Y" & issuer_long_name == "NORTH TONAWANDA N Y"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "NORTH TONAWANDA N Y"
replace seed_issuer = "NEW CARLISLE OHIO" if seed_issuer == "CARLISLE OHIO" & issuer_long_name == "NEW CARLISLE OHIO"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "NEW CARLISLE OHIO"
replace seed_issuer = "WEST CHESTER TWP OHIO" if seed_issuer == "CHESTER TWP OHIO" & issuer_long_name == "WEST CHESTER TWP OHIO"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "WEST CHESTER TWP OHIO"
replace seed_issuer = "BOWLING GREEN OHIO" if seed_issuer == "GREEN OHIO" & issuer_long_name == "BOWLING GREEN OHIO"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "BOWLING GREEN OHIO"
drop if issuer_long_name == "PORT PORTLAND ORE ARPT REV"m
replace seed_issuer = "NORTH LONDONDERRY TWP PA" if seed_issuer == "DERRY TWP PA" & issuer_long_name == "NORTH LONDONDERRY TWP PA"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "NORTH LONDONDERRY TWP PA"
replace seed_issuer = "NORTHAMPTON TWP PA" if seed_issuer == "HAMPTON TWP PA" & issuer_long_name == "NORTHAMPTON TWP PA"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "NORTHAMPTON TWP PA"
replace seed_issuer = "LOWER SOUTHAMPTON TWP PA" if seed_issuer == "HAMPTON TWP PA" & issuer_long_name == "LOWER SOUTHAMPTON TWP PA"
replace seed_issuer_id = seed_issuer_id+0.6 if seed_issuer == "LOWER SOUTHAMPTON TWP PA"
replace seed_issuer = "WEST MANHEIM TWP PA" if seed_issuer == "MANHEIM TWP PA" & issuer_long_name == "WEST MANHEIM TWP PA"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "WEST MANHEIM TWP PA"
replace seed_issuer = "MIDDLE SMITHFIELD TWP PA" if seed_issuer == "SMITHFIELD TWP PA" & issuer_long_name == "MIDDLE SMITHFIELD TWP PA"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "MIDDLE SMITHFIELD TWP PA"
replace seed_issuer = "WEST COLUMBIA S C" if seed_issuer == "COLUMBIA S C" & issuer_long_name == "WEST COLUMBIA S C WTR & SWR REV"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "WEST COLUMBIA S C"
replace seed_issuer = "NORTH MYRTLE BEACH S C" if seed_issuer == "MYRTLE BEACH S C" & issuer_long_name == "NORTH MYRTLE BEACH S C"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "NORTH MYRTLE BEACH S C"
replace seed_issuer = "MC ALLEN TEX" if seed_issuer == "ALLEN TEX" & issuer_long_name == "MC ALLEN TEX"
replace seed_issuer = "MC ALLEN TEX" if seed_issuer == "ALLEN TEX" & issuer_long_name == "MC ALLEN TEX INTL TOLL BRDG REV"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "MC ALLEN TEX"
replace seed_issuer = "COPPER CANYON TEX" if seed_issuer == "CANYON TEX" & issuer_long_name == "COPPER CANYON TEX"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "COPPER CANYON TEX"
replace seed_issuer = "NORTH RICHLAND HILLS TEX" if seed_issuer == "RICHLAND HILLS TEX" & issuer_long_name == "NORTH RICHLAND HILLS TEX"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "NORTH RICHLAND HILLS TEX"
replace seed_issuer = "EAST WENATCHEE WASH" if seed_issuer == "WENATCHEE WASH" & issuer_long_name == "EAST WENATCHEE WASH"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "EAST WENATCHEE WASH"
replace seed_issuer = "NEW BERLIN WIS" if seed_issuer == "BERLIN WIS" & issuer_long_name == "NEW BERLIN WIS"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "NEW BERLIN WIS"
replace seed_issuer = "BLACK RIVER FALLS WIS" if seed_issuer == "RIVER FALLS WIS" & issuer_long_name == "BLACK RIVER FALLS WIS"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "BLACK RIVER FALLS WIS"

replace fips = "24510" if seed_issuer == "BALTIMORE MD"
replace fips = "26043" if seed_issuer == "NORWAY MICH"
replace fips = "27099" if seed_issuer == "ADAMS MINN"
replace fips = "27157" if seed_issuer == "LAKE CITY MINN"
replace fips = "27037" if seed_issuer == "LAKEVILLE MINN"
replace fips = "27049" if seed_issuer == "PINE ISLAND MINN"
replace fips = "27053" if seed_issuer == "ST ANTHONY MINN"
replace fips = "27053" if seed_issuer == "ST LOUIS PARK MINN"
replace fips = "27163" if seed_issuer == "STILLWATER MINN"
replace fips = "29189" if seed_issuer == "CLAYTON MO"
replace fips = "29037" if seed_issuer == "RAYMORE MO"
replace fips = "29021" if seed_issuer == "ST JOSEPH MO"
replace fips = "29183" if seed_issuer == "ST PETERS MO"
replace fips = "28089" if seed_issuer == "CANTON MISS"
*CARY N C spans two counties; picked one at random
replace fips = "37087" if seed_issuer == "CARY N C"
replace fips = "37135" if seed_issuer == "HILLSBOROUGH N C"
replace fips = "37097" if seed_issuer == "MOORESVILLE N C"
drop if seed_issuer == "UNIVERSITY N C"
replace fips = "31109" if seed_issuer == "LINCOLN NEB"
replace fips = "35103" if seed_issuer == "LAS CRUCES N MEX"
replace fips = "36061" if seed_issuer == "NEW YORK N Y"
replace fips = "39113" if seed_issuer == "CENTERVILLE OHIO"
replace fips = "16920" if seed_issuer == "CRANBERRY TWP PA"
replace fips = "44009" if seed_issuer == "NARRAGANSETT R I"
replace fips = "46011" if seed_issuer == "BROOKINGS S D"
replace fips = "47103" if seed_issuer == "FAYETTEVILLE TENN"
replace fips = "47187" if seed_issuer == "FRANKLIN TENN"
replace fips = "47179" if seed_issuer == "JOHNSON CITY TENN"
replace fips = "48215" if seed_issuer == "MC ALLEN TEX"
replace fips = "48453" if seed_issuer == "AUSTIN TEX"
replace fips = "48061" if seed_issuer == "BROWNSVILLE TEX"
replace fips = "48491" if seed_issuer == "CEDAR PARK TEX"
replace fips = "48041" if seed_issuer == "COLLEGE STATION TEX"
replace fips = "48439" if seed_issuer == "FORT WORTH TEX"
drop if issuer_long_name == "SERVICE CTR RELOCATION INC FORT WORTH TEX LEASE REV"
replace fips = "48491" if seed_issuer == "GEORGETOWN TEX"
replace fips = "48471" if seed_issuer == "HUNTSVILLE TEX"
replace fips = "48085" if seed_issuer == "MC KINNEY TEX"
replace fips = "51550" if seed_issuer == "CHESAPEAKE VA"
replace fips = "51670" if seed_issuer == "HOPEWELL VA"
replace fips = "51810" if seed_issuer == "VIRGINIA BEACH VA"
drop if issuer_long_name == "PORT PASCO WASH"
replace fips = "53031" if seed_issuer == "PORT TOWNSEND WASH"
drop if issuer_long_name == "PORT SEATTLE WASH"
drop if issuer_long_name == "PORT SUNNYSIDE WASH"
replace fips = "55025" if seed_issuer == "DE FOREST WIS"
replace fips = "55151" if seed_issuer == "GERMANTOWN WIS"
replace fips = "55079" if seed_issuer == "GREENDALE WIS"
replace fips = "55109" if seed_issuer == "NEW RICHMOND WIS"
replace fips = "55021" if seed_issuer == "PORTAGE WIS"
*WATERTOWN WIS spans 2 counties, picked one at random
replace fips = "55055" if seed_issuer == "WATERTOWN WIS"
replace fips = "55073" if seed_issuer == "WAUSAU WIS"

*other fips fixing
replace fips = "51610" if seed_issuer == "FALLS CHURCH VA"
replace fips = "42019" if seed_issuer == "CRANBERRY TWP PA"
replace fips = "51520" if seed_issuer == "BRISTOL VA"
replace fips = "51820" if seed_issuer == "WAYNESBORO VA"
replace fips = "51121" if seed_issuer == "BLACKSBURG VA"
replace fips = "35013" if seed_issuer == "LAS CRUCES N MEX"
replace fips = "51735" if seed_issuer == "POQUOSON VA"
replace fips = "51840" if seed_issuer == "WINCHESTER VA"
replace seed_issuer = "MANASSAS PARK VA" if issuer_long_name == "MANASSAS PARK VA"
replace seed_issuer_id = seed_issuer_id+0.5 if seed_issuer == "MANASSAS PARK VA"
replace fips = "51685" if seed_issuer == "MANASSAS PARK VA"
replace fips = "55131" if seed_issuer == "GERMANTOWN WIS"
replace fips = "51059" if seed_issuer == "HERNDON VA"
replace fips = "51059" if seed_issuer == "FAIRFAX VA"
replace fips = "51059" if seed_issuer == "VIENNA VA"
replace fips = "51660" if seed_issuer == "HARRISONBURG VA"
replace fips = "51161" if seed_issuer == "SALEM VA"
replace fips = "51161" if seed_issuer == "ROANOKE VA"
replace fips = "51069" if seed_issuer == "FREDERICKSBURG VA"
replace fips = "51570" if seed_issuer == "COLONIAL HEIGHTS VA"
replace fips = "51680" if seed_issuer == "LYNCHBURG VA"
replace fips = "51683" if seed_issuer == "MANASSAS VA"
replace fips = "51590" if seed_issuer == "DANVILLE VA"

replace fips = "09007" if seed_issuer == "CHESTER CONN"
replace fips = "25021" if seed_issuer == "DOVER MASS"
replace fips = "27053" if seed_issuer == "CRYSTAL MINN"
replace fips = "27095" if seed_issuer == "ISLE MINN"
replace fips = "31175" if seed_issuer == "ORD NEB"
replace fips = "36071" if seed_issuer == "CHESTER N Y"
replace fips = "39153" if seed_issuer == "GREEN OHIO"
replace fips = "48085" if seed_issuer == "ALLEN TEX"
replace fips = "48439" if seed_issuer == "RICHLAND HILLS TEX"
replace fips = "53021" if seed_issuer == "PASCO WASH"
replace fips = "53033" if seed_issuer == "SEATTLE WASH"
replace fips = "55047" if seed_issuer == "BERLIN WIS"

*gen var for total debt raised within a county 2000-2020
tab year
gegen county_debt = sum(amount), by(fips)
*gen additional vars for total UTGO debt, LTGO debt, and REV debt raised in a county
gegen county_utgo = sum(amount) if go_unlim == 1, by(fips)
gegen county_ltgo = sum(amount) if go_lim == 1, by(fips)
gegen county_rev = sum(amount) if rev == 1, by(fips)

*make lns
local temp debt utgo ltgo rev
foreach x of local temp{
	replace county_`x' = 0 if county_`x' == .
	gen ln_county_`x' = ln(1+county_`x')
}

*then drop to cities only
keep if issuer_type == "city"	

*gen total amounts by cities
gegen city_debt = sum(amount), by(seed_issuer)
gegen city_utgo = sum(amount) if go_unlim == 1, by(seed_issuer)
gegen city_ltgo = sum(amount) if go_lim == 1, by(seed_issuer)
gegen city_rev = sum(amount) if rev == 1, by(seed_issuer)
*make lns
local temp debt utgo ltgo rev
foreach x of local temp{
	replace city_`x' = 0 if city_`x' == .
	gen ln_city_`x' = ln(1+city_`x')
}

*for collapse, don't include county and state demos for now
*don't want the county/state demos to be weighted based on # or timing of issuances
*merge in beginning-period county/state demos separately after collapse

*collapse to issuer level
gcollapse (max) county_debt county_utgo county_ltgo county_rev ln_county_debt ///
	ln_county_utgo ln_county_ltgo ln_county_rev city_debt city_utgo city_ltgo city_rev ///
	ln_city_debt ln_city_utgo ln_city_ltgo ln_city_rev ///
	, by(seed_issuer seed_issuer_id fips state state_name city_go_vote city_rev_vote state_go_vote state_utgo_allowed state_ltgo_allowed state_fullfaith state_sep_debtservice_levy state_sep_pledgerev state_statutorylien)

sort state seed_issuer

duplicates tag seed_issuer, gen(dup)
tab dup
drop dup
*no dups

*make LTGO, UTGO, REV percentages
gen frac_utgo = city_utgo / city_debt
gen frac_ltgo = city_ltgo / city_debt
gen frac_rev = city_rev / city_debt

*make indicators for categories of states in the map
*only want to compare control (no vote) with UTGO vote only OR all GO vote only
gen control = 1 if city_go_vote == 0 & city_rev_vote == 0
gen utgo_only = 1 if inlist(state, "WA", "MI", "OH") 
gen allgo_only = 1 if city_go_vote == 1 & city_rev_vote == 0
replace allgo_only = 0 if utgo_only == 1
tab state if allgo_only == 1

local temp control utgo_only allgo_only
foreach x of local temp{
	replace `x' = 0 if `x' == .
}

gen insample = 1 if control == 1 | utgo_only == 1 | allgo_only == 1
replace insample = 0 if insample == .

tab state if insample == 1

tab control
*17.5% control; 1,032 issuers
tab utgo_only
*11.6% UTGO only; 693 issuers
tab allgo_only
*17.51 all GO only; 1,017 issuers
tab insample
*46.17% in sample; 2,742 issuers

*make vars for other debt raised in the same county, but not by the issuer
gen county_debt_other = county_debt - city_debt
gen ln_county_debt_other = ln(1+county_debt_other)

*Merge in county demos from 2001
mmerge fips using "$BEA\countydemos_2001.dta", ///
	type(n:1) missing(nomatch)
/*
                 obs |   7407
                vars |     49  (including _merge)
         ------------+---------------------------------------------------------
              _merge |     20  obs only in master data                (code==1)
                     |   1468  obs only in using data                 (code==2)
                     |   5919  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
drop if _merge == 2
drop _merge


*merge in state demos from 2001
mmerge state_name using "$BEA\state_demos_2001.dta", type(n:1) missing(nomatch)
*DC and HI not matched, as expected
drop if _merge == 2
drop _merge

*make ln's of state and county demos
rename state_persinc state_pers_inc
rename (employment state_employment) (emp state_emp)
local temp emp gdp percap_inc pers_inc
foreach x of local temp{
	gen ln_`x' = ln(`x')
}
local temp emp gdp percap_inc pers_inc
foreach x of local temp{
	gen ln_state_`x' = ln(state_`x')
}

gen ln_pop = ln(pop)


*Bring in Gao et al indicator
mmerge state using "$DATA\Gao et al\250624_GLM_table1.dta", ///
	type(n:1) missing(nomatch)
*DC and HI, drop
drop if _merge == 2
*rest of them matched
drop _merge


*Make sample indicators:
*Look at comparison between benchmark and UTGO+LTGO states (excluding UTGO only)

gen insample_allgo = 1 if control == 1
replace insample_allgo = 1 if allgo_only == 1
replace insample_allgo = 0 if insample_allgo == .

*Look at comparison between benchmark and UTGO only states
gen insample_utgo_only = 1 if control == 1 | utgo_only == 1
replace insample_utgo_only = 0 if insample_utgo_only == .

*label vars*
label var frac_ltgo "Pct LTGO"
label var frac_rev "Pct Rev"
label var frac_utgo "Pct UTGO"
label var state_go_vote "State GO vote"
label var ln_gdp "County ln(GDP)"
label var ln_emp "County ln(Emp)"
label var ln_percap_inc "County ln(Percap Inc)"
label var ln_pers_inc "County ln(Pers. Inc)"
label var ln_city_debt "ln(Issuer debt)"
label var ln_county_debt_other "ln(Non-issuer debt in county)"

*save file
save "$MERGENT\Clean\260611_city_issuerlevel.dta", replace

**# Bookmark #1
**Now merge in issuer-level yield spreads merge into main issuer-level data**

*Go to latest issuer-level file, drop old issuer yield spread, bring in new one
use "$MERGENT\Clean\260611_city_issuerlevel.dta", clear
mmerge seed_issuer using "$MERGENT\Clean\260610_issuers_yieldspread.dta", ///
	type(n:1) missing(nomatch)
*all matched, hooray
drop _merge
sort state seed_issuer 

*Do additional cleaning
*Gen indicator for both statutory lien and separate fund for pledged revenues
gen sepfund_statlien = 1 if state_sep_pledgerev == 1 & state_statutorylien == 1
replace sepfund_statlien = 0 if sepfund_statlien == .
*Going forward, treat these as one measure. For future variable naming, can use something like "Separate pledged revenue"

*Make an index out of this combo, full faith, and separate debt service
gen invest_protect = state_fullfaith + state_sep_debtservice_levy + sepfund_statlien
tab invest_protect
/*
invest_prot |
        ect |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |         17        0.28        0.28
          1 |      2,426       40.11       40.39
          2 |      2,838       46.92       87.30
          3 |        768       12.70      100.00
------------+-----------------------------------
      Total |      6,049      100.00
*/
gen invest_prot_scaled = 0 if invest_protect == 0
replace invest_prot_scaled = 0.33 if invest_protect == 1
replace invest_prot_scaled = 0.67 if invest_protect == 2
replace invest_prot_scaled = 1 if invest_protect == 3

*Label vars
label var glm_proactive "Proactive State"
label var state_sep_debtservice_levy "SepLevy"
label var state_sep_pledgerev "PledgedFund"
label var state_statutorylien "StatLien"
label var sepfund_statlien "PledgedFund + StatLien"
label var invest_prot_scaled "Fidelity Index"
label var state_fullfaith "FullFaith"
label var state_ltgo_allowed "LTGO Allowed"
label var ln_pop "County ln(Pop)"
label var issuer_yield_spread "WAvg Yield Spread"

*save
save "$MERGENT\Clean\260611_city_issuerlevel_yieldspread.dta", replace
