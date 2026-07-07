#!/usr/bin/env python3
r"""
260702_build_sourcelevel_final14.py -- Debt by Democracy: Phase 3-4 FINAL 14 states.

Build 260702_sourcelevel_final14.csv for the final 14 states (CT DE IL IN IA KS MD MN
NV NY PA RI SC VA), completing the 50-state source-level classification. Mirrors the
expansion builder 260624_build_sourcelevel_expand25.py (inline one-row-per-source dicts
-> DataFrame -> ASCII guard -> UTF-8-with-BOM write).

Classifications are grounded in the downloaded corpus under Data\Statutes\raw\<ST>\
(260625_<state>_<div>.txt files), located via the curated pointers in
documentation\260625_final15_seed_manifest.csv. Each row reads the bond-AUTHORITY
section AND the bond-ELECTION-PROCEDURE sections and captures the four pilot-omission
categories: public-notice publication (note_pubnotice), ballot/question wording
(note_textreq), petition/protest provisions (note_petition), and revenue-bond vote
requirements AND their exemptions (note_vote on rev rows / note_exception).

Conventions (see findings.md "sourcelevel.csv conventions" + "Phase 3-4 extraction --
PILOT OMISSIONS TO FIX"):
- control = 0 for ALL 14 states. NO `pilot` column. EVERY column populated ("None
  indicated" only after genuinely checking the corpus; never blank).
- ONE ROW PER SOURCE. bond_type in {go, rev, both} reflects only the bonds that source
  governs; "both" only when a single source genuinely governs both (NY LFL Sec. 34.00).
- The section sign glyph appears ONLY in `source`; note_* text is plain ASCII ("Sec.").
- source_year is its own column (CT = 2024; the other 13 states = 2025, per the Justia
  editions actually downloaded / cache page titles).
- note_timing = ONLY the timing of WHEN the election is held; notice timing ->
  note_pubnotice; protest/petition timing -> note_petition.
- SECONDARY DOCS (DE/SC/VA) fetched to raw\<ST>\_secondary\ as cross-references; cited
  in notes where the Justia corpus is thin (DE municipal charters are special legislation
  not in the general Title 22 corpus).

Output: Data\Statutes\260702_sourcelevel_final14.csv  (UTF-8 with BOM)
"""
from __future__ import annotations

from pathlib import Path
import polars as pl

OUT = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
          r"\Data\Statutes\260702_sourcelevel_final14.csv")

COLS = ["stab", "state", "control", "source", "source_url", "source_year",
        "source_type", "source_filename", "bond_type", "note_vote", "note_textreq",
        "note_timing", "note_pubnotice", "note_exception", "note_nichevote",
        "note_optin", "note_petition", "note_votereqbyothergovtlevels"]

