**************************
*Voting on bonds         *
*Clean population data   *
*Last updated: 02/25/25  *
**************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global IL "$DATA\Home Rule"
global DESCRIPT "$MAIN\Descriptives"
global RESULTS "$MAIN\Results\2025-02_IL"

/*Data notes:
- From Census, downloaded 2000-2010 and 2010-2020 population estimates for cities
- 2000-2010: https://www2.census.gov/programs-surveys/popest/datasets/2000-2010/intercensal/cities/
- 2010-2020: https://www2.census.gov/programs-surveys/popest/datasets/2010-2020/cities/
-  Definition of difference places in the census data: https://www.census.gov/content/dam/Census/data/developers/understandingplace.pdf 
*/

***Import 2000 data***
import delimited using "$IL\cb_citypop_2000.csv", clear varn(1)
*keep only IL
keep if state == 17

destring census2000pop, replace force
tab sumlev
drop if inlist(sumlev, 40, 50, 61, 71)

*do other cleaning
*drop "balance" of "county" or "balance" of "township"
gen name_upper = strupper(name)
gen temp1 = 1 if strpos(name_upper, "BALANCE") > 0
gen temp2 = 1 if strpos(name_upper, "COUNTY") > 0
drop if temp1 == 1 & temp2 == 1
drop temp2
gen temp2 = 1 if strpos(name_upper, "TOWNSHIP") > 0
drop if temp1 == 1 & temp2 == 1
*no balance of townships left
drop temp2
count if temp1 == 1
*0
drop temp1

*what about Villages whose names end in (PT.)?
*checked plainfield village. Their website + wikipedia + census quickfacts uses just the population from "plainfield village", not "plainfield village (pt.)"
gen temp1 = 1 if strpos(name_upper, "(PT.)") > 0
*drop these
drop if temp1 == 1
drop temp*
tab sumlev

*get to unique names
drop sumlev county cousub
duplicates drop
drop concit

*only keep 2000
keep state place name census2000pop name_upper

*rename astoria village to astoria town for later matching
replace name_upper = "ASTORIA TOWN" if name_upper == "ASTORIA VILLAGE"

*save
save "$IL\cb_citypop_2000_clean.dta", replace

***Import and clean 2000-2010 data***
import delimited using "$IL\cb_citypop_2000_2010.csv", clear varn(1)
*keep only IL
keep if state == 17
*look at categories of sumlev
tab sumlev
/*
     SUMLEV |      Freq.     Percent        Cum.
------------+-----------------------------------
         40 |          1        0.01        0.01
         50 |        102        1.39        1.40
         61 |      1,434       19.48       20.87
         71 |      2,993       40.65       61.52
        157 |      1,534       20.83       82.36
        162 |      1,299       17.64      100.00
------------+-----------------------------------
      Total |      7,363      100.00
*/
*40 = state, 50 = county, 61 = township, 71 = some villages, some "balance of township", 157 = some villages, some "balance of county" or weird duplicates, some city, 162 = city
*I don't think we want the "balance of", because this is the population in a township that is separate from the population within incorporated places in the township
*for now, drop state and county
drop if sumlev == 40 | sumlev == 50
*in IL, townships are subdivisions of counties, but often coterminous with cities (or broader than cities)
*for our purposes, don't think we want to include townships
drop if inlist(sumlev, 61, 71)

*do other cleaning
*drop "balance" of "county" or "balance" of "township"
gen name_upper = strupper(name)
gen temp1 = 1 if strpos(name_upper, "BALANCE") > 0
gen temp2 = 1 if strpos(name_upper, "COUNTY") > 0
drop if temp1 == 1 & temp2 == 1
drop temp2
gen temp2 = 1 if strpos(name_upper, "TOWNSHIP") > 0
drop if temp1 == 1 & temp2 == 1
*no balance of townships left
drop temp2
count if temp1 == 1
*0
drop temp1

*what about Villages whose names end in (PT.)?
*checked plainfield village. Their website + wikipedia + census quickfacts uses just the population from "plainfield village", not "plainfield village (pt.)"
gen temp1 = 1 if strpos(name_upper, "(PT.)") > 0
*drop these
drop if temp1 == 1
drop temp*
tab sumlev

*check duplicates by name
duplicates tag name, gen(dup)
tab dup
*hand-checked: many duplicates where the names and pops are the same, but different sumlev and county #
*combine these / drop duplicates
drop sumlev county cousub
duplicates drop
*drop and regen dup
drop dup
duplicates tag name, gen(dup)
tab dup
*no dups by name, good

