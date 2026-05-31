****************************
*Voting on bonds           *
*Clean data for Texas pilot*
*Last updated: 11/21/24    *
****************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA/TX"

***Start with issue-level file of merged Mergent + MSRB***
use "$MERGENT\Clean\241120_issue_level.dta", clear

*Get unique seed issuer names for TX cities and counties
keep if state == "TX" & inlist(issuer_type,"city","county")
*1,758 issuances
*make seed_issuer not strL for later rangejoin
gen temp1 = seed_issuer
drop seed_issuer
rename temp1 seed_issuer
order seed_issuer, after(state)
*save file
save "$TX\241120_tx_issue_level.dta", replace
*get list of unique seed issuer names to match to TX voting data
preserve
keep seed_issuer seed_issuer_id
duplicates drop
count
*357 seed issuers
export delimited using "$TX\241120_tx_seedissuer_formatch.csv", replace
restore

*Fuzzy matched these names, then merge in crosswalk to TX BRB names
use "$TX/240512_TX_uniquegovt_election_issuance.dta", clear
*make uppercase names
gen muni_upper = upper(muni_formatch)
*merge in fuzzy matched crosswalk to get governmentname (TX BRB identifier)
mmerge muni_upper using "$TX\241120_tx_uniquegovt_fuzzymatch_crosswalk.dta", ///
	type(1:n) missing(nomatch)
/*
                 obs |    939
                vars |     11  (including _merge)
         ------------+---------------------------------------------------------
              _merge |    606  obs only in master data                (code==1)
                     |    333  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
keep if _merge == 3
drop _merge match
sort muni_id_formatch
order governmentname muni_upper seed_issuer county
drop governmenttype issuername muni_formatch muni_id_formatch
duplicates tag governmentname, gen(dup)
*br if dup > 0
*2 dups, fix these
drop if governmentname == "Burkburnett" & seed_issuer == "BURNET TEX"
drop if governmentname == "El Paso" & seed_issuer == "EL PA"
drop dup
*save, then merge into voting data 
save "$TX\241120_tx_uniquegovt_fuzzymatch_crosswalk_step2.dta", replace

*Start with voting data, then merge in
use "$TX/240510_TX_local_election.dta", clear
mmerge governmentname using "$TX\241120_tx_uniquegovt_fuzzymatch_crosswalk_step2.dta", ///
	type(n:1) missing(nomatch)
/*
                 obs |   9082
                vars |     16  (including _merge)
         ------------+---------------------------------------------------------
              _merge |   7187  obs only in master data                (code==1)
                     |     81  obs only in using data                 (code==2)
                     |   1814  obs both in master and using data      (code==3)
-------------------------------------------------------------------------------
*/
sort seed_issuer
*not matched are typically school districts and special districts
keep if _merge == 3
drop _merge
order seed_issuer electiondate amount votesfor votesagainst result purpose, before(governmentname)

*clean election date
gen temp1 = date(electiondate, "MDY")
format temp1 %td 
gen year = year(temp1)
gen month = month(temp1)
rename temp1 date_election
order date_election year month, after(seed_issuer)
drop electiondate

*clean result
tab result
/*
     Result |      Freq.     Percent        Cum.
------------+-----------------------------------
  Cancelled |         20        1.10        1.10
    Carried |      1,601       88.26       89.36
   Defeated |        187       10.31       99.67
         NR |          6        0.33      100.00
------------+-----------------------------------
      Total |      1,814      100.00
*/

*gen winning margin
gen votestotal = votesfor + votesagainst
gen votemargin = (votesfor - votesagainst) / votestotal if result == "Carried"
replace votemargin = (votesagainst - votesfor) / votestotal if result == "Defeated"
*br if votemargin == .
*missing if cancelled or too old, makes sense
order votemargin votestotal votesfor votesagainst, after(result)

sort seed_issuer date_election

*Mergent data has 2000-2020; only keep voting years from 1995 (not clear how long it takes to issue) to 2020
sum year
*voting data goes from 1953 to 2024
keep if inrange(year,1995,2020)

*Note that the voting data is at the proposition level. One bond issuance is made up of multiple propositions
*Also, defeated proposals won't have bonds issued, so won't be in the Mergent data at all
replace votemargin = . if result == "Defeated"
rename votemargin winmargin
sum winmargin, d
/*
                          winmargin
-------------------------------------------------------------
      Percentiles      Smallest
 1%     .0122358       .0001714
 5%     .0620388       .0014202
10%     .1240106           .002       Obs               1,251
25%      .247251       .0020346       Sum of wgt.       1,251

50%     .4207759                      Mean            .479586
                        Largest       Std. dev.       .299249
75%     .6461039              1
90%            1              1       Variance         .08955
95%            1              1       Skewness       .5231053
99%            1              1       Kurtosis       2.219901
*/
*They usually win pretty handily

