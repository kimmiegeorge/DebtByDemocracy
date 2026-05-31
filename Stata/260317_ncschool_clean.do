***************************
*Partisan school boards NC*
*Clean NC data   *
*Last updated: 03/17/26   *
***************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global NC "$DATA\NC School"
global NCElec "$NC\school election data"

/*Zipped txt files downloaded from:
https://www.ncsbe.gov/results-data/election-results/historical-election-results-data
See README and python code in Data\NC School for cleaning process
*/

**# Bookmark #1
*Start with NC_schoolboard_elections files*
import delimited "$NCElec\NC_schoolboard_elections.csv", varnames(1) case(lower) clear

*Goal is to get to election-level data. Don't need precinct information

*First, figure out which variables we can safely drop
tab ftp_date
*no obs
tab real_precinct
*don't care if this is a real or administrative precinct 
tab district
*All not found
count if precinct_abbrv != .
*All missing
count if absentee_or_early != .
*All missing
count if contest_group_id != .
*50,000 not missing; keep this for now
tab contest_type
*almost all are C
*br if contest_type == "S"
*Can't tell how these are different, keep this for now
drop ftp_date real_precinct district precinct_abbrv absentee_or_early
tab runoff_status
*All 0 or missing
tab recount_status
*All 0 or missing
tab winner_status
*All 0 or missing
drop runoff_status recount_status winner_status
drop vote_for
*this is how many choices a voter can make in the election

*Check what total votes measures
gen temp1 = election_day + early_voting + absentee_by_mail + provisional
count if temp1 != total_votes
*Always equal, yay!
*Don't think we care when the votes are cast, but worth keeping around
*Combine absentee by mail and provisional
rename (election_day early_voting) (elecday_votes early_votes)
gen mailprov_votes = absentee_by_mail + provisional
drop absentee_by_mail provisional temp1
order total_votes, before(elecday_votes)

*Checked manually that Python code picked up party both when the raw var was "party" and "choice party"

*Need to clean dates from strings to Stata dates
gen date_new = date(election_date,"MDY")
format date_new %td
drop election_date
rename date_new election_date
*get month, year
gen month = month(election_date)
gen year = year(election_date)
order year month, before(election_date)
tab year
/*
       year |      Freq.     Percent        Cum.
------------+-----------------------------------
       2010 |        997       11.38       11.38
       2011 |        116        1.32       12.70
       2012 |        904       10.32       23.02
       2013 |         13        0.15       23.17
       2014 |        968       11.05       34.21
       2015 |         83        0.95       35.16
       2016 |      1,081       12.34       47.50
       2017 |        113        1.29       48.78
       2018 |      1,011       11.54       60.32
       2019 |         73        0.83       61.15
       2020 |        967       11.04       72.19
       2021 |         60        0.68       72.87
       2022 |      1,174       13.40       86.27
       2023 |         67        0.76       87.04
       2024 |      1,082       12.35       99.38
       2025 |         54        0.62      100.00
------------+-----------------------------------
      Total |      8,763      100.00
*/
tab month
/*

      month |      Freq.     Percent        Cum.
------------+-----------------------------------
          3 |      1,141       13.02       13.02
          5 |      1,860       21.23       34.25
          6 |         10        0.11       34.36
          7 |          8        0.09       34.45
          9 |          6        0.07       34.52
         10 |         34        0.39       34.91
         11 |      5,700       65.05       99.95
         12 |          4        0.05      100.00
------------+-----------------------------------
      Total |      8,763      100.00
*/

rename month calmonth
gen month = mofd(election_date)
format month %tm
order month, after(year)

