#!/usr/bin/env python3
r"""
260624_build_sourcelevel_expand25.py -- Debt by Democracy: Phase 3-4 EXPANSION.

Build 260624_sourcelevel_expand25.csv for the 25 expansion states (24 now + WY when
its download finishes). Classifications are grounded in the downloaded corpus under
Data\Statutes\raw\<st>\ (Justia HTML, ND chapter-PDF text, NE statute- pages, LA rs-
pages), located via the curated seed pointers in 260613_expansion_seed_manifest.csv.

Schema / conventions follow the pilot 260611_build_sourcelevel.py (see findings.md
"sourcelevel.csv conventions"), with these EXPANSION deltas (user decision 2026-06-24):
- DROP the `pilot` column entirely (irrelevant in this expansion-dedicated file).
- Keep the `control` column; set control = 0 for ALL states.
- POPULATE EVERY COLUMN for every state. Use "None indicated" only after genuinely
  checking the corpus; never leave a cell blank or "N/A".

Carried over from the pilot:
- ONE ROW PER SOURCE (one statute section / one document per row). bond_type,
  source_url and every note_* describe THAT one source only. Pair an authority
  section with its procedure section as separate rows, cross-referencing in notes.
- bond_type in {go, rev, both} reflects only the bonds the row's source governs.
- source column KEEPS the section sign glyph; it is the ONLY non-ASCII char allowed
  and only in `source`. note_* text stays plain ASCII (write "Sec." in notes).
- source_year = the cited edition / publication year (its own column).
- note_timing = ONLY the required timing of WHEN the election is held. Notice timing
  -> note_pubnotice; protest/petition timing -> note_petition.
- Absence is the standard phrase "None indicated".

PROCESS REVISION vs the pilot (findings.md "PILOT OMISSIONS"): for every state, after
the GO/revenue authority + threshold (note_vote), the bond-ELECTION-PROCEDURE sections
were scanned for (1) public-notice publication rules (note_pubnotice), (2) required
ballot/question wording (note_textreq), (3) petition/protest provisions (note_petition),
and (4) revenue-bond vote requirements AND their exemptions (note_vote on the rev row /
note_exception).

Output: Data\Statutes\260717_sourcelevel_expand25.csv  (UTF-8 with BOM)

2026-07-17 RE-GROUNDING (dated copy of 260624_build_sourcelevel_expand25.py; the Jun-24
builder reproduces the current CSV exactly, so this is a faithful baseline). After the
targeted dependency fetch (260717_fetch_dependencies.py) closed the out-of-corpus gaps,
five Batch A rows are regrounded on PRIMARY TEXT now in the corpus (raw/<ST>/260717_*.txt):
  - TX GO (art. XI Sec. 5): note_pubnotice/note_timing/note_textreq -> Gov. Code ch. 1251
    (Sec. 1251.003 notice+timing [corrects the user-flagged "None indicated"], Sec. 1251.052 ballot).
  - TX rev (art. XI Sec. 5): note_exception -> Gov. Code ch. 1502 (Sec. 1502.051 authority,
    Sec. 1502.054 not-a-debt/no-tax, Sec. 1502.055 election only to SELL, not to issue).
  - OH GO/rev (art. XII Sec. 11 / art. XVIII Sec. 12): -> Rev. Code ch. 133 (Sec. 133.05
    5.5% unvoted / 10.5% voted net-debt; Sec. 133.18 submission to electors; Sec. 133.05(B)
    self-supporting-securities exclusion) + ch. 5705 (Sec. 5705.02 ten-mill; Sec. 5705.19/.191).
  - OK rev (tit. 11 Sec. 22-155): note_exception/note_nichevote -> the general PUBLIC TRUST
    route (60 O.S. Sec. 176 et seq.): a public trust issues revenue bonds with NO public vote,
    only a 2/3 governing-body approval -- correcting the narrow-trigger read of Sec. 22-155.
  - FL GO (Sec. 100.201): note_pubnotice -> Sec. 100.342 (30 days; newspaper; twice, fifth
    and third weeks before the election).
  - CA GO (Sec. 43608): note_textreq -> Elections Code Sec. 13247 (ballot label per Sec. 9051,
    followed by "Yes"/"No").
NOTE: source/source_url/source_filename fields are left on the original constitutional/statutory
anchor (one row per source); the fetched authorities are cited inside the note_* text.
"""
from __future__ import annotations

from pathlib import Path
import polars as pl

OUT = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
          r"\Data\Statutes\260717_sourcelevel_expand25.csv")

COLS = ["stab", "state", "control", "source", "source_url", "source_year",
        "source_type", "source_filename", "bond_type", "note_vote", "note_textreq",
        "note_timing", "note_pubnotice", "note_exception", "note_nichevote",
        "note_optin", "note_petition", "note_votereqbyothergovtlevels"]

J = "https://law.justia.com/codes"
JC = "https://law.justia.com/constitution"

# The section sign is the one non-ASCII glyph permitted (source column only).
SECT = "§"
NONE = "None indicated"


def R(**kw):
    """One source row; control defaults to 0, every note defaults to NONE."""
    base = dict(control=0, source_type="primary", note_vote=NONE, note_textreq=NONE,
                note_timing=NONE, note_pubnotice=NONE, note_exception=NONE,
                note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
                note_votereqbyothergovtlevels=NONE)
    base.update(kw)
    return base