*drop 2000 pop vars not needed; rename others
drop estimatesbase2000 popestimate2000 popestimate2010 dup

*rename astoria town to astoria village 

*merge in actual 2000 census data
mmerge name_upper using "$IL\cb_citypop_2000_clean.dta", type(1:1) missing(nomatch)
*all merged
drop _merge
order census2000pop, before(popestimate2001)
order name_upper, after(place)
order name, after(census2010pop)
*rename pop vars
rename (census2000pop census2010pop) (pop2000 pop2010)
forvalues i = 2001(1)2009 {
	rename popestimate`i' pop`i'
}

*Save
save "$IL\cb_citypop_2000_2010_clean.dta", replace

***Import and clean 2010-2020 data, then append***
import delimited using "$IL\cb_citypop_2010_2020.csv", clear varn(1)
*keep only IL
keep if state == 17
*Clean
drop if inlist(sumlev, 61, 71,40,50)

*drop "balance" of "county" or "balance" of "township"
gen name_upper = strupper(name)
gen temp1 = 1 if strpos(name_upper, "BALANCE") > 0
gen temp2 = 1 if strpos(name_upper, "COUNTY") > 0
drop if temp1 == 1 & temp2 == 1
drop temp2
gen temp2 = 1 if strpos(name_upper, "TOWNSHIP") > 0
drop if temp1 == 1 & temp2 == 1
*no balance of townships left
drop temp2
count if temp1 == 1
*0
drop temp1

*what about Villages whose names end in (PT.)?
*checked plainfield village. Their website + wikipedia + census quickfacts uses just the population from "plainfield village", not "plainfield village (pt.)"
gen temp1 = 1 if strpos(name_upper, "(PT.)") > 0
*drop these
drop if temp1 == 1
drop temp*
tab sumlev

*check duplicates by name
duplicates tag name, gen(dup)
tab dup
*hand-checked: many duplicates where the names and pops are the same, but different sumlev and county #
*combine these / drop duplicates
drop sumlev county cousub
duplicates drop
*drop and regen dup
drop dup
duplicates tag name, gen(dup)
tab dup
*still some dups
sort name
*br if dup > 0
*estimates are the same, just primgeo_flag = 1 or not
drop if primgeo_flag == 1 & dup > 0
drop dup
duplicates tag name, gen(dup)
tab dup
*no dups, good

*drop certain vars
drop concit primgeo_flag funcstat stname census2010pop popestimate042020 dup estimatesbase2010
drop popestimate2010
order name_upper, after(place)

*rename pop vars
forvalues i = 2011(1)2020 {
	rename popestimate`i' pop`i'
}

order name, after(pop2020)

*save 
save "$IL\cb_citypop_2011_2020_clean.dta", replace

