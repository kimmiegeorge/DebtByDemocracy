#!/usr/bin/env python3
r"""
260915_build_sourcelevel_debtlimit.py -- Debt by Democracy, 2nd R&R, PART 3A.

Build 260915_sourcelevel_debtlimit.csv: one row per source authority stating the
MUNICIPAL DEBT LIMIT (the ceiling on how much debt a general-law / home-rule city
may carry) and whether a popular vote lets the city exceed it or is required to
incur debt at all. Grounded in the EXISTING bond corpus (state constitutions +
municipal debt/finance chapters already on disk from the bond project); the tax
files (raw\<ST>\260914_*.txt) are NOT used for this dimension.

Conventions (see memory sourcelevel-schema-rules / statutes-batchb-workflow):
- ONE ROW PER SOURCE, each with its own source_url; cross-refs go in the notes.
- The section sign is the ONLY non-ASCII glyph, ONLY in `source`. Notes are plain
  ASCII ("Sec." not the glyph). CSV written UTF-8 WITH BOM (Excel renders the glyph).
- `control` preserved from the bond CSVs (control=1 only for KY, MA, MS, NH, NJ, TN, WI).
- General local governments only (cities/towns; county/other-level differences noted
  in note_votebyothergovtlevels). No school/special-district limits as the row subject.

Columns: stab, state, control, source, source_url, source_year, source_type,
source_filename, has_limit, limit_basis, threshold, vote_to_exceed, note_scope,
note_exception, note_votebyothergovtlevels.

has_limit / vote_to_exceed in {Y, N, Depends}. "vote_to_exceed" = whether a voter
vote raises/lifts the ceiling (Y), the ceiling is absolute regardless of vote (N),
or it turns on class/charter (Depends). Where the ceiling itself is expressed as
"no debt beyond the year's income/revenue without a vote", vote_to_exceed=Y.

GROUNDING NOTES (hand-checked 2026-09-15 against the corpus):
- AZ art. IX Sec. 8 and KY Const. Sec. 157/158 primary text are NOT on disk (the
  pilot AZ constitution file is a partial and the KY constitution file is a TOC-only
  stub); each debt limit is instead grounded on the on-disk implementing STATUTE
  (Ariz. Rev. Stat. Sec. 35-451; Ky. Rev. Stat. Sec. 66.041), flagged in note_scope.
- FL / AK / MD / TN / TX = no fixed percentage-of-value municipal debt ceiling found
  in the corpus (true absence in general law, or charter-set) -- flagged, not invented.
"""
from __future__ import annotations
from pathlib import Path
import polars as pl

OUT = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
          r"\Data\Statutes\260915_sourcelevel_debtlimit.csv")

COLS = ["stab", "state", "control", "source", "source_url", "source_year",
        "source_type", "source_filename", "has_limit", "limit_basis", "threshold",
        "vote_to_exceed", "limit_exceedable", "note_scope", "note_exception",
        "note_votebyothergovtlevels"]

# limit_exceedable: conditional on has_limit, can the stated ceiling be exceeded by
# ANY mechanism? Y = yes (popular vote, legislative special act, state board/officer,
# or a higher voted tier); N = strictly binding hard cap (no override mechanism);
# Depends = charter/class-dependent or override mechanism uncertain in corpus;
# N/A = no limit exists (has_limit=N). vote_to_exceed already isolates the popular-vote
# route, so (vote_to_exceed=N, limit_exceedable=Y) = raisable but NOT by popular vote
# (RI Gen. Assembly/director; MA oversight board; NJ Local Finance Board), while
# (vote_to_exceed=N, limit_exceedable=N) = a hard cap (WV, GA, IN, NM, etc.).
EXCEEDABLE = {
    # Y via popular vote (these are the vote_to_exceed=Y rows)
    "AZ": "Y", "AR": "Y", "CA": "Y", "ID": "Y", "MO": "Y", "ND": "Y", "OH": "Y",
    "OK": "Y", "PA": "Y", "SC": "Y", "UT": "Y", "WA": "Y",
    # Y via a NON-popular-vote mechanism
    "MA": "Y",   # Municipal Finance Oversight Board raises 5% -> 10%
    "NJ": "Y",   # Local Finance Board may authorize debt beyond the limit (Sec. 40A:2-7)
    "RI": "Y",   # General Assembly special act / state director of revenue (Sec. 45-12-4)
    # N: strictly binding hard cap (no override mechanism found)
    "AL": "N", "CO": "N", "GA": "N", "IA": "N", "IN": "N", "KS": "N", "KY": "N",
    "LA": "N", "ME": "N", "MI": "N", "MN": "N", "MS": "N", "MT": "N", "NC": "N",
    "NH": "N", "NM": "N", "NV": "N", "NY": "N", "OR": "N", "SD": "N", "VA": "N",
    "VT": "N", "WI": "N", "WV": "N", "WY": "N",
    # Depends: charter/class-dependent, or override mechanism uncertain in corpus
    "CT": "Depends",   # special-act overrides plausible but not cleanly grounded in corpus
    "DE": "Depends",   # 16% for Wilmington; other cities charter-set
    "IL": "Depends",   # home-rule: no limit; non-home-rule 8.625% (referendum-raise not grounded)
    "MD": "Depends",   # charter/public-local-law
    "NE": "Depends",   # purpose-based statutory caps
    "TX": "Depends",   # no fixed % cap; tax-rate/charter constrained
    # N/A: no limit exists
    "AK": "N/A", "FL": "N/A", "TN": "N/A",
}

J = "https://law.justia.com/codes"
JC = "https://law.justia.com/constitution"
SECT = "\u00a7"
NONE = "None indicated"


def R(**kw):
    base = dict(control=0, source_type="primary", source_year=2025,
                has_limit=NONE, limit_basis=NONE, threshold=NONE,
                vote_to_exceed=NONE, note_scope=NONE, note_exception=NONE,
                note_votebyothergovtlevels=NONE)
    base.update(kw)
    return base