tab month
/*
      month |      Freq.     Percent        Cum.
------------+-----------------------------------
     2010m5 |        426        4.86        4.86
     2010m6 |          6        0.07        4.93
    2010m11 |        565        6.45       11.38
    2011m10 |         21        0.24       11.62
    2011m11 |         95        1.08       12.70
     2012m5 |        309        3.53       16.23
    2012m11 |        595        6.79       23.02
    2013m10 |         13        0.15       23.17
     2014m5 |        341        3.89       27.06
    2014m11 |        627        7.16       34.21
    2015m11 |         83        0.95       35.16
     2016m3 |        441        5.03       40.19
     2016m6 |          2        0.02       40.21
    2016m11 |        638        7.28       47.50
     2017m9 |          6        0.07       47.56
    2017m11 |        107        1.22       48.78
     2018m5 |        338        3.86       52.64
     2018m6 |          2        0.02       52.66
    2018m11 |        671        7.66       60.32
    2019m11 |         73        0.83       61.15
     2020m3 |        320        3.65       64.81
    2020m11 |        647        7.38       72.19
    2021m11 |         60        0.68       72.87
     2022m5 |        446        5.09       77.96
     2022m7 |          8        0.09       78.06
    2022m11 |        716        8.17       86.23
    2022m12 |          4        0.05       86.27
    2023m11 |         67        0.76       87.04
     2024m3 |        380        4.34       91.37
    2024m11 |        702        8.01       99.38
    2025m11 |         54        0.62      100.00
------------+-----------------------------------
      Total |      8,763      100.00
*/

/*When school board elections occur: https://ballotpedia.org/Rules_governing_school_board_election_dates_and_timing_in_North_Carolina
- Typically occur on day of state primary election (March in even-numbered years) or day of state general election (November in even-numbered years)
- How NC elections work: https://www.ncsbe.gov/about-elections/types-elections
- Note that there are also non-partisan primaries. The primary trims # candidates down to 2x the number of seats. If needed, a non-partisan primary occurs in October before general election in November
*/

*Want to collapse total votes to candidate-level, don't need precinct level
*gen unique ID for election. Can't use election date and contest name because some contest names are generic (like "board of education") and don't say the county
*So use election date, county, and contest name
gegen election_county_id = group(election_date county contest_name)
*gen numeric county ID
gegen county_id = group(county)
*Collapse to county-election-candidate level
gcollapse (sum) total_votes elecday_votes early_votes mailprov_votes ///
	, by(election_county_id county contest_name election_date choice party contest_type contest_group_id year month calmonth)
sort county election_date contest_name
order election_county_id county year month calmonth election_date contest_name
*Note that contest_type doesn't help tell you whether it's a primary or not

drop contest_group_id contest_type

**# Bookmark #2
*Clean in order to collapse from county-election-candidate-level to county-election level
local temp total elecday early mailprov
foreach x of local temp{
	gegen `x'_votes_race = sum(`x'_votes), by(election_county_id)
}
*Identify winner
gegen winning_votes = max(total_votes), by(election_county_id)
gen winner = 1 if total_votes == winning_votes
replace winner = 0 if winner == .
*gen winning percentage
gen win_pct = winning_votes / total_votes_race
*Many people run unopposed, so also have indicator for number of candidates besides write-in
*Now that totals are generated, drop write-in
gen temp1 = 1 if strpos(upper(choice),"WRITE") > 0 & strpos(upper(choice),"IN") > 0
tab temp1
*2,377
*br if temp1 == 1
*These are all write-ins
count if temp1 == 1 & winner == 1
*9 cases where the write-in is the winner
*br if temp1 == 1 & winner == 1
*a few cases where everyone was a write-in, so the write-in won

*Gen number of non-write-in candidates
*for nunique gegen, need numeric var, so make temp numeric for candidate. OK if same candidate has different name form across races; within a race, they'll have only one
gegen temp2 = group(choice)
gegen n_candidates = nunique(temp2) if temp1 != 1, by(election_county_id)
*great, this measures the number of non-write-in candidates in a race. fill in for an election
gegen n_candidates_new = max(n_candidates), by(election_county_id)
drop n_candidates
rename n_candidates_new n_candidates

*Drop elections with only write-ins. Stats around winning percentage, competitiveness get very weird. Only 7 elections where this happens
drop if n_candidates == .

*In addition to winning percent, generate percent difference between first and second
*Gen identifier for second
drop temp2
gegen temp2 = select(total_votes), by(election_county_id) n(-2)
gen runnerup = 1 if total_votes == temp2
replace runnerup = 0 if runnerup == .
*gen num votes difference between winner and runnerup
gen numvote_margin = winning_votes - temp2
gen vote_margin = numvote_margin / total_votes_race
drop temp1 temp2

*Now, want to gen an indicator for any party var present
gen temp1 = 1 if party != ""
replace temp1 = 0 if temp1 == .
gegen partisan = max(temp1), by(election_county_id)
drop temp1
*Where there is party info, gen party of winner. For this, want to exclude primaries
*Gen party of winner; deal with primaries later
gen winner_party = party if winner == 1 & partisan == 1
gegen temp1 = mode(winner_party), by(election_county_id)
drop winner_party 
rename temp1 winner_party
count if winner_party == "" & partisan == 1
*0, good