*only keep if carried
keep if result == "Carried"
*drop if winmargin == 1, these are data errors
drop if winmargin == 1

*Later, realized a typo in San Antonio's date for the May 12, 2007 election. Fix:
replace date_election = date("05/12/2007", "MDY") if seed_issuer == "SAN ANTONIO TEX" & year == 2007

/*How to deal with the dates:
- Suppose there is an earlier vote, A, and a later vote, B
- If the offering_date is after date_A but before date_B, then match it to A's voting data
- How to use Stata to merge in this way? I think there's a way in SAS
- Try rangejoin
*/
*ssc install rangejoin

*First issue is how to aggregate voting data to the date_election-level
*Simplest way is to sum votesfor and votesagainst and calc new winmargin, though it isn't really accurate
*Other way is to calculate average winmargin and min to get at "how competitive were these really"
*Maybe that better reflects overall sentiment
gegen avg_winmargin = mean(winmargin), by(seed_issuer date_election)
gegen min_winmargin = min(winmargin), by(seed_issuer date_election)
*gen weighted avg win margin based on amount
*Calc total amount
gegen amount_total = sum(amount), by(seed_issuer date_election)
gen temp1 = winmargin * amount
gegen temp2 = sum(temp1), by(seed_issuer date_election)
gen temp3 = temp2 / amount_total
rename temp3 wavg_winmargin
drop temp*

drop amount result winmargin votestotal votesfor votesagainst purpose purposedescription propnumber source
order amount_total min_winmargin avg_winmargin wavg_winmargin, after(month)
drop governmentname governmenttype county muni_upper
*collapse
gcollapse (mean) amount_total avg_winmargin min_winmargin wavg_winmargin, by(seed_issuer date_election year month)

*To use rangejoin, need a var for each election date that has the last range
*gen running var for each date_election in an issuer
by seed_issuer: gen date_id = _n
*gen total dates
gegen n_dates = count(date_election), by(seed_issuer)
tab n_dates
/*
    n_dates |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |        117       30.00       30.00
          2 |         98       25.13       55.13
          3 |         81       20.77       75.90
          4 |         28        7.18       83.08
          5 |         15        3.85       86.92
          6 |         18        4.62       91.54
          7 |          7        1.79       93.33
          8 |         16        4.10       97.44
         10 |         10        2.56      100.00
------------+-----------------------------------
      Total |        390      100.00
*/
*For n_dates = 1, can make last day of range by 12/31/2020
gen date_last = date("12/31/2020", "MDY") if n_dates == 1
format date_last %td

*For an issuer with 2 elections, make the date_last of the FIRST election = date of second election
gegen temp1 = max(date_election) if n_dates == 2, by(seed_issuer)
replace temp1 = . if date_id == 2
format temp1 %td
*make the date_last of the SECOND election = 12/31/2020
replace temp1 = date("12/31/2020", "MDY") if n_dates == 2 & date_id == 2
replace date_last = temp1 if date_last == . & temp1 != .
drop temp1

*For an issuer with 3 elections:
*Make date_last of FIRST election = date of second election
gen temp1 = date_election if n_dates == 3 & date_id == 2
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 3 & date_id == 1
drop temp*
*Make date_last of SECOND election = date of third election
gen temp1 = date_election if n_dates == 3 & date_id == 3
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 3 & date_id == 2
drop temp*
*Make date_last of THIRD election = 12/31/2020
replace date_last = date("12/31/2020", "MDY") if date_last == . & n_dates == 3 & date_id == 3

*For an issuer with 4 elections, repeat prior steps but add an iteration:
gen temp1 = date_election if n_dates == 4 & date_id == 2
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 4 & date_id == 1
drop temp*
gen temp1 = date_election if n_dates == 4 & date_id == 3
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 4 & date_id == 2
drop temp*
gen temp1 = date_election if n_dates == 4 & date_id == 4
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 4 & date_id == 3
drop temp*
replace date_last = date("12/31/2020", "MDY") if date_last == . & n_dates == 4 & date_id == 4