ROWS = [
    # ==================== ARKANSAS ====================
    # AR is unusual: per City of Hot Springs v. Creviston the AR Constitution requires
    # a vote for BOTH GO (Amend. 62) AND revenue bonds. Constitution Amendments path
    # was not in the crawl; grounded instead in the implementing statutes.
    R(stab="AR", state="arkansas",
      source=f"Ark. Code {SECT} 14-164-309 (Local Government Bond Act; Amend. 62)",
      source_url=f"{J}/arkansas/title-14/subtitle-10/chapter-164/subchapter-3/section-14-164-309/",
      source_year=2024,
      source_filename="AR/260615_arkansas_title-14.txt",
      bond_type="go",
      note_vote="General obligation bonds (local capital improvement bonds under Arkansas Constitution Amendment 62) must be approved by a majority of the electors voting on the question at a general or special election",
      note_textreq="The authorizing ordinance sets the form of the ballot question(s), which must state the purpose(s) for which the bonds are issued and the maximum rate of any ad valorem tax to be levied to pay the bonds",
      note_timing="Held at the general election or at a special election called for that purpose under Sec. 7-11-201 et seq., as provided in the ordinance",
      note_pubnotice="The issuer's clerk gives notice by one publication in a newspaper of general circulation in the municipality or county not less than 10 days before the election; no other publication or posting is required",
      note_exception="Refunding bonds may be issued without an election (Sec. 14-164-324)",
      note_votereqbyothergovtlevels="The same election requirement applies to both counties and municipalities (Sec. 14-164-309(a))"),
    R(stab="AR", state="arkansas",
      source=f"Ark. Code {SECT} 14-72-606 (revenue-bond election procedures)",
      source_url=f"{J}/arkansas/title-14/subtitle-4/chapter-72/subchapter-6/section-14-72-606/",
      source_year=2024,
      source_filename="AR/260615_arkansas_title-14.txt",
      bond_type="rev",
      note_vote="Revenue bonds also require voter approval: the Arkansas Supreme Court (City of Hot Springs v. Creviston) held the Arkansas Constitution requires county/municipal revenue bonds to be approved by the electors. A majority of the electors voting on the question must approve (Sec. 14-72-606(a)(3); legislative intent Sec. 14-72-602)",
      note_textreq="The ordinance sets the form of the ballot question(s), which must state the purposes for which the revenue bonds are to be issued and the proposed sources of repayment; multi-purpose issues are voted as separate questions",
      note_timing="Held at a special election called for that purpose under Sec. 7-11-201 et seq., as provided in the ordinance",
      note_pubnotice="The county/municipal clerk gives notice by one publication in a newspaper of general circulation not less than 10 days before the election",
      note_exception="Refunding revenue bonds may be issued without an election if the repayment source is substantially the same and the principal is not increased (Sec. 14-72-609)",
      note_votereqbyothergovtlevels="The same election requirement applies to both counties and municipalities, including their boards and agencies (Sec. 14-72-602)"),

    # ==================== CALIFORNIA ====================
    # GO: 2/3 constitutional vote (art. XVI Sec. 18), implemented by the city
    # procedure (Gov. Code Sec. 43600 et seq.) and a parallel county procedure.
    # Revenue: TWO rows that reconcile each other -- the optional Revenue Bond Law
    # of 1941 (statutory majority vote) vs. the general no-vote revenue-bond
    # framework (special-fund doctrine; revenue bonds are not constitutional debt).
    R(stab="CA", state="california",
      source=f"Cal. Const. art. XVI, {SECT} 18",
      source_url=f"https://law.justia.com/constitution/california/article-xvi/section-18/",
      source_year=2025,
      source_filename="CA/260615_california_constitution.txt",
      bond_type="go",
      note_vote="A city, county, or town may not incur any indebtedness or liability exceeding the income and revenue provided for the year without the assent of two-thirds of the voters voting at an election held for that purpose",
      note_textreq=NONE,
      note_timing="At an election held for that purpose",
      note_pubnotice=NONE,
      note_exception="Revenue bonds payable solely from enterprise revenues are not 'indebtedness' under this section (judicial special-fund doctrine) and need no vote; for general obligation bonds to repair public school buildings found structurally unsafe, a majority (not two-thirds) vote suffices",
      note_votereqbyothergovtlevels="The two-thirds requirement applies alike to counties, cities, towns, townships, boards of education, and school districts"),
    R(stab="CA", state="california",
      source=f"Cal. Gov. Code {SECT} 43608 (city general obligation bond procedure)",
      source_url=f"{J}/california/code-gov/title-4/division-4/chapter-4/article-1/section-43608/",
      source_year=2025,
      source_filename="CA/260615_california_code-gov.txt",
      bond_type="go",
      note_vote="City GO bonds require approval by two-thirds of the electors voting on the proposition (Sec. 43614); proceedings begin when the city legislative body, by a two-thirds vote of all its members, determines the public necessity (Sec. 43607) and then orders the election by ordinance (Sec. 43608)",
      note_textreq="The bond ordinance must recite the object and purpose of the indebtedness, the estimated cost of the improvements, the principal amount of the indebtedness, and the maximum rate of interest (Sec. 43610). BALLOT-FACE wording (previously an out-of-corpus gap) is now grounded on Elections Code Division 13, re-fetched 2026-07-17 (raw/CA/260717_california_elections-code-division-13-ballot.txt): 'The statement of all measures submitted to the voters shall be abbreviated on the ballot in a ballot label as provided for in Section 9051. The ballot label shall be followed by the words, \"Yes\" and \"No\"' (Elec. Code Sec. 13247)",
      note_timing="At an election called for that purpose, which may be consolidated with another election (Sec. 43608, 43612)",
      note_pubnotice="The ordinance calling the election is published once a day for at least seven days in a daily newspaper in the city, or once a week for two weeks in a weekly newspaper, or, if none, posted in three public places (Sec. 43611)",
      note_exception=NONE,
      note_petition="If a proposition is defeated, the city may not call another election on a substantially similar proposition within six months unless a petition signed by 15 percent of the city electors (measured by the last gubernatorial vote) is filed (Sec. 43616)",
      note_votereqbyothergovtlevels="Counties follow a parallel procedure (Cal. Gov. Code Sec. 29900-29909) and also require a two-thirds vote of the electors voting (Sec. 29908)"),
    R(stab="CA", state="california",
      source=f"Cal. Gov. Code {SECT} 54386 (Revenue Bond Law of 1941)",
      source_url=f"{J}/california/code-gov/title-5/division-2/part-1/chapter-6/article-3/section-54386/",
      source_year=2025,
      source_filename="CA/260615_california_code-gov.txt",
      bond_type="rev",
      note_vote="Under the Revenue Bond Law of 1941 a majority of the voters voting on the proposition must approve before bonds may issue (Sec. 54386); a city is a 'local agency' covered by the chapter (Sec. 54307), and issuance is conditioned on authorization at the election (Sec. 54387), so the majority vote is a precondition of using this chapter, not optional within it",
      note_textreq="The authorizing resolution must state that the bonds are revenue bonds payable exclusively from the enterprise revenues, and that resolution frames the submitted proposition (Sec. 54382, 54384)",
      note_timing="At an election held for that purpose, which may be combined with an election on other propositions (Sec. 54380, 54383)",
      note_pubnotice="The resolution is published once a day for at least seven days in a daily newspaper in the local agency (or the equivalent for a less-than-daily paper) (Sec. 54385)",
      note_exception="Reconciliation: this chapter is only an OPTIONAL alternate method of financing (Sec. 54301.1, 54302) and refunding bonds issued under it need no election (Sec. 54661). Because revenue bonds payable solely from enterprise revenues are not constitutional 'indebtedness' (special-fund doctrine under Cal. Const. art. XVI Sec. 18), no vote is constitutionally required and cities commonly issue revenue bonds with no election under other authorities (see the Sec. 53570 row)",
      note_votereqbyothergovtlevels="'Local agency' also includes counties, public corporations, and districts authorized to operate an enterprise (Sec. 54307)"),
    R(stab="CA", state="california",
      source=f"Cal. Gov. Code {SECT} 53570 (general revenue-bond provisions)",
      source_url=f"{J}/california/code-gov/title-5/division-2/part-1/chapter-3/article-10/section-53570/",
      source_year=2025,
      source_filename="CA/260615_california_code-gov.txt",
      bond_type="rev",
      note_vote="No voter approval is required for revenue bonds issued outside the optional Revenue Bond Law of 1941. 'Revenue bonds' are defined as obligations payable from funds other than the proceeds of ad valorem taxes (Sec. 53570); such obligations are not constitutional 'indebtedness' and need no election",
      note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
      note_exception="Reconciliation: California revenue bonds payable solely from enterprise revenues escape the Cal. Const. art. XVI Sec. 18 two-thirds debt vote under the judicial special-fund doctrine. Cities most often issue enterprise revenue bonds with no vote under charter home-rule authority, this general framework, or a joint-powers/Marks-Roos pooling bond (Gov. Code Sec. 6584 et seq., outside the downloaded corpus). The Revenue Bond Law of 1941 (the Sec. 54386 row) is the lone optional scheme that adds a statutory majority vote",
      note_votereqbyothergovtlevels="'Local agency' here includes districts, counties, cities, school districts, and other public entities (Sec. 53570)"),

    # ==================== COLORADO ====================
    R(stab="CO", state="colorado",
      source=f"Colo. Rev. Stat. {SECT} 31-15-302 (municipal indebtedness)",
      source_url=f"{J}/colorado/title-31/powers-and-functions-of-cities-and-towns/article-15/part-3/section-31-15-302/",
      source_year=2024,
      source_filename="CO/260615_colorado_title-31.txt",
      bond_type="go",
      note_vote="No municipal debt may be created (except debt for supplying water) unless the question of incurring it is submitted at a regular or special municipal election and a majority of the registered electors voting on the question vote in favor (Sec. 31-15-302(1)(d)(II))",
      note_textreq="The debt is created by an irrepealable ordinance specifying the purposes to which the funds will be applied and providing for the levy of a tax to pay the debt; the ordinance or resolution submitting the question must state the maximum net effective interest rate at which the indebtedness may be incurred (Sec. 31-15-302(1)(d)(II),(V))",
      note_timing="At a regular or special municipal election held under the Colorado Municipal Election Code of 1965",
      note_pubnotice="Conducted under the Colorado Municipal Election Code of 1965; Sec. 31-15-302 itself does not prescribe a publication schedule",
      note_exception="Debt incurred to supply water requires no election, and the 3-percent-of-actual-value debt limit and the 30-year maturity cap do not apply to water debt (Sec. 31-15-302(1)(d)(II))",
      note_votereqbyothergovtlevels="Counties must obtain a majority vote to fund county indebtedness (Sec. 30-26-102); the TABOR row (Colo. Const. art. X Sec. 20) adds a voter-approval requirement for all districts"),
    R(stab="CO", state="colorado",
      source=f"Colo. Rev. Stat. {SECT} 30-26-102 (county funding indebtedness)",
      source_url=f"{J}/colorado/title-30/county-powers-and-functions/county-finance/article-26/part-1/section-30-26-102/",
      source_year=2024,
      source_filename="CO/260615_colorado_title-30.txt",
      bond_type="go",
      note_vote="County funding indebtedness must be approved by a majority of all the votes cast on the question (Sec. 30-26-102(1))",
      note_textreq="Electors vote by a separate ballot printed with the words 'for funding county debt' or 'against funding county debt' (Sec. 30-26-102(1))",
      note_timing=NONE,
      note_pubnotice=NONE,
      note_exception=NONE,
      note_votereqbyothergovtlevels="Municipalities must obtain a majority vote to incur debt (Sec. 31-15-302); the TABOR row adds a voter-approval requirement for all districts"),
    R(stab="CO", state="colorado",
      source=f"Colo. Const. art. X, {SECT} 20 (Taxpayer's Bill of Rights / TABOR)",
      source_url="https://law.justia.com/constitution/colorado/cnart10.html",
      source_year=2024,
      source_filename="CO/260615_colorado_constitution.txt",
      bond_type="both",
      note_vote="Voter approval in advance is required for the creation of any multiple-fiscal-year direct or indirect district debt or other financial obligation (without adequate present cash reserves pledged irrevocably) (art. X Sec. 20(4)(b))",
      note_textreq="The ballot title for a debt question must begin 'SHALL (DISTRICT) DEBT BE INCREASED (principal amount), WITH A REPAYMENT COST OF (maximum total cost)' (art. X Sec. 20(3)(c))",
      note_timing="At a November election, or on the first Tuesday in November of odd-numbered years, or at a general election (art. X Sec. 20(3)(a))",
      note_pubnotice="The district must mail a titled notice ('NOTICE OF ELECTION TO INCREASE DEBT') to all registered-voter households at least 30 days before the election (art. X Sec. 20(3)(b))",
      note_exception="TABOR-defined 'enterprises' (a government-owned business authorized to issue its own revenue bonds and receiving under 10 percent of annual revenue in government grants) are excluded from 'district', so enterprise revenue bonds require no vote (art. X Sec. 20(2)(b),(d))",
      note_votereqbyothergovtlevels="'District' means the state or any local government (counties, cities, towns, school districts), excluding enterprises (art. X Sec. 20(2)(b))"),

    # ==================== FLORIDA ====================
    R(stab="FL", state="florida",
      source=f"Fla. Const. art. VII, {SECT} 12 (local bonds)",
      source_url="https://law.justia.com/constitution/florida/",
      source_year=2025,
      source_filename="FL/260615_florida_constitution.txt",
      bond_type="go",
      note_vote="A municipality (or county, school district, special district) may issue bonds payable from ad valorem taxation and maturing more than 12 months after issuance ONLY when approved by vote of the electors (art. VII Sec. 12(a)); the historic 'freeholder' limitation has been superseded so all qualified electors may vote",
      note_textreq=NONE,
      note_timing="At an election; bond referenda may be held with other elections (Fla. Stat. 100.261)",
      note_pubnotice=NONE,
      note_exception="No election is needed to refund outstanding bonds at a lower net average interest cost rate (art. VII Sec. 12(b)); bonds NOT payable from ad valorem taxes (revenue bonds) fall outside this section and need no vote",
      note_votereqbyothergovtlevels="The same requirement applies to counties, school districts, special districts, and local governmental bodies with taxing power (art. VII Sec. 12)"),
    R(stab="FL", state="florida",
      source=f"Fla. Stat. {SECT} 100.201 (referendum required before issuing bonds)",
      source_url=f"{J}/florida/title-ix/chapter-100/section-100-201/",
      source_year=2025,
      source_filename="FL/260615_florida_title-ix.txt",
      bond_type="go",
      note_vote="Bonds that by law must be approved by referendum may be issued only after approval by a majority of the votes cast by those eligible to vote in the referendum (Sec. 100.201); a majority in favor authorizes issuance under art. VII Sec. 12 (Sec. 100.281)",
      note_textreq=NONE,
      note_timing="The governing authority orders the referendum by resolution; it may be held with other elections (Sec. 100.211, 100.261)",
      note_pubnotice="The governing authority gives notice of the bond referendum in the manner prescribed by Fla. Stat. Sec. 100.342 (Sec. 100.211). Sec. 100.342, re-fetched 2026-07-17 (raw/FL/260717_florida_statutes-section-100-342.txt), requires 'at least 30 days' notice of the election or referendum by publication in a newspaper of general circulation in the county, district, or municipality' (or on the applicable governmental website under s. 50.0311); 'The publication must be made at least twice, once in the fifth week and once in the third week before the week in which the election or referendum is to be held', with posting in at least five places if no newspaper/website is available. General election laws govern the conduct of the referendum (Sec. 100.221)",
      note_exception=NONE,
      note_votereqbyothergovtlevels="Applies to counties, districts, and municipalities alike (Sec. 100.201, 100.211)"),
    R(stab="FL", state="florida",
      source=f"Fla. Stat. {SECT} 166.121 (issuance of municipal bonds)",
      source_url=f"{J}/florida/title-xii/chapter-166/part-ii/section-166-121/",
      source_year=2025,
      source_filename="FL/260615_florida_title-xii.txt",
      bond_type="rev",
      note_vote="Municipal bonds are authorized by resolution or ordinance of the governing body and require an affirmative vote of the electors ONLY 'if required by the State Constitution' (Sec. 166.121(1)); revenue bonds payable solely from non-ad-valorem revenues fall outside art. VII Sec. 12 and so need no election",
      note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
      note_exception="Because revenue bonds are not payable from ad valorem taxation, the constitutional referendum (art. VII Sec. 12) does not apply; only ad-valorem-tax-backed GO bonds maturing over 12 months require a vote",
      note_votereqbyothergovtlevels="The governing body of every municipality may borrow and issue bonds for purposes permitted by the Constitution (Sec. 166.111)"),

    # ==================== GEORGIA ====================
    R(stab="GA", state="georgia",
      source=f"Ga. Code {SECT} 36-82-1 (election for bonded debt; notice)",
      source_url=f"{J}/georgia/title-36/provisions-applicable-to-counties-municipal-corporations-and-other-governmental-entities/chapter-82/article-1/section-36-82-1/",
      source_year=2024,
      source_filename="GA/260615_georgia_title-36.txt",
      bond_type="go",
      note_vote="A municipality (or county or political subdivision) that wishes to incur bonded debt under the Georgia Constitution must hold an election; a requisite majority of the qualified voters voting must vote for the bonds, which then authorizes issuance under Ga. Const. art. IX, Sec. V, Para. I or II (Sec. 36-82-3(a))",
      note_textreq="The election notice must specify the principal amount of the bonds, the purpose, the interest rate(s) (or a stated maximum rate), and the amount of principal to be paid each year; any brochure or advertisement issued with the governing body's consent is a binding statement of intention as to the use of the bond funds (Sec. 36-82-1(b),(d))",
      note_timing="On the day named in the published notice (Sec. 36-82-1(b))",
      note_pubnotice="Notice must be given for not less than 30 days immediately preceding the election in the newspaper in which the county sheriff's advertisements are published (Sec. 36-82-1(b))",
      note_exception="Outstanding bonded debt may be refunded by ordinance/resolution without a referendum, subject to stated conditions (Sec. 36-82-1(e), 36-82-3(b))",
      note_votereqbyothergovtlevels="The same election requirement applies to counties, municipal corporations, and other political subdivisions (Sec. 36-82-1(a))"),
    R(stab="GA", state="georgia",
      source=f"Ga. Code {SECT} 36-82-63 (revenue bonds; authorizing resolution)",
      source_url=f"{J}/georgia/title-36/provisions-applicable-to-counties-municipal-corporations-and-other-governmental-entities/chapter-82/article-3/section-36-82-63/",
      source_year=2024,
      source_filename="GA/260615_georgia_title-36.txt",
      bond_type="rev",
      note_vote="No voter approval; revenue bonds (issued in anticipation of the revenues of an undertaking) are authorized by a resolution adopted by a majority of the members of the governing body, which may take effect immediately and need not be published or posted (Sec. 36-82-63)",
      note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
      note_exception="Revenue bonds are payable solely from the revenues of the undertaking and are not a general obligation requiring an election under the Revenue Bond Law (Sec. 36-82-63)",
      note_votereqbyothergovtlevels="Available to counties, municipalities, and other political subdivisions under the Revenue Bond Law (Sec. 36-82-60 et seq.)"),

    # ==================== IDAHO ====================
    R(stab="ID", state="idaho",
      source=f"Idaho Code {SECT} 50-1026 (city bonds; ordinance; election)",
      source_url=f"{J}/idaho/title-50/chapter-10/section-50-1026/",
      source_year=2025,
      source_filename="ID/260615_idaho_title-50.txt",
      bond_type="go",
      note_vote="City general obligation coupon bonds may be issued only if two-thirds of the qualified electors voting at the election assent (Sec. 50-1026), implementing the Idaho Constitution's two-thirds requirement for municipal indebtedness (art. VIII Sec. 3)",
      note_textreq="The ballot must be substantially: 'In favor of issuing bonds to the amount of ... dollars for the purpose stated in Ordinance No. ...' and 'Against issuing bonds ...'; the bond ordinance must set forth the purposes required by Sec. 57-203 and provide for a tax to pay interest and a sinking fund within 30 years (Sec. 50-1026)",
      note_timing="On an election date authorized by Sec. 50-405 that falls more than 45 days after the clerk orders the election (Sec. 50-1026)",
      note_pubnotice="Notice is given by the county clerk in the official newspaper of the city in accordance with the election law in Title 34 (Sec. 50-1026)",
      note_exception="The constitutional vote does not apply to ordinary and necessary expenses authorized by general law (Idaho Const. art. VIII Sec. 3)",
      note_votereqbyothergovtlevels="The two-thirds vote applies to counties, cities, school districts, and other subdivisions (Idaho Const. art. VIII Sec. 3)"),
    R(stab="ID", state="idaho",
      source=f"Idaho Const. art. VIII, {SECT} 3 (revenue-bond provisos) & Revenue Bond Act ({SECT} 50-1027)",
      source_url="https://law.justia.com/constitution/idaho/article-viii/section-3/",
      source_year=2025,
      source_filename="ID/260615_idaho_constitution.txt",
      bond_type="rev",
      note_vote="Revenue bonds payable solely from facility revenues are NOT uniformly vote-exempt in Idaho: for water systems, sewage collection/treatment systems, and rehabilitation of electrical generating facilities, a MAJORITY of the qualified electors voting must assent; for off-street parking, public recreation, and air-navigation facilities, a TWO-THIRDS vote is required (Idaho Const. art. VIII Sec. 3)",
      note_textreq=NONE,
      note_timing="At an election held for that purpose (Idaho Const. art. VIII Sec. 3)",
      note_pubnotice=NONE,
      note_exception="Port-district revenue bonds may be issued WITHOUT any voter authorization (Idaho Const. art. VIII Sec. 3); pure special-fund revenue obligations not pledging tax revenue fall outside the art. VIII Sec. 3 debt limit. Procedure for revenue bonds is set by the Revenue Bond Act, Sec. 50-1027 et seq.",
      note_votereqbyothergovtlevels="The facility-specific revenue-bond votes apply to cities and other political subdivisions; port districts are exempt (Idaho Const. art. VIII Sec. 3)"),

    # ==================== LOUISIANA ====================
    R(stab="LA", state="louisiana",
      source=f"La. Rev. Stat. {SECT} 39:521 (general obligation bonds)",
      source_url=f"{J}/louisiana/revised-statutes/title-39/rs-39-521/",
      source_year=2025,
      source_filename="LA/260615_louisiana_title-39.txt",
      bond_type="go",
      note_vote="GO bonds (issued under La. Const. art. VI Sec. 33) may be issued only after approval by a majority of the electors who vote at an election held under the Louisiana Election Code (Sec. 39:521(A))",
      note_textreq="The proposition must state the maximum principal amount, the maximum term (not exceeding 40 years), the maximum interest rate, the purposes of the bonds, and the estimated millage rate to be levied in the first year (Sec. 39:521(A))",
      note_timing="At an election held in accordance with the Louisiana Election Code; bonds may be issued after the results are promulgated (Sec. 39:521(A),(B))",
      note_pubnotice="Conducted under the Louisiana Election Code (Title 18); Sec. 39:521 does not itself prescribe the publication schedule",
      note_exception="The full faith and credit is pledged and an unlimited ad valorem tax is levied; debt is capped (for municipalities and parishes, 10 percent per purpose or 35 percent in the aggregate) (Sec. 39:521(C),(D))",
      note_votereqbyothergovtlevels="'Governmental entity' covers parishes, municipalities, school boards/districts, and other subdivisions, each with its own debt cap (Sec. 39:521(C))"),
    R(stab="LA", state="louisiana",
      source=f"La. Rev. Stat. {SECT} 39:524 (revenue bonds)",
      source_url=f"{J}/louisiana/revised-statutes/title-39/rs-39-524/",
      source_year=2025,
      source_filename="LA/260615_louisiana_title-39.txt",
      bond_type="rev",
      note_vote="Revenue bonds are not automatically subject to a vote, but a protest petition can force one: the governing authority adopts a resolution of intention, and if a sufficient petition objects, the bonds may not be issued until approved by a majority of the qualified electors voting at a special election (Sec. 39:524(J))",
      note_textreq=NONE,
      note_timing="If a petition forces an election, it is held in the manner provided by Chapter 6-A of Title 18 of the Louisiana Revised Statutes (Sec. 39:524(J))",
      note_pubnotice="The resolution of intention (with a general description of the bonds, security, and source of repayment, and the date of a public hearing on objections) must be published in four consecutive weekly issues of a newspaper of general circulation in the parish (Sec. 39:524(J))",
      note_exception="Revenue bonds are payable solely from the revenues of the system or work of public improvement and are not a charge on the entity's other income (La. Const. art. VI Sec. 37; Sec. 39:524(A),(C))",
      note_petition="At the public hearing, a petition signed by electors numbering at least 5 percent of those who voted at the last election in the governmental entity, certified by the registrar of voters, forces a majority-vote special election (Sec. 39:524(J))",
      note_votereqbyothergovtlevels="Available to any governmental entity (parishes, municipalities, and other subdivisions) (Sec. 39:524(A))"),

    # ==================== MAINE ====================
    R(stab="ME", state="maine",
      source=f"Me. Stat. tit. 30-A, {SECT} 5772 (general obligation securities)",
      source_url=f"{J}/maine/title-30-a/part-2/subpart-9/chapter-223/subchapter-6/section-5772/",
      source_year=2025,
      source_filename="me/260615_maine_title-30-a.txt",
      bond_type="go",
      note_vote="Maine imposes no uniform statewide bond referendum; municipal general obligation securities are authorized by the municipal legislative body. In a town the legislative body is the open town meeting, so resident voters approve the bonds by majority vote; in a council form of government the council authorizes",
      note_textreq="The treasurer must prepare a signed financial statement to accompany any bond question submitted to the electors for ratification, setting out total bonds outstanding/authorized-but-unissued/contemplated and an estimate and explanation of the principal and interest cost; the statement may be printed on the ballot (Sec. 5772(2-A))",
      note_timing="At a town meeting or municipal election when a bond question is submitted to the electors",
      note_pubnotice=NONE,
      note_exception="Securities to fund or refund existing debt are authorized on the same basis; anticipatory borrowing (notes) is permitted within the authorized amount (Sec. 5772(1),(2))",
      note_votereqbyothergovtlevels="Counties and other municipalities authorize bonds through their own legislative bodies under Title 30-A"),
    R(stab="ME", state="maine",
      source=f"Me. Stat. tit. 30-A, {SECT} 5404 (municipal revenue bonds)",
      source_url=f"{J}/maine/title-30-a/part-2/subpart-8/chapter-213/section-5404/",
      source_year=2025,
      source_filename="me/260615_maine_title-30-a.txt",
      bond_type="rev",
      note_vote="Whether a vote is required depends on the type of municipality: a CITY's municipal officers may issue revenue bonds for a revenue-producing municipal facility by resolution with no referendum; a TOWN may not issue them until the general purpose and maximum principal amount are approved by ballot by a majority of the votes cast (Sec. 5404(1),(1)(A))",
      note_textreq="For a town, the ballot must state the general purpose and the maximum principal amount of the proposed bonds; the treasurer's financial statement must accompany any revenue or revenue-refunding bond question submitted to the electors (Sec. 5404(1)(A),(1-A))",
      note_timing="Town votes are held and conducted under Sec. 2528 to 2531-B (town-meeting/secret-ballot procedure) (Sec. 5404(1)(A))",
      note_pubnotice=NONE,
      note_exception="The town-vote requirement applies only to municipalities of population 1,000 or more; total votes cast must equal at least 20 percent of the municipality's vote for Governor at the last gubernatorial election (Sec. 5404(1),(1)(A))",
      note_votereqbyothergovtlevels="Cities issue revenue bonds without a referendum; only towns must hold a ballot vote (Sec. 5404(1)(A))"),

    # ==================== MICHIGAN ====================
    R(stab="MI", state="michigan",
      source=f"Mich. Comp. Laws {SECT} 141.164 (Unlimited Tax Election Act)",
      source_url=f"{J}/michigan/chapter-141/statute-act-189-of-1979/section-141-164/",
      source_year=2025,
      source_filename="mi/260615_michigan_chapter-141.txt",
      bond_type="go",
      note_vote="Unlimited-tax (UTGO) bonds require voter approval: a municipality may make a binding unlimited tax pledge to secure bonds only upon the approving vote of a majority of the qualified electors voting on the question (Sec. 141.164(1),(3)), consistent with Mich. Const. 1963 art. IX Sec. 6",
      note_textreq=NONE,
      note_timing="At a regularly scheduled election or a special election called for the purpose (Sec. 141.164(1))",
      note_pubnotice="The notice of election sets out a brief description of the purpose of each unlimited tax pledge and the estimated period over which the obligations will be issued (Sec. 141.164(3) procedure)",
      note_exception="Limited-tax GO bonds do not need a vote (see the Sec. 141.2517 row); this act does not require a vote where one is not otherwise required by law (Sec. 141.164)",
      note_votereqbyothergovtlevels="Applies to any 'public corporation' authorized to pledge unlimited taxes (counties, cities, villages, townships, districts) (Sec. 141.162, 141.164)"),
    R(stab="MI", state="michigan",
      source=f"Mich. Comp. Laws {SECT} 141.2517 (Revised Municipal Finance Act; capital improvement)",
      source_url=f"{J}/michigan/chapter-141/statute-act-34-of-2001/division-34-2001-v/section-141-2517/",
      source_year=2025,
      source_filename="mi/260615_michigan_chapter-141.txt",
      bond_type="go",
      note_vote="Limited-tax GO bonds for capital improvement items may be issued by resolution of the governing body WITHOUT a vote of the electors; a vote (majority) is required only if a sufficient referendum petition is filed (Sec. 141.2517(1),(2))",
      note_textreq=NONE,
      note_timing="If a referendum is forced, it is held at a general or special election (Sec. 141.2517(2))",
      note_pubnotice="Before issuance the unit must publish a notice of intent (at least 1/4 page) directed to the electors, stating the maximum amount, purpose, source of payment, and the right of referendum (Sec. 141.2517(2))",
      note_exception="Securities under this section may not exceed 5 percent of state equalized valuation (Sec. 141.2517(3))",
      note_petition="If within 45 days after the notice of intent a petition signed by not less than 10 percent or 15,000 of the registered electors (whichever is less) is filed, the bonds may not be issued until approved by a majority vote (Sec. 141.2517(2))",
      note_votereqbyothergovtlevels="Applies to counties, cities, villages, and townships (Sec. 141.2517(1))"),
    R(stab="MI", state="michigan",
      source=f"Mich. Comp. Laws {SECT} 141.133 (Revenue Bond Act of 1933)",
      source_url=f"{J}/michigan/chapter-141/statute-act-94-of-1933/section-141-133/",
      source_year=2025,
      source_filename="mi/260615_michigan_chapter-141.txt",
      bond_type="rev",
      note_vote="Revenue bonds are issued by the governing body WITHOUT submitting the proposition to the voters; a majority vote is required only if a sufficient referendum petition is filed after the notice of intent (Sec. 141.133)",
      note_textreq=NONE,
      note_timing="If a referendum is forced, it is held at a general or special election (Sec. 141.133)",
      note_pubnotice="The governing body must publish a notice of intent to issue bonds, directed to the electors, stating the maximum amount, purpose, source of payment, and right of referendum (Sec. 141.133)",
      note_exception="No notice of intent is required for refunding bonds or bonds issued to comply with a court order or a state/federal pollution-control order (Sec. 141.133)",
      note_petition="A petition signed by not less than 10 percent or 15,000 of the registered electors (whichever is less), filed within 45 days of the notice, forces a majority-vote referendum (Sec. 141.133)",
      note_votereqbyothergovtlevels="Applies to all 'public corporations' (borrowers) under the Revenue Bond Act (Sec. 141.133)"),

    # ==================== MISSOURI ====================
    R(stab="MO", state="missouri",
      source=f"Mo. Const. art. VI, {SECT} 26(b)",
      source_url="https://law.justia.com/constitution/missouri/article-vi/section-26-b/",
      source_year=2025,
      source_filename="mo/260615_missouri_constitution.txt",
      bond_type="go",
      note_vote="A city, county, town or village may incur GO debt (up to 5 percent of taxable tangible property) only by a vote of the qualified electors; the required margin is four-sevenths at the general municipal election day, primary, or general elections, and two-thirds at all other elections (art. VI Sec. 26(b))",
      note_textreq=NONE,
      note_timing="At a general municipal election day, primary, general, or other election (the date determines whether the 4/7 or 2/3 margin applies) (art. VI Sec. 26(b))",
      note_pubnotice=NONE,
      note_exception="Additional 5 percent for streets/sewers (Sec. 26(c)/(d)) and additional 10 percent for waterworks/electric/light plants (Sec. 26(e)) carry the same 4/7-or-2/3 vote; before incurring debt an annual tax sufficient to pay principal and interest within 20 years must be provided (Sec. 26(f))",
      note_votereqbyothergovtlevels="The same vote applies to counties, cities, incorporated towns or villages, school districts (15 percent limit), and other political subdivisions (art. VI Sec. 26(b))"),
    R(stab="MO", state="missouri",
      source=f"Mo. Const. art. VI, {SECT} 27(a) (utility/airport revenue bonds)",
      source_url="https://law.justia.com/constitution/missouri/article-vi/section-27-a/",
      source_year=2025,
      source_filename="mo/260615_missouri_constitution.txt",
      bond_type="rev",
      note_vote="Missouri requires a vote even for these revenue bonds: a city, county or town may issue revenue bonds for water/gas/electric/heating/power plants or airports only by a vote of a majority of the qualified electors voting thereon (art. VI Sec. 27(a))",
      note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
      note_exception="The bonds are payable solely from the revenues of the utility or airport and are not subject to the GO debt limit; only enterprises listed in Sec. 27(a) are covered",
      note_votereqbyothergovtlevels="Applies to any county, city, or incorporated town or village owning the utility or airport (art. VI Sec. 27(a))"),
    R(stab="MO", state="missouri",
      source=f"Mo. Rev. Stat. {SECT} 250.070 (sewerage system revenue bonds)",
      source_url=f"{J}/missouri/title-xv/chapter-250/section-250-070/",
      source_year=2025,
      source_filename="mo/260615_missouri_title-xv.txt",
      bond_type="rev",
      note_vote="Sewer/waterworks-sewerage revenue bonds may not be issued unless approved by a majority of the voters of the city, town or village (or four-sevenths of the voters of a sewer district) voting on the question (Sec. 250.070(1))",
      note_textreq="The ballot must be substantially: 'Shall ... (name of city, town, village, or district) issue revenue bonds in the amount of ... dollars?' (Sec. 250.070(2))",
      note_timing=NONE, note_pubnotice=NONE,
      note_exception="The bonds are payable solely from the revenues of the sewerage (or combined waterworks-and-sewerage) system",
      note_votereqbyothergovtlevels="Cities/towns/villages use a majority; sewer districts use four-sevenths of those voting (Sec. 250.070(1))"),

    # ==================== MONTANA ====================
    R(stab="MT", state="montana",
      source=f"Mont. Code {SECT} 7-7-4221 (election on incurring indebtedness)",
      source_url=f"{J}/montana/title-7/chapter-7/part-42/section-7-7-4221/",
      source_year=2025,
      source_filename="mt/260615_montana_title-7.txt",
      bond_type="go",
      note_vote="Whenever a municipality wishes to issue bonds pledging its general credit, the question must first be submitted to the registered electors and is approved by a majority of the votes cast on the issue (Sec. 7-7-4221(1), 7-7-4235)",
      note_textreq=NONE,
      note_timing="At an election; a 20-percent petition may also compel the governing body to call the election (Sec. 7-7-4221, 7-7-4224)",
      note_pubnotice="Notice of the election is given under Sec. 13-1-108 and must state the election date, the amount of bonds proposed, and the purpose (Sec. 7-7-4227)",
      note_exception="No election is needed to issue refunding bonds or revenue bonds that do not pledge the general credit of the municipality (Sec. 7-7-4221(2)); however, water and sewer system bonds DO require an election (Sec. 7-7-4222)",
      note_petition="Electors may petition for a bond election; the petition must be signed by not less than 20 percent of the qualified electors and state the purpose and an estimate of the amount (Sec. 7-7-4224)",
      note_votereqbyothergovtlevels="Counties follow a parallel procedure in Title 7, chapter 7, part 22"),
    R(stab="MT", state="montana",
      source=f"Mont. Code {SECT} 7-7-4222 (election for water and sewer system bonds)",
      source_url=f"{J}/montana/title-7/chapter-7/part-42/section-7-7-4222/",
      source_year=2025,
      source_filename="mt/260615_montana_title-7.txt",
      bond_type="rev",
      note_vote="Montana requires an election for municipal water and sewer system bonds; approval is by a majority of the votes cast on the issue (Sec. 7-7-4222, 7-7-4235)",
      note_textreq=NONE,
      note_timing="At an election held in the manner provided for general-credit bond elections (Sec. 7-7-4222, 7-7-4227)",
      note_pubnotice="Notice of the election is given under Sec. 13-1-108, stating the date, amount, and purpose (Sec. 7-7-4227)",
      note_exception="Revenue bonds that do not pledge the general credit of the municipality are otherwise exempt from the bond election (Sec. 7-7-4221(2)); the water/sewer election requirement is the exception to that exemption",
      note_votereqbyothergovtlevels="Applies to cities and towns issuing water/sewer system bonds (Sec. 7-7-4222)"),

    # ==================== NORTH CAROLINA ====================
    R(stab="NC", state="north carolina",
      source=f"N.C. Gen. Stat. {SECT} 159-61 (bond referenda; Local Government Bond Act)",
      source_url=f"{J}/north-carolina/chapter-159/article-4/section-159-61/",
      source_year=2025,
      source_filename="nc/260615_north-carolina_chapter-159.txt",
      bond_type="go",
      note_vote="When a bond order must be approved by the voters, it passes on the affirmative vote of a majority of those who vote on it (Sec. 159-61(a)); voter approval is required for GO debt secured by a pledge of taxing power under N.C. Const. art. V Sec. 4",
      note_textreq="The ballot question is in substantially the statutory form, stating the bond amount, purpose, that additional property taxes may be levied to pay the bonds, the estimated cumulative cost over the life of the bonds at the highest recent interest rate, and the resulting tax-liability increase per $100,000 of value (Sec. 159-61(d))",
      note_timing="The referendum date is fixed by the governing board, not more than one year after the bond order, on a date permitted by G.S. 163-287 (Sec. 159-61(b))",
      note_pubnotice="The clerk publishes notice of the referendum at least twice: the first not less than 14 days and the second not less than 7 days before the last day to register; the notice states the date, the maximum bond amount, the purpose, and that taxes will or may be levied (Sec. 159-61(c))",
      note_exception="Not all GO bonds require a vote: under the Local Government Bond Act and N.C. Const. art. V Sec. 4, certain bonds (e.g., two-thirds bonds and bonds for specified purposes) may be issued without a referendum",
      note_votereqbyothergovtlevels="Applies uniformly to counties, cities, and special districts; referenda are conducted by the county board of elections (Sec. 159-61(b))"),
    R(stab="NC", state="north carolina",
      source=f"N.C. Gen. Stat. {SECT} 159-83 (Local Government Revenue Bond Act; powers)",
      source_url=f"{J}/north-carolina/chapter-159/article-5/section-159-83/",
      source_year=2025,
      source_filename="nc/260615_north-carolina_chapter-159.txt",
      bond_type="rev",
      note_vote="No voter approval; a municipality issues revenue bonds for a revenue bond project by resolution of its governing board (subject to Local Government Commission approval), payable from project revenues (Sec. 159-83)",
      note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
      note_exception="Revenue bonds are payable solely from the rates, fees, and charges of the revenue-producing utility or enterprise and are not secured by the taxing power, so the art. V Sec. 4 referendum does not apply (Sec. 159-83)",
      note_votereqbyothergovtlevels="The State and each municipality (counties, cities, and other units) have these revenue-bond powers (Sec. 159-83)"),

    # ==================== NORTH DAKOTA ====================
    R(stab="ND", state="north dakota",
      source=f"N.D. Cent. Code {SECT} 21-03-07 (election required)",
      source_url=f"{J}/north-dakota/title-21/chapter-21-03/",
      source_year=2025,
      source_filename="ND/260615_north-dakota_title-21.txt",
      bond_type="go",
      note_vote="A municipality (county, city, public school district, or park district) may not issue bonds unless first authorized at a primary or general election by a vote equal to SIXTY PERCENT of all the qualified voters of the municipality voting on the question (Sec. 21-03-07)",
      note_textreq="A bond-election ballot form substantially as prescribed in Sec. 21-03-13 must be used (Sec. 21-03-10.1, 21-03-13)",
      note_timing="For a county, city, school district, or park district the election must be set for the same date as a statewide primary or general election; the question must be certified to the county auditor at least 64 days before the election (Sec. 21-03-11)",
      note_pubnotice="The election is called, conducted, and noticed in the manner specified by Sec. 21-03-11 (publication of legal notice arranged with the county)",
      note_exception="No vote is required for the bonds excepted in Sec. 21-03-07 (e.g., refunding and certain special-fund/revenue obligations under Sec. 21-03-06); the constitutional debt cap is 5 percent of assessed value, raisable by a 2/3 vote (plus a separate 4 percent for waterworks/sewers) (N.D. Const. art. X Sec. 15)",
      note_petition="Voters may initiate a bond election by filing an initial resolution with a petition signed by one-fourth of the municipality's qualified electors (Sec. 21-03-10(2))",
      note_votereqbyothergovtlevels="The 60 percent requirement applies to counties, cities, public school districts, and park districts (Sec. 21-03-07, 21-03-11)"),
    R(stab="ND", state="north dakota",
      source=f"N.D. Const. art. X, {SECT} 15 (revenue-producing utility bonds)",
      source_url="https://law.justia.com/constitution/north-dakota/article-x/section-15/",
      source_year=2025,
      source_filename="ND/260615_north-dakota_constitution.txt",
      bond_type="rev",
      note_vote="Any county or city may issue bonds upon a revenue-producing utility it owns (or to purchase, acquire, build, or establish one) by a MAJORITY vote, in an amount not exceeding the physical value of the utility (N.D. Const. art. X Sec. 15)",
      note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
      note_exception="Bonds on revenue-producing utilities are excluded from the entity's 5-percent general debt limit (N.D. Const. art. X Sec. 15); a city may also become indebted up to 4 percent for waterworks or sewers",
      note_votereqbyothergovtlevels="Applies to both counties and cities owning a revenue-producing utility (N.D. Const. art. X Sec. 15)"),

    # ==================== NEBRASKA ====================
    R(stab="NE", state="nebraska",
      source=f"Neb. Rev. Stat. {SECT} 18-506.01 (revenue and GO bonds; conditions)",
      source_url=f"{J}/nebraska/chapter-18/statute-18-506-01/",
      source_year=2025,
      source_filename="NE/260615_nebraska_chapter-18.txt",
      bond_type="both",
      note_vote="Revenue bonds (authorized by Sec. 18-502) may be issued by ordinance of the mayor and council or village board WITHOUT any vote. General obligation bonds (authorized by Sec. 18-506) may be issued only after the question is submitted to the electors and more than a majority of the electors voting at the election vote in favor (Sec. 18-506.01)",
      note_textreq=NONE,
      note_timing="At a general or special election (Sec. 18-506.01)",
      note_pubnotice="For GO bonds, three weeks' notice of the election must be published in a legal newspaper published in or of general circulation in the city or village (Sec. 18-506.01)",
      note_exception="Revenue bonds require no election; by judicial construction sewer bonds require approval by more than 60 percent of the electors voting (State ex rel. City of Grand Island v. Johnson)",
      note_votereqbyothergovtlevels="Applies to cities and villages (the mayor and council or board of trustees) (Sec. 18-506.01)"),

    # ==================== NEW MEXICO ====================
    R(stab="NM", state="new mexico",
      source=f"N.M. Stat. {SECT} 3-30-6 (bond election; publication; ballots)",
      source_url=f"{J}/new-mexico/chapter-3/article-30/section-3-30-6/",
      source_year=2025,
      source_filename="NM/260615_new-mexico_chapter-3.txt",
      bond_type="go",
      note_vote="Before GO bonds are issued the governing body must submit the question to the qualified electors; a majority of those voting must approve (N.M. Const. art. IX Sec. 12; Sec. 3-30-6(A))",
      note_textreq="The question must state the purpose and the amount of the issue, with a separate question for each purpose; the ballot reads 'For ... (type) bonds' and 'Against ... (type) bonds' for each issue (Sec. 3-30-6(C))",
      note_timing="At the regular local election or a special election called for the purpose under N.M. Const. art. IX Sec. 12 (Sec. 3-30-6(A))",
      note_pubnotice="The governing body gives notice of the time and place of the election and the purpose of the bonds; the election is conducted under the Local Election Act (Ch. 1, art. 22) (Sec. 3-30-6(B))",
      note_exception="The debt is created by an irrepealable ordinance providing a tax (not exceeding 12 mills) to pay it within 50 years; a special-election proposal that fails may not be resubmitted within one year (N.M. Const. art. IX Sec. 12; Sec. 3-30-6)",
      note_votereqbyothergovtlevels="Applies to cities, towns, and villages (N.M. Const. art. IX Sec. 12)"),
    R(stab="NM", state="new mexico",
      source=f"N.M. Stat. {SECT} 3-23-2 (election on acquiring a utility with revenue bonds)",
      source_url=f"{J}/new-mexico/chapter-3/article-23/section-3-23-2/",
      source_year=2025,
      source_filename="NM/260615_new-mexico_chapter-3.txt",
      bond_type="rev",
      note_vote="New Mexico revenue bonds are not always vote-exempt: a municipality may not acquire a municipal utility with revenue-bond funds until the question of acquiring the utility is submitted to the qualified electors and a majority of the votes cast favor the acquisition (Sec. 3-23-2(A))",
      note_textreq=NONE,
      note_timing="At a regular local election or a special election (no special election within 90 days before a regular local election) (Sec. 3-23-2(A))",
      note_pubnotice=NONE,
      note_exception="No election is required to acquire a generating facility by a municipality that already owned electric facilities on July 1, 1979, or where the voters have already approved a debt for the utility under art. IX Sec. 12 / Sec. 3-30, or where the municipality has owned and operated the utility for more than one year (Sec. 3-23-2(A),(E)); revenue bonds to improve an already-owned utility are not subject to this acquisition vote",
      note_votereqbyothergovtlevels="Applies to municipalities acquiring a utility (Sec. 3-23-2)"),

    # ==================== OHIO ====================
    # Ohio's operative bond-vote statutes (Ohio Rev. Code ch. 133 Uniform Public
    # Securities Law; ch. 5705 the 10-mill limit) sit in Ohio code titles that were
    # NOT among the downloaded titles (5, 7, 19, 35, 49), so these rows are grounded
    # in the Ohio Constitution, which IS in the corpus, with the statutes referenced.
    R(stab="OH", state="ohio",
      source=f"Ohio Const. art. XII, {SECT} 11 (with Ohio Rev. Code ch. 133, 5705)",
      source_url="https://law.justia.com/constitution/ohio/article-xii/section-11/",
      source_year=2025,
      source_filename="oh/260615_ohio_constitution.txt",
      bond_type="go",
      note_vote="Unvoted (limited-tax) GO bonds may be issued without an election within the 10-mill 'inside millage' limitation and statutory net-debt limits; GO bonds requiring a property tax levied OUTSIDE the 10-mill limit (unlimited-tax / UTGO) must be approved by a majority of the electors. Any debt must be accompanied by a tax sufficient to pay it (Ohio Const. art. XII Sec. 11)",
      note_textreq=NONE,
      note_timing="At a general or special election; the taxing authority submits the question of issuing GO bonds to the electors by legislation declaring the necessity, purpose, and election date (Ohio Rev. Code Sec. 133.18, now in corpus)",
      note_pubnotice=NONE,
      note_exception="The voted/unvoted procedure and the millage framework are now in the corpus (Ohio Rev. Code ch. 133 + ch. 5705 re-fetched 2026-07-17; raw/OH/260717_ohio_revised-code-chapter-133.txt and raw/OH/260717_ohio_revised-code-chapter-5705-key.txt). On primary text: a municipal corporation 'shall not incur net indebtedness that exceeds ... ten and one-half per cent of its tax valuation, or incur WITHOUT A VOTE of the electors net indebtedness that exceeds ... five and one-half per cent of that tax valuation' (Sec. 133.05(A)) -- so unvoted GO debt is capped at 5.5% and voted GO debt up to 10.5%; Sec. 133.18 governs submitting GO bonds to the electors. The 'ten-mill limitation' (Sec. 5705.02) caps aggregate inside-millage tax at ten mills per dollar of valuation except levies specifically authorized in excess; a two-thirds vote of the taxing authority may certify to the ballot a levy in excess of the ten-mill limitation (Sec. 5705.19, Sec. 5705.191), tying the constitutional 10-mill cap (art. XII Sec. 2) to the voted/unvoted line",
      note_votereqbyothergovtlevels="The same voted/unvoted framework applies to counties, municipalities, townships, and school districts (Ohio Rev. Code ch. 133)"),
    R(stab="OH", state="ohio",
      source=f"Ohio Const. art. XVIII, {SECT} 12 (municipal utility mortgage bonds)",
      source_url="https://law.justia.com/constitution/ohio/article-xviii/section-12/",
      source_year=2025,
      source_filename="oh/260615_ohio_constitution.txt",
      bond_type="rev",
      note_vote="No voter approval; a municipality that acquires, constructs, or extends a public utility may issue mortgage (revenue) bonds for it beyond the general debt limit, secured only by the property and revenues of the utility and imposing no liability on the municipality (Ohio Const. art. XVIII Sec. 12)",
      note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
      note_exception="These bonds are not 'net indebtedness' of the municipality and are excluded from the debt limit; the foreclosure franchise may not exceed 20 years (Ohio Const. art. XVIII Sec. 12). The statutory exclusion is now in corpus and confirms the no-vote result: in calculating a municipal corporation's net indebtedness, 'Self-supporting securities issued for any purposes including, without limitation ... Water systems or facilities' and other utility purposes 'shall [not] be considered' (Ohio Rev. Code Sec. 133.05(B)(1), re-fetched 2026-07-17), so revenue-secured utility bonds fall outside the 5.5% unvoted / 10.5% voted net-debt caps that trigger an election",
      note_votereqbyothergovtlevels="Available to any municipality owning or building a public utility (Ohio Const. art. XVIII Sec. 12)"),

    # ==================== OKLAHOMA ====================
    R(stab="OK", state="oklahoma",
      source=f"Okla. Stat. tit. 11, {SECT} 22-128 (municipal improvement bonds)",
      source_url=f"{J}/oklahoma/title-11/section-11-22-128/",
      source_year=2025,
      source_filename="OK/260615_oklahoma_title-11.txt",
      bond_type="go",
      note_vote="No money may be borrowed or GO bonds issued for municipal improvements until the governing body is instructed to do so by a vote of at least THREE-FIFTHS of the registered voters voting on the question (Sec. 11-22-128), consistent with Okla. Const. art. X Sec. 26",
      note_textreq="Where the bonds finance conservation easements, the question must reflect that purpose (Sec. 11-22-128)",
      note_timing="At any election held in the municipality (Sec. 11-22-128)",
      note_pubnotice=NONE,
      note_exception="Bonds are payable within 25 years and the governing body must levy a tax to pay them; the 3/5 requirement applies unless the Constitution and laws provide otherwise (Sec. 11-22-128)",
      note_votereqbyothergovtlevels="Counties and school districts have their own constitutional bond-vote requirements (Okla. Const. art. X)"),
    R(stab="OK", state="oklahoma",
      source=f"Okla. Stat. tit. 11, {SECT} 22-155 (Municipal Utility Revenue Bond Act)",
      source_url=f"{J}/oklahoma/title-11/section-11-22-155/",
      source_year=2025,
      source_filename="OK/260615_oklahoma_title-11.txt",
      bond_type="rev",
      note_vote="Oklahoma revenue bonds are not always vote-exempt: as a condition precedent to issuing utility revenue obligations, the municipality must submit the question to the qualified voters at an election if the kind of public utility has not previously been owned/operated by the municipality (or its public trust), or has not been approved by a majority of voters within the preceding 10 years (Sec. 11-22-155)",
      note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
      note_exception="No new election is required where the municipality (or a public trust having it as beneficiary) already owned/operated that kind of utility, or where voters approved the acquisition/construction within the prior 10 years (Sec. 11-22-155). NARROW-TRIGGER CAVEAT: Sec. 22-155 is the Municipal Utility Revenue Bond Act, whose public vote attaches only to a municipality DIRECTLY financing a kind of utility it has not previously owned. The GENERAL / modern vehicle for municipal revenue financing in Oklahoma is the PUBLIC TRUST (60 O.S. Sec. 176 et seq., the Public Trust Act, re-fetched 2026-07-17: raw/OK/260717_oklahoma_title-60-public-trust-act-176-180.txt), a separate legal entity with the municipality as beneficiary. A public trust issues its revenue bonds through its trustees with NO public referendum; the only approval the Act requires is governmental, not electoral: 'No trust in which a county or municipality is the beneficiary shall hereafter create an indebtedness or obligation until the indebtedness or obligation has been approved by a two-thirds (2/3) vote of the governing body of the beneficiary' (60 O.S. Sec. 176); a municipal governing body of fewer than seven members approves by a 3/5 vote. Debt issued pursuant to a vote of the electors under the Constitution is separately excepted from the trust-debt definition",
      note_nichevote="Public-trust revenue financing (the general no-referendum route) requires a two-thirds vote of the beneficiary municipality's governing body (a 3/5 vote for a governing body of fewer than seven members), not a vote of the electors (60 O.S. Sec. 176)",
      note_votereqbyothergovtlevels="Applies to municipalities and their beneficiary public trusts (Sec. 11-22-155; 60 O.S. Sec. 176 for the public-trust route, which also covers counties as beneficiaries)"),

    # ==================== OREGON ====================
    R(stab="OR", state="oregon",
      source=f"Or. Rev. Stat. {SECT} 287A.050 (city general obligation bonds)",
      source_url=f"{J}/oregon/volume-07/chapter-287a/section-287a-050/",
      source_year=2025,
      source_filename="or/260615_oregon_chapter-287a.txt",
      bond_type="go",
      note_vote="A city may issue general obligation bonds only upon approval of the electors of the city; approval is by a majority of those voting (Sec. 287A.050(1))",
      note_textreq=NONE,
      note_timing="At an election (Sec. 287A.050)",
      note_pubnotice=NONE,
      note_exception="GO refunding bonds may be issued to refund or purchase outstanding GO bonds WITHOUT elector approval (Sec. 287A.050); proceeds finance capital construction/improvements permitted by Or. Const. art. XI Sec. 11, 11b, and 11L",
      note_votereqbyothergovtlevels="A county may likewise issue GO bonds only upon approval of the electors of the county, unless its charter provides otherwise (Sec. 287A.050)"),
    R(stab="OR", state="oregon",
      source=f"Or. Rev. Stat. {SECT} 287A.150 (revenue bonds)",
      source_url=f"{J}/oregon/volume-07/chapter-287a/section-287a-150/",
      source_year=2025,
      source_filename="or/260615_oregon_chapter-287a.txt",
      bond_type="rev",
      note_vote="Revenue bonds are authorized by resolution or nonemergency ordinance and do not require an automatic vote; a majority-vote election is triggered only by referral (of an ordinance) or by a sufficient petition (against a resolution) (Sec. 287A.150)",
      note_textreq=NONE,
      note_timing="If referred or petitioned, the question is placed on the ballot at the next lawfully available election date (Sec. 287A.150(2),(3))",
      note_pubnotice="For resolution-authorized revenue bonds, a notice must be published in a newspaper of general circulation stating the resolution date, the expected source of repayment, the estimated principal amount, the referral procedure, and the petition deadline; the bonds may not be sold for at least 60 days after publication (Sec. 287A.150(3),(4))",
      note_exception="A nonemergency ordinance is subject to referral; if no petition/referral occurs the bonds issue with no vote (Sec. 287A.150(2),(3))",
      note_petition="If, within 60 days after the notice, electors file petitions with valid signatures of at least 5 percent of the public body's electors, the question must go to a vote and the bonds may not be sold unless a majority approve (Sec. 287A.150(3)(b))",
      note_votereqbyothergovtlevels="Applies to any 'public body' (cities, counties, and districts) issuing revenue bonds (Sec. 287A.150(1))"),

    # ==================== SOUTH DAKOTA ====================
    R(stab="SD", state="south dakota",
      source=f"S.D. Codified Laws {SECT} 6-8B-2 (election required for issuance)",
      source_url=f"{J}/south-dakota/title-6/chapter-08b/section-6-8b-2/",
      source_year=2025,
      source_filename="SD/260615_south-dakota_title-9.txt",
      bond_type="go",
      note_vote="Unless otherwise provided, no bonds for general or special purposes may be issued by any public body unless SIXTY PERCENT of the voters of the public body voting on the question vote in favor (Sec. 6-8B-2)",
      note_textreq=NONE,
      note_timing="At an election held in the manner provided by law for other elections of the public body (Sec. 6-8B-2)",
      note_pubnotice=NONE,
      note_exception="The 60 percent requirement applies only where an election is required; revenue obligations payable solely from a segregated revenue source are excepted (see the Sec. 9-40-15 row); the constitutional basis is S.D. Const. art. XIII Sec. 4",
      note_votereqbyothergovtlevels="Applies to any 'public body' (municipalities, counties, and other local governments) (Sec. 6-8B-2)"),
    R(stab="SD", state="south dakota",
      source=f"S.D. Codified Laws {SECT} 9-40-15 (utility revenue bonds; no election)",
      source_url=f"{J}/south-dakota/title-9/chapter-40/section-9-40-15/",
      source_year=2025,
      source_filename="SD/260615_south-dakota_title-9.txt",
      bond_type="rev",
      note_vote="No election is required to authorize municipal utility revenue bonds that are made payable SOLELY from the revenue or income of the utility (or from a segregated portion of it), unless an election is required by S.D. Const. art. XIII Sec. 4 (Sec. 9-40-15)",
      note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
      note_exception="If the bonds pledge the general credit of the municipality (rather than being payable solely from segregated utility revenue) the 60 percent election under Sec. 6-8B-2 applies",
      note_votereqbyothergovtlevels="Available to municipalities issuing utility revenue bonds (Sec. 9-40-15)"),

    # ==================== TEXAS ====================
    # Texas's general municipal bond-ELECTION statute (Tex. Gov. Code ch. 1251,
    # majority vote) is in the Government Code, which was NOT among the downloaded
    # TX codes (Local Government, Finance, Utilities, Election). These rows are
    # grounded in the Texas Constitution, which IS in the corpus.
    R(stab="TX", state="texas",
      source=f"Tex. Const. art. XI, {SECT} 5 (home-rule cities; debt restrictions)",
      source_url="https://law.justia.com/constitution/texas/",
      source_year=2025,
      source_filename="tx/260615_texas_constitution.txt",
      bond_type="go",
      note_vote="A city may not create GO debt unless provision is made, at the time of creating the debt, to assess and collect a sufficient annual tax to pay the interest and provide a sinking fund; by statute a municipality must obtain approval of a majority of the voters at a bond election before issuing tax-supported GO bonds (Tex. Const. art. XI Sec. 5; Tex. Gov. Code ch. 1251)",
      note_textreq="The ballot for a measure seeking voter approval of debt obligations must state a plain-language description of the single specific purpose, the total principal amount, and 'that taxes sufficient to pay the principal of and interest on the debt obligations will be imposed'; each single specific purpose is a separate proposition (Tex. Gov. Code Sec. 1251.052, now in corpus)",
      note_timing="At a bond election held not less than 15 nor more than 90 days after the election order, under the general election laws (Tex. Gov. Code Sec. 1251.003, now in corpus)",
      note_pubnotice="In addition to the notice required by Election Code Sec. 4.003(c), notice of the bond election is given by posting a substantial copy of the election order at three public places in the county or municipality and at the county courthouse (Tex. Gov. Code Sec. 1251.003(d), re-fetched 2026-07-17; raw/TX/260717_texas_government-code-chapter-1251.txt). The user-flagged 'None indicated' is corrected: Sec. 1251.003 does prescribe the public notice",
      note_exception="The operative bond-election procedure, notice, and ballot form are now in the corpus (Tex. Gov. Code ch. 1251, Bond Elections, re-fetched 2026-07-17): Sec. 1251.003 (conduct/notice/timing), Sec. 1251.004 (the same election must also submit the debt-service tax), Sec. 1251.052 (ballot form). This row is grounded in the Texas Constitution and now also on ch. 1251 primary text",
      note_votereqbyothergovtlevels="Counties and other political subdivisions likewise hold bond elections under Tex. Gov. Code ch. 1251 (general-law cities under art. XI Sec. 4)"),
    R(stab="TX", state="texas",
      source=f"Tex. Const. art. XI, {SECT} 5 (revenue bonds; special-fund principle)",
      source_url="https://law.justia.com/constitution/texas/",
      source_year=2025,
      source_filename="tx/260615_texas_constitution.txt",
      bond_type="rev",
      note_vote="No voter approval; municipal revenue bonds (e.g., for water, sewer, electric, and other utility systems) payable solely from the revenues of the system are not tax-supported 'debt' and are issued by the governing body without an election",
      note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
      note_exception="Because revenue bonds do not pledge ad valorem taxes, the art. XI Sec. 5 tax/debt limitation and the statutory bond election do not apply. The general revenue-bond authority is now in the corpus: Tex. Gov. Code ch. 1502 (re-fetched 2026-07-17; raw/TX/260717_texas_government-code-chapter-1502.txt) lets the governing body of a municipality issue public securities to fund a utility system, park, or pool (Sec. 1502.051), and each such public security 'is not a debt of the municipality', 'may be a charge only on the encumbered utility system, park, or pool', and must recite that 'The holder of this obligation is not entitled to demand payment of this obligation out of any money raised by taxation' (Sec. 1502.054). The ONLY election ch. 1502 requires is to SELL a utility system, park, or pool ('Unless authorized by a majority vote of the qualified voters ... a municipality may not sell a utility system, park, or pool', Sec. 1502.055) -- not to issue the revenue bonds. So issuance is by the governing body with no election. (LGC ch. 307's no-election clause, by contrast, is the narrow Gulf-tideland park-bond provision and is NOT a valid general substitute.)",
      note_votereqbyothergovtlevels="Available to home-rule and general-law municipalities and other issuers"),

    # ==================== UTAH ====================
    R(stab="UT", state="utah",
      source=f"Utah Code {SECT} 11-14-201 (election on bond issues)",
      source_url=f"{J}/utah/title-11/chapter-14/part-2/section-201/",
      source_year=2025,
      source_filename="UT/260615_utah_title-11.txt",
      bond_type="go",
      note_vote="GO bonds may not be issued unless a majority of the qualified voters of the local political subdivision who vote on the bond proposition approve issuance (Local Government Bonding Act, Sec. 11-14-201, 11-14-202)",
      note_textreq=NONE,
      note_timing="At an election; the governing body must approve the submitting resolution and provide it to the lieutenant governor and election officer at least 75 days before the election (Sec. 11-14-201(1)(a))",
      note_pubnotice="The submitting resolution is provided to the lieutenant governor and the election officer and notice is given as required by the Act and Title 20A election law (Sec. 11-14-201)",
      note_exception="Refunding bonds may be issued without an election unless an election is required by the Utah Constitution (Sec. 11-14, 11-27-5)",
      note_votereqbyothergovtlevels="Applies to any local political subdivision (cities, counties, towns, districts) (Sec. 11-14-201)"),
    R(stab="UT", state="utah",
      source=f"Utah Code {SECT} 11-14-301(5) (revenue bonds excluded from election)",
      source_url=f"{J}/utah/title-11/chapter-14/part-3/section-301/",
      source_year=2025,
      source_filename="UT/260615_utah_title-11.txt",
      bond_type="rev",
      note_vote="No voter approval; bonds issued by a city, town, or county payable solely from the revenues of revenue-producing facilities (or from a special fund of excise taxes) are expressly EXCLUDED from the election requirement of Sec. 11-14-201, except to the extent the Utah Constitution requires (Sec. 11-14-301(5))",
      note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
      note_exception="Such revenue bonds count as bonded indebtedness only to the extent required by the Utah Constitution; improvement-district bonds payable solely from district revenues are likewise excluded (Sec. 11-14-301(4),(5))",
      note_votereqbyothergovtlevels="Applies to cities, towns, and counties issuing revenue-secured bonds (Sec. 11-14-301(5))"),

    # ==================== VERMONT ====================
    R(stab="VT", state="vermont",
      source=f"Vt. Stat. tit. 24, {SECT} 1756 (bonded debt; submission and vote)",
      source_url=f"{J}/vermont/title-24/chapter-53/section-1756/",
      source_year=2025,
      source_filename="vt/260615_vermont_title-24.txt",
      bond_type="both",
      note_vote="A municipality may issue bonded debt for public improvements only when a majority of all the voters present and voting on the question at a meeting held for that purpose vote to authorize it; this applies to general obligation and revenue bonds alike (Sec. 1756)",
      note_textreq="Blank and defective ballots are not counted in determining the question (Sec. 1756(b))",
      note_timing="At an annual or special meeting of the municipal corporation held for that purpose (Sec. 1756(a))",
      note_pubnotice=NONE,
      note_exception="The legislative branch may order the submission on its own resolution (by majority of those present and voting) or must do so on a petition of at least 10 percent of the voters (Sec. 1756(a))",
      note_petition="On a petition signed by at least 10 percent of the voters of the municipal corporation, the proposition of incurring a bonded debt must be submitted to the qualified voters (Sec. 1756(a))",
      note_votereqbyothergovtlevels="Applies to municipal corporations (towns, cities, incorporated villages) (Sec. 1756)"),

    # ==================== WASHINGTON ====================
    R(stab="WA", state="washington",
      source=f"Wash. Const. art. VII, {SECT} 2 & art. VIII, {SECT} 6 (excess-levy GO bonds)",
      source_url="https://law.justia.com/constitution/washington/",
      source_year=2025,
      source_filename="wa/260615_washington_constitution.txt",
      bond_type="go",
      note_vote="Voted (unlimited-tax) GO bonds for capital purposes require approval by at least THREE-FIFTHS of the voters voting on the proposition, levying a tax in excess of the 1 percent property-tax limit (Wash. Const. art. VII Sec. 2(b)); a municipality may incur non-voted (councilmanic) debt only up to 1.5 percent of taxable property (art. VIII Sec. 6)",
      note_textreq=NONE,
      note_timing="At an election held in the manner provided by law for bond elections, not oftener than twice in a calendar year (art. VII Sec. 2(b))",
      note_pubnotice=NONE,
      note_exception="The 3/5 vote is valid only if the total number voting on the proposition is at least 40 percent of the voters voting at the last preceding general election (the validation requirement); with voter assent total debt may reach 5 percent of taxable property, plus 5 percent more for municipally owned water, light, and sewers (art. VII Sec. 2(b); art. VIII Sec. 6)",
      note_votereqbyothergovtlevels="Applies to counties, cities, towns, school districts, and other municipal corporations (art. VIII Sec. 6)"),
    R(stab="WA", state="washington",
      source=f"Wash. Rev. Code {SECT} 35.41.030 (city revenue bonds)",
      source_url=f"{J}/washington/title-35/chapter-35-41/section-35-41-030/",
      source_year=2025,
      source_filename="wa/260615_washington_title-35.txt",
      bond_type="rev",
      note_vote="No voter approval; city revenue bonds are authorized by the legislative body and are payable solely from the revenues of the utility or enterprise, not from taxes (Sec. 35.41.030)",
      note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
      note_exception="Revenue bonds are not 'indebtedness' under the art. VIII Sec. 6 debt limit and require no election because they pledge no taxing power",
      note_votereqbyothergovtlevels="Available to cities and towns (and, under parallel statutes, counties and districts) (Sec. 35.41.030)"),

    # ==================== WEST VIRGINIA ====================
    R(stab="WV", state="west virginia",
      source=f"W. Va. Code {SECT} 13-1-4 (bond issue submitted to voters)",
      source_url=f"{J}/west-virginia/chapter-13/article-1/section-13-1-4/",
      source_year=2025,
      source_filename="wv/260615_west-virginia_chapter-13.txt",
      bond_type="go",
      note_vote="No debt may be contracted or bonds issued under this article until all questions connected with it are submitted to the qualified electors of the political division and receive THREE-FIFTHS of all the votes cast for and against (W. Va. Const. art. X Sec. 8; Sec. 13-1-3, 13-1-4); a county board of education for school purposes needs only a majority",
      note_textreq=NONE,
      note_timing="At an election ordered by the governing body (Sec. 13-1-4)",
      note_pubnotice=NONE,
      note_exception="Refunding/exchange bonds may be issued without an election and do not create a new debt (Sec. 13-1 article provisions)",
      note_petition="The governing body must order a bond election when petitioned in writing by legal voters equal to 20 percent of the votes cast in the political division for Governor (county) or for mayor or board member (municipality or school district) (Sec. 13-1-4)",
      note_votereqbyothergovtlevels="Applies to counties, municipalities, and school districts (Sec. 13-1-4; school districts vote by majority per W. Va. Const. art. X Sec. 10)"),
    R(stab="WV", state="west virginia",
      source=f"W. Va. Code ch. 13 (municipal/county revenue bonds; no election)",
      source_url=f"{J}/west-virginia/chapter-13/",
      source_year=2025,
      source_filename="wv/260615_west-virginia_chapter-13.txt",
      bond_type="rev",
      note_vote="No voter approval; revenue bonds (e.g., for industrial/commercial projects and utility enterprises) are payable solely from the revenues of the project and do not constitute an indebtedness of the county or municipality within the meaning of the West Virginia Constitution, so no election is required",
      note_textreq="Each revenue bond must state on its face that it is issued under the article and does not constitute an indebtedness of the county or municipality within the meaning of the Constitution",
      note_timing=NONE, note_pubnotice=NONE,
      note_exception="Because revenue bonds pledge no taxing power and are not constitutional 'debt', the three-fifths bond election does not apply; the county/municipality may not pay project costs from its general funds",
      note_votereqbyothergovtlevels="Available to counties and municipalities issuing project revenue bonds"),

    # ==================== WYOMING ====================
    R(stab="WY", state="wyoming",
      source=f"Wyo. Stat. {SECT} 15-7-102 (city bonds; election; Political Subdivision Bond Election Law {SECT} 22-21-101 to 22-21-112)",
      source_url=f"{J}/wyoming/title-15/chapter-7/article-1/section-15-7-102/",
      source_year=2025,
      source_filename="WY/260615_wyoming_title-15.txt",
      bond_type="go",
      note_vote="No city or town bonds may be issued for the enumerated purposes until the proposition is submitted to and approved by the qualified electors; the bond question is approved if a majority of the ballots cast on it favor issuance (Sec. 15-7-102(b); Sec. 22-21-110)",
      note_textreq="The bond question must state the purpose of the bonds, the maximum principal amount, the maximum number of years of the indebtedness, and the maximum interest rate (Sec. 22-21-103)",
      note_timing="Every bond election is held on a primary or general election day, or on the Tuesday after the first Monday in May or November, or the Tuesday after the third Monday in August; the subdivision must notify the county clerk at least 110 days before the election (Sec. 22-21-103)",
      note_pubnotice="The county clerk publishes notice of the election at least once in a newspaper of general circulation in the subdivision (generally between 90 and 70 days before a November/general election, or 101 to 91 days before an August election); the notice states the subdivision, the date/time/place, the questions, and that only qualified electors may vote (Sec. 22-21-104)",
      note_exception="Bonds are subject to the debt limit in Sec. 15-7-109; sewerage-system bonds may run up to 40 years; if a bond proposal is defeated, a proposal for the same general purpose may not be resubmitted within 12 months (Sec. 15-7-102(a), 22-21-110)",
      note_petition=NONE,
      note_votereqbyothergovtlevels="The Political Subdivision Bond Election Law applies to all political subdivisions -- counties, cities, towns, and special districts (Sec. 22-21-101 to 22-21-112)"),
    R(stab="WY", state="wyoming",
      source=f"Wyo. Stat. {SECT} 15-7-102(c) (enterprise-revenue financing) & {SECT} 15-9-213 (revenue bonds)",
      source_url=f"{J}/wyoming/title-15/chapter-7/article-1/section-15-7-102/",
      source_year=2025,
      source_filename="WY/260615_wyoming_title-15.txt",
      bond_type="rev",
      note_vote="Wyoming revenue financing is split, so revenue bonds are not uniformly vote-exempt: a borrowing repaid SOLELY from the revenues of the enterprise, with security restricted to that enterprise's revenues and assets, is not a 'bond' and needs NO election (Sec. 15-7-102(c)); but municipal revenue bonds issued under Sec. 15-9-213, payable solely from nontax revenues, DO require an election of the qualified electors under the Political Subdivision Bond Election Law",
      note_textreq="A Sec. 15-9-213 revenue bond must recite that it is payable solely from the nontax revenues or special funds pledged and that it does not constitute a debt of the municipality within any constitutional or statutory limitation",
      note_timing=NONE,
      note_pubnotice=NONE,
      note_exception="Enterprise-revenue loans from the United States or the State of Wyoming (or their agencies/subdivisions), repaid solely from the associated enterprise's revenues, are expressly not 'bonds' and need no vote (Sec. 15-7-102(c)); Sec. 15-9-213 revenue bonds are not municipal indebtedness but still require the election",
      note_votereqbyothergovtlevels="Applies to municipalities (cities and towns) issuing revenue obligations (Sec. 15-7-102, 15-9-213)"),
]


def main() -> None:
    import sys
    sys.stdout.reconfigure(encoding="utf-8")
    df = pl.DataFrame([{c: r.get(c) for c in COLS} for r in ROWS]).select(COLS)

    # Guard: only the section sign (U+00A7) may appear; flag any OTHER non-ASCII char.
    allowed = {0x00A7}
    bad = []
    for r in df.iter_rows(named=True):
        for c, v in r.items():
            if isinstance(v, str):
                for ch in v:
                    if ord(ch) > 127 and ord(ch) not in allowed:
                        bad.append((r["stab"], c, ch, hex(ord(ch))))
    if bad:
        print("!! disallowed non-ASCII characters found (fix these):")
        for s, c, ch, h in bad[:40]:
            print(f"   {s} {c}: {ch!r} {h}")
    else:
        print("ASCII check: clean (section sign allowed in source).")

    OUT.write_text(df.write_csv(), encoding="utf-8-sig")
    print("Wrote", OUT, "rows:", df.height)
    print("states:", df["stab"].n_unique(), sorted(df["stab"].unique().to_list()))


if __name__ == "__main__":
    main()