*Note that within a county, there can be multiple school board elections. E.g., 11/5/2024 Anson County BoE Districts 1, 3, 6, 7

*Gen county-year competitiveness indicators: avg # candidates, vote margin, each major party fielding a candidate. For this, need to drop primaries
*Identify primaries by whether the last few end in "(DEM)" or "(REP)"
gen temp1 = 1 if strpos(contest_name,"(DEM)") > 0
replace temp1 = 1 if strpos(contest_name,"(REP)") > 0
*How to identify non-partisan primaries? Look for a county-year that has multiple dates?
gegen temp2 = nunique(election_date), by(county year)
tab temp2
/*
      temp2 |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      5,716       65.23       65.23
          2 |      3,030       34.58       99.81
          3 |         17        0.19      100.00
------------+-----------------------------------
      Total |      8,763      100.00
*/
br county year month election_date contest_name choice party temp1 temp2 if temp2 > 1
*add other indications of primaries
replace temp1 = 1 if strpos(contest_name,"- DEM") > 0 | strpos(contest_name,"- REP") > 0
tab temp1
*777 partisan primaries picked up
*Ex: In Alleghany County 2010, partisan primary was in May, partisan general was in Nov
*DEM/REP seems to pick up primaries well when partisan. What about when not partisan? Ex: May 17, 2022 Asheville City Schools seems a nonpartisan primary
*Can't just pick the November elections because sometimes a county has multiple, and one has the main election in May and one has the main one in Nov
*Ex: Cabarrus county 2012 
*Conservatively, for non-partisan primaries, use having the same contest name, like for Asheville City Schools
gegen temp3 = nunique(election_date), by(county year contest_name)
tab temp3
*only 1 or 2
*Just for these cases, keep the November election
gegen temp4 = max(calmonth) if temp3 == 2, by(county year)
replace temp1 = 1 if temp1 == . & temp3 == 2 & calmonth != temp4
*249 changes made
drop temp3 temp4
*br county year month election_date contest_name choice party temp1 temp2 if temp2 == 3
*This is fine, two different school boards in a county, the primary does get picked up already
*Drop if temp1 == 1, then re-gen temp2
drop if temp1 == 1
*Drop 1,026 primary elections
drop temp2 
gegen temp2 = nunique(election_date), by(county year)
tab temp2
/*
      temp2 |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      6,830       88.28       88.28
          2 |        894       11.55       99.83
          3 |         13        0.17      100.00
------------+-----------------------------------
      Total |      7,737      100.00
*/
br county year month election_date contest_name choice party temp1 temp2 if temp2 == 2
*Check for any other primaries and systematic ways to drop them
*Do some manually
replace temp1 = 1 if election_county_id == 569
replace temp1 = 1 if election_county_id == 856
replace temp1 = 1 if election_county_id == 855
replace temp1 = 1 if election_county_id == 33
replace temp1 = 1 if inlist(election_county_id,34,35)
replace temp1 = 1 if inlist(election_county_id,889,71,97,98,632,633,918,106,646,930)
*drop board of education redistricting
drop if election_county_id == 913
*drop newly selected primary elections and re-gen temp2
drop if temp1 == 1
drop temp2
gegen temp2 = nunique(election_date), by(county year)
tab temp2
/*
      temp2 |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      6,964       91.31       91.31
          2 |        650        8.52       99.83
          3 |         13        0.17      100.00
------------+-----------------------------------
      Total |      7,627      100.00
*/
*Some of the city elections span multiple counties. At the county level, would have duplicates from these
*See how big of a phenomenon this is
*Ex: KANNAPOLIS CITY SCHOOLS BOARD OF EDUCATION AREA I with ROWAN county 
*Ignore for now, hopefully not a big deal

*Gen indicator for partisan month, year
gegen partisan_mth = max(partisan), by(county month)
gegen partisan_yr = max(partisan), by(county year)