*For an issuer with 5 elections:
gen temp1 = date_election if n_dates == 5 & date_id == 2
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 5 & date_id == 1
drop temp*
gen temp1 = date_election if n_dates == 5 & date_id == 3
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 5 & date_id == 2
drop temp*
gen temp1 = date_election if n_dates == 5 & date_id == 4
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 5 & date_id == 3
drop temp*
gen temp1 = date_election if n_dates == 5 & date_id == 5
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 5 & date_id == 4
drop temp*
replace date_last = date("12/31/2020", "MDY") if date_last == . & n_dates == 5 & date_id == 5

*For an issuer with 6 elections:
gen temp1 = date_election if n_dates == 6 & date_id == 2
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 6 & date_id == 1
drop temp*
gen temp1 = date_election if n_dates == 6 & date_id == 3
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 6 & date_id == 2
drop temp*
gen temp1 = date_election if n_dates == 6 & date_id == 4
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 6 & date_id == 3
drop temp*
gen temp1 = date_election if n_dates == 6 & date_id == 5
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 6 & date_id == 4
drop temp*
gen temp1 = date_election if n_dates == 6 & date_id == 6
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 6 & date_id == 5
drop temp*
replace date_last = date("12/31/2020", "MDY") if date_last == . & n_dates == 6 & date_id == 6

*For an issuer with 7 elections:
gen temp1 = date_election if n_dates == 7 & date_id == 2
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 7 & date_id == 1
drop temp*
gen temp1 = date_election if n_dates == 7 & date_id == 3
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 7 & date_id == 2
drop temp*
gen temp1 = date_election if n_dates == 7 & date_id == 4
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 7 & date_id == 3
drop temp*
gen temp1 = date_election if n_dates == 7 & date_id == 5
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 7 & date_id == 4
drop temp*
gen temp1 = date_election if n_dates == 7 & date_id == 6
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 7 & date_id == 5
drop temp*
gen temp1 = date_election if n_dates == 7 & date_id == 7
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 7 & date_id == 6
drop temp*
replace date_last = date("12/31/2020", "MDY") if date_last == . & n_dates == 7 & date_id == 7

*For an issuer with 8 elections:
gen temp1 = date_election if n_dates == 8 & date_id == 2
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 8 & date_id == 1
drop temp*
gen temp1 = date_election if n_dates == 8 & date_id == 3
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 8 & date_id == 2
drop temp*
gen temp1 = date_election if n_dates == 8 & date_id == 4
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 8 & date_id == 3
drop temp*
gen temp1 = date_election if n_dates == 8 & date_id == 5
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 8 & date_id == 4
drop temp*
gen temp1 = date_election if n_dates == 8 & date_id == 6
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 8 & date_id == 5
drop temp*
gen temp1 = date_election if n_dates == 8 & date_id == 7
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 8 & date_id == 6
drop temp*
gen temp1 = date_election if n_dates == 8 & date_id == 8
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 8 & date_id == 7
drop temp*
replace date_last = date("12/31/2020", "MDY") if date_last == . & n_dates == 8 & date_id == 8

*For an issuer with 10 elections:
gen temp1 = date_election if n_dates == 10 & date_id == 2
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 1
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 3
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 2
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 4
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 3
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 5
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 4
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 6
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 5
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 7
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 6
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 8
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 7
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 9
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 8
drop temp*
gen temp1 = date_election if n_dates == 10 & date_id == 10
format temp1 %td
gegen temp2 = max(temp1), by(seed_issuer)
format temp2 %td
replace date_last = temp2 if date_last == . & n_dates == 10 & date_id == 9
drop temp*
replace date_last = date("12/31/2020", "MDY") if date_last == . & n_dates == 10 & date_id == 10

*check if date_last is missing
count if date_last == .
*0, good
drop date_id
order year date_election date_last, after(seed_issuer)

*save
save "$TX/241121_txbrb_election_issuelevel.dta", replace

*Rangejoin this with Mergent data based on seed_issuer
*ssc install rangestat
rangejoin offering_date date_election date_last using "$TX\241120_tx_issue_level.dta", by(seed_issuer)
*clean
rename year year_election
rename month month_election
rename year_U year_issue
*order
order state seed_issuer seed_issuer_id issuer_type issue_id year_issue offering_date bond_type vote_req date_election min_winmargin
order n_dates date_last, before(qtr)
*gen month var for issuance
gen month_issue = month(offering_date)
rename qtr qtr_issue

count if state == ""
*68 elections that don't get matched
*drop these
drop if state == ""

*Note that rev bonds get matched to the election period even though the vote isn't required
*Can this help be a falsification test?

*Save file
save "$TX/241121_txmerge_election_issuelevel.dta", replace