**Merge the two**
use "$IL\cb_citypop_2000_2010_clean.dta", clear
mmerge name_upper using "$IL\cb_citypop_2011_2020_clean.dta", type(1:1) missing(nomatch)
/*
                 obs |   1300
                vars |     28  (including _merge)
         ------------+---------------------------------------------------------
              _merge |      2  obs only in master data                (code==1)
                     |      1  obs only in using data                 (code==2)
                     |   1297  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*br if _merge == 1
*GARDEN PRAIRIE VILLAGE, WHITEASH VILLAGE
*br if _merge == 2
*ST. ROSE VILLAGE
*Hand-checked, not from typos, just missing
drop _merge
sort name_upper
*save
save "$IL\cb_citypop_2000_2020_clean.dta", replace

*get list of names to fuzzy match to Mergent
keep place name_upper
export delimited using "$IL\il_citypop_namelist.csv", replace

*get Mergent IL issuer list ready for fuzzy match
import delimited using "$IL\250220_issuer_list.csv", clear varn(1)
*gen id
gegen temp_id = group(seed_issuer)
*remove ILL at end
gen temp1 = strpos(seed_issuer, " ILL")
gen temp2 = substr(seed_issuer,1,temp1-1) if temp1 != 0
replace temp2 = seed_issuer if temp2 == ""
rename temp2 seed_issuer_tomatch
drop temp1
order seed_issuer_tomatch, before(seed_issuer)

*save
export delimited using "$IL\250225_il_issuerlist_tomatch.csv", replace

**Bring in fuzzy match results**
*Start with Mergent IL list
import delimited using "$IL\250220_issuer_list.csv", clear varn(1)
*gen id
gegen temp_id = group(seed_issuer)
*remove ILL at end
gen temp1 = strpos(seed_issuer, " ILL")
gen temp2 = substr(seed_issuer,1,temp1-1) if temp1 != 0
replace temp2 = seed_issuer if temp2 == ""
rename temp2 seed_issuer_tomatch
drop temp1
order seed_issuer_tomatch, before(seed_issuer)

*merge in fuzzy match
mmerge seed_issuer_tomatch using "$IL\250225_il_fuzzymatchresults_clean.dta", ///
	type(1:n) missing(nomatch)
/*
                 obs |    380
                vars |      9  (including _merge)
         ------------+---------------------------------------------------------
              _merge |     11  obs only in master data                (code==1)
                     |    369  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*br if _merge == 1
*manually correct
replace name_upper = "EL PASO CITY" if seed_issuer == "EL PA"
replace name_upper = "FOREST PARK VILLAGE" if seed_issuer == "FOREST PK ILL"
replace name_upper = "HOMER VILLAGE" if seed_issuer == "HOMER TWP ILL"
replace name_upper = "LAKE IN THE HILLS VILLAGE" if seed_issuer == "LAKE IN HILLS ILL"
replace name_upper = "O'FALLON CITY" if seed_issuer == "O FALLON ILL"
replace name_upper = "PALOS PARK VILLAGE" if seed_issuer == "PALOS PK VLG ILL" 
replace name_upper = "SALEM CITY" if seed_issuer == "SALEM TWP ILL" 
replace name_upper = "UNIVERSITY PARK VILLAGE" if seed_issuer == "UNIVERSITY ILL" 

drop _merge left_index right_index

drop if name_upper == ""

*merge in population
mmerge name_upper using "$IL\cb_citypop_2000_2020_clean.dta", type(n:1) missing(nomatch)
/*
                 obs |   1306
                vars |     32  (including _merge)
         ------------+---------------------------------------------------------
              _merge |    929  obs only in using data                 (code==2)
                     |    377  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
*drop if only in using; these are cities that don't issue rev or GO bonds in Mergent
drop if _merge == 2
drop _merge
*drop no-longer-needed vars
drop seed_issuer_tomatch temp_id stname name 

rename (state place) (state_fips il_place_fips)

**# Bookmark #2
***Define pop bandwidths***

*Should population bandwidths be decided each year or be time-invariant?
*sort by 2010 pop to learn about data
sort pop2010
sum pop2010, d
*min: 225, p25: 3757, median: 9,570, mean: 24,726.38, p75: 23,153, max: 2,695,598

*see how many issuers in rough pop buckets based on 2010
*2,500:
count if pop2010 >= (25000-2500) & pop2010 < 25000
*14
count if pop2010 >= 25000 & pop2010 < (25000+2500)
*11

*5,000:
count if pop2010 >= (25000-5000) & pop2010 < 25000
*22
count if pop2010 >= 25000 & pop2010 < (25000+5000)
*50

*7,500:
count if pop2010 >= (25000-7500) & pop2010 < 25000
*41
count if pop2010 >= 25000 & pop2010 < (25000+7500)
*26

*10,000:
count if pop2010 >= (25000-10000) & pop2010 < 25000
*56
count if pop2010 >= 25000 & pop2010 < (25000+10000)
*33

*reshape:
reshape long pop, i(seed_issuer homerule_ever name_upper state_fips il_place_fips) j(year)

*check for duplicates
duplicates tag seed_issuer year, gen(dup)
tab dup
*br if dup > 0 
*accidentally had matched Henry to both Henry and McHenry, fix
drop if seed_issuer == "HENRY ILL" & name_upper == "MCHENRY CITY"
drop dup

*make pop buckets based on each year
gen band2500 = 1 if pop >= (25000-2500) & pop < (25000+2500) & pop != .
replace band2500 = 0 if band2500 == . & pop != .
gen band5000 = 1 if pop >= (25000-5000) & pop < (25000+5000) & pop != .
replace band5000 = 0 if band5000 == . & pop != .
gen band7500 = 1 if pop >= (25000-7500) & pop < (25000+7500) & pop != .
replace band7500 = 0 if band7500 == . & pop != .
gen band10000 = 1 if pop >= (25000-10000) & pop < (25000+10000) & pop != .
replace band10000 = 0 if band10000 == . & pop != .

sum band2500
*mean = 6.5%
sum band5000
*mean = 31.6%
sum band7500
*mean = 37.8%
sum band10000
*mean = 41.8%

*save file
save "$IL\250225_il_issuerpop_clean.dta", replace