tab party
/*
      party |      Freq.     Percent        Cum.
------------+-----------------------------------
        DEM |        511       44.86       44.86
        LIB |          4        0.35       45.22
        REP |        559       49.08       94.29
        UNA |         65        5.71      100.00
------------+-----------------------------------
      Total |      1,139      100.00
*/
drop temp1 temp2
*Before collapsing from candidate level, gen indicator for a partisan race where only one party has candidates (rough measure of a very politically skewed area)
*Gen temp numeric for party: DEM = 1, REP = 2, LIB or UNA = 3
gen party_id = 1 if party == "DEM"
replace party_id = 2 if party == "REP"
replace party_id = 3 if party == "LIB"
replace party_id = 3 if party == "UNA" 
*Gen count of # parties represented in a race
gegen n_parties_race = nunique(party_id) if partisan == 1, by(election_county_id)
tab n_parties_race
/*
n_parties_r |
        ace |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |        324       28.05       28.05
          2 |        717       62.08       90.13
          3 |        114        9.87      100.00
------------+-----------------------------------
      Total |      1,155      100.00
*/
*br if n_parties_race == 1
count if partisan == 1
*1,155, good, matches
tab partisan
/*
   partisan |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      6,472       84.86       84.86
          1 |      1,155       15.14      100.00
------------+-----------------------------------
      Total |      7,627      100.00
*/
*15% of general election races are partisan
*gen indicator for only one party is reflected
gen oneparty = 1 if n_parties_race == 1 & partisan == 1
replace oneparty = 0 if oneparty == . & partisan == 1

*Gen winner-party ID where rep = 1, dem = 0
gen win_party_rep = 1 if winner_party == "REP"
replace win_party_rep = 0 if inlist(winner_party,"DEM","UNA","LIB")

*Now collapse to the race-level
gcollapse (max) partisan partisan_mth partisan_yr ///
	win_party_rep total_votes_race elecday_votes_race early_votes_race mailprov_votes_race  ///
	 winning_votes win_pct n_candidates numvote_margin vote_margin oneparty  ///
	, by(election_county_id county year month calmonth election_date contest_name)
sort county election_date contest_name
*2,110 races

count if vote_margin == .	
*258 cases, these look like cases where person ran unopposed
replace vote_margin = 1 if vote_margin == .

*Get number of close elections
*gen close indicator as 5% vote margin or less
gen close = 1 if vote_margin <= 0.05
replace close = 0 if close == .
tab close
/*
      close |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      1,617       76.64       76.64
          1 |        493       23.36      100.00
------------+-----------------------------------
      Total |      2,110      100.00
*/

*Identify non-partisan close races
gen close_nonpartisan = 1 if close == 1 & partisan == 0
replace close_nonpartisan = 0 if close_nonpartisan == .

*Identify partisan close races
gen close_partisan = 1 if close == 1 & partisan == 1
replace close_partisan = 0 if close_partisan == .

tab close_nonpartisan 
/*
close_nonpa |
     rtisan |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      1,737       82.32       82.32
          1 |        373       17.68      100.00
------------+-----------------------------------
      Total |      2,110      100.00
*/

tab close_partisan
/*
close_parti |
        san |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      1,990       94.31       94.31
          1 |        120        5.69      100.00
------------+-----------------------------------
      Total |      2,110      100.00
*/

*Identify races where republicans narrowly won and narrowly lost (Lee 2008 J Econometrics)
rename win_party_rep win_rep
gen close_win_rep = 1 if close == 1 & win_rep == 1
replace close_win_rep = 0 if close_win_rep == . & win_rep != .
gen close_win_dem = 1 if close == 1 & win_rep == 0
replace close_win_dem = 0 if close_win_dem == . & win_rep != .
tab close_win_rep
/*
close_win_r |
         ep |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |        459       84.38       84.38
          1 |         85       15.63      100.00
------------+-----------------------------------
      Total |        544      100.00
*/
tab close_win_dem
/*
close_win_d |
         em |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |        509       93.57       93.57
          1 |         35        6.43      100.00
------------+-----------------------------------
      Total |        544      100.00
*/

*save data at the race level
save "$NCElec\260301_schoolboard_electionlevel_clean.dta", replace

**# Bookmark #3
*Descriptives at the election level:
use "$NCElec\260301_schoolboard_electionlevel_clean.dta", clear
tab partisan
/*
      (max) |
   partisan |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      1,566       74.22       74.22
          1 |        544       25.78      100.00
------------+-----------------------------------
      Total |      2,110      100.00
*/
tab year partisan
*Interesting, the partisan races can only happen in even years

