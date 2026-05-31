************************
*Voting on bonds       *
*Add rating variables  *
*Last updated: 11/19/25*
************************

***Set up globals***
global MAIN "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
*global MAIN "C:\Users\jxh230025\Dropbox\Voting on Bonds"
global DATA "$MAIN\Data"
global MERGENT "$DATA\Mergent"
global BEA "$DATA\BEA"
global TX "$DATA\TX"
global DESCRIPT "$MAIN\Descriptives"
global RESULTS "$MAIN\Results\2025-10_results"

**# Bookmark #1
*Start with main city file with yield spreads and update state law classifications*
use "$MERGENT\Clean\251027_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

*Make ordinal rating variables*

*I think somehow, the moody's and S&P ratings got switched around 
*switch these back

rename (rating_s rating_action_s rating_date_s) (rating_moody rating_action_moody rating_date_moody)
rename  (rating_m rating_action_m rating_date_m) (rating_s rating_action_s rating_date_s)
rename (rating_moody rating_action_moody rating_date_moody) (rating_m rating_action_m rating_date_m)

*fix typo in #Aaa in moody's
replace rating_m = "Aaa" if rating_m == "#Aaa"

tab rating_f
/*
   rating_f |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |        384        6.64        6.64
         A+ |        610       10.55       17.19
         A- |        156        2.70       19.89
         AA |      1,120       19.37       39.25
        AA+ |        767       13.26       52.52
        AA- |        814       14.08       66.59
        AAA |      1,714       29.64       96.23
        BB- |          2        0.03       96.26
        BBB |         26        0.45       96.71
       BBB+ |        140        2.42       99.14
       BBB- |         29        0.50       99.64
          W |         21        0.36      100.00
------------+-----------------------------------
      Total |      5,783      100.00
*/

tab rating_m
/*
   rating_m |      Freq.     Percent        Cum.
------------+-----------------------------------
         A1 |      5,832       11.52       11.52
         A2 |      3,409        6.74       18.26
         A3 |      2,002        3.96       22.22
        Aa1 |      6,433       12.71       34.93
        Aa2 |     14,698       29.05       63.98
        Aa3 |     10,415       20.58       84.56
        Aaa |      6,497       12.84       97.40
        Ba1 |          7        0.01       97.41
        Ba2 |         11        0.02       97.43
       Baa1 |        708        1.40       98.83
       Baa2 |        331        0.65       99.48
       Baa3 |        246        0.49       99.97
         WR |         15        0.03      100.00
------------+-----------------------------------
      Total |     50,604      100.00
*/

tab rating_s
/*
   rating_s |      Freq.     Percent        Cum.
------------+-----------------------------------
          A |      5,011        7.02        7.02
         A+ |      8,111       11.36       18.38
         A- |      2,028        2.84       21.22
         AA |     14,739       20.64       41.86
        AA+ |      9,143       12.81       54.67
        AA- |     10,424       14.60       69.27
        AAA |     20,746       29.06       98.32
          B |          2        0.00       98.32
         B+ |         22        0.03       98.35
         BB |         22        0.03       98.39
        BB+ |         17        0.02       98.41
        BB- |          4        0.01       98.41
        BBB |        455        0.64       99.05
       BBB+ |        587        0.82       99.87
       BBB- |         90        0.13      100.00
------------+-----------------------------------
      Total |     71,401      100.00
*/

/*Notes
- Cuny et al. 2025: Define Low Rating = 1 if credit rating is below A- (S&P's and Fitch?) / A3 (Moodys?)
- Gao et al. 2019: Indicator variable for each possible Moody's rating, and S&P if Moody's not available
- Cuny 2018: Credit rating = 24 for Aaa, then down to D of 1
*/

*Generate low rating following Cuny et al.
gen rating_low = 1 if inlist(rating_s,"B","B+","BB","BB+","BB-","BBB","BBB+","BBB-")
replace rating_low = 1 if rating_low == . & inlist(rating_m,"Ba1","Ba2","Baa1","Baa2","Baa3","WR")
replace rating_low = 1 if rating_low == . & inlist(rating_f,"BB-","BBB","BBB+","BBB-","W")
replace rating_low = 0 if rating_low == . & rated == 1
tab rating_low
/*
 rating_low |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    101,163       97.57       97.57
          1 |      2,520        2.43      100.00
------------+-----------------------------------
      Total |    103,683      100.00
*/