ROWS = [
    # ==================== ALASKA ====================
    R(stab="AK", state="alaska",
      source=f"Alaska Stat. ch. 29.47 (municipal bonds)",
      source_url=f"{J}/alaska/title-29/chapter-47/",
      source_filename="AK/alaska_title-29.txt",
      has_limit="N", limit_basis="No percentage-of-value debt ceiling in general law",
      threshold=NONE, vote_to_exceed="N/A",
      note_scope="General-law and home-rule boroughs and cities. Title 29 conditions GO bonds on a majority vote (AS 29.47.190) but sets NO percentage debt limit; home-rule municipalities may set limits by charter (charter text not in corpus)",
      note_exception="Revenue bonds need no vote (AS 29.47.250)",
      note_votebyothergovtlevels="Boroughs are municipalities (AS 01.10.060) under the same Title 29 framework"),

    # ==================== ALABAMA ====================
    R(stab="AL", state="alabama",
      source=f"Ala. Const. {SECT} 225 (municipal indebtedness limit)",
      source_url=f"{JC}/alabama/",
      source_year=2022,
      source_filename="AL/alabama_constitution.txt",
      has_limit="Y", limit_basis="Percent of assessed value of property in the municipality",
      threshold="5% (cities/towns under 6,000 population) plus an additional 3% for waterworks, gas or electric plants, sewerage, or street improvements",
      vote_to_exceed="N",
      note_scope="Quote: 'No city, town, or other municipal corporation having a population of less than six thousand ... shall become indebted ... exceeding five per centum of the assessed value of the property therein, except for the construction of or purchase of water works, gas, or electric lighting plants, or sewerage, or for the improvement of streets, for which purposes an additional indebtedness not exceeding three per centum may be created' (Sec. 225). Sec. 225 continues with a parallel provision for cities of 6,000 or more",
      note_exception="Does not affect debt authorized by other law, or temporary loans repaid within one year; GO bonds separately require a majority vote (Sec. 222); Sheffield and Tuscumbia excepted",
      note_votebyothergovtlevels="Counties limited to 3.5% of assessed value (Sec. 224), with an additional 1.5% for counties already over the limit"),

    # ==================== ARIZONA ====================
    R(stab="AZ", state="arizona",
      source=f"Ariz. Const. art. IX, {SECT} 8 (local debt limits; assent of taxpayers)",
      source_url="https://law.justia.com/constitution/arizona/9/8.htm",
      source_filename="AZ/260915_arizona_constitution-article-ix-bodies.txt",
      has_limit="Y", limit_basis="Percent of taxable property in the municipality",
      threshold="6% without a vote; a majority vote of the property-taxpayer electors is required to exceed 6%; an additional 20% (with such assent) for municipally owned water, artificial light or sewers and for open space preserves, parks, playgrounds and recreational facilities",
      vote_to_exceed="Y",
      note_scope="Quote: 'No county, city, town, school district, or other municipal corporation shall for any purpose become indebted in any manner to an amount exceeding six per centum of the taxable property ... without the assent of a majority of the property taxpayers, who must also in all respects be qualified electors, therein voting at an election' (art. IX Sec. 8). Implementing statute: Ariz. Rev. Stat. Sec. 35-451 ('may be increased above six percent ... only as provided in this article'), election under Sec. 35-452 (ordered on petition of 15% of electors)",
      note_exception="With voter assent an incorporated city or town may add up to 20% additional for municipally owned water, light or sewers and for open space/parks/playgrounds/recreational facilities (art. IX Sec. 8)",
      note_votebyothergovtlevels="The 6% base applies to counties, towns, and school districts; counties and school districts may under no circumstances exceed 15% of taxable property (art. IX Sec. 8)"),

    # ==================== ARKANSAS ====================
    R(stab="AR", state="arkansas",
      source=f"Ark. Const. art. 12, {SECT} 4 (Amend. 10; current-revenue limit)",
      source_url=f"{JC}/arkansas/",
      source_year=2024,
      source_filename="AR/260615_arkansas_constitution.txt",
      has_limit="Y", limit_basis="Current fiscal-year revenue (municipalities may not contract debt beyond the year's revenue)",
      threshold="No contract or evidence of indebtedness in excess of the revenue for the current fiscal year",
      vote_to_exceed="Y",
      note_scope="Quote: 'nor shall any city council ... enter into any contract or make any allowance for any purpose whatsoever, or authorize the issuance of any ... evidences of indebtedness in excess of the revenue for such city or town for the current fiscal year' (art. 12 Sec. 4, as amended by Amend. 10)",
      note_exception="Local capital-improvement (GO) bonds approved by a majority of the electors under Amendment 62 / Ark. Code Sec. 14-164-309 are the voter-approved route to fund capital debt beyond the current-year limit; refunding excepted",
      note_votebyothergovtlevels="The same current-year-revenue limit applies to counties and incorporated towns (art. 12 Sec. 4)"),

    # ==================== CALIFORNIA ====================
    R(stab="CA", state="california",
      source=f"Cal. Const. art. XVI, {SECT} 18 (debt limit)",
      source_url=f"{JC}/california/article-xvi/section-18/",
      source_filename="CA/260615_california_constitution.txt",
      has_limit="Y", limit_basis="Annual income and revenue provided for the year",
      threshold="May not incur indebtedness or liability exceeding the year's income and revenue without a two-thirds vote",
      vote_to_exceed="Y",
      note_scope="Quote: a city, county or town may not 'incur any indebtedness or liability ... exceeding in any year the income and revenue provided for such year without the assent of two-thirds of the voters' (art. XVI Sec. 18). No fixed percentage-of-value cap; the limit is the year's revenue unless voters approve",
      note_exception="Revenue bonds payable solely from enterprise revenues are not 'indebtedness' (special-fund doctrine) and are outside this limit; a majority (not two-thirds) vote suffices for bonds to repair structurally unsafe school buildings",
      note_votebyothergovtlevels="The two-thirds requirement applies alike to counties, cities, towns, school districts"),

    # ==================== COLORADO ====================
    R(stab="CO", state="colorado",
      source=f"Colo. Rev. Stat. {SECT} 31-15-302 (municipal indebtedness limit)",
      source_url=f"{J}/colorado/title-31/powers-and-functions-of-cities-and-towns/article-15/part-3/section-31-15-302/",
      source_year=2024,
      source_filename="CO/260615_colorado_title-31.txt",
      has_limit="Y", limit_basis="Percent of actual value of taxable property (as determined by the assessor)",
      threshold="3% of actual value (debt to supply water is exempt from the 3% cap)",
      vote_to_exceed="N",
      note_scope="Quote: 'indebtedness for all such purposes shall not at any time exceed three percent of the actual value ... of the taxable property in the municipality except such debt as may be incurred in supplying water' (Sec. 31-15-302(1)(d)(II)). Any municipal debt also requires a majority vote (Sec. 31-15-302) and TABOR voter approval (Const. art. X Sec. 20)",
      note_exception="Water debt is exempt from both the 3% cap and the 30-year maturity limit",
      note_votebyothergovtlevels="Counties must obtain a majority vote to fund indebtedness (Sec. 30-26-102); TABOR (art. X Sec. 20) applies to all districts"),

    # ==================== CONNECTICUT ====================
    R(stab="CT", state="connecticut",
      source=f"Conn. Gen. Stat. {SECT} 7-374 (debt limitation)",
      source_url=f"{J}/connecticut/title-7/chapter-109/section-7-374/",
      source_year=2024,
      source_filename="CT/260625_connecticut_title-7.txt",
      has_limit="Y", limit_basis="Multiple of annual tax receipts (not a percentage of property value)",
      threshold="Total indebtedness may not exceed 7 times annual tax receipts, with category sub-limits: general purposes 2.25x; urban renewal 3.25x; water pollution control 3.75x; school building 4.5x; unfunded past pension obligation 3x (Sec. 7-374(b))",
      vote_to_exceed="N",
      note_scope="Connecticut caps municipal debt by category as multiples of 'the annual receipts from taxation' rather than by a percentage of assessed value: general purposes 'two and one-quarter'; urban renewal 'three and one-quarter'; water pollution control 'three and three-quarters'; school building 'four and one-half'; unfunded past benefit obligation 'three'; and total debt not more than seven times (Sec. 7-374(b)). Whether a bond issue must be submitted to voters is governed by the municipal charter, not the general statutes",
      note_exception="Refunding bonds, and self-liquidating/revenue obligations, are excluded from the Sec. 7-374 limit; special-act authorities (e.g. parking, Sec. 7-206a) are exempt from any statutory indebtedness limitation",
      note_votebyothergovtlevels="Applies to any municipality as defined in Sec. 7-369 (towns, cities, boroughs, districts)"),

    # ==================== DELAWARE ====================
    R(stab="DE", state="delaware",
      source=f"22 Del. C. {SECT} 106 (municipal debt limit)",
      source_url=f"{J}/delaware/title-22/chapter-1/section-106/",
      source_filename="DE/260625_delaware_title-22.txt",
      has_limit="Depends", limit_basis="Percent of assessed valuation of taxable real estate (for large cities); charter-set for other municipalities",
      threshold="16% of assessed valuation of taxable real estate for cities over 50,000 population (e.g. Wilmington); other municipalities' limits are fixed by their special-act charters",
      vote_to_exceed="Depends",
      note_scope="Quote: bonds are capped at 'sixteen percent of the assessed valuation of real estate taxable by such city' for cities over 50,000 (Sec. 106); most Delaware municipalities' borrowing power and any debt ceiling are set by special-act charters (charters not in the downloaded Title 22 corpus -- documented gap)",
      note_exception="Six categories are excluded from the Sec. 106 limit (Sec. 106(a)(1)-(6)): water bonds; sewer bonds with rates/fees; school bonds up to 3%; other law-authorized exclusions (parking authority, urban renewal); guaranties excluded by their authorizing law; and bonds funding outstanding notes",
      note_votebyothergovtlevels="Counties borrow under Title 9; whether a bond referendum is required is charter-based"),

    # ==================== FLORIDA ====================
    R(stab="FL", state="florida",
      source=f"Fla. Const. art. VII, {SECT} 12 (local bonds)",
      source_url=f"{JC}/florida/",
      source_filename="FL/260615_florida_constitution.txt",
      has_limit="N", limit_basis="No percentage-of-value municipal debt ceiling",
      threshold=NONE, vote_to_exceed="N/A",
      note_scope="Florida imposes no percentage-of-value debt limit on municipalities. Instead, bonds payable from ad valorem taxation and maturing more than 12 months out must be approved by a vote of the electors (art. VII Sec. 12(a)); the constraint is the vote requirement, not a debt ceiling",
      note_exception="Revenue bonds (not payable from ad valorem taxes) fall outside art. VII Sec. 12 and need no vote; refunding at a lower net average interest cost needs no vote",
      note_votebyothergovtlevels="The vote requirement applies to counties, school districts, and special districts alike (art. VII Sec. 12)"),

    # ==================== GEORGIA ====================
    R(stab="GA", state="georgia",
      source=f"Ga. Const. art. IX, {SECT} V, Para. I (debt limit)",
      source_url=f"{JC}/georgia/",
      source_year=2024,
      source_filename="GA/260615_georgia_constitution.txt",
      has_limit="Y", limit_basis="Percent of assessed value of all taxable property",
      threshold="10% of the assessed value of all taxable property",
      vote_to_exceed="N",
      note_scope="Quote: debt of any 'county, municipality, or other political subdivision of this state, including debt incurred on behalf of any special district, shall never exceed 10 percent of the assessed value of all taxable property' (art. IX Sec. V Para. I). Incurring bonded debt also requires a majority vote of the qualified voters (Sec. 36-82-1)",
      note_exception="Temporary loans to pay current-year expenses (capped at 75% of total gross income of the prior year) are outside the bonded-debt limit; refunding excepted",
      note_votebyothergovtlevels="The 10% ceiling and the election requirement apply to counties, municipalities, and other political subdivisions"),

    # ==================== IOWA ====================
    R(stab="IA", state="iowa",
      source=f"Iowa Const. art. XI, {SECT} 3 (debt limit)",
      source_url=f"{JC}/iowa/",
      source_filename="IA/260625_iowa_constitution.txt",
      has_limit="Y", limit_basis="Percent of value of taxable property",
      threshold="5% of the value of taxable property; indebtedness in excess is void",
      vote_to_exceed="N",
      note_scope="Quote: no county 'or other political or municipal corporation shall be allowed to become indebted in any manner, or for any purpose, to an amount, in the aggregate, exceeding five per centum on the value of the taxable property within such county or corporation' (art. XI Sec. 3); statutory limitation Iowa Code Sec. 346.24. General-purpose GO bonds separately require a 60% vote (Sec. 384.26); the 5% is an absolute ceiling",
      note_exception="Certain self-supporting/revenue obligations are excluded when computing the limit",
      note_votebyothergovtlevels="The 5% ceiling applies to counties and all political/municipal corporations"),

    # ==================== IDAHO ====================
    R(stab="ID", state="idaho",
      source=f"Idaho Const. art. VIII, {SECT} 3 (debt limit)",
      source_url=f"{JC}/idaho/article-viii/section-3/",
      source_filename="ID/260615_idaho_constitution.txt",
      has_limit="Y", limit_basis="Annual income and revenue provided for the year",
      threshold="May not incur indebtedness or liability exceeding the year's income and revenue without a two-thirds vote",
      vote_to_exceed="Y",
      note_scope="Quote: no county, city or subdivision 'shall incur any indebtedness, or liability, in any manner, or for any purpose, exceeding in that year, the income and revenue provided for it for such year, without the assent of two-thirds (2/3) of the qualified electors' (art. VIII Sec. 3). No fixed percentage-of-value cap; the limit is the year's revenue unless voters approve",
      note_exception="Ordinary and necessary expenses authorized by general law are outside the limit; pure special-fund revenue obligations fall outside art. VIII Sec. 3",
      note_votebyothergovtlevels="The two-thirds requirement applies to counties, cities, school districts, and other subdivisions"),

    # ==================== ILLINOIS ====================
    R(stab="IL", state="illinois",
      source=f"65 ILCS 5/8-5-1 ({SECT} 8-5-1, Municipal Code; debt limit)",
      source_url=f"{J}/illinois/chapter-65/act-65-ilcs-5/article-8/",
      source_filename="IL/260625_illinois_chapter-65.txt",
      has_limit="Depends", limit_basis="Percent of value of taxable property (non-home-rule municipalities)",
      threshold="8.625% of the value of the taxable property for non-home-rule municipalities; home-rule units have no statutory debt limit",
      vote_to_exceed="Depends",
      note_scope="Quote: the statutory ceiling is '8.625% on the value of the taxable property' (Sec. 8-5-1) for non-home-rule municipalities. Home-rule units (automatic for municipalities over 25,000 population under Ill. Const. art. VII Sec. 6) have independent debt authority and are not subject to Sec. 8-5-1; a home rule unit may not incur ad valorem-property-tax debt maturing more than 40 years out (art. VII Sec. 6(d)(1))",
      note_exception="Enterprise/utility revenue bonds and refunding are outside the Sec. 8-5-1 limit; home-rule units exempt",
      note_votebyothergovtlevels="Counties and other units issue GO bonds under parallel provisions outside the Municipal Code"),

    # ==================== INDIANA ====================
    R(stab="IN", state="indiana",
      source=f"Ind. Const. art. 13, {SECT} 1 (debt limit)",
      source_url=f"{JC}/indiana/",
      source_filename="IN/260625_indiana_constitution.txt",
      has_limit="Y", limit_basis="Percent of value of taxable property",
      threshold="2% of the value of taxable property; indebtedness in excess is void",
      vote_to_exceed="N",
      note_scope="Quote: 'No political or municipal corporation in this State shall ever become indebted, in any manner or for any purpose to an amount, in the aggregate, exceeding two per centum on the value of the taxable property within such corporation ... and all bonds or obligations, in excess of such amount, given by such corporations, shall be void' (art. 13 Sec. 1)",
      note_exception="A war/foreign-invasion/great-public-calamity exception applies on petition of a majority of the property owners; controlled-project bonds are separately subject to petition-remonstrance or a referendum (IC 6-1.1-20)",
      note_votebyothergovtlevels="The 2% ceiling applies to all political and municipal corporations"),

    # ==================== KANSAS ====================
    R(stab="KS", state="kansas",
      source=f"Kan. Stat. Ann. {SECT} 10-308 (cities; debt limit)",
      source_url=f"{J}/kansas/chapter-10/article-3/section-10-308/",
      source_filename="KS/260625_kansas_chapter-10.txt",
      has_limit="Y", limit_basis="Percent of assessed valuation of the city",
      threshold="30% of assessed valuation (authorized and outstanding bonded indebtedness of a city)",
      vote_to_exceed="N",
      note_scope="Quote: 'The authorized and outstanding bonded indebtedness of any city shall not exceed 30% of the assessed valuation of the city' (Sec. 10-308(a)). Under Kan. Const. art. 12 Sec. 5(b), cities determine local affairs by ordinance with referendums only as the legislature prescribes",
      note_exception="Bonds for storm/sanitary sewer systems, municipal utilities, and specified street improvements are excluded when computing the 30% limit (Sec. 10-309); other statutory exemptions apply",
      note_votebyothergovtlevels="'Municipality' for bond purposes includes counties, townships, school districts and other taxing subdivisions (Sec. 10-101 et seq.), each with its own statutory limit"),

    # ==================== KENTUCKY ====================
    R(stab="KY", state="kentucky", control=1,
      source=f"Ky. Const. {SECT} 158 (maximum indebtedness of cities)",
      source_url="https://law.justia.com/constitution/kentucky/158.html",
      source_filename="KY/260915_kentucky_constitution-secs-156-159.txt",
      has_limit="Y", limit_basis="Percent of value of taxable property, scaled by population",
      threshold="Cities of 15,000+ population: 10%; 3,000-15,000: 5%; under 3,000: 3% of the value of taxable property (counties/taxing districts: 2%)",
      vote_to_exceed="N",
      note_scope="Quote: 'Cities, towns, counties, and taxing districts shall not incur indebtedness to an amount exceeding the following maximum percentages on the value of the taxable property therein ...: Cities having a population of fifteen thousand or more, ten percent (10%); cities having a population of less than fifteen thousand but not less than three thousand, five percent (5%); cities having a population of less than three thousand, three percent (3%); and counties and taxing districts, two percent (2%)' (Const. Sec. 158). Implementing statute: Ky. Rev. Stat. Sec. 66.041 (same population-scaled percentages of net indebtedness); cities issue bonds by ordinance with no referendum (Sec. 66.101). Const. Sec. 157 separately caps the tax RATE (a tax-dimension item), not debt",
      note_exception="Renewal bonds and bonds to fund floating indebtedness are excepted; the General Assembly may set additional limits/conditions (Sec. 158); revenue obligations are not counted as net indebtedness under Sec. 66.041",
      note_votebyothergovtlevels="Counties and taxing districts are limited to 2% of taxable property (Const. Sec. 158; Sec. 66.041(2))"),

    # ==================== LOUISIANA ====================
    R(stab="LA", state="louisiana",
      source=f"La. Rev. Stat. {SECT} 39:521 (general obligation bonds; debt limit)",
      source_url=f"{J}/louisiana/revised-statutes/title-39/rs-39-521/",
      source_filename="LA/260615_louisiana_title-39.txt",
      has_limit="Y", limit_basis="Percent of assessed valuation of taxable property",
      threshold="10% of assessed valuation per purpose, and 35% in the aggregate, for municipalities and parishes",
      vote_to_exceed="N",
      note_scope="Debt is capped 'for municipalities and parishes, 10 percent per purpose or 35 percent in the aggregate' of assessed valuation (Sec. 39:521(C),(D)); the full faith and credit is pledged and an unlimited ad valorem tax levied. GO bonds require approval by a majority of the electors voting (Sec. 39:521(A))",
      note_exception="Revenue bonds payable solely from system revenues (Sec. 39:524) are outside the GO debt cap",
      note_votebyothergovtlevels="'Governmental entity' covers parishes, municipalities, school boards/districts, each with its own cap (Sec. 39:521(C))"),

    # ==================== MASSACHUSETTS ====================
    R(stab="MA", state="massachusetts", control=1,
      source=f"Mass. Gen. Laws ch. 44, {SECT} 10 (debt limit)",
      source_url=f"{J}/massachusetts/part-i/title-vii/chapter-44/section-10/",
      source_filename="MA/massachusetts_title-vii.txt",
      has_limit="Y", limit_basis="Percent of equalized valuation of the city or town",
      threshold="5% of equalized valuation; a city or town may authorize debt in excess of 5% but not more than 10% with approval of the Municipal Finance Oversight Board",
      vote_to_exceed="N",
      note_scope="Quote: a city or town may not authorize 'indebtedness to an amount exceeding 5 per cent of the equalized valuation of the city or town. A city or town may authorize indebtedness in excess of 5 per cent but not in excess of 10 per cent, of the aforesaid equalized valuation' (ch. 44 Sec. 10). Raising the ceiling to 10% requires approval of the Municipal Finance Oversight Board, NOT a popular vote",
      note_exception="Debt incurred outside the limit under ch. 44 Sec. 8 (water, sewer, and other revenue-producing/long-lived assets) does not count against the ch. 44 Sec. 10 limit",
      note_votebyothergovtlevels="In towns, within-limit debt is authorized by a two-thirds town-meeting vote; the equalized-valuation ceiling is the same for cities and towns"),

    # ==================== MARYLAND ====================
    R(stab="MD", state="maryland",
      source=f"Md. Code, Local Government (municipal charters govern debt limits)",
      source_url=f"{J}/maryland/local-government/",
      source_filename="MD/260625_maryland_local-government.txt",
      has_limit="Depends", limit_basis="Set by municipal charter / public local law; no uniform statewide percentage ceiling",
      threshold="Varies by charter (no general statutory percentage-of-value limit in the Local Government Article)",
      vote_to_exceed="Depends",
      note_scope="Maryland's Local Government Article does not impose a uniform percentage-of-value municipal debt ceiling; each municipality's borrowing power and any debt limit are set by its charter or by public local law (charter/public-local text not fully in the downloaded corpus -- gap)",
      note_exception=NONE,
      note_votebyothergovtlevels="County debt limits are likewise charter/public-local-law based"),

    # ==================== MAINE ====================
    R(stab="ME", state="maine",
      source=f"Me. Stat. tit. 30-A, {SECT} 5702 (debt limit)",
      source_url=f"{J}/maine/title-30-a/part-2/subpart-9/chapter-223/subchapter-2/section-5702/",
      source_filename="me/260615_maine_title-30-a.txt",
      has_limit="Y", limit_basis="Percent of last full state valuation of the municipality",
      threshold="7.5% of last full state valuation (a municipality may set a lower percentage); separate additional limits for school, airport, sewer, and special-district purposes",
      vote_to_exceed="N",
      note_scope="Quote: municipal debt is limited to '7 1/2% of its last full state valuation, or any lower percentage or amount that a municipality may set' (Sec. 5702), with separate outstanding-debt limits for school, municipal airport, sewer, and special-district purposes. Bonds are authorized by the town meeting (voters) or council (Sec. 5772)",
      note_exception="Debt for school, airport, sewer, and special-district purposes is measured against separate additional limits; certain notes/temporary borrowing excepted",
      note_votebyothergovtlevels="Counties and other municipalities authorize debt through their own legislative bodies under Title 30-A"),

    # ==================== MICHIGAN ====================
    R(stab="MI", state="michigan",
      source=f"Mich. Comp. Laws {SECT} 117.4a (Home Rule City Act; net indebtedness limit)",
      source_url=f"{J}/michigan/chapter-117/statute-act-279-of-1909/section-117-4a/",
      source_filename="MI/260615_michigan_chapter-117.txt",
      has_limit="Y", limit_basis="Percent of assessed value of real and personal property in the city",
      threshold="10% of the assessed value of all the real and personal property in the city",
      vote_to_exceed="N",
      note_scope="Quote: net indebtedness may not exceed 'Ten percent of the assessed value of all the real and personal property in the city' (Home Rule City Act, Sec. 117.4a). Michigan cities are home-rule; the charter operates within this statutory ceiling",
      note_exception="Numerous categories are excluded from 'net indebtedness' (e.g. revenue bonds, special-assessment debt, and bonds for which other funds are pledged); limited-tax GO bonds capped separately at 5% of state equalized valuation (Sec. 141.2517)",
      note_votebyothergovtlevels="Counties and other units have parallel statutory net-debt limits; the Headlee Amendment (Const. art. IX Secs. 25-34) constrains tax-supported debt"),

    # ==================== MINNESOTA ====================
    R(stab="MN", state="minnesota",
      source=f"Minn. Stat. {SECT} 475.53 (net debt limit)",
      source_url=f"{J}/minnesota/chapter-475/section-475-53/",
      source_filename="MN/260625_minnesota_chapter-475.txt",
      has_limit="Y", limit_basis="Percent of estimated market value of taxable property",
      threshold="3% of the estimated market value of taxable property in the municipality",
      vote_to_exceed="N",
      note_scope="Quote: a municipality may not incur net debt exceeding 'three percent of the estimated market value of taxable property in the municipality' (Sec. 475.53)",
      note_exception="Many obligations are excluded from 'net debt' (e.g. revenue/utility obligations, improvement warrants, tax/aid anticipation), so the 3% limit reaches only tax-supported general debt",
      note_votebyothergovtlevels="Applies to municipalities generally (cities, towns); counties and school districts have their own limits under ch. 475"),

    # ==================== MISSOURI ====================
    R(stab="MO", state="missouri",
      source=f"Mo. Const. art. VI, {SECT} 26(b)-(e) (debt limits)",
      source_url=f"{JC}/missouri/article-vi/section-26-b/",
      source_filename="MO/260615_missouri_constitution.txt",
      has_limit="Y", limit_basis="Percent of value of taxable tangible property",
      threshold="5% of taxable tangible property (Sec. 26(b)); +5% for general purposes (26(c)); +10% for streets/sewers (26(d)); +10% for water/light plants, total not to exceed 20% (26(e))",
      vote_to_exceed="Y",
      note_scope="Quote: a city or subdivision 'may become indebted in an amount not to exceed five percent of the value of taxable tangible property therein' by a vote of the electors (art. VI Sec. 26(b)); the vote is four-sevenths at general municipal/primary/general elections and two-thirds at other elections. Additional increments (26(c)-(e)) each require the same vote; 26(e) caps total GO debt at 20% of assessed valuation",
      note_exception="Industrial-development debt is capped separately at 10% (art. VI Sec. 23(a)); utility/airport and sewerage revenue bonds require a vote but sit outside the GO debt limit (Sec. 27(a); Sec. 250.070)",
      note_votebyothergovtlevels="The same vote applies to counties, cities, towns, villages; school districts are limited to 15% (art. VI Sec. 26(b))"),

    # ==================== MISSISSIPPI ====================
    R(stab="MS", state="mississippi", control=1,
      source=f"Miss. Code {SECT} 21-33-303 (municipal debt limit)",
      source_url=f"{J}/mississippi/title-21/chapter-33/article-5/section-21-33-303/",
      source_year=2024,
      source_filename="MS/mississippi_title-21.txt",
      has_limit="Y", limit_basis="Percent of assessed value of taxable property",
      threshold="15% of assessed value of taxable property (general); up to 20% of assessed value including all bonds for specified/combined purposes",
      vote_to_exceed="N",
      note_scope="Quote: municipal indebtedness may not exceed 'fifteen percent (15%) of the assessed value of the taxable property within such municipality' generally, or 'twenty percent (20%) of the assessed value of all taxable property' including the specified categories (Sec. 21-33-303). GO bonds are issued by resolution unless a protest petition forces an election (Sec. 21-33-307)",
      note_exception="Utility revenue bonds and certain self-liquidating obligations (Sec. 21-27-45) are not counted as municipal indebtedness",
      note_votebyothergovtlevels="Counties have a parallel statutory debt limit; the row subject is the municipal cap"),

    # ==================== MONTANA ====================
    R(stab="MT", state="montana",
      source=f"Mont. Code {SECT} 7-7-4201 (limitation on bonded indebtedness)",
      source_url=f"{J}/montana/title-7/chapter-7/part-42/section-7-7-4201/",
      source_filename="mt/260615_montana_title-7.txt",
      has_limit="Y", limit_basis="Percent of total assessed value of taxable property",
      threshold="2.5% of total assessed value of taxable property; an additional amount up to 55% over that limit may be incurred for water/sewer systems (Sec. 7-7-4202)",
      vote_to_exceed="N",
      note_scope="Quote: 'a city or town may not issue bonds or incur other indebtedness for any purpose in an amount that with all outstanding and unpaid indebtedness exceeds 2.5% of the total assessed value of taxable property' (Sec. 7-7-4201(1)). GO bonds pledging general credit require a majority vote (Sec. 7-7-4221)",
      note_exception="Funding/refunding bonds and bonds for tax-protest repayment are not new indebtedness (Sec. 7-7-4201(2),(3)); the water/sewer additional limit under Sec. 7-7-4202 requires an election",
      note_votebyothergovtlevels="Counties follow a parallel limit in Title 7, chapter 7, part 22"),

    # ==================== NORTH CAROLINA ====================
    R(stab="NC", state="north carolina",
      source=f"N.C. Gen. Stat. {SECT} 159-55 (net debt limit)",
      source_url=f"{J}/north-carolina/chapter-159/article-4/section-159-55/",
      source_filename="nc/260615_north-carolina_chapter-159.txt",
      has_limit="Y", limit_basis="Percent of assessed value of property subject to taxation",
      threshold="8% of the assessed value of property subject to taxation by the issuing unit",
      vote_to_exceed="N",
      note_scope="Quote: 'No bond order shall be adopted unless it appears ... that the net debt of the unit does not exceed eight percent (8%) of the assessed value of property subject to taxation by the issuing unit' (Sec. 159-55(c)). GO debt secured by taxing power also requires a voter referendum (N.C. Const. art. V Sec. 4; Sec. 159-61)",
      note_exception="Enumerated debt is excluded from 'net debt' when computing the 8% (funding/refunding, revenue bonds, water/sewer/utility debt, and other categories listed in Sec. 159-55(c))",
      note_votebyothergovtlevels="The 8% net-debt ceiling applies uniformly to counties, cities, and other units under the Local Government Bond Act"),

    # ==================== NORTH DAKOTA ====================
    R(stab="ND", state="north dakota",
      source=f"N.D. Const. art. X, {SECT} 15 (debt limit)",
      source_url=f"{JC}/north-dakota/article-x/section-15/",
      source_filename="ND/260615_north-dakota_constitution.txt",
      has_limit="Y", limit_basis="Percent of assessed value of taxable property",
      threshold="5% of assessed value; a city may by a two-thirds vote increase this by 3% (to 8%); an additional 4% for waterworks/sewers; utility bonds up to the physical value of the utility by majority vote",
      vote_to_exceed="Y",
      note_scope="Quote: 'The debt of any county, township, city, town, school district or any other political subdivision, shall never exceed five per centum upon the assessed value of the taxable property therein; provided that any incorporated city may, by a two-thirds vote, increase such indebtedness three per centum on such assessed value beyond said five per centum limit' (art. X Sec. 15). Any bond issuance also requires a 60% vote (Sec. 21-03-07)",
      note_exception="Revenue-producing utility bonds (up to the physical value of the utility, by majority vote) and a separate 4% for waterworks/sewers are outside the 5%/8% general limit (art. X Sec. 15)",
      note_votebyothergovtlevels="The 5% ceiling applies to counties, townships, cities, and school districts; the 3% two-thirds increase is available to incorporated cities"),

    # ==================== NEBRASKA ====================
    R(stab="NE", state="nebraska",
      source=f"Neb. Rev. Stat. ch. 16-18 (city debt authorizations)",
      source_url=f"{J}/nebraska/chapter-16/",
      source_filename="NE/260615_nebraska_chapter-16.txt",
      has_limit="Depends", limit_basis="Purpose-specific statutory bond authorizations tied to taxable valuation; no single uniform aggregate percentage ceiling",
      threshold="Set purpose-by-purpose (e.g. cold-storage/refrigeration plant bonds capped at 5% of taxable valuation, Sec. 17-960); no single statewide aggregate debt-limit percentage in the general city chapters",
      vote_to_exceed="Depends",
      note_scope="Nebraska does not fix a single uniform percentage-of-value municipal debt ceiling; debt authority is granted purpose-by-purpose in the class-of-city chapters, several of which cap the specific issue as a percentage of taxable valuation and require a majority vote (e.g. Sec. 17-956 to 17-960). GO bonds require a majority vote (Sec. 18-506.01)",
      note_exception="Revenue bonds are issued without a vote (Sec. 18-506.01); purpose-specific caps and vote requirements vary by chapter",
      note_votebyothergovtlevels="Limits and votes differ by class of city/village; counties have separate authorizations"),

    # ==================== NEW HAMPSHIRE ====================
    R(stab="NH", state="new hampshire", control=1,
      source=f"N.H. Rev. Stat. {SECT} 33:4-a (municipal debt limit)",
      source_url=f"{J}/new-hampshire/title-iii/chapter-33/section-33-4-a/",
      source_filename="NH/new-hampshire_title-iii.txt",
      has_limit="Y", limit_basis="Percent of the locally assessed valuation (as equalized)",
      threshold="3% of valuation for municipal (non-school) purposes; 7% for school purposes",
      vote_to_exceed="N",
      note_scope="Quote: cities/towns may not incur 'net indebtedness, except for school purposes, to an amount ... exceeding 3 percent of their valuation', and 'net indebtedness for school purposes ... exceeding 7 percent of said valuation' (Sec. 33:4-a). Cities authorize bonds by a two-thirds council vote; towns by a 3/5 town-meeting vote (Sec. 33:8, 33:9)",
      note_exception="Debt for water, sewer, and certain self-supporting/enterprise purposes is excluded from the applicable limit; school debt is measured against the separate 7%",
      note_votebyothergovtlevels="Separate percentage limits apply for county and village-district purposes"),

    # ==================== NEW JERSEY ====================
    R(stab="NJ", state="new jersey", control=1,
      source=f"N.J. Rev. Stat. {SECT} 40A:2-6 (Local Bond Law; debt limitation)",
      source_url=f"{J}/new-jersey/title-40a/section-40a-2-6/",
      source_filename="NJ/new-jersey_title-40a.txt",
      has_limit="Y", limit_basis="Percent of equalized valuation basis (net debt / average equalized valuations)",
      threshold="3.5% of equalized valuation for a municipality (2.00% for a county)",
      vote_to_exceed="N",
      note_scope="Quote: 'No bond ordinance shall be finally adopted if it appears ... that the percentage of net debt ... exceeds 2.00%, in the case of a county, or 3 1/2 %, in the case of a municipality' (Sec. 40A:2-6). No bond referendum; a bond ordinance is adopted by a two-thirds governing-body vote (Sec. 40A:2-17)",
      note_exception="Self-liquidating utility debt is deducted from gross debt (Sec. 40A:2-45 to 2-48); exceptions and Local Finance Board applications allow debt beyond the limit (Sec. 40A:2-7)",
      note_votebyothergovtlevels="Counties are limited to 2.00% of equalized valuation (Sec. 40A:2-6)"),

    # ==================== NEW MEXICO ====================
    R(stab="NM", state="new mexico",
      source=f"N.M. Const. art. IX, {SECT} 13 (debt limit)",
      source_url=f"{JC}/new-mexico/",
      source_filename="NM/260615_new-mexico_constitution.txt",
      has_limit="Y", limit_basis="Percent of value of taxable property",
      threshold="4% of the value of taxable property; bonds in excess are void",
      vote_to_exceed="N",
      note_scope="Quote: 'No county, city, town or village shall ever become indebted to an amount in the aggregate, including existing indebtedness, exceeding four per centum on the value of the taxable property ... and all bonds or obligations issued in excess of such amount shall be void' (art. IX Sec. 13). GO bonds require a majority vote (art. IX Sec. 12; Sec. 3-30-6)",
      note_exception="A city, town, or village may contract debt in excess of the 4% for a water-supply or sewer system (art. IX Sec. 13)",
      note_votebyothergovtlevels="The 4% ceiling applies to counties, cities, towns, and villages"),

    # ==================== NEVADA ====================
    R(stab="NV", state="nevada",
      source=f"Nev. Rev. Stat. {SECT} 266.600 (general-law cities; debt limit)",
      source_url=f"{J}/nevada/chapter-266/",
      source_filename="NV/260625_nevada_chapter-266.txt",
      has_limit="Y", limit_basis="Percent of total assessed valuation of taxable property",
      threshold="30% of total assessed valuation in outstanding bonds; other (non-bonded) evidences of indebtedness capped at 20% of assessed valuation",
      vote_to_exceed="N",
      note_scope="Quote: 'no city may issue or have outstanding at any time bonds in an amount in excess of 30 percent of the total assessed valuation of the taxable property within such city ... nor warrants, certificates, scrip or other evidences of indebtedness, excepting the bonded indebtedness, in excess of 20 percent of the assessed valuation' (Sec. 266.600(4))",
      note_exception="Does not restrict borrowing for procuring water supplies (Sec. 266.600(4)); GO securities are issued under the Local Government Securities Law (ch. 350)",
      note_votebyothergovtlevels="Charter cities' limits are set in their special charters; counties have separate limits"),

    # ==================== NEW YORK ====================
    R(stab="NY", state="new york",
      source=f"N.Y. Const. art. VIII, {SECT} 4 (limitations on local indebtedness)",
      source_url=f"{JC}/new-york/article-viii/section-4/",
      source_filename="NY/260625_new-york_constitution.txt",
      has_limit="Y", limit_basis="Percent of average full valuation of taxable real estate (five-year average)",
      threshold="Cities under 125,000 population: 7% (excluding education); cities of 125,000+ (other than New York City): 9%; New York City: 10%",
      vote_to_exceed="N",
      note_scope="Quote: no city 'shall be allowed to contract indebtedness for any purpose or in any manner which, including existing indebtedness, shall exceed an amount equal to the following percentages of the average full valuation of taxable real estate' (art. VIII Sec. 4), with a city of less than 125,000 inhabitants limited to seven per centum for city purposes. NY municipal debt is generally issued without a referendum under the Local Finance Law",
      note_exception="Debt-service-excluded and self-liquidating obligations, and specified exclusions, do not count toward the percentage ceilings (art. VIII Sec. 5)",
      note_votebyothergovtlevels="Counties (other than Nassau) 7%, Nassau 10%; towns and villages 7% (art. VIII Sec. 4)"),

    # ==================== OHIO ====================
    R(stab="OH", state="ohio",
      source=f"Ohio Rev. Code {SECT} 133.05 (net indebtedness limit)",
      source_url=f"{J}/ohio/title-1/chapter-133/section-133-05/",
      source_filename="OH/260717_ohio_revised-code-chapter-133.txt",
      has_limit="Y", limit_basis="Percent of tax (assessed) valuation; split between unvoted and voted debt",
      threshold="Net indebtedness may not exceed 10.5% of tax valuation, and unvoted net indebtedness may not exceed 5.5% of tax valuation",
      vote_to_exceed="Y",
      note_scope="Quote: a municipal corporation 'shall not incur ... net indebtedness that exceeds ... ten and one-half per cent of its tax valuation, or incur without a vote of the electors net indebtedness that exceeds ... five and one-half per cent of that tax valuation' (Sec. 133.05(A)). Unvoted GO debt is thus capped at 5.5% and voted GO debt up to 10.5%; the ten-mill limitation (Sec. 5705.02) ties the voted/unvoted line to the property tax",
      note_exception="Self-supporting (revenue) securities and other categories are excluded from net indebtedness (Sec. 133.05(B))",
      note_votebyothergovtlevels="Counties, townships, and school districts have their own net-debt percentages under ch. 133"),

    # ==================== OKLAHOMA ====================
    R(stab="OK", state="oklahoma",
      source=f"Okla. Const. art. X, {SECT} 26 (debt limit) & {SECT} 27",
      source_url=f"{JC}/oklahoma/",
      source_filename="OK/260717_oklahoma_constitution-article-x-bodies.txt",
      has_limit="Y", limit_basis="Current-year income and revenue; then percent of assessed valuation with a vote",
      threshold="No debt beyond the year's income/revenue without a three-fifths vote; with such assent, aggregate debt may not exceed 5% of assessed valuation (Sec. 26); a majority vote may exceed 5% for public utilities and streets/bridges (Sec. 27)",
      vote_to_exceed="Y",
      note_scope="Quote: no municipality 'shall be allowed to become indebted ... to an amount exceeding, in any year, the income and revenue provided for such year without the assent of three-fifths of the voters ... nor, in cases requiring such assent, shall any indebtedness ... exceed[] five percent (5%) of the valuation of the taxable property' (art. X Sec. 26(a)). Sec. 27 lets a majority vote authorize debt above the Sec. 26 amount for utilities and streets/bridges",
      note_exception="Public-trust revenue financing (60 O.S. Sec. 176) is a separate no-referendum route; the Sec. 27 utility/street debt requires only a majority vote",
      note_votebyothergovtlevels="The Sec. 26 framework applies to counties, cities, towns, townships, and school districts (schools may reach 10% with a 3/5 vote)"),

    # ==================== OREGON ====================
    R(stab="OR", state="oregon",
      source=f"Or. Rev. Stat. {SECT} 287A.100 (city GO bond debt limit)",
      source_url=f"{J}/oregon/volume-07/chapter-287a/section-287a-100/",
      source_filename="or/260615_oregon_chapter-287a.txt",
      has_limit="Y", limit_basis="Percent of real market value of taxable property",
      threshold="3% of real market value of taxable property (unless the city charter sets a lower limit)",
      vote_to_exceed="N",
      note_scope="Quote: 'Unless the city charter provides a lesser limitation, a city may not issue or have outstanding at the time of issuance general obligation bonds in a principal amount that exceeds three percent of the real market value of the taxable property within its boundaries' (Sec. 287A.100(2)). GO bonds require voter approval (Sec. 287A.050)",
      note_exception="Revenue bonds and credit enhancement devices are not subject to the debt limit (Sec. 287A.140(5)); the charter may impose a lower limit",
      note_votebyothergovtlevels="Counties are limited to 2% of real market value (Sec. 287A.105)"),

    # ==================== PENNSYLVANIA ====================
    R(stab="PA", state="pennsylvania",
      source=f"53 Pa.C.S. {SECT} 8022 (Local Government Unit Debt Act; debt limits)",
      source_url=f"{J}/pennsylvania/title-53/chapter-80/section-8022/",
      source_filename="PA/260625_pennsylvania_title-53.txt",
      has_limit="Y", limit_basis="Percent of the borrowing base (annual arithmetic average of total revenues)",
      threshold="Nonelectoral debt (plus lease-rental debt) capped at 250% of the borrowing base for a municipality; voter-approved (electoral) debt is not subject to any limit",
      vote_to_exceed="Y",
      note_scope="Quote: the nonelectoral debt limit is 'Two hundred fifty percent of its borrowing base in the case of any other local government unit' (Sec. 8022(a)(3)); the borrowing base is the annual average of total revenues (Sec. 8002). Electoral debt approved by the voters is excluded from these limits, so a referendum lifts the ceiling",
      note_exception="Self-liquidating debt (Sec. 8024) and subsidized debt (Sec. 8025) are excluded when computing the limits; a home-rule county charter may impose stricter limits",
      note_votebyothergovtlevels="Counties: 300% of borrowing base; school districts of the first class: 200% (Sec. 8022)"),

    # ==================== RHODE ISLAND ====================
    R(stab="RI", state="rhode island",
      source=f"R.I. Gen. Laws {SECT} 45-12-2 (debt limit)",
      source_url=f"{J}/rhode-island/title-45/chapter-45-12/section-45-12-2/",
      source_filename="RI/260625_rhode-island_title-45.txt",
      has_limit="Y", limit_basis="Percent of full assessed value of taxable property",
      threshold="3% of the full assessed value of taxable property within the city or town",
      vote_to_exceed="N",
      note_scope="Quote: a city or town may not incur indebtedness beyond 'three percent (3%) of the full assessed value of the taxable property within the city or town' (Sec. 45-12-2). Exceeding the 3% is NOT done by popular vote: it requires a special act of the General Assembly, or the state director of revenue's determination that appropriated sums/available funds are insufficient (Sec. 45-12-4) -- so vote_to_exceed is N (legislative/administrative, not a referendum)",
      note_exception="Borrowing in anticipation of taxes (Sec. 45-12-4) and various special-act/self-supporting obligations are outside the 3% limit",
      note_votebyothergovtlevels="The 3% ceiling applies to cities and towns; excess requires General Assembly authorization"),

    # ==================== SOUTH CAROLINA ====================
    R(stab="SC", state="south carolina",
      source=f"S.C. Const. art. X, {SECT} 14 (debt limit)",
      source_url=f"{JC}/south-carolina/",
      source_filename="SC/260625_south-carolina_constitution.txt",
      has_limit="Y", limit_basis="Percent of assessed value of all taxable property",
      threshold="8% of the assessed value of all taxable property; a political subdivision may exceed 8% if approved by a majority vote in a referendum",
      vote_to_exceed="Y",
      note_scope="Quote: general obligation debt is limited to 'eight percent of the assessed value of all taxable property of such political subdivision' (art. X Sec. 14); the subdivision may incur debt above 8% when approved by a majority vote of the qualified electors in a referendum",
      note_exception="Bonded indebtedness existing on the 1977 fifth-anniversary date, and debt approved by referendum, are outside the 8% limit; revenue bonds are not GO debt",
      note_votebyothergovtlevels="The 8% ceiling (exceedable by referendum) applies to counties, municipalities, and school districts"),

    # ==================== SOUTH DAKOTA ====================
    R(stab="SD", state="south dakota",
      source=f"S.D. Const. art. XIII, {SECT} 4 (debt limit)",
      source_url=f"{JC}/south-dakota/",
      source_filename="SD/260615_south-dakota_constitution.txt",
      has_limit="Y", limit_basis="Percent of assessed valuation of taxable property",
      threshold="5% of assessed valuation; an additional 10% may be incurred for specified purposes (e.g. water/utility systems)",
      vote_to_exceed="N",
      note_scope="Quote: 'The debt of any county, city, town or civil township shall never exceed five per centum upon the assessed valuation of the taxable property therein' (art. XIII Sec. 4); a municipal corporation may incur an additional indebtedness not exceeding 10% for the specified (utility) purposes. Bond issuance requires a 60% vote (Sec. 6-8B-2)",
      note_exception="Utility revenue bonds payable solely from segregated revenue need no election and sit outside the general limit (Sec. 9-40-15)",
      note_votebyothergovtlevels="The 5% ceiling applies to counties, cities, towns, and civil townships; school districts 10%"),

    # ==================== TENNESSEE ====================
    R(stab="TN", state="tennessee", control=1,
      source=f"Tenn. Code {SECT} 9-21 (Local Government Public Obligations Act)",
      source_url=f"{J}/tennessee/title-9/chapter-21/",
      source_filename="TN/tennessee_title-9.txt",
      has_limit="N", limit_basis="No uniform percentage-of-value municipal debt ceiling in general law",
      threshold="No general statutory percentage cap; project-specific financings (e.g. certain full-faith-and-credit pledges) are conditioned on total bonded debt not exceeding 10% of assessed valuation",
      vote_to_exceed="N/A",
      note_scope="Tennessee's general local-debt law (title 9, ch. 21) imposes no uniform percentage-of-value debt ceiling on municipalities; GO bonds are authorized by resolution with a 20-day protest-petition referendum right (Sec. 9-21-205 to 210). Certain purpose-specific pledges are conditioned on total bonded debt not exceeding 10% of assessed valuation",
      note_exception="Revenue bonds (title 9, ch. 21, part 3) have no percentage limit and no referendum",
      note_votebyothergovtlevels="Counties issue debt under the same title 9, ch. 21 framework without a percentage ceiling"),

    # ==================== TEXAS ====================
    R(stab="TX", state="texas",
      source=f"Tex. Const. art. XI, {SECT} 5 (home-rule cities)",
      source_url=f"{JC}/texas/",
      source_filename="tx/260615_texas_constitution.txt",
      has_limit="Depends", limit_basis="No percentage-of-value debt ceiling; constrained by the ad valorem tax-rate limit and charter",
      threshold="No fixed percentage debt limit; a home-rule city's ad valorem tax is capped at $2.50 per $100 valuation (art. XI Sec. 5), and a tax sufficient to service the debt must be provided when the debt is created",
      vote_to_exceed="Depends",
      note_scope="Texas imposes no percentage-of-value municipal debt ceiling. A home-rule city 'may not create debt unless provision is made, at the time of creating the debt, to assess and collect a sufficient annual tax to pay the interest and provide a sinking fund' (art. XI Sec. 5); the practical limit is the $2.50/$100 ad valorem tax-rate ceiling and the city charter. Tax-supported GO bonds require voter approval (Tex. Gov. Code ch. 1251)",
      note_exception="Revenue bonds (not tax-supported) are outside the tax/debt limitation (Tex. Gov. Code ch. 1502)",
      note_votebyothergovtlevels="General-law cities are limited under art. XI Sec. 4 ($1.50/$100 in some classes); counties hold bond elections under Gov. Code ch. 1251"),

    # ==================== UTAH ====================
    R(stab="UT", state="utah",
      source=f"Utah Const. art. XIV, {SECT} 3-4 (debt limits)",
      source_url=f"{JC}/utah/",
      source_filename="UT/260717_utah_constitution-article-xiv-bodies.txt",
      has_limit="Y", limit_basis="Percent of value of taxable property in the municipality",
      threshold="4% of the value of taxable property for cities/towns, plus an additional 8% for supplying water, artificial light, or sewers owned by the municipality",
      vote_to_exceed="Y",
      note_scope="Quote: a 'city, town, school district, or other municipal corporation, may become indebted' only up to a percentage of the value of taxable property (art. XIV Sec. 4), being four per centum for cities/towns with an eight per centum additional 'for supplying such city or town' with water, light, or sewers. Art. XIV Sec. 3 bars debt beyond the current year's revenue without an election",
      note_exception="The additional 8% is available only for municipally owned water/light/sewer works; debt within the current-year revenue needs no vote",
      note_votebyothergovtlevels="Other subdivisions are generally limited to a lower percentage (art. XIV Sec. 3)"),

    # ==================== VIRGINIA ====================
    R(stab="VA", state="virginia",
      source=f"Va. Const. art. VII, {SECT} 10 (debt limit)",
      source_url=f"{JC}/virginia/",
      source_filename="VA/260625_virginia_constitution.txt",
      has_limit="Y", limit_basis="Percent of assessed valuation of taxable real estate",
      threshold="10% of the assessed valuation of taxable real estate in the city or town",
      vote_to_exceed="N",
      note_scope="Quote: 'No city or town shall issue any bonds or other interest-bearing obligations which, including existing indebtedness, shall at any time exceed ten per centum of the assessed valuation of the real estate in the city or town subject to taxation' (art. VII Sec. 10)",
      note_exception="Revenue bonds and certain self-supporting debt, and debt for specified purposes, are excluded when computing the 10% limit (art. VII Sec. 10(a))",
      note_votebyothergovtlevels="Counties operating under traditional forms have their own referendum-based debt rules; the 10% ceiling is the city/town rule"),

    # ==================== VERMONT ====================
    R(stab="VT", state="vermont",
      source=f"Vt. Stat. tit. 24, {SECT} 1762 (debt limit)",
      source_url=f"{J}/vermont/title-24/",
      source_filename="VT/260615_vermont_title-24.txt",
      has_limit="Y", limit_basis="Multiple of the municipal grand list (not a percentage of full value)",
      threshold="Aggregate indebtedness for public improvements may not exceed ten times the amount of the last grand list; debt in excess is void",
      vote_to_exceed="N",
      note_scope="Quote: 'A municipal corporation shall not incur an indebtedness for public improvements which, with its previously contracted indebtedness, shall, in the aggregate, exceed ten times the amount of the last grand list ... Bonds or obligations given or created in excess of the limit ... shall be void' (tit. 24 Sec. 1762). Bonds are authorized by a vote of the municipality (town meeting)",
      note_exception="Debt for ordinary expenses (Sec. 1752/1754) is not subject to the ten-times-grand-list limit",
      note_votebyothergovtlevels="Applies to municipal corporations (towns, cities, villages)"),

    # ==================== WASHINGTON ====================
    R(stab="WA", state="washington",
      source=f"Wash. Const. art. VIII, {SECT} 6 (limitations upon municipal indebtedness)",
      source_url=f"{JC}/washington/",
      source_filename="WA/260615_washington_constitution.txt",
      has_limit="Y", limit_basis="Percent of value of taxable property",
      threshold="1.5% without a vote; up to 5% with a three-fifths voter assent; an additional 5% each for water/light/sewers and (for cities) other municipal purposes",
      vote_to_exceed="Y",
      note_scope="Quote: no municipal corporation 'shall for any purpose become indebted ... exceeding one and one-half per centum of the taxable property ... without the assent of three-fifths of the voters therein, ... nor in cases requiring such assent shall the total indebtedness at any time exceed five per centum on the value of the taxable property' (art. VIII Sec. 6)",
      note_exception="With voter assent a city or town may add up to 5% additional for municipally owned water, light, and sewers (art. VIII Sec. 6)",
      note_votebyothergovtlevels="The 1.5%/5% framework applies to counties, cities, towns, school districts, and other municipal corporations"),

    # ==================== WISCONSIN ====================
    R(stab="WI", state="wisconsin", control=1,
      source=f"Wis. Const. art. XI, {SECT} 3 (debt limit)",
      source_url=f"{JC}/wisconsin/",
      source_filename="WI/wisconsin_constitution.txt",
      has_limit="Y", limit_basis="Percent of value of taxable property (equalized for state purposes)",
      threshold="5% of the value of taxable property (an allowable percentage set by the legislature within the constitutional 5% ceiling)",
      vote_to_exceed="N",
      note_scope="Quote: a municipality may not 'become indebted in an amount that exceeds an allowable percentage of the taxable property located therein equalized for state purposes as provided by the legislature. In all cases the allowable [percentage] ...' does not exceed five per centum (art. XI Sec. 3). Revenue obligations (Sec. 66.0621) are not counted toward this limit",
      note_exception="Revenue obligations payable only from a special redemption fund are not indebtedness of the municipality and are outside the 5% limit (Sec. 66.0621)",
      note_votebyothergovtlevels="The 5% ceiling applies to counties, cities, towns, villages, and school districts"),

    # ==================== WEST VIRGINIA ====================
    R(stab="WV", state="west virginia",
      source=f"W. Va. Const. art. X, {SECT} 8 (debt limit)",
      source_url=f"{JC}/west-virginia/",
      source_filename="WV/260615_west-virginia_constitution.txt",
      has_limit="Y", limit_basis="Percent of value of taxable property",
      threshold="5% of the value of taxable property (aggregate, including existing indebtedness); the 5% is an absolute ceiling",
      vote_to_exceed="N",
      note_scope="Quote: no municipal corporation 'shall ... be allowed to become indebted ... to an amount, including existing indebtedness, in the aggregate, exceeding five per centum on the value of the taxable property therein' (art. X Sec. 8); and 'no debt shall be contracted under this section, unless all questions connected with the same, shall have been first submitted to a vote of the people, and have received three fifths of all the votes cast'. A 3/5 vote is required to incur any debt, but the 5% ceiling cannot be exceeded by vote",
      note_exception="A direct annual tax sufficient to pay principal (within 34 years) and interest must accompany the debt (art. X Sec. 8)",
      note_votebyothergovtlevels="The 5% ceiling and 3/5 vote apply to counties, cities, and school districts"),

    # ==================== WYOMING ====================
    R(stab="WY", state="wyoming",
      source=f"Wyo. Const. art. 16, {SECT} 5 (debt limit)",
      source_url=f"{JC}/wyoming/",
      source_filename="WY/260615_wyoming_constitution.txt",
      has_limit="Y", limit_basis="Percent of assessed value of taxable property",
      threshold="4% of assessed value; an additional 4% may be created for sewage disposal systems; debt for supplying water is excepted",
      vote_to_exceed="N",
      note_scope="Quote: 'No city or town shall in any manner create any indebtedness exceeding four per cent (4%) of the assessed value of the taxable property therein, except that an additional indebtedness of four per cent (4%) ... may be created for sewage disposal systems' (art. 16 Sec. 5). Creating debt requires an elector vote (art. 16 Sec. 4)",
      note_exception="Indebtedness for supplying water to a city or town is excepted from the 4% limit (art. 16 Sec. 5)",
      note_votebyothergovtlevels="Counties are limited to 2% of assessed value (art. 16 Sec. 3); the 4% is the city/town ceiling"),
]


def main():
    missing = {r["stab"] for r in ROWS} ^ set(EXCEEDABLE)
    if missing:
        raise SystemExit(f"EXCEEDABLE / ROWS stab mismatch: {sorted(missing)}")
    for r in ROWS:
        r["limit_exceedable"] = EXCEEDABLE[r["stab"]]
    df = pl.DataFrame([{c: r.get(c, NONE) for c in COLS} for r in ROWS])
    # ASCII guard: the section sign (U+00A7) is allowed, ONLY in `source`.
    bad = []
    for r in df.iter_rows(named=True):
        for c in COLS:
            v = str(r[c])
            for ch in v:
                if ord(ch) > 127 and not (c == "source" and ch == SECT):
                    bad.append((r["stab"], c, repr(ch), v[:60]))
    if bad:
        print("!!! NON-ASCII outside source/section-sign:")
        for b in bad[:40]:
            print("   ", b)
        raise SystemExit("ASCII guard failed")
    with open(OUT, "wb") as fh:
        fh.write(b"\xef\xbb\xbf")  # UTF-8 BOM
        fh.write(df.write_csv().encode("utf-8"))
    print(f"Wrote {OUT}  ({df.height} rows, {len(COLS)} cols)")
    print("has_limit counts:", dict(df["has_limit"].value_counts().iter_rows()))
    print("vote_to_exceed counts:", dict(df["vote_to_exceed"].value_counts().iter_rows()))
    print("limit_exceedable counts:", dict(df["limit_exceedable"].value_counts().iter_rows()))
    # cross-tab the informative combination
    ct = (df.group_by(["vote_to_exceed", "limit_exceedable"]).len().sort("vote_to_exceed"))
    print("vote_to_exceed x limit_exceedable:")
    for row in ct.iter_rows(named=True):
        print(f"   vote={row['vote_to_exceed']:8} exceedable={row['limit_exceedable']:8} n={row['len']}")


if __name__ == "__main__":
    main()
