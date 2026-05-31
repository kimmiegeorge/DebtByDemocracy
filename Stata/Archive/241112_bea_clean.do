************************
*Voting on bonds       *
*BEA data cleaning     *
*Last updated: 11/12/24*
************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"

***Import GDP***
import delimited "$BEA\CAGDP1__ALL_AREAS_2001_2022.csv", varnames(1) clear
*Only keep real GDP (line code 1)
keep if linecode == 1
*Note real GDP is in thousands of dollars, chained to 2017 dollars
*drop unneeded vars
drop region tablename industryclassification description unit 
*fix varnames of years: 2001-2022
rename v9 year2001
rename v10 year2002
rename v11 year2003
rename v12 year2004
rename v13 year2005
rename v14 year2006
rename v15 year2007
rename v16 year2008
rename v17 year2009
rename v18 year2010
rename v19 year2011
rename v20 year2012
rename v21 year2013
rename v22 year2014
rename v23 year2015
rename v24 year2016
rename v25 year2017
rename v26 year2018
rename v27 year2019
rename v28 year2020
rename v29 year2021
rename v30 year2022 

*destring
forvalues i = 2001(1)2022{
	destring year`i', replace force
}

*clean fips
gen fips = substr(geofips, 3,5)
drop geofips
order fips, before(geoname)

*reshape
reshape long year, i(fips) j(yr)
rename year gdp
rename yr year
drop linecode
label var gdp "Real GDP"

*save
save "$BEA\gdp_2001_2022.dta", replace 

***Import personal income and other demographics***
import delimited "$BEA\CAINC4__ALL_AREAS_1969_2022.csv", varnames(1) clear
*only keep years we need
drop v9-v40
*only keep personal income, population, per capita personal income, total employment
keep if inlist(linecode,10,20,30,7010)
drop region tablename industryclassification
*note units: personal income in thousands of dollars, population in # people, per capita personal income in dollars, total employment in numbe rof jobs 
drop unit description

rename v41 year2001
rename v42 year2002
rename v43 year2003
rename v44 year2004
rename v45 year2005
rename v46 year2006
rename v47 year2007
rename v48 year2008
rename v49 year2009
rename v50 year2010
rename v51 year2011
rename v52 year2012
rename v53 year2013
rename v54 year2014
rename v55 year2015
rename v56 year2016
rename v57 year2017
rename v58 year2018
rename v59 year2019
rename v60 year2020
rename v61 year2021
rename v62 year2022 

*destring
forvalues i = 2001(1)2022{
	destring year`i', replace force
}

*clean fips
gen fips = substr(geofips, 3,5)
drop geofips
order fips, before(geoname)

*save different files for gdp, personal income, per capita income, population
preserve
keep if linecode == 10
*reshape
reshape long year, i(fips) j(yr)
rename year pers_inc
rename yr year
drop linecode
label var pers_inc "Personal income"
save "$BEA\pers_inc_2001_2022.dta", replace
restore 

preserve
keep if linecode == 20
*reshape
reshape long year, i(fips) j(yr)
rename year pop
rename yr year
drop linecode
label var pop "Population"
save "$BEA\pop_2001_2022.dta", replace
restore 

preserve
keep if linecode == 30
*reshape
reshape long year, i(fips) j(yr)
rename year percap_inc
rename yr year
drop linecode
label var percap_inc "Per capita income"
save "$BEA\percap_inc_2001_2022.dta", replace
restore 

preserve
keep if linecode == 7010
*reshape
reshape long year, i(fips) j(yr)
rename year employment
rename yr year
drop linecode
label var employment "Employment"
save "$BEA\employment_2001_2022.dta", replace
restore 