J = "https://law.justia.com/codes"

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
    # ==================== CONNECTICUT ====================
    # Home-rule state: no statewide bond referendum. GO bonds authorized by the
    # municipality's legislative body / delegate; any referendum is charter-based.
    R(stab="CT", state="connecticut",
      source=f"Conn. Gen. Stat. {SECT} 7-369 (authority to issue bonds)",
      source_url=f"{J}/connecticut/title-7/chapter-109/section-7-369/",
      source_year=2024,
      source_filename="CT/260625_connecticut_title-7.txt",
      bond_type="go",
      note_vote="Connecticut imposes no statewide referendum for municipal general obligation bonds. A municipality may issue bonds once it has made appropriations or incurred debts exceeding $10,000 (Sec. 7-369); the bonds are authorized and the manner of issuance designated by the municipality's legislative body or an officer or board it delegates (Sec. 7-370). Whether a bond issue must be submitted to the voters is governed by the municipality's charter, not the general statutes",
      note_textreq="No form is set by the general statutes; where a charter or petition forces a vote at a town meeting, the clerk phrases the item as a 'Yes' or 'No' question in the form prescribed by Sec. 9-369 (Sec. 7-7)",
      note_timing="Where a town-meeting item is petitioned to a paper-ballot or voting-machine vote, the vote is held on a day set not less than 7 nor more than 14 days after the meeting adjourns (Sec. 7-7)",
      note_pubnotice="None indicated; the general statutes prescribe no publication schedule for authorizing bonds (procedure is fixed by charter)",
      note_exception="Refunding bonds may be issued without new authorization (Sec. 7-370c); revenue bonds are separately governed and are excluded from the Sec. 7-374 debt limit",
      note_optin="A municipal charter may require that a bond issue be approved by referendum",
      note_petition="At a town meeting, 200 persons or 10 percent of those qualified to vote (whichever is less) may petition the clerk at least 24 hours before the meeting to submit an item (including a bond appropriation) to a vote by paper ballot or voting machine (Sec. 7-7)",
      note_votereqbyothergovtlevels="'Municipality' is defined broadly (Sec. 7-369) to include any town, city, borough, consolidated town and city, consolidated town and borough, metropolitan district, district (Sec. 7-324), and other municipal corporation with power to levy taxes and issue bonds; the same charter-based approach applies to all"),
    R(stab="CT", state="connecticut",
      source=f"Conn. Gen. Stat. {SECT} 7-206 (municipal revenue bonds)",
      source_url=f"{J}/connecticut/title-7/chapter-100/section-7-206/",
      source_year=2024,
      source_filename="CT/260625_connecticut_title-7.txt",
      bond_type="rev",
      note_vote="No voter approval. Revenue bonds are authorized by ordinance of the municipality's legislative body (Sec. 7-206 for parking facilities; Sec. 7-235 for waterworks; Sec. 7-233f for electric systems); they pledge no faith and credit, are payable solely from the enterprise revenues, and are not subject to the Sec. 7-374 debt limit",
      note_exception="Each revenue bond states on its face that it does not constitute a general indebtedness of the municipality within any statutory limitation and is excluded from the Sec. 7-374 debt limit (Sec. 7-206(b), 7-235)",
      note_votereqbyothergovtlevels="The legislative body of any municipality may issue such revenue bonds; parallel enterprise revenue-bond authority appears for water (Sec. 7-235) and electric (Sec. 7-233f) systems"),

    # ==================== ILLINOIS ====================
    # GO bonds: mandatory referendum under 65 ILCS 5/8-4-1, except home-rule units and
    # the 16 enumerated categories (which include utility/enterprise revenue bonds).
    R(stab="IL", state="illinois",
      source=f"65 ILCS 5/8-4-1 ({SECT} 8-4-1, Municipal Code; referendum required)",
      source_url=f"{J}/illinois/chapter-65/act-65-ilcs-5/article-8/",
      source_year=2025,
      source_filename="IL/260625_illinois_chapter-65.txt",
      bond_type="go",
      note_vote="No bonds may be issued by the corporate authorities of a municipality until the question of authorizing the bonds has been submitted to the electors and approved by a majority of those voting on the question (Sec. 8-4-1). Home-rule municipalities are exempt, having independent debt authority under Ill. Const. art. VII Sec. 6",
      note_textreq="The ballot is in the statutory form (Sec. 8-4-2): 'Shall bonds in the amount of $.... be issued by the city (or village or incorporated town) of .... for the purpose of .... (state purpose), bearing interest at the rate of not to exceed ....%?' with YES and NO",
      note_timing="The clerk certifies the proposition to the election authority, which submits the question at an election held in accordance with the general election law (Sec. 8-4-1)",
      note_pubnotice="Notice is given under Section 12-5 of the Election Code at least 10 and not more than 45 days before the election; the notice states the amount of the bond issue, the purpose, and the maximum rate of interest (Sec. 8-4-1)",
      note_exception="Sixteen categories may be issued WITHOUT a referendum (Sec. 8-4-1(1)-(16)), including refunding bonds (Sec. 8-4-3), judgment-funding bonds, and the enterprise/utility revenue bonds authorized by the Article 11 divisions listed in Sec. 8-4-1(4) (e.g., waterworks under Sec. 11-139); home-rule units are exempt",
      note_petition="Certain bonds issuable without a referendum are subject to a backdoor referendum: after the ordinance is published, voters may petition to force the question to referendum under the general election law",
      note_votereqbyothergovtlevels="Applies to the corporate authorities of any municipality (cities, villages, incorporated towns); counties and other units of local government issue GO bonds under parallel provisions outside the Municipal Code"),
    R(stab="IL", state="illinois",
      source=f"65 ILCS 5/8-4-1(4) ({SECT} 8-4-1, no-referendum exceptions; utility revenue bonds)",
      source_url=f"{J}/illinois/chapter-65/act-65-ilcs-5/article-8/",
      source_year=2025,
      source_filename="IL/260625_illinois_chapter-65.txt",
      bond_type="rev",
      note_vote="No voter approval. Municipal utility and enterprise revenue bonds (waterworks under Sec. 11-139-1 through 11-139-12, combined waterworks-and-sewerage under Sec. 11-71, and similar systems) are expressly among the bonds the corporate authorities may issue WITHOUT submitting the question to the electors (Sec. 8-4-1(4)); they are payable from the enterprise revenues",
      note_exception="These revenue bonds are payable solely from the utility system revenues and are not subject to the Sec. 8-4-1 referendum. The operative Article 11 divisions were not among the downloaded portion of the Municipal Code (the article 11 body is absent from the corpus); this row is grounded in the Sec. 8-4-1(4) exception list, which is in the corpus",
      note_petition="Revenue bonds issued without a referendum may be subject to a backdoor referendum by voter petition under the general election law after publication of the authorizing ordinance",
      note_votereqbyothergovtlevels="Available to the corporate authorities of any municipality operating the utility or enterprise (Sec. 8-4-1(4))"),

    # ==================== INDIANA ====================
    # GO bonds by ordinance, subject to IC 6-1.1-20 controlled-project petition-and-
    # remonstrance OR (above a cost threshold) a mandatory referendum. IC 6-1.1-20 is in
    # Title 6, which was NOT downloaded (gap); the framework is cross-referenced in-corpus.
    R(stab="IN", state="indiana",
      source=f"Ind. Code {SECT} 36-4-6-19 (city loans and issuance of bonds)",
      source_url=f"{J}/indiana/title-36/article-4/chapter-6/section-36-4-6-19/",
      source_year=2025,
      source_filename="IN/260625_indiana_title-36.txt",
      bond_type="go",
      note_vote="A city legislative body issues general obligation bonds by ordinance (Sec. 36-4-6-19). The bonds are subject to IC 6-1.1-20: a 'controlled project' is subject either to a petition-and-remonstrance process (IC 6-1.1-20-3.1) or, if the project cost exceeds the statutory threshold, to a mandatory referendum in which a majority of voters must approve (IC 6-1.1-20-3.5). Whether a referendum is required therefore depends on the size and type of the project",
      note_textreq="Not specified in Sec. 36-4-6-19; the controlled-project referendum ballot form is prescribed by IC 6-1.1-20 (Title 6, outside the downloaded corpus)",
      note_timing="Not specified in Sec. 36-4-6-19; a controlled-project referendum is held at a general or primary election under IC 6-1.1-20 and IC 3 (outside the downloaded corpus)",
      note_pubnotice="The authorizing ordinance must include the time and manner of giving notice of the sale of the bonds (Sec. 36-4-6-19(b)(2)); notice and publication for the petition-remonstrance and referendum are governed by IC 6-1.1-20",
      note_exception="Bonds that are not 'controlled projects' need no referendum (e.g., refunding bonds and bonds payable from sources other than property taxes); utility revenue bonds are not subject to the property-tax controlled-project process. IC 6-1.1-20 lies in Title 6, which was not among the downloaded titles; the framework is grounded on Sec. 36-4-6-19 and the cross-references in Sec. 36-3-5-8 and 36-3-4-21, all in the corpus",
      note_petition="Petition-and-remonstrance: for a controlled project below the referendum threshold, taxpayers and voters may sign petitions for or against issuing the bonds, and the position with the larger number of signatures prevails (IC 6-1.1-20-3.1; recited at Sec. 36-3-5-8)",
      note_votereqbyothergovtlevels="The same IC 6-1.1-20 controlled-project framework applies to counties, special taxing districts (Sec. 36-3-5-8), consolidated cities (Sec. 36-3-4-21), and other political subdivisions"),
    R(stab="IN", state="indiana",
      source=f"Ind. Code {SECT} 8-1-2.2-11 (municipal utility revenue bonds; issuance)",
      source_url=f"{J}/indiana/title-8/article-1/chapter-2-2/section-8-1-2-2-11/",
      source_year=2025,
      source_filename="IN/260625_indiana_title-8.txt",
      bond_type="rev",
      note_vote="No voter approval. A municipality or joint agency issues revenue bonds by resolution of its governing body (Sec. 8-1-2.2-11); the principal and interest are payable solely from the revenues and other available funds pledged, and the bonds are not general obligations. Parallel municipally owned utility revenue bonds are issued under IC 8-1.5-2 and paid from the utility's net earnings (Sec. 8-1.5-2-24)",
      note_exception="Neither the faith and credit nor the taxing power of the municipality or the state is pledged; every bond recites that it is payable solely from the pledged revenues and that the municipality is not obligated to pay except from those revenues (Sec. 8-1-2.2-18)",
      note_votereqbyothergovtlevels="Available to municipalities and joint agencies owning electric utility systems (Sec. 8-1-2.2-11); municipally owned water and other utilities issue revenue bonds under IC 8-1.5"),

    # ==================== IOWA ====================
    # Essential-purpose GO bonds (reverse referendum) vs general-purpose GO bonds
    # (mandatory 60 percent election). Revenue bonds by resolution; storm-water reverse ref.
    R(stab="IA", state="iowa",
      source=f"Iowa Code {SECT} 384.25 (general obligation bonds for essential purposes)",
      source_url=f"{J}/iowa/title-ix/chapter-384/section-384-25/",
      source_year=2025,
      source_filename="IA/260625_iowa_title-ix.txt",
      bond_type="go",
      note_vote="Essential corporate purpose general obligation bonds are issued WITHOUT an election: the council publishes notice, holds a meeting, receives objections, and may take action, subject to a 15-day appeal to district court (Sec. 384.25(2)). For large essential purposes under Sec. 384.24(3)(w) or (x) of $3 million or more, the council publishes a notice of the right to petition, and a petition triggers a special election (Sec. 384.25(3))",
      note_textreq="The notice states the amount and purposes of the bonds and an estimate of the annual property-tax increase on a residence with an actual value of $100,000; for the petitionable essential purposes the notice also states the maximum rate of interest and the right to petition for an election (Sec. 384.25(2),(3))",
      note_timing="If a petition is filed for a $3 million-or-more essential-purpose issue, the county commissioner of elections calls a special election, conducted in the manner provided in Sec. 384.26 (Sec. 384.25(3))",
      note_pubnotice="Notice of the proposed action is published as provided in Sec. 362.3; for the petitionable essential purposes, the notice is published at least once at least 10 days before the meeting (Sec. 384.25(2),(3))",
      note_exception="A standard essential corporate purpose issue requires no election unless a sufficient petition under Sec. 384.25(3) forces one; the essential/general purpose categories are defined in Sec. 384.24",
      note_petition="For a $3 million-or-more essential-purpose issue, a petition signed by eligible electors equal to 20 percent of the persons who voted for President at the last general election requires the council either to abandon the bonds or to hold a special election (Sec. 384.25(3)(b))",
      note_votereqbyothergovtlevels="Chapter 384 governs cities; counties issue general obligation bonds under a parallel procedure in Chapter 331"),
    R(stab="IA", state="iowa",
      source=f"Iowa Code {SECT} 384.26 (general obligation bonds for general purposes)",
      source_url=f"{J}/iowa/title-ix/chapter-384/section-384-26/",
      source_year=2025,
      source_filename="IA/260625_iowa_title-ix.txt",
      bond_type="go",
      note_vote="General corporate purpose general obligation bonds require a mandatory election: before instituting proceedings the council must call a special election on the question of issuing the bonds (Sec. 384.26(2)); the proposition is not adopted unless the vote in favor is at least 60 percent of the total vote cast for and against (Sec. 384.26(4))",
      note_textreq="The proposition is submitted in the statutory form: 'Shall the .... (name of the city) issue its bonds in an amount not exceeding the amount of $.... for the purpose of ....?' (Sec. 384.26(2)(b)); the ballot is in substantially the form for submitting special questions at general elections",
      note_timing="The election is held on the date specified in Sec. 39.2(4)(d) (Sec. 384.26(3))",
      note_pubnotice="Notice of the proposal, including the amount and purpose and an estimate of the annual property-tax increase on a $100,000 residence, is published as provided in Sec. 362.3 with the minutes calling the election; notice of the election is given by publication as required by Sec. 49.53 in a newspaper of general circulation (Sec. 384.26(2),(3))",
      note_exception="In lieu of an election, for issues below population-based amount caps ($520,000 / $910,000 / $1,300,000, indexed annually), the council may publish a notice of the right to petition; if no petition is filed the bonds may be issued without a vote (Sec. 384.26(5))",
      note_nichevote="A 60 percent supermajority of the votes cast for and against is required to adopt a general corporate purpose bond issue (Sec. 384.26(4))",
      note_petition="Under the in-lieu-of-election alternative, a petition filed in the manner provided by Sec. 362.4 requires the council either to abandon the bonds or to call a special election (Sec. 384.26(5)(c))",
      note_votereqbyothergovtlevels="Chapter 384 governs cities; counties issue general obligation bonds under a parallel procedure in Chapter 331"),
    R(stab="IA", state="iowa",
      source=f"Iowa Code {SECT} 384.83 (procedures for revenue bonds)",
      source_url=f"{J}/iowa/title-ix/chapter-384/section-384-83/",
      source_year=2025,
      source_filename="IA/260625_iowa_title-ix.txt",
      bond_type="rev",
      note_vote="Generally no election: a city issues revenue bonds by resolution of the governing body of the city utility, combined utility system, or city enterprise, adopted by a majority of the members (Sec. 384.83(1)); the bonds are payable solely from the net revenues (Sec. 384.87). Before issuance the governing body publishes notice, holds a meeting to receive objections, and is subject to a 15-day appeal (Sec. 384.83(2))",
      note_textreq="None indicated for a standard revenue-bond issue; if a storm-water reverse-referendum election is triggered, the proposition is on issuing the revenue bonds for the storm-water drainage construction project (Sec. 384.84A)",
      note_timing="If a storm-water reverse-referendum petition forces an election, the county commissioner of elections calls a special election (Sec. 384.84A)",
      note_pubnotice="Notice of the meeting is published as directed in Sec. 362.3, stating the maximum amount of the proposed revenue bonds, the purposes, and the utility or enterprise whose net revenues will pay them (Sec. 384.83(2))",
      note_exception="Storm-water drainage revenue bonds are not vote-exempt: for projects above cost thresholds ($750,000 / $1.5 million / $2 million by population) a petition can force a majority-vote special election (Sec. 384.84A); this election requirement does not apply to storm-water facilities mandated by the federal EPA (Sec. 384.84A(5))",
      note_petition="For a storm-water drainage revenue-bond project meeting the cost thresholds, a petition signed by eligible electors equal to at least 3 percent of the city's registered voters requires the council to abandon the project or hold a majority-vote special election (Sec. 384.84A(2))",
      note_votereqbyothergovtlevels="Chapter 384 governs cities, through the governing body of the city utility or enterprise"),

    # ==================== KANSAS ====================
    # GO bonds: an election is required when a law requires it OR a sufficient protest
    # petition is filed. Utility revenue bonds under Art. 12 require a majority vote.
    R(stab="KS", state="kansas",
      source=f"Kan. Stat. Ann. {SECT} 10-120 (bond election; notice) with {SECT} 10-120a",
      source_url=f"{J}/kansas/chapter-10/article-1/section-10-120/",
      source_year=2025,
      source_filename="KS/260625_kansas_chapter-10.txt",
      bond_type="go",
      note_vote="An election is required to authorize bonds whenever a law specifically requires one OR whenever a law authorizes the filing of a petition requesting an election and a sufficient petition is filed (Sec. 10-120a(c)); it is thus mandatory for some purposes and a protest-petition (reverse referendum) for others. When held, the bonds are approved by a majority of those voting (Sec. 10-120)",
      note_textreq="The notice of a bond election must state the total amount of the bonds, the amount representing the actual project cost, the projected interest, the projected issuance expenses, the projected annual principal and interest payments, and the projected annual tax rate and source of taxation to retire the bonds (Sec. 10-120a(b))",
      note_timing="The election is held on the date of a general, primary, or special election as defined in Sec. 25-2502 (Sec. 10-120(a))",
      note_pubnotice="Notice is published in a newspaper of general circulation once each week for two consecutive weeks and on the county election office website; the first publication is not less than 21 days before the election, and the notice states the time and place and the purpose of the bonds (Sec. 10-120(b))",
      note_exception="Whether a vote is mandatory or petition-triggered depends on the specific bond law; some purposes are issued without a vote",
      note_petition="Kansas uses protest-petition (reverse-referendum) triggers: where a law authorizes a petition and a sufficient petition is filed, an election must be held (Sec. 10-120a(c)); for example, a lease-purchase agreement over $100,000 requires an election if a protest petition signed by 5 percent of the qualified voters is filed (Sec. 10-1116c)",
      note_votereqbyothergovtlevels="'Municipality' means any county, township, city, municipal university, school district, and any other taxing district or political subdivision authorized to issue bonds (Sec. 10-120a(a))"),
    R(stab="KS", state="kansas",
      source=f"Kan. Stat. Ann. {SECT} 10-1212 (utility revenue bonds; election required)",
      source_url=f"{J}/kansas/chapter-10/article-12/section-10-1212/",
      source_year=2025,
      source_filename="KS/260625_kansas_chapter-10.txt",
      bond_type="rev",
      note_vote="Kansas requires a vote for these revenue bonds: no city may issue bonds under the utility revenue bond act (Article 12; 'revenue bonds' meaning bonds paid exclusively from the revenue of a utility, Sec. 10-1201) unless the question is submitted to the electors at a regular or special election and a majority of those voting approve, except as provided by Sec. 10-1210 (Sec. 10-1212)",
      note_textreq="None indicated in Sec. 10-1212; the election is called, noticed, held, and canvassed in the manner provided by the general bond law (which prescribes the notice content in Sec. 10-120a)",
      note_timing="At a regular or special election called for the purpose, held in the manner provided by the general bond law (Sec. 10-1212, 10-120)",
      note_pubnotice="Governed by the general bond law: notice published in a newspaper of general circulation once each week for two consecutive weeks, the first not less than 21 days before the election (Sec. 10-120(b))",
      note_exception="Refunding revenue bonds may be issued WITHOUT an election (Sec. 10-1210; Sec. 10-1213 authorizes refunding revenue bonds without an election). Cities may also issue revenue bonds under other or home-rule authority without a vote, so the requirement depends on the act relied upon",
      note_votereqbyothergovtlevels="Available to any municipality as defined in Sec. 10-101 that owns a revenue-producing utility (Sec. 10-1201)"),

    # ==================== MARYLAND ====================
    # Municipal GO and revenue bonds; a referendum applies only if the municipality's
    # charter requires it (Sec. 19-304(d)).
    R(stab="MD", state="maryland",
      source=f"Md. Code, Local Gov't {SECT} 19-302 (authority to borrow) with {SECT} 19-304",
      source_url=f"{J}/maryland/local-government/division-iv/title-19/subtitle-3/section-19-302/",
      source_year=2025,
      source_filename="MD/260625_maryland_local-government.txt",
      bond_type="go",
      note_vote="A municipality may borrow money for any public purpose and issue and sell general obligation bonds (Sec. 19-302(a)). There is no statewide referendum; if the municipality's charter requires a referendum on the issuance of municipal bonds, the bonds may be issued only if approved by a majority of the voters voting on the question (Sec. 19-304(d)(1))",
      note_textreq="None indicated in these sections (any ballot question is set by the charter)",
      note_timing="If a charter referendum fails, another referendum on issuing bonds for the same public purpose may not be held until one year after the election (Sec. 19-304(d)(2))",
      note_pubnotice="A municipality may sell bonds only after soliciting competitive bids at a public sale and publishing notice of the bond sale in a newspaper of general circulation two times over a period of at least 10 days before the sale (Sec. 19-304(e))",
      note_exception="A municipality may not issue bonds maturing later than 40 years after issue, may issue bonds only for cash, and may not sell them below par (Sec. 19-304(a),(b),(c)); tax anticipation notes may not mature later than 18 months (Sec. 19-304(a)(2))",
      note_optin="Whether a referendum is required is set by the municipality's charter (Sec. 19-304(d)); the charter may or may not impose one",
      note_votereqbyothergovtlevels="This subtitle governs municipalities; counties borrow and issue bonds under public local laws or their county charters"),
    R(stab="MD", state="maryland",
      source=f"Md. Code, Local Gov't {SECT} 19-302(b) (municipal revenue bonds)",
      source_url=f"{J}/maryland/local-government/division-iv/title-19/subtitle-3/section-19-302/",
      source_year=2025,
      source_filename="MD/260625_maryland_local-government.txt",
      bond_type="rev",
      note_vote="No statewide referendum. In its charter a municipality may provide for the issuance of revenue bonds payable as to principal and interest solely from the revenues of one or more revenue-producing projects of the municipality (Sec. 19-302(b)); a referendum applies only if the charter requires one for the issuance of municipal bonds (Sec. 19-304(d))",
      note_textreq="None indicated in these sections (any ballot question is set by the charter)",
      note_exception="Revenue bonds are payable solely from the revenues of the revenue-producing project or projects (Sec. 19-302(b)); the 40-year maturity and cash/par-value limits of Sec. 19-304 apply",
      note_optin="A municipal charter may require a referendum on the issuance of revenue bonds (Sec. 19-304(d))",
      note_votereqbyothergovtlevels="This subtitle governs municipalities acting under their charters; counties issue revenue bonds under public local laws or their county charters"),

    # ==================== MINNESOTA ====================
    # Sec. 475.58: majority election unless one of 11 exceptions; revenue-producing
    # obligations exempt; reverse-referendum triggers for funding/refunding and streets.
    R(stab="MN", state="minnesota",
      source=f"Minn. Stat. {SECT} 475.58 subd. 1 (obligations; elections to determine issue)",
      source_url=f"{J}/minnesota/chapters-474-477c/chapter-475/section-475-58/",
      source_year=2025,
      source_filename="MN/260625_minnesota_chapter-475.txt",
      bond_type="go",
      note_vote="Obligations authorized by law or charter may be issued upon the approval of a majority of the electors voting on the question, but no election is required for eleven categories (Sec. 475.58 subd. 1): unpaid judgments; refunding; special-assessment or tax-increment improvements where at least 20 percent is assessed or from tax increments; obligations payable wholly from the income of revenue-producing conveniences; a home-rule charter permitting no-election issuance; any law permitting no-election issuance; pension funding; capital improvement plan bonds (Sec. 373.40); tax-abatement bonds; postemployment-benefit funding; and Sec. 475.755 obligations. Whether a vote is required therefore depends on the funding source or authority",
      note_textreq="None indicated in Sec. 475.58 (the ballot is governed by the general election law)",
      note_timing="If an election is required and the obligations are not approved, the same question may not be resubmitted for 180 days, and, if not approved a second time, not for one year after the second election (Sec. 475.58 subd. 1a)",
      note_pubnotice="For funding or refunding bonds issued when gross debt exceeds the statutory threshold, the initial resolution is published once each week for two successive weeks (Sec. 475.58 subd. 2); for street reconstruction bonds, the public-hearing notice is published in the official newspaper at least 10 but not more than 28 days before the hearing (Sec. 475.58 subd. 3b)",
      note_exception="The eleven categories in subdivision 1 need no election, including refunding, special-assessment and tax-increment improvements, revenue-financed obligations, home-rule and other statutory no-election authority, capital improvement plan bonds, abatement bonds, and pension or postemployment-benefit funding",
      note_nichevote="Street reconstruction or overlay bonds and capital improvement plan bonds require approval by a two-thirds majority of the governing body present (Sec. 475.58 subd. 3b(1); Sec. 373.40)",
      note_petition="Reverse-referendum triggers: for funding or refunding bonds over the debt threshold, a petition by 10 or more voters who are taxpayers, filed within 10 days after the second publication, forces a majority election (Sec. 475.58 subd. 2); for street reconstruction bonds, a petition signed by voters equal to 5 percent of the votes cast in the last municipal general election, filed within 30 days of the hearing, forces a majority election (Sec. 475.58 subd. 3b(2))",
      note_votereqbyothergovtlevels="Applies to any municipality; subdivision 2 references counties, cities, towns, and school districts"),
    R(stab="MN", state="minnesota",
      source=f"Minn. Stat. {SECT} 475.58 subd. 1(4) (revenue-producing conveniences)",
      source_url=f"{J}/minnesota/chapters-474-477c/chapter-475/section-475-58/",
      source_year=2025,
      source_filename="MN/260625_minnesota_chapter-475.txt",
      bond_type="rev",
      note_vote="No voter approval. Obligations payable wholly from the income of revenue-producing conveniences (revenue bonds) are expressly exempt from the election requirement (Sec. 475.58 subd. 1(4))",
      note_exception="Revenue bonds pledge only the enterprise income; a municipality may also, without an election, issue obligations to refund existing debt of a youth ice arena secured by facility revenues (Sec. 475.58 subd. 3a)",
      note_votereqbyothergovtlevels="Available to municipalities generally (counties, cities, towns, school districts)"),

    # ==================== NEVADA ====================
    # GO must be voted, except a revenue-secured GO (reverse referendum) and special or
    # medium-term obligations (no election).
    R(stab="NV", state="nevada",
      source=f"Nev. Rev. Stat. {SECT} 350.020 (submission to electors of general obligations)",
      source_url=f"{J}/nevada/chapter-350/statute-350-020/",
      source_year=2025,
      source_filename="NV/260625_nevada_chapter-350.txt",
      bond_type="go",
      note_vote="A municipality proposing to issue or incur general obligations must submit the proposal to the electors at a special election called for the purpose, the next general municipal election, or the general state election, and a majority must approve (Sec. 350.020(1)); the exceptions are a revenue-secured general obligation under subsection 3 and special or medium-term obligations under subsection 8",
      note_textreq="None indicated in Sec. 350.020 (the ballot question is governed by the general election law)",
      note_timing="A special election may be held on a primary election date only on a unanimous emergency finding by the governing body, or on the second Tuesday after the first Monday in June of an odd-numbered year; otherwise the question is put at the next general municipal or general state election (Sec. 350.020(1),(2))",
      note_pubnotice="For a revenue-secured general obligation issued without an election under subsection 3, a resolution of intent is published (stating the amount, the purpose, and the petition deadline and location), and notice of the public hearing is published three times, once each week for three consecutive weeks, the third publication at least 10 days before the hearing (Sec. 350.020(3))",
      note_exception="A general obligation additionally secured by a pledge of gross or net project revenue may be incurred WITHOUT an election if the governing body determines by a two-thirds vote that the pledged revenue will cover debt service, subject to a petition (Sec. 350.020(3)); special obligations and medium-term obligations may be issued without an election (Sec. 350.020(8))",
      note_nichevote="The no-election path for a revenue-secured general obligation requires an affirmative vote of two-thirds of the members elected to the governing body (Sec. 350.020(3))",
      note_petition="Reverse-referendum: for a revenue-secured general obligation under subsection 3, a petition signed by not less than 5 percent of the registered voters of the municipality, presented within 90 days after publication of the resolution of intent, forces an election (Sec. 350.020(3))",
      note_votereqbyothergovtlevels="'Municipality' is broad (counties, cities, and other local governments); a school district may issue general obligation bonds under a separate 10-year voter-authorization mechanism (Sec. 350.020(4))"),
    R(stab="NV", state="nevada",
      source=f"Nev. Rev. Stat. {SECT} 350.020(8) (special and medium-term obligations)",
      source_url=f"{J}/nevada/chapter-350/statute-350-020/",
      source_year=2025,
      source_filename="NV/260625_nevada_chapter-350.txt",
      bond_type="rev",
      note_vote="No voter approval. A municipality may issue special obligations without an election (Sec. 350.020(8)); a 'special obligation' is a municipal security issued under NRS 350.582 and payable from pledged revenues (Sec. 350.0075). Medium-term obligations may likewise be issued without an election",
      note_exception="Special obligations (revenue bonds) are payable from the pledged revenues and do not pledge the general credit; medium-term obligations mature not later than 10 years after issuance (Sec. 350.091(2))",
      note_votereqbyothergovtlevels="Available to municipalities generally (counties, cities, and districts)"),

    # ==================== NEW YORK ====================
    # Cities: no mandatory or permissive referendum on bond resolutions unless the city
    # opts in by local law. One 'both' row (Sec. 34.00 governs all city obligations).
    R(stab="NY", state="new york",
      source=f"N.Y. Local Fin. Law {SECT} 34.00 (bond resolution referendum; cities)",
      source_url=f"{J}/new-york/lfn/article-2/title-3/34-00/",
      source_year=2025,
      source_filename="NY/260625_new-york_lfn.txt",
      bond_type="both",
      note_vote="In any city, neither the expenditure of money for a purpose for which obligations are to be issued nor a bond or capital note resolution is subject to a mandatory or a permissive referendum (Sec. 34.00.a); city obligations are authorized by the finance board (the common council) without a voter referendum, and this applies to obligations for both governmental and revenue-producing purposes",
      note_textreq="None indicated (no referendum applies by default)",
      note_timing="None indicated (no referendum applies by default)",
      note_pubnotice="None indicated for referendum purposes (no election is held by default)",
      note_exception="Revenue-producing projects are also financed through public authorities and industrial development agencies, whose bonds are not city obligations and require no city referendum",
      note_optin="A city may adopt a local law requiring that all bond resolutions, or those for purposes or amounts specified in the local law, be subject to a mandatory or a permissive referendum after adoption by the finance board (Sec. 34.00.b)",
      note_petition="Where a permissive referendum applies (in towns and villages), a petition of the electors filed within the statutory period forces the bond resolution to a vote; in a city this occurs only if the city has opted in by local law",
      note_votereqbyothergovtlevels="Town bond resolutions (for example, for town highway improvements) are subject to permissive referendum under Sec. 35.00 and Article 7 of the Town Law; village bond resolutions are subject to permissive referendum under Sec. 36.00; counties are governed by the Local Finance Law"),

    # ==================== PENNSYLVANIA ====================
    # Local Government Unit Debt Act: nonelectoral GO (no vote, within limits) vs
    # electoral debt (majority referendum, to exceed limits). Self-liquidating revenue no vote.
    R(stab="PA", state="pennsylvania",
      source=f"53 Pa.C.S. {SECT} 8022 (limitations on incurring debt) with {SECT} 8041-8043",
      source_url=f"{J}/pennsylvania/title-53/chapter-80/section-8022/",
      source_year=2025,
      source_filename="PA/260625_pennsylvania_title-53.txt",
      bond_type="go",
      note_vote="Under the Local Government Unit Debt Act a local government unit may incur nonelectoral general obligation debt by ordinance WITHOUT a referendum, up to the statutory debt limits (a percentage of its borrowing base) (Sec. 8022). To incur electoral debt exceeding those limits, or to transfer nonelectoral debt to electoral debt (Sec. 8023), the governing body must obtain the assent of the electors, a majority of the votes cast at the election (Sec. 8041, 8043(d)); whether a referendum is required therefore depends on whether the debt is within the nonelectoral limits",
      note_textreq="The ballot question is in substantially the form: 'Shall debt in the sum of (amount) dollars for the purpose of financing (brief description of project) be (authorized to be incurred as)(transferred from nonelectoral debt to) debt approved by the electors?' (Sec. 8042(a)(5))",
      note_timing="The election is held on a municipal, general, primary, or special election date; a special election may be fixed if the nearest such election is more than 90 or less than 30 days from the desire resolution (Sec. 8041(b)); the governing body certifies the question at least 45 days before the election (Sec. 8043(a))",
      note_pubnotice="Notice is published in one but not more than two newspapers of general circulation and in the legal journal; if only newspaper publication is done, three times at intervals of not less than three days, the first 14 to 21 days before the election; the notice states the date, the estimated debt amount, the project, the estimated cost, and the ballot question (Sec. 8042)",
      note_exception="Self-liquidating debt evidenced by revenue bonds is excluded from the nonelectoral debt limit (Sec. 8025); electoral debt, subsidized debt, and certain purposes are outside the regular debt limits; a home-rule county may set more restrictive nonelectoral limits",
      note_nichevote="A majority of the votes cast approves the debt, 'irrespective of any other statute requiring a greater percentage' (Sec. 8043(d))",
      note_votereqbyothergovtlevels="'Local government unit' includes counties, cities, boroughs, incorporated towns, townships, and home-rule municipalities (Sec. 8002); the same electoral and nonelectoral framework applies to all"),
    R(stab="PA", state="pennsylvania",
      source=f"53 Pa.C.S. {SECT} 8025 (exclusion of self-liquidating revenue bonds)",
      source_url=f"{J}/pennsylvania/title-53/chapter-80/section-8025/",
      source_year=2025,
      source_filename="PA/260625_pennsylvania_title-53.txt",
      bond_type="rev",
      note_vote="No voter approval. Revenue bonds and notes are payable solely from the revenues of the project financed; bond counsel must opine that the holders have no claim upon the taxing power or tax revenues of the local government unit, but only upon the specific pledged revenues (Sec. 8025). Self-liquidating revenue debt is excluded from net nonelectoral debt and needs no referendum",
      note_textreq="None indicated (no referendum applies)",
      note_pubnotice="The ordinance authorizing the bonds is advertised and takes effect under Sec. 8003; no election notice is required (no referendum)",
      note_exception="Revenue bonds are not general obligations; on default, recovery is limited to the assessments, revenues, rates, rents, tolls, and charges from the project that are pledged for payment (Sec. 8262(b))",
      note_votereqbyothergovtlevels="Available to any local government unit (counties, cities, boroughs, townships) issuing self-liquidating revenue bonds"),

    # ==================== RHODE ISLAND ====================
    # Bonds require voter approval (referendum or financial town meeting) via the enabling
    # act, the ministerial-approval route, or the charter. Revenue bonds by resolution, no vote.
    R(stab="RI", state="rhode island",
      source=f"R.I. Gen. Laws {SECT} 45-12-2.1 (ministerial approval) with {SECT} 45-12-2, 45-12-19",
      source_url=f"{J}/rhode-island/title-45/chapter-45-12/section-45-12-2-1/",
      source_year=2025,
      source_filename="RI/260625_rhode-island_title-45.txt",
      bond_type="go",
      note_vote="A city or town may not incur bonded debt except under a general or special law of the General Assembly (Sec. 45-12-2), or, since 2008, through ministerial approval by the auditor general for a highly rated municipality (Sec. 45-12-2.1). Under the ministerial route the bond authorization must have been approved by local referendum at a general or special election or by financial town meeting (Sec. 45-12-2.1(4)); a special enabling act commonly likewise conditions issuance on elector approval. Whether a referendum is required therefore depends on the authorizing law and the charter",
      note_textreq="None indicated in these sections (the ballot question is set by the enabling act or charter)",
      note_timing="The local referendum is held at a general or special election or at a financial town meeting (Sec. 45-12-2.1(4))",
      note_pubnotice="None indicated in these sections; once a law effective upon elector approval has been approved, defects in the posting or notice of the election do not invalidate it (Sec. 45-12-20)",
      note_exception="Pension obligation bonds, other post-employment-benefit bonds, and tax-synchronization bonds may not use ministerial approval (Sec. 45-12-2.1); once a general or special law effective upon elector approval has been approved, the city or town may issue the bonds without a further referendum, by ordinance or resolution (Sec. 45-12-20)",
      note_optin="A charter may provide that a bond ordinance or resolution becomes effective only upon approval by a majority of electors voting; this charter referendum is inoperative where the authorizing law itself already requires elector approval and operative where it does not (Sec. 45-12-19)",
      note_votereqbyothergovtlevels="Applies to cities and towns; a town may authorize bonds by financial town meeting rather than by election (Sec. 45-12-2.1(4))"),
    R(stab="RI", state="rhode island",
      source=f"R.I. Gen. Laws {SECT} 45-54-10 (municipal revenue bonds; resolution)",
      source_url=f"{J}/rhode-island/title-45/chapter-45-54/section-45-54-10/",
      source_year=2025,
      source_filename="RI/260625_rhode-island_title-45.txt",
      bond_type="rev",
      note_vote="No voter approval. A municipal financing corporation is authorized to provide by resolution for the issuance of revenue bonds to pay the cost of projects (Sec. 45-54-10); the bonds are payable solely from the pledged project revenues and may be issued without obtaining the consent of any state agency or the happening of any other proceedings or conditions (Sec. 45-54-10(c)). Parallel municipal revenue-bond authority appears at Sec. 45-50-14",
      note_exception="Revenue bonds do not pledge the credit of the state or its political subdivisions (Sec. 45-54-17; Sec. 45-50-11); they are payable only from the project revenues",
      note_votereqbyothergovtlevels="Available to municipal financing corporations and authorities established by cities and towns (Chapter 45-54)"),

    # ==================== SOUTH CAROLINA ====================
    # GO within the 8 percent limit no referendum; above 8 percent referendum; 15 percent
    # reverse-referendum petition. Utility revenue bonds (Revenue Bond Act) no vote.
    R(stab="SC", state="south carolina",
      source=f"S.C. Code Ann. {SECT} 5-21-240 (municipal GO bonds) with S.C. Const. art. X, {SECT} 14",
      source_url=f"{J}/south-carolina/title-5/chapter-21/section-5-21-240/",
      source_year=2025,
      source_filename="SC/260625_south-carolina_title-5.txt",
      bond_type="go",
      note_vote="A municipal council may issue general obligation bonds for any corporate purpose up to the applicable constitutional debt limit (Sec. 5-21-240). Under S.C. Const. art. X, Sec. 14(7)(a), a political subdivision may incur general obligation debt up to 8 percent of the assessed value of taxable property WITHOUT a referendum; general obligation debt exceeding 8 percent must be authorized by a majority of the qualified electors voting in a referendum (art. X, Sec. 14(6)). Whether a referendum is required therefore depends on the 8 percent limit",
      note_textreq="For a bond referendum the ballot asks whether the municipal council shall be empowered to issue general obligation bonds for the specified purpose, followed by 'YES' and 'NO', with a separate question for each purpose (water and sewer purposes may be combined) (Sec. 5-21 bond-election provisions)",
      note_timing="General obligation debt authorized at a referendum must be issued within 5 years of the referendum (art. X, Sec. 14(6)(c))",
      note_pubnotice="None indicated in these sections (the referendum is conducted under the general election law)",
      note_exception="General obligation debt within the 8 percent limit needs no referendum; refunding bonds, tax-anticipation notes (art. X, Sec. 14(8), maturing within 90 days), and bond-anticipation notes (Sec. 14(9)) are not subject to the reverse-referendum petition",
      note_petition="Within 60 days after an ordinance authorizing full-faith-and-credit bonds, the electors may initiate its repeal by a petition signed by at least 15 percent of the registered electors at the last regular municipal election, certified by the municipal election commission; if the council does not repeal the ordinance, a referendum is held within one year (Sec. 5-17-10, 5-17-20, 5-17-30). Referendum-approved bond issues and tax-anticipation notes are excluded",
      note_votereqbyothergovtlevels="'Political subdivisions' (counties, incorporated municipalities, and special purpose districts) share the art. X, Sec. 14 framework; a county may not incur bonded debt for services benefiting only a particular area without a special assessment or charge on that area; municipal acquisition or first construction of a utility system requires a referendum (art. VIII, Sec. 16)"),
    R(stab="SC", state="south carolina",
      source=f"S.C. Code Ann. {SECT} 6-21-10 et seq. (Revenue Bond Act for Utilities)",
      source_url=f"{J}/south-carolina/title-6/chapter-21/section-6-21-10/",
      source_year=2025,
      source_filename="SC/260625_south-carolina_title-6.txt",
      bond_type="rev",
      note_vote="No voter approval. Under the Revenue Bond Act for Utilities a borrower issues revenue bonds payable solely from the revenues derived from operating the utility system or project; each bond states on its face that it is issued under the chapter and does not constitute an indebtedness of the borrower within any state constitutional provision or statutory limitation (Sec. 6-21). No referendum is required",
      note_textreq="None indicated (no referendum applies)",
      note_exception="Revenue bonds are not indebtedness within the constitutional debt limit; nothing in the chapter authorizes creating a debt within the meaning of any constitutional limitation. Separately, municipal acquisition or first construction of a gas, water, sewer, electric, or transportation utility requires an acquisition referendum (S.C. Const. art. VIII, Sec. 16), which is an acquisition vote rather than a revenue-bond vote",
      note_votereqbyothergovtlevels="Available to municipalities and other borrowers (counties, special purpose districts) under the Act"),

    # ==================== VIRGINIA ====================
    # Cities/towns issue GO by ordinance without a referendum (except art. VII Sec. 10(a)(2)
    # revenue-undertaking full-faith bonds); counties require a referendum. Revenue no vote.
    R(stab="VA", state="virginia",
      source=f"Va. Code {SECT} 15.2-2636 (ordinance for bond issue) with Va. Const. art. VII, {SECT} 10",
      source_url=f"{J}/virginia/title-15-2/chapter-26/section-15-2-2636/",
      source_year=2025,
      source_filename="VA/260625_virginia_title-15-2.txt",
      bond_type="go",
      note_vote="A city or town may authorize and issue general obligation bonds under Va. Const. art. VII, Sec. 10(a) and the Public Finance Act of 1991 by ordinance or resolution WITHOUT submitting the question to the voters, except bonds under Sec. 10(a)(2) (full-faith-and-credit bonds for a revenue-producing undertaking), which require voter approval (Sec. 15.2-2636). The ordinance must be passed by a recorded affirmative vote of a majority of all members elected to the governing body. City and town general obligation debt is capped at 10 percent of the assessed value of taxable real estate (art. VII, Sec. 10(a))",
      note_textreq="For a required referendum the circuit court fixes the ballot question (Sec. 15.2-2610, 15.2-2611); the authorizing ordinance states the maximum principal amount and, in brief and general terms, the purposes (Sec. 15.2-2636)",
      note_timing="Bonds authorized by referendum may not be issued more than 8 years after the referendum, extendable by the circuit court to up to 10 years (Sec. 15.2-2611)",
      note_pubnotice="Before final authorization the governing body must hold a public hearing; notice is published twice, the first no more than 28 days and the second no less than 7 days before the hearing, stating the estimated maximum amount, the proposed use of the proceeds, and the time and place (Sec. 15.2-2606); no hearing is required for voter-approved bonds or for obligations under Sec. 15.2-2629, 15.2-2630, or 15.2-2643 (Sec. 15.2-2606(B))",
      note_exception="Refunding bonds are not subject to referendum (Sec. 15.2-2643); revenue bonds and revenue-anticipation obligations are excluded from the 10 percent debt limit (art. VII, Sec. 10(a)(1),(3)); a charter or special-act referendum requirement controls over the Act (Sec. 15.2-2601)",
      note_optin="A charter or special act may impose a referendum requirement on bond issuance, which after July 1, 1992 controls over the Public Finance Act (Sec. 15.2-2601)",
      note_votereqbyothergovtlevels="Counties may not contract bond debt except as authorized by the General Assembly by general law and generally must submit the question to a majority vote of the qualified voters (art. VII, Sec. 10(b); Sec. 15.2-2640); a county may elect by referendum to be treated as a city (Sec. 15.2-2640); county school bonds require voter approval unless sold to the Literary Fund or a state agency"),
    R(stab="VA", state="virginia",
      source=f"Va. Code {SECT} 15.2-2608 (bonds for revenue-producing undertakings)",
      source_url=f"{J}/virginia/title-15-2/chapter-26/section-15-2-2608/",
      source_year=2025,
      source_filename="VA/260625_virginia_title-15-2.txt",
      bond_type="rev",
      note_vote="No voter approval. A locality may issue revenue bonds for any revenue-producing undertaking in accordance with Va. Const. art. VII, Sec. 10 (Sec. 15.2-2608); bonds payable exclusively from the revenues of a water system or other undertaking are excluded from the debt limit and need no referendum (art. VII, Sec. 10(a)(3)). The bonds are authorized by ordinance or resolution of a majority of the governing body",
      note_textreq="None indicated (no referendum applies)",
      note_pubnotice="The public hearing under Sec. 15.2-2606 applies (notice published twice, 28 and 7 days before) unless the bonds were voter-approved",
      note_exception="Revenue bonds pledge no taxing power; if full faith and credit is added to secure a revenue-producing undertaking, the art. VII, Sec. 10(a)(2) referendum is triggered instead; refunding bonds are not subject to referendum (Sec. 15.2-2643)",
      note_votereqbyothergovtlevels="Available to any locality (counties, cities, and towns)"),

    # ==================== DELAWARE ====================
    # Municipal bond authority is charter-based (special legislation not in the general
    # Title 22 corpus). Sec. 106 gives large cities a 16 percent debt limit, authorized by
    # the governing body. Secondary doc: raw\DE\_secondary\DE_title22_delcode.pdf.
    R(stab="DE", state="delaware",
      source=f"22 Del. C. {SECT} 106 (debt limit; municipal charters govern bond authorization)",
      source_url=f"{J}/delaware/title-22/chapter-1/section-106/",
      source_year=2025,
      source_filename="DE/260625_delaware_title-22.txt",
      bond_type="go",
      note_vote="Delaware municipal general obligation bond authority is charter-based: each city or town charter, a special act of the General Assembly, grants the power to borrow and issue bonds and specifies whether a local referendum or special election is required; the general municipal law (Title 22) supplies only supplemental provisions. Under Sec. 106, a city over 50,000 in population (Wilmington) may issue bonds up to 16 percent of the assessed value of taxable real estate, which must be approved and authorized by the governing body in the same manner as the city's other obligations (Sec. 106(b)), that is, by ordinance with no referendum imposed by Sec. 106; many smaller-town charters instead condition bond issues on approval by the qualified voters at a special election",
      note_textreq="None indicated in the general municipal law (any ballot question is set by the municipality's charter)",
      note_timing="None indicated in the general municipal law (set by the municipality's charter)",
      note_pubnotice="None indicated in the general municipal law (set by the municipality's charter)",
      note_exception="Water bonds, sewer bonds, school bonds (up to 3 percent), parking-authority bonds, and urban-renewal bonds are excluded from the Sec. 106 debt limit (Sec. 106(a)(1)-(4)). The operative charters are special legislation not contained in the downloaded Title 22 corpus; this row is grounded on Sec. 106 (in the corpus) and cross-referenced to the Title 22 secondary document at raw/DE/_secondary/DE_title22_delcode.pdf",
      note_optin="A municipal charter, or the Home Rule provisions of Title 22 chapter 8, may require a referendum or special election to authorize bonds",
      note_votereqbyothergovtlevels="Sec. 106 applies to cities over 50,000 (Wilmington); other municipalities authorize bonds under their own charters, and counties borrow under Title 9"),
    R(stab="DE", state="delaware",
      source=f"22 Del. C. {SECT} 106(a)(1),(2) (water and sewer revenue-supported bonds)",
      source_url=f"{J}/delaware/title-22/chapter-1/section-106/",
      source_year=2025,
      source_filename="DE/260625_delaware_title-22.txt",
      bond_type="rev",
      note_vote="No voter approval under the general municipal law: water bonds, and sewer bonds for which the city collects rates, rents, or fees, are excluded from the Sec. 106 debt limit (Sec. 106(a)(1),(2)) and are authorized by the governing body; municipal electric companies issue revenue bonds under Title 22 chapter 13. Revenue bonds are payable from the enterprise revenues, though an individual municipality's charter may still impose a referendum",
      note_textreq="None indicated in the general municipal law (set by the municipality's charter)",
      note_exception="Water, sewer, and enterprise revenue bonds are excluded from the Sec. 106 debt limit (Sec. 106(a)(1),(2)); municipal electric revenue bonds are authorized under Title 22 chapter 13. Charter provisions are special legislation not in the downloaded corpus; cross-referenced to raw/DE/_secondary/DE_title22_delcode.pdf",
      note_optin="A municipal charter may require a referendum to authorize revenue bonds",
      note_votereqbyothergovtlevels="Available to municipalities issuing utility or enterprise revenue bonds under their charters and Title 22"),
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

    # Guard: no null/blank cells.
    nulls = []
    for r in df.iter_rows(named=True):
        for c, v in r.items():
            if v is None or (isinstance(v, str) and v.strip() == ""):
                nulls.append((r["stab"], c))
    print("blank/null cells:", len(nulls), nulls[:20] if nulls else "")

    # Guard: the section sign appears only in `source`.
    misplaced = []
    for r in df.iter_rows(named=True):
        for c, v in r.items():
            if c != "source" and isinstance(v, str) and "§" in v:
                misplaced.append((r["stab"], c))
    print("section sign outside source:", misplaced if misplaced else "none")

    OUT.write_text(df.write_csv(), encoding="utf-8-sig")
    print("Wrote", OUT, "rows:", df.height)
    print("states:", df["stab"].n_unique(), sorted(df["stab"].unique().to_list()))
    print("control values:", df["control"].unique().to_list())
    print("bond_type counts:", df["bond_type"].value_counts().sort("bond_type").to_dicts())
    print("rows per state:", df.group_by("stab").len().sort("stab").to_dicts())


if __name__ == "__main__":
    main()