*Generate var for rating FE like Gao et al. 2019:
gen rating_fe = rating_m if rating_m != ""
replace rating_fe = rating_s if rating_m == "" & rating_s != ""
replace rating_fe = rating_f if rating_m == "" & rating_s == "" & rating_f != ""
replace rating_fe = "Unrated" if rating_fe == ""
*Make into numeric
gegen rating_fe_id = group(rating_fe)

*Gen var where each "level" of rating is its own number
/*Moodys ~ S&P / Fitch
Aaa ~ AAA -- 16
Aa1 ~ AA+ -- 15
Aa2 ~ AA -- 14
Aa3 ~ AA- --13
A1 ~ A+ --12
A2 ~ A --11
A3 ~ A- --10
Baa1 ~ BBB+ --9
Baa2 ~ BBB --8
Baa3 ~ BBB- --7
Ba1 ~ BB+ --6
Ba2 ~ BB --5
Ba3 ~ BB- --4
    ~ B+ --3
	~ B --2
WR ~ W in Fitch --1
*/
*Do Moody's first; if mismatch, take Moody's
gen rating_num = 16 if rating_m == "Aaa"
replace rating_num = 15 if rating_m == "Aa1"
replace rating_num = 14 if rating_m == "Aa2"
replace rating_num = 13 if rating_m == "Aa3"
replace rating_num = 12 if rating_m == "A1"
replace rating_num = 11 if rating_m == "A2"
replace rating_num = 10 if rating_m == "A3"
replace rating_num = 9 if rating_m == "Baa1"
replace rating_num = 8 if rating_m == "Baa2"
replace rating_num = 7 if rating_m == "Baa3"
replace rating_num = 6 if rating_m == "Ba1"
replace rating_num = 5 if rating_m == "Ba2"
replace rating_num = 4 if rating_m == "Ba3"
replace rating_num = 1 if rating_m == "WR"
*Do S&P
replace rating_num = 16 if rating_num == . & rating_s == "AAA"
replace rating_num = 15 if rating_num == . & rating_s == "AA+"
replace rating_num = 14 if rating_num == . & rating_s == "AA"
replace rating_num = 13 if rating_num == . & rating_s == "AA-"
replace rating_num = 12 if rating_num == . & rating_s == "A+"
replace rating_num = 11 if rating_num == . & rating_s == "A"
replace rating_num = 10 if rating_num == . & rating_s == "A-"
replace rating_num = 9 if rating_num == . & rating_s == "BBB+"
replace rating_num = 8 if rating_num == . & rating_s == "BBB"
replace rating_num = 7 if rating_num == . & rating_s == "BBB-"
replace rating_num = 6 if rating_num == . & rating_s == "BB+"
replace rating_num = 5 if rating_num == . & rating_s == "BB"
replace rating_num = 4 if rating_num == . & rating_s == "BB-"
replace rating_num = 3 if rating_num == . & rating_s == "B+"
replace rating_num = 2 if rating_num == . & rating_s == "B"
*Do Fitch
replace rating_num = 16 if rating_num == . & rating_f == "AAA"
replace rating_num = 15 if rating_num == . & rating_f == "AA+"
replace rating_num = 14 if rating_num == . & rating_f == "AA"
replace rating_num = 13 if rating_num == . & rating_f == "AA-"
replace rating_num = 12 if rating_num == . & rating_f == "A+"
replace rating_num = 11 if rating_num == . & rating_f == "A"
replace rating_num = 10 if rating_num == . & rating_f == "A-"
replace rating_num = 9 if rating_num == . & rating_f == "BBB+"
replace rating_num = 8 if rating_num == . & rating_f == "BBB"
replace rating_num = 7 if rating_num == . & rating_f == "BBB-"
replace rating_num = 6 if rating_num == . & rating_f == "BB+"
replace rating_num = 5 if rating_num == . & rating_f == "BB"
replace rating_num = 4 if rating_num == . & rating_f == "BB-"
replace rating_num = 3 if rating_num == . & rating_f == "B+"
replace rating_num = 2 if rating_num == . & rating_f == "B"
replace rating_num = 1 if rating_num == . & rating_f == "W"

count if rating_num == .
count if rated == 0
*good, these are the same
replace rating_num = 0 if rated == 0

*save file
save "$MERGENT\Clean\251119_city_cusiplevel_statereq_purpose_yieldspread.dta", replace


use "$MERGENT\Clean\251119_city_cusiplevel_statereq_purpose_yieldspread.dta", clear