*do this just for even years
tab year partisan if mod(year,2) == 0
/*
           |    (max) partisan
      year |         0          1 |     Total
-----------+----------------------+----------
      2010 |       207         33 |       240 
      2012 |       209         27 |       236 
      2014 |       205         35 |       240 
      2016 |       200         55 |       255 
      2018 |       169         82 |       251 
      2020 |       158         89 |       247 
      2022 |       160         99 |       259 
      2024 |       137        123 |       260 
-----------+----------------------+----------
     Total |     1,445        543 |     1,988 
*/

*For vote margin stats, exclude races where people run unopposed. It is a different measure of competitiveness, but really throws off vote margins
*count if vote_margin == 1
*drop if vote_margin == 1
tabstat vote_margin if vote_margin != 1 & partisan == 1 & mod(year,2) == 0, by(year) stat(mean sd p5 median p95)
/*
    year |      Mean        SD        p5       p50       p95
---------+--------------------------------------------------
    2010 |   .076909  .1037475  .0046846  .0372044  .3708294
    2012 |  .1202059  .0971939  .0038744  .1052052  .2900247
    2014 |  .0789283  .0901858  .0008569  .0370275  .2579516
    2016 |  .1724828   .164551  .0090559  .0929875    .48294
    2018 |  .1534189  .1676476  .0039495  .0906492  .3615592
    2020 |  .1330229  .1685759  .0003111   .035739  .4515174
    2022 |  .1698718  .1783253  .0022267    .10609  .4588746
    2024 |  .2091929  .1931766  .0042291  .1694149   .607469
---------+--------------------------------------------------
   Total |  .1590488  .1699934  .0024097  .0932234  .4557243
------------------------------------------------------------
*/
tabstat vote_margin if vote_margin != 1 & partisan == 0 & mod(year,2) == 0, by(year) stat(mean sd p5 median p95)
/*
    year |      Mean        SD        p5       p50       p95
---------+--------------------------------------------------
    2010 |  .4301746  .4086333  .0066807  .2191565  .9893455
    2012 |  .4969974  .4284832  .0055862  .3277469  .9886471
    2014 |   .405057   .410462  .0060573  .1978572  .9839122
    2016 |  .5037033  .4220406  .0066262  .3349784  .9824666
    2018 |  .4734506  .4135329  .0115506  .3127949  .9908287
    2020 |  .4474124  .4012906  .0116058  .3011499    .97426
    2022 |  .3225468  .3408346  .0095037  .1938636  .9657827
    2024 |  .3630519  .3760623   .007163  .1810176   .965421
---------+--------------------------------------------------
   Total |  .4351732   .406908  .0074483   .250182  .9843055
------------------------------------------------------------
*/

tabstat vote_margin if vote_margin != 1 & partisan == 1 & win_party_rep == 1 & mod(year,2) == 0, by(year) stat(mean sd p5 median p95)
/*
    year |      Mean        SD        p5       p50       p95
---------+--------------------------------------------------
    2010 |  .0777744   .092728  .0046846  .0509248    .28435
    2012 |  .1202192  .0882027  .0038744  .1216723  .2432233
    2014 |  .0799938  .0966158  .0008569  .0326774   .250541
    2016 |  .1938128  .1720589  .0127953  .1326158    .48294
    2018 |  .1772067  .1799162  .0041503  .1607316  .3876672
    2020 |  .1460311  .1747977  .0003111  .0402452  .4515174
    2022 |  .1818425  .1810925  .0014591  .1387702  .4588746
    2024 |  .2045533  .1943275  .0031439  .1636936  .6151958
---------+--------------------------------------------------
   Total |  .1713723  .1752021   .002064   .113091  .4663145
------------------------------------------------------------

*/

tabstat vote_margin if vote_margin != 1 & partisan == 1 & win_party_rep == 0 & mod(year,2) == 0, by(year) stat(mean sd p5 median p95)
/*
    year |      Mean        SD        p5       p50       p95
---------+--------------------------------------------------
    2010 |  .0760435  .1202686  .0073358  .0353062  .3708294
    2012 |  .1201617  .1472115  .0296485   .040812  .2900247
    2014 |  .0772539  .0864975  .0132778  .0445734  .2579516
    2016 |  .1179728  .1373355  .0047405  .0432702  .3945876
    2018 |  .0880025  .1090422  .0023179  .0241142  .2838542
    2020 |   .035461   .053435  .0021776  .0125353  .1145959
    2022 |  .1296845  .1687286  .0028536  .0679805  .6432532
    2024 |  .2323911  .1947572  .0050306  .1897826   .607469
---------+--------------------------------------------------
   Total |  .1197224  .1465296  .0039495  .0480731  .4248434
------------------------------------------------------------
*/

tabstat n_candidates if partisan == 1 & mod(year,2) == 0, by(year) stat(mean sd p5 median p95)
/*
    year |      Mean        SD        p5       p50       p95
---------+--------------------------------------------------
    2010 |  2.181818  1.722181         1         1         6
    2012 |  1.962963  1.453946         1         1         6
    2014 |  2.285714  1.775179         1         2         6
    2016 |  2.018182  1.407531         1         2         6
    2018 |  2.182927  1.736522         1         2         6
    2020 |  1.921348  1.785196         1         1         6
    2022 |  2.151515  1.534392         1         2         6
    2024 |   2.04065  1.621568         1         2         6
---------+--------------------------------------------------
   Total |  2.081031  1.633615         1         2         6
------------------------------------------------------------
*/

tabstat n_candidates if partisan == 0 & mod(year,2) == 0, by(year) stat(mean sd p5 median p95)
/*
    year |      Mean        SD        p5       p50       p95
---------+--------------------------------------------------
    2010 |  2.661836   2.06723         1         2         7
    2012 |  2.406699  1.990881         1         2         7
    2014 |  2.658537  2.162625         1         2         7
    2016 |     2.365  2.007968         1         2       6.5
    2018 |   2.43787  1.966381         1         2         7
    2020 |  2.601266  2.117383         1         2         7
    2022 |   3.00625  2.170404         1         2         8
    2024 |  2.583942  2.045951         1         2         8
---------+--------------------------------------------------
   Total |  2.581315  2.069381         1         2         7
------------------------------------------------------------
*/

tabstat oneparty if partisan == 1 & mod(year,2) == 0, by(year) stat(mean)
/*
    year |      Mean
---------+----------
    2010 |  .5757576
    2012 |  .5555556
    2014 |  .5714286
    2016 |  .4727273
    2018 |  .4878049
    2020 |  .6629213
    2022 |  .4242424
    2024 |  .5203252
---------+----------
   Total |  .5248619
--------------------
*/

*Get sum of close elections across races over time
preserve
gcollapse (sum) close, by(year partisan_yr)
keep if mod(year,2) == 0
sort partisan_yr year
list
restore

tabstat close if partisan == 1 & mod(year,2) == 0, by(year) stat(mean)
/*
    year |      Mean
---------+----------
    2010 |  .2727273
    2012 |  .1481481
    2014 |  .3142857
    2016 |  .2181818
    2018 |  .2195122
    2020 |  .2134831
    2022 |  .2424242
    2024 |  .1788618
---------+----------
   Total |  .2191529
--------------------
*/
tabstat close if partisan == 0 & mod(year,2) == 0, by(year) stat(mean)
/*

    year |      Mean
---------+----------
    2010 |  .2125604
    2012 |  .2200957
    2014 |  .2634146
    2016 |      .195
    2018 |  .2366864
    2020 |  .2151899
    2022 |     .2625
    2024 |  .2189781
---------+----------
   Total |  .2276817
--------------------
*/

*Want number of close partisan races over time, then number where dems win or reps win
preserve
keep if close == 1 & partisan == 1
gcollapse (sum) n_close=close n_close_win_rep=close_win_rep n_close_win_dem=close_win_dem, by(year)
list
restore
/*
     +--------------------------------------+
     | year   n_close   n_clos~p   n_clos~m |
     |--------------------------------------|
  1. | 2010         9          4          5 |
  2. | 2012         4          2          2 |
  3. | 2014        11          7          4 |
  4. | 2016        12          7          5 |
  5. | 2017         1          0          1 |
     |--------------------------------------|
  6. | 2018        18         11          7 |
  7. | 2020        19         16          3 |
  8. | 2022        24         19          5 |
  9. | 2024        22         19          3 |
     +--------------------------------------+
*/

*Want to get number of close partisan races and close races with Rep vs. Dem winners at county level to see how much variation there is

*Get to county-year level
*Calculate average # candidates per county-year, average competitiveness per county-year
gegen avg_cand = mean(n_candidates), by(county year)
gegen avg_oneparty = mean(oneparty), by(county year)
*Calc avg vote margin excluding when it equals one (i.e., unopposed)
gegen temp1 = mean(vote_margin) if vote_margin != 1, by(county year)
*Need to fill in avg_vote_margin across all races
gegen avg_vote_margin = max(temp1), by(county year)
*Now avg_vote_margin just missing if all races in that county-year ran unopposed. OK
drop temp1

*Gen number of races per county-year
gegen temp1 = count(election_county_id), by(county year)
rename temp1 n_races

*Gen number and % of unopposed races
*Note that when n_candidates == 1 and vote_margin < 1, it's due to write-ins
gen temp1 = 1 if n_candidates == 1
gegen n_unopp = sum(temp1), by(county year)
gen pct_unopp = n_unopp / n_races
drop temp1

*Check within a county-year: does partisan vary?
gegen temp1 = min(partisan), by(county year)
gegen temp2 = max(partisan), by(county year)
count if temp1 != temp2
*7
*br if temp1 != temp2
/*These are:
- Craven county in 2022: Craven County BOE District 01 (unexpired) has partisan 0 while other BOE districts have partisan 1
- Cabarrus county in 2024: Cabarrus County Schools BOE has partisan 1 while Kannapolis City Schools BOE Area I and II have partisan 0
*/ 
*Still have partisan county if at least one race is partisan

*Before collapsing to party-year level, need to get winning party at that level

*Eventual regression: look at yields for elections where republicans just won vs. where republicans just lost?

*Collapse to county-year level
*At county-year level, also want number of close partisan, close non-partisan, etc.
gcollapse (max) partisan_yr n_races avg_vote_margin avg_cand avg_oneparty n_unopp pct_unopp ///
	(sum) n_win_rep=win_rep n_close=close n_close_nonpartisan=close_nonpartisan ///
	n_close_partisan=close_partisan n_close_win_rep=close_win_rep n_close_win_dem=close_win_dem ///
	, by(county year)

label var partisan_yr "Partisan"
label var avg_vote_margin "Vote Margin"
label var avg_cand "Num Candidates"
label var avg_oneparty "One-Party"
label var n_races "Num Races"
label var n_win_rep "Races Win Rep"
label var n_close "Num Close"
label var n_close_nonpartisan "Num Close Nonpartisan"
label var n_close_partisan "Num Close Partisan"
label var n_close_win_rep "Num Close Win Rep"
label var n_close_win_dem "Num Close Win Dem"
label var n_unopp "Num Unopposed"
label var pct_unopp "Pct Unopposed"
	
*Gen partisan_ever = if county is ever partisan
gegen partisan_ever = max(partisan_yr), by(county)

*Gen year when a county switches
sort county year
by county: gen temp1 = 1 if partisan_yr == 1 & partisan_yr[_n-1] == 0 	
gen temp2 = year if temp1 == 1	
gegen year_to_partisan = max(temp2), by(county)
drop temp1 temp2
*how many counties?
gunique county
*100 counties, and NC has exactly 100, good
*821 county-year obs
*how many counties ever partisan?
gunique county if partisan_ever == 1
*49 counties turn partisan, 51 counties haven't

*how many counties that switch since 2010?
gegen temp1 = min(partisan_yr), by(county)
gegen temp2 = max(partisan_yr), by(county)
gen county_switch = 1 if temp1 != temp2
replace county_switch = 0 if county_switch == .
tab county_switch
/*
county_swit |
         ch |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |        538       65.53       65.53
          1 |        283       34.47      100.00
------------+-----------------------------------
      Total |        821      100.00
*/
gunique county if county_switch == 1
*35 counties switch, meaning that 14 counties are already partisan by 2010
drop temp*
gen switch_pre2010 = 1 if partisan_ever == 1 & county_switch == 0
replace switch_pre2010 = 0 if switch_pre2010 == .

*Number of close races over time by county-year?
tab n_close
/*
  Num Close |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |        381       46.41       46.41
          1 |        393       47.87       94.28
          2 |         41        4.99       99.27
          3 |          6        0.73      100.00
------------+-----------------------------------
      Total |        821      100.00
*/
*gen % of close races in a county-year
gen pct_close = n_close / n_races
sum pct_close, d
/*
                          pct_close
-------------------------------------------------------------
      Percentiles      Smallest
 1%            0              0
 5%            0              0
10%            0              0       Obs                 821
25%            0              0       Sum of wgt.         821

50%           .2                      Mean            .405208
                        Largest       Std. dev.      .4476237
75%            1              1
90%            1              1       Variance        .200367
95%            1              1       Skewness       .4428955
99%            1              1       Kurtosis       1.372119
*/

/*gen indicator for county ever having close
gen close_dummy = 1 if n_close > 0
replace close_dummy = 0 if close_dummy == .
gegen close_ever = max(close_dummy), by(county)
*How many counties with close ever?
gunique county if close_ever == 1
*93 counties; so, almost all counties have a close election sometime
*/

*How many counties have close partisan elections?
gunique county if n_close_partisan == 1
*34 counties
gunique county year if n_close_partisan == 1
*105 county-years
gunique county if n_close_win_rep == 1
*32 counties
gunique county if n_close_win_dem == 1
*17 counties

*Number of unopposed races over time by county-year?
tab n_unopp
/*
        Num |
  Unopposed |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |        449       54.69       54.69
          1 |        124       15.10       69.79
          2 |        119       14.49       84.29
          3 |         84       10.23       94.52
          4 |         29        3.53       98.05
          5 |          9        1.10       99.15
          6 |          5        0.61       99.76
          7 |          2        0.24      100.00
------------+-----------------------------------
      Total |        821      100.00

*/
pwcorr partisan_yr n_unopp, star(0.05)
*corr = 0.0838, statistically significant at the 5% level

*save file
save "$NCElec\260317_schoolboard_countyyrlevel.dta", replace

**# Bookmark #3
*Get data for chart of avg vote margin over time by partisan and not. Want to start from the election-level, then average across. Don't need this to be at the county-level right now
use "$NCElec\260301_schoolboard_electionlevel_clean.dta", clear

preserve
drop if vote_margin == 1
gcollapse (mean) vote_margin, by(year partisan_yr)
keep if mod(year,2) == 0
sort partisan_yr year
restore

preserve
gcollapse (mean) n_candidates, by(year partisan_yr)
keep if mod(year,2) == 0
sort partisan_yr year
restore

*Switch to county-year data for county-level trends
use "$NCElec\260301_schoolboard_countyyrlevel.dta", clear
*drop races in odd years; these are never partisan
keep if mod(year,2) == 0

*Collapse to county level for map and switching year
preserve
gcollapse (max) partisan_ever year_to_partisan county_switch switch_pre2010 ///
	, by(county)	
tab year_to_partisan
/*

      (max) |
year_to_par |
      tisan |      Freq.     Percent        Cum.
------------+-----------------------------------
       2014 |          2        5.71        5.71
       2016 |          6       17.14       22.86
       2017 |          1        2.86       25.71
       2018 |         11       31.43       57.14
       2020 |          2        5.71       62.86
       2022 |          3        8.57       71.43
       2024 |         10       28.57      100.00
------------+-----------------------------------
      Total |         35      100.00

*/
*saved this down to 260301_county_partisan_list.csv
restore

*Also want to make map as of 2010, 2016, 2018
preserve
keep if inlist(year,2010,2016,2018)
gcollapse (max) partisan_yr year_to_partisan county_switch switch_pre2010  ///
	, by(county year)	
export delimited using "$NCElec\260302_county_partisan_2010_2016_2018.csv", replace
restore
	
*Collapse to year-level for graph of how many counties are partisan in any given year
preserve
gcollapse (sum) partisan_yr, by(year)
*saved this down to 260301_election_graphs.csv
restore		
	
*Collapse to year level to graph how many counties have close partisan elections over time
*Collapse to year level to graph how many counties have close partisan elections won by reps vs. dems over time
gen close_partisan_dummy = 1 if n_close_partisan > 0
gen close_win_rep_dummy = 1 if n_close_win_rep > 0
gen close_win_dem_dummy = 1 if n_close_win_dem > 0
replace close_partisan_dummy = 0 if close_partisan_dummy == .
replace close_win_rep_dummy = 0 if close_win_rep_dummy == .
replace close_win_dem_dummy = 0 if close_win_dem_dummy == .

count if close_partisan > 0 & year == 2010

gcollapse (sum) close_partisan_dummy close_win_rep_dummy close_win_dem_dummy, by(year)