*Yield spreads in our sample:
gen temp1 = 1 if inlist(state,"MI","OH","WA")
sum offering_yield_spread if city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 1.50
sum offering_yield_spread if bond_type == "go" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 1.42
sum offering_yield_spread if bond_type == "rev" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 1.58
sum offering_yield_spread if bond_type == "go" & rating_num == 16 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 1.36
sum offering_yield_spread if bond_type == "go" & rating_num == 9 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 1.69
sum offering_yield_spread if bond_type == "rev" & rating_num == 16 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 1.83
sum offering_yield_spread if bond_type == "rev" & rating_num == 9 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 2.07

*No vote states:
sum offering_yield_spread if city_go_vote == 0 & city_rev_vote == 0 
*avg = 1.29
sum offering_yield_spread if bond_type == "go" & city_go_vote == 0 & city_rev_vote == 0 
*avg = 1.24
sum offering_yield_spread if bond_type == "rev" & city_go_vote == 0 & city_rev_vote == 0 
*avg = 1.54
sum offering_yield_spread if bond_type == "go" & rating_num == 16 & city_go_vote == 0 & city_rev_vote == 0 
*avg = 1.13
sum offering_yield_spread if bond_type == "go" & rating_num == 9 & city_go_vote == 0 & city_rev_vote == 0 
*avg = 2.12
sum offering_yield_spread if bond_type == "rev" & rating_num == 16 & city_go_vote == 0 & city_rev_vote == 0 
*avg = 1.76
sum offering_yield_spread if bond_type == "rev" & rating_num == 9 & city_go_vote == 0 & city_rev_vote == 0 
*avg = 1.89

*average credit rating?
sum rating_num if bond_type == "go" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1 
*4.63
sum rating_num if bond_type == "rev" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*4.98
sum rating_num if bond_type == "go" & city_go_vote == 0 & city_rev_vote == 0 
*4.36
sum rating_num if bond_type == "rev" & city_go_vote == 0 & city_rev_vote == 0 
*3.73

sum rating_num if bond_type == "go" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1 & rating_num > 1
*14.2
sum rating_num if bond_type == "rev" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1 & rating_num > 1
*13.6
sum rating_num if bond_type == "go" & city_go_vote == 0 & city_rev_vote == 0 & rating_num > 1
*13.9
sum rating_num if bond_type == "rev" & city_go_vote == 0 & city_rev_vote == 0 & rating_num > 1
*12.96

/*
Yield spreads
GO vote = 1 (light green): 1.50 
	GO bonds: 1.42
		Aaa: 1.36
		Baa1: 1.69
		Diff = 33 bp
	Rev bonds: 1.58
		Aaa: 1.83
		Baa1: 2.07
		Diff = 24 bp
	Rev - GO = 16 bp
GO vote = 0 (white): 1.29
	GO bonds: 1.24
		Aaa: 1.13
		Baa1: 2.12
		Diff = 0.99 bps
	Rev bonds: 1.54
		Aaa: 1.76
		Baa1: 1.89
		Diff = 0.13 bps
	Rev - GO = 30 bps
*/

sum offering_yield if city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*average is 3.27
sum offering_yield if bond_type == "go" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 3.15
sum offering_yield if bond_type == "rev" & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 3.38
sum offering_yield if bond_type == "go" & rating_num == 16 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 3.14
sum offering_yield if bond_type == "go" & rating_num == 9 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 3.06
sum offering_yield if bond_type == "rev" & rating_num == 16 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 4.16
sum offering_yield if bond_type == "rev" & rating_num == 9 & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
*avg = 3.49

/*
Offering yields
GO vote = 1 (light green): 3.27
	GO bonds: 3.15
		Aaa: 3.14
		Baa3: 3.06
	Rev bonds: 3.38
		Aaa: 4.16
		Baa3: 3.49
	Rev - GO = 23 bp
GO vote = 0 (white)
	GO bonds
		Aaa:
		Ba1:
	Rev bonds
		Aaa:
		Ba1:
*/
*Why are the yields weirder for Baa3 revenue bonds?

forvalues x = 0(1)16{
	sum offering_yield_spread if bond_type == "go" & rating_num == `x' & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
}

forvalues x = 0(1)16{
	sum offering_yield_spread if bond_type == "rev" & rating_num == `x' & city_go_vote == 1 & city_rev_vote == 0 & temp1 != 1
}
*Obs start to drop off after rating_num = 9, which is Baa1