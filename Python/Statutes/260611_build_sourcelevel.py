#!/usr/bin/env python3
r"""
260611_build_sourcelevel.py  --  Debt by Democracy: state statute AI task

Phase 4. Build 260611_sourcelevel.csv for the 10-state pilot. Classifications are
grounded in the downloaded corpus under Data\Statutes\raw (Justia HTML, KY PDF-
repaired text, and local secondary PDFs), located via the curated seed pointers.

Schema / conventions (user-confirmed; see findings.md "sourcelevel.csv conventions"):
- ONE ROW PER SOURCE (one statute section / one document per row), never one row
  per state. bond_type, source_url and the note_* text all describe THAT one source
  only. If a provision pairs an authority section with a procedure section (e.g. MS
  21-33-301 + 21-33-307), each gets its own row with its own source_url; cross-refs
  to the other section live in the notes.
- bond_type in {go, rev, both} reflects only the bonds the row's source governs.
- source column KEEPS the section sign (Sec.) symbol; it is the ONLY non-ASCII
  glyph allowed (the CSV is written UTF-8-with-BOM so Excel renders it cleanly).
  All note_* text stays plain ASCII (write "Sec." in notes, not the symbol).
- source_year = the year of the cited edition / publication (e.g. 2024, 2025); the
  citation year lives in this dedicated column, not inside the source string.
- The four formerly "control-only" note columns (note_nichevote, note_optin,
  note_petition, note_votereqbyothergovtlevels) are filled for ALL pilot states.
- note_optin = a city's own ability to ADD a vote requirement (ordinance/charter).
- note_timing = ONLY the required timing of WHEN the election must be held. Timing
  of public notice goes in note_pubnotice; timing of a protest/petition goes in
  note_petition. (Do not put notice or petition timing in note_timing.)
- Absence is written as the standard phrase "None indicated".
- note_vote states the requirement/threshold only; it does NOT list which voters
  may vote. Be specific (pull actual thresholds, ballot text, deadlines).
- control flags are copied from the dummy; NEVER changed here.

Output: Data\Statutes\260611_sourcelevel.csv
"""
from __future__ import annotations

from pathlib import Path
import polars as pl

OUT = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
          r"\Data\Statutes\260611_sourcelevel.csv")

COLS = ["stab", "state", "pilot", "control", "source", "source_url", "source_year",
        "source_type", "source_filename", "bond_type", "note_vote", "note_textreq",
        "note_timing", "note_pubnotice", "note_exception", "note_nichevote",
        "note_optin", "note_petition", "note_votereqbyothergovtlevels"]

J = "https://law.justia.com/codes"

# The section sign is the one non-ASCII glyph permitted (source column only).
SECT = "§"
NONE = "None indicated"

ROWS = [
    # ---------------- ALASKA (non-control) ----------------
    dict(stab="AK", state="alaska", pilot=1, control=0,
         source=f"Alaska Stat. {SECT} 29.47.190",
         source_url=f"{J}/alaska/title-29/chapter-47/article-3/section-29-47-190/",
         source_year=2025,
         source_type="primary", source_filename="AK/alaska_title-29.txt",
         bond_type="go",
         note_vote="General obligation bonds must be authorized by a majority vote at an election",
         note_textreq=NONE, note_timing=NONE,
         note_pubnotice="Notice of existing indebtedness must be published weekly for 3 consecutive weeks, the first at least 20 days before the election, stating the current GO indebtedness (including authorized-but-unsold bonds), the debt-service cost, and the total assessed property value",
         note_exception=NONE, note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels="Boroughs are municipalities (AS 01.10.060) and subject to the same Title 29 GO-bond vote requirement"),
    dict(stab="AK", state="alaska", pilot=1, control=0,
         source=f"Alaska Stat. {SECT} 29.47.250",
         source_url=f"{J}/alaska/title-29/chapter-47/article-4/section-29-47-250/",
         source_year=2025,
         source_type="primary", source_filename="AK/alaska_title-29.txt",
         bond_type="rev",
         note_vote="No election is required to authorize revenue bonds",
         note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
         note_exception=NONE, note_nichevote=NONE,
         note_optin="A city may, by its own ordinance, choose to require a vote for revenue bonds",
         note_petition=NONE,
         note_votereqbyothergovtlevels="Same revenue-bond rule applies to boroughs (municipalities, AS 01.10.060)"),

    # ---------------- KENTUCKY (control) ----------------
    dict(stab="KY", state="kentucky", pilot=1, control=1,
         source=f"Ky. Rev. Stat. {SECT} 66.101 (Ch. 66 Local Government Debt)",
         source_url=f"{J}/kentucky/chapter-66/section-66-101/",
         source_year=2025,
         source_type="primary", source_filename="KY/kentucky_chapter-66.txt",
         bond_type="both",
         note_vote="No voter referendum required for cities; a city authorizes bonds by ordinance (KRS 66.101)",
         note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
         note_exception="None within Ch. 66 (see KRS 96.640 utility exception)",
         note_nichevote="A vote is required only in the niche utility case (electric plant) under KRS 96.640; rarely used",
         note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels="Counties also issue bonds under Ch. 66 (e.g., county bond approval, KRS 66.310) without a referendum"),
    dict(stab="KY", state="kentucky", pilot=1, control=1,
         source=f"Ky. Rev. Stat. {SECT} 96.640 - utility (electric plant) exception",
         source_url=f"{J}/kentucky/chapter-96/section-96-640/",
         source_year=2025,
         source_type="primary", source_filename="KY/kentucky_chapter-96.txt",
         bond_type="both",
         note_vote="A majority of qualified voters voting must approve before a city may construct, purchase, or condemn an electric plant or issue bonds (including revenue bonds) for it; rarely used in practice",
         note_textreq="Ballot must state the project and the maximum amount of revenue bonds (e.g., 'Are you in favor of the city constructing and operating a municipal electric plant ... and the issuance of revenue bonds in the maximum amount of $___')",
         note_timing="Held at the next regular November election, provided the ordinance is certified to the county clerk by the second Tuesday in August preceding that election",
         note_pubnotice="The mayor advertises the election by newspaper publication (KRS Chapter 424) and by printed handbills posted in at least four conspicuous places in each voting precinct and at the courthouse door",
         note_exception="This is the rare situation where KY cities do need a vote (electric/utility plant bonds)",
         note_nichevote="Yes - utility (electric plant) bonds require voter approval (KRS 96.640)",
         note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels="Applies to municipalities acquiring or financing electric plants"),
    dict(stab="KY", state="kentucky", pilot=1, control=1,
         source="Kentucky League of Cities - Municipal Bonds 101",
         source_url="https://www.klc.org/userfiles/files/MunicipalBonds101Summer2019.pdf",
         source_year=2019,
         source_type="secondary", source_filename="KY/_secondary/klc_MunicipalBonds101_2019.pdf",
         bond_type="both",
         note_vote="No voter approval required today. Historically (pre-1994) KY cities needed a two-thirds vote of the public for GO debt not repayable within one year; a 1994 amendment to the KY Constitution (Sec. 157) removed this. Cities may now issue GO debt so long as the annual budget is balanced (expenditures do not exceed revenues).",
         note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
         note_exception="GO debt is subject to a balanced-budget condition (KY Const. Sec. 157/157b) and population-based debt limits (Sec. 158), but no referendum",
         note_nichevote="Confirms the only niche vote case is the utility/electric-plant exception (KRS 96.640)",
         note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels="Notes that bonds are issued by states, cities, counties, and other governmental entities; no referendum described for any"),

    # ---------------- ALABAMA (non-control) ----------------
    dict(stab="AL", state="alabama", pilot=1, control=0,
         source=f"Ala. Const. {SECT} 222",
         source_url="https://law.justia.com/constitution/alabama/CA-245767.html",
         source_year=2022,
         source_type="primary", source_filename="AL/alabama_constitution.txt",
         bond_type="go",
         note_vote="General obligation bonds must first be authorized by a majority vote (by ballot) of the qualified voters voting on the proposition",
         note_textreq="Ballot must contain 'For ... bond issue' and 'Against ... bond issue', with the character of the bond stated in the blank",
         note_timing=NONE, note_pubnotice=NONE,
         note_exception="Does not apply to renewal/refunding of lawfully issued bonds, or to bonds for street/sidewalk improvements or sanitary/storm sewers whose cost is assessed against the abutting/benefited property (special assessment). Warrants (a limited-obligation instrument distinct from bonds) require no election, so cities often use warrants to avoid the GO vote.",
         note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels="The same majority-vote requirement applies to counties, towns, villages, districts, and other political subdivisions of counties (Sec. 222)"),
    dict(stab="AL", state="alabama", pilot=1, control=0,
         source=f"Ala. Const. {SECT} 222.01 - revenue bond utility exception",
         source_url="https://alison.legislature.state.al.us/files/pdf/lsa/proposed-constitution/2022-constitution-statewide.pdf",
         source_year=2022,
         source_type="primary", source_filename="_secondary/AL_222.01_alison.pdf",
         bond_type="rev",
         note_vote="Revenue bonds and other revenue securities issued to extend, enlarge, or improve a municipal water, sewer, gas, or electric system do not require a voter election (Sec. 222.01)",
         note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
         note_exception="Revenue (non-GO) financing for water/sewer/gas/electric utilities is exempt from the Sec. 222 GO vote requirement",
         note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels=NONE),
    dict(stab="AL", state="alabama", pilot=1, control=0,
         source="Alabama League of Municipalities - Municipal Debt Financing",
         source_url="https://almonline.org/Assets/Files/LegalSelectedReadings/40.Municipal-Debt-Financing-REVISED-2024.pdf",
         source_year=2024,
         source_type="secondary", source_filename="_secondary/AL_almonline_debt.pdf",
         bond_type="both",
         note_vote="Confirms only GO bonds must be voted upon; warrants, revenue bonds, and assessment and refunding bonds do not require an election",
         note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
         note_exception="Cities may issue warrants (Ala. Code 11-81-4) and refunding securities without an election; revenue bonds are issued under Title 11, Ch. 81, Art. 5",
         note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels=NONE),

    # ---------------- ARIZONA (non-control; no dummy benchmark) ----------------
    dict(stab="AZ", state="arizona", pilot=1, control=0,
         source=f"Ariz. Rev. Stat. {SECT} 35-452",
         source_url="https://law.justia.com/codes/arizona/title-35/section-35-452/",
         source_year=2025,
         source_type="primary", source_filename="AZ/arizona_title-35.txt",
         bond_type="go",
         note_vote="General obligation indebtedness must be approved by a majority of the qualified electors voting at an election",
         note_textreq=NONE,
         note_timing="The bond election is held on the first Tuesday after the first Monday in November",
         note_pubnotice=NONE, note_exception=NONE, note_nichevote=NONE, note_optin=NONE,
         note_petition="The governing body must order a bond election upon a petition signed by 15 percent of the qualified electors",
         note_votereqbyothergovtlevels="Applies to cities, towns, counties, school districts and other political subdivisions (Sec. 35-451); counties must submit street/highway bonds to a majority vote (Sec. 11-372)"),
    dict(stab="AZ", state="arizona", pilot=1, control=0,
         source=f"Ariz. Rev. Stat. {SECT} 9-523 - utility revenue bonds",
         source_url="https://law.justia.com/codes/arizona/title-9/section-9-523/",
         source_year=2025,
         source_type="primary", source_filename="AZ/arizona_title-9.txt",
         bond_type="rev",
         note_vote="Utility revenue bonds require the assent of a majority of the qualified electors voting at an election held for that purpose",
         note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE, note_exception=NONE,
         note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels="Applies to municipal utility undertakings under this article"),
    dict(stab="AZ", state="arizona", pilot=1, control=0,
         source=f"Ariz. Rev. Stat. {SECT} 9-441.03 - housing development bonds",
         source_url="https://law.justia.com/codes/arizona/title-9/section-9-441-03/",
         source_year=2025,
         source_type="primary", source_filename="AZ/arizona_title-9.txt",
         bond_type="rev",
         note_vote="No voter approval required; housing development bonds are payable solely from project revenues and are not a general obligation of the municipality",
         note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
         note_exception="These bonds do not pledge the city's full faith and credit, so the GO election requirement does not apply",
         note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels=NONE),

    # ---------------- MASSACHUSETTS (control) ----------------
    dict(stab="MA", state="massachusetts", pilot=1, control=1,
         source=f"Mass. Gen. Laws ch. 44, {SECT} 7",
         source_url="https://law.justia.com/codes/massachusetts/part-i/title-vii/chapter-44/section-7/",
         source_year=2025,
         source_type="primary", source_filename="MA/massachusetts_title-vii.txt",
         bond_type="go",
         note_vote="No resident referendum; a city incurs general obligation debt WITHIN the statutory debt limit by a two-thirds vote of the city council (the legislative body) for the public purposes enumerated in Sec. 7",
         note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
         note_exception="Sec. 7 enumerates the within-limit purposes (land/asset acquisition, public buildings and infrastructure, judgments, etc.)",
         note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels="In towns, the two-thirds authorization is given by the town meeting (a vote of town residents)"),
    dict(stab="MA", state="massachusetts", pilot=1, control=1,
         source=f"Mass. Gen. Laws ch. 44, {SECT} 8",
         source_url="https://law.justia.com/codes/massachusetts/part-i/title-vii/chapter-44/section-8/",
         source_year=2025,
         source_type="primary", source_filename="MA/massachusetts_title-vii.txt",
         bond_type="rev",
         note_vote="No resident referendum; debt for revenue-producing and utility purposes is incurred OUTSIDE the statutory debt limit by a two-thirds vote of the city council",
         note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
         note_exception="Sec. 8 enumerates the outside-limit purposes - water supply, treatment and mains; sewer and drainage systems; energy and other revenue-producing or long-lived assets - which serve as the state's municipal revenue/enterprise financing mechanism",
         note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels="In towns, the two-thirds authorization is given by the town meeting"),

    # ---------------- MISSISSIPPI (control) ----------------
    dict(stab="MS", state="mississippi", pilot=1, control=1,
         source=f"Miss. Code {SECT} 21-33-301",
         source_url="https://law.justia.com/codes/mississippi/title-21/chapter-33/article-5/section-21-33-301/",
         source_year=2024,
         source_type="primary", source_filename="MS/mississippi_title-21.txt",
         bond_type="go",
         note_vote="Authorizes the governing authority to issue GO bonds for the enumerated municipal purposes; most purposes need no automatic voter approval (issued by resolution under Sec. 21-33-307). Bonds to acquire or improve an EXISTING mass transit system are the exception and always require a majority-vote election.",
         note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
         note_exception="Mass transit: no bonds for acquiring or improving an existing mass transit system may be issued unless a majority of the qualified electors voting approve at an election (Sec. 21-33-301(o))",
         note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels=NONE),
    dict(stab="MS", state="mississippi", pilot=1, control=1,
         source=f"Miss. Code {SECT} 21-33-307",
         source_url="https://law.justia.com/codes/mississippi/title-21/chapter-33/article-5/section-21-33-307/",
         source_year=2024,
         source_type="primary", source_filename="MS/mississippi_title-21.txt",
         bond_type="go",
         note_vote="No automatic voter approval; the governing authority adopts a resolution of intent to issue the bonds. An election is required only if a protest petition is filed.",
         note_textreq=NONE, note_timing=NONE,
         note_pubnotice="The resolution of intent must be published once a week for 3 consecutive weeks (first publication at least 21 days, and last not more than 7 days, before the date fixed for issuance); if no local newspaper, the resolution is posted at 3 public places for at least 21 days. Election notice (if any) is published on the same 3-weeks / 21-7-day schedule.",
         note_exception="If no protest is filed, the bonds may be issued without an election at any time within 2 years after the date set in the resolution",
         note_nichevote=NONE,
         note_optin="The governing authority may, in its discretion, call an election even if no protest is filed",
         note_petition="If 10 percent of the qualified electors (or 1,500, whichever is less) file a written protest by the date set in the resolution, a bond election is held under Sec. 21-33-309 (majority of those voting decides; ballot reads FOR / AGAINST THE BOND ISSUE)",
         note_votereqbyothergovtlevels=NONE),
    dict(stab="MS", state="mississippi", pilot=1, control=1,
         source=f"Miss. Code {SECT} 21-27-43",
         source_url="https://law.justia.com/codes/mississippi/title-21/chapter-27/municipally-owned-utilities/section-21-27-43/",
         source_year=2024,
         source_type="primary", source_filename="MS/mississippi_title-21.txt",
         bond_type="rev",
         note_vote="Municipal utility revenue bonds (water, sewer, gas, electric, garbage, transportation systems authorized by Sec. 21-27-23) are EXEMPT from the general election requirement; they may be issued after published notice unless a 20 percent protest petition forces an election. (Non-revenue bonds under Sec. 21-27-23 instead require a majority-vote special election.)",
         note_textreq=NONE,
         note_timing="If a protest petition forces an election, the election is ordered to be held not later than 40 days after the date of the last notice of the proposed revenue bond issue",
         note_pubnotice="Notice of intention to issue the revenue bonds (amount and terms) is published once a week for 3 consecutive weeks; the bonds may be sold 10 days after the last publication. If an election is required, notice of the election is published once a week for 3 consecutive weeks before the election.",
         note_exception="Revenue bonds are payable solely from system revenues, do not pledge the municipality's taxing power, and are not municipal indebtedness (Sec. 21-27-45)",
         note_nichevote=NONE,
         note_optin="The governing authority may call an election even if no protest petition is filed",
         note_petition="Within 10 days after the last publication of the notice of intention, a petition signed by at least 20 percent of the qualified voters protesting the issue forces a special election (majority of those voting decides)",
         note_votereqbyothergovtlevels=NONE),

    # ---------------- NEW HAMPSHIRE (control) ----------------
    dict(stab="NH", state="new hampshire", pilot=1, control=1,
         source=f"N.H. Rev. Stat. {SECT} 33:9 - City Bonds",
         source_url="https://law.justia.com/codes/new-hampshire/title-iii/chapter-33/section-33-9/",
         source_year=2025,
         source_type="primary", source_filename="NH/new-hampshire_title-iii.txt",
         bond_type="both",
         note_vote="No resident referendum for cities; city bonds are authorized by a resolution of the city council passed by at least two-thirds of all members of each branch",
         note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE, note_exception=NONE,
         note_nichevote=NONE,
         note_optin="A town that has adopted a council charter without a budgetary town meeting may choose in its charter to use the city (council) bond procedure (Sec. 33:8-e)",
         note_petition=NONE,
         note_votereqbyothergovtlevels="Towns and village districts instead authorize bonds by a 3/5 ballot vote of voters at town meeting (Sec. 33:8) - i.e., towns require a resident vote, cities do not"),
    dict(stab="NH", state="new hampshire", pilot=1, control=1,
         source=f"N.H. Rev. Stat. {SECT} 33:8 - Town or District Bonds",
         source_url="https://law.justia.com/codes/new-hampshire/title-iii/chapter-33/section-33-8/",
         source_year=2025,
         source_type="primary", source_filename="NH/new-hampshire_title-iii.txt",
         bond_type="both",
         note_vote="Towns and village districts authorize bonds by a 3/5 ballot vote of the voters present and voting at town meeting (tax anticipation notes by a majority); a municipality with an optional charter legislative body uses a 2/3 or 3/5 vote per its charter, defaulting to 3/5",
         note_textreq=NONE,
         note_timing="Vote taken at an annual or special town meeting; a special meeting is valid only if a majority of all legal voters are present and vote (unless the superior court permits an emergency meeting)",
         note_pubnotice="The warrant for a special meeting is published once in a newspaper of general circulation within one week after posting; the warrant must be served/posted at least 14 days before the meeting",
         note_exception=NONE, note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels="This row is the TOWN requirement; cities instead use a 2/3 city-council vote (Sec. 33:9)"),

    # ---------------- NEW JERSEY (control) ----------------
    dict(stab="NJ", state="new jersey", pilot=1, control=1,
         source=f"N.J. Rev. Stat. {SECT} 40A:2-17",
         source_url="https://law.justia.com/codes/new-jersey/title-40a/section-40a-2-17/",
         source_year=2025,
         source_type="primary", source_filename="NJ/new-jersey_title-40a.txt",
         bond_type="go",
         note_vote="No voter referendum; a municipality authorizes general obligation bonds by adopting a bond ordinance (two-thirds vote of the full governing body) under the Local Bond Law",
         note_textreq=NONE, note_timing=NONE,
         note_pubnotice="The bond ordinance (or a summary) is published after introduction with notice of a hearing at least 10 days later; a copy is posted on the municipal bulletin board and made available to the public at least one week before final consideration, a public hearing is held before adoption, and the ordinance takes effect 20 days after the first publication following final adoption (Sec. 40A:2-18)",
         note_exception="A bond ordinance to fund, refund, renew, or retire existing obligations is not subject to referendum (Sec. 40A:2-18)",
         note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels=NONE),
    dict(stab="NJ", state="new jersey", pilot=1, control=1,
         source=f"N.J. Rev. Stat. {SECT} 40A:2-47 - self-liquidating municipal utility",
         source_url="https://law.justia.com/codes/new-jersey/title-40a/section-40a-2-47/",
         source_year=2025,
         source_type="primary", source_filename="NJ/new-jersey_title-40a.txt",
         bond_type="rev",
         note_vote="No voter referendum; obligations financing a municipal public utility (water, sewer, etc.) are 'self-liquidating' bonds authorized by bond ordinance under the Local Bond Law, the same way as other municipal debt. Genuinely non-recourse revenue bonds are issued by separate municipal/county utilities authorities under the Local Authorities Fiscal Control Law (Sec. 40A:5A), also without a referendum.",
         note_textreq=NONE, note_timing=NONE,
         note_pubnotice="Same bond-ordinance procedure as Sec. 40A:2-17 (publication, public hearing); self-liquidating debt is excluded from the municipal debt limit (Sec. 40A:2-45 to 40A:2-48)",
         note_exception="Self-liquidating utility debt is deducted from gross debt and does not count against the statutory debt limit",
         note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels="Municipal and county utilities authorities created under Sec. 40A:5A issue revenue bonds in their own name without a referendum"),

    # ---------------- TENNESSEE (control) ----------------
    dict(stab="TN", state="tennessee", pilot=1, control=1,
         source=f"Tenn. Code {SECT} 9-21-205 - initial resolution (GO bonds)",
         source_url="https://law.justia.com/codes/tennessee/title-9/chapter-21/part-2/section-9-21-205/",
         source_year=2024,
         source_type="primary", source_filename="TN/tennessee_title-9.txt",
         bond_type="go",
         note_vote="No automatic voter approval; GO bonds are authorized by an 'initial resolution' of the governing body (majority vote of the body) stating the amount, project, interest rate, and source of payment. A referendum occurs only if triggered by a protest petition (Sec. 9-21-206/207).",
         note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
         note_exception="No initial resolution is required for a mandated project, or (for a county) for a school project (Sec. 9-21-205(b)); water/sewer bonds declared an emergency by a three-fourths vote need no election (Sec. 9-21-207(a))",
         note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels="Counties follow the same resolution procedure; a county need not adopt an initial resolution for a school project"),
    dict(stab="TN", state="tennessee", pilot=1, control=1,
         source=f"Tenn. Code {SECT} 9-21-206 - publication of notice / protest right",
         source_url="https://law.justia.com/codes/tennessee/title-9/chapter-21/part-2/section-9-21-206/",
         source_year=2024,
         source_type="primary", source_filename="TN/tennessee_title-9.txt",
         bond_type="go",
         note_vote="The initial resolution is published with a statutory notice giving voters a 20-day right to protest; a sufficient petition forces a referendum in which a majority of the registered voters voting must assent (Sec. 9-21-207, 9-21-209, 9-21-210)",
         note_textreq="The published notice must be in substantially the statutory form stating that, unless a 10 percent petition is filed within 20 days, the bonds will be issued as proposed",
         note_timing=NONE,
         note_pubnotice="The initial resolution, together with the statutory notice, must be published in full once in a newspaper of general circulation in the local government",
         note_exception=NONE, note_nichevote=NONE,
         note_optin="The governing body may decide to hold an election to ascertain the will of the electorate even if no petition is filed (Sec. 9-21-208)",
         note_petition="If within 20 days of publication a petition signed by at least 10 percent of the registered voters protests the issuance, a referendum is required; the county election commission certifies the signatures within 15 days (Sec. 9-21-207(b))",
         note_votereqbyothergovtlevels="The same notice/petition procedure applies to counties"),
    dict(stab="TN", state="tennessee", pilot=1, control=1,
         source=f"Tenn. Code {SECT} 9-21-301 - revenue bonds",
         source_url="https://law.justia.com/codes/tennessee/title-9/chapter-21/part-3/section-9-21-301/",
         source_year=2024,
         source_type="primary", source_filename="TN/tennessee_title-9.txt",
         bond_type="rev",
         note_vote="No voter approval and no protest-petition; revenue bonds (payable exclusively from the revenues of a public works project) are authorized solely by an initial resolution of the governing body (Sec. 9-21-304)",
         note_textreq=NONE, note_timing=NONE,
         note_pubnotice="The initial revenue-bond resolution must be published in full once in a newspaper of general circulation (Sec. 9-21-304); no protest/referendum mechanism attaches",
         note_exception="The 10 percent protest-petition referendum applies only to GO bonds (Part 2), not to revenue bonds (Part 3)",
         note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels="Counties and other local governments issue revenue bonds under the same Part 3 procedure without a referendum"),
    dict(stab="TN", state="tennessee", pilot=1, control=1,
         source="Tenn. Att'y Gen. Op. (Nov. 6, 2013) - County Bond Referendum",
         source_url="Local file (Tenn. Att'y Gen. Op., Nov. 6, 2013); see source_filename - tn.gov connection resets",
         source_year=2013,
         source_type="secondary", source_filename="TN/_secondary/TN_AG_op_2013_bond_referendum.pdf",
         bond_type="go",
         note_vote="Confirms TN cities/counties need no automatic referendum: GO bonds issue after the initial-resolution / 20-day-protest process, and an election occurs only if a sufficient 10 percent petition is certified (Sec. 9-21-205 to 9-21-210). Holds that if the governing body rescinds its authorizing resolution after a petition is certified, no election is required, because Tennessee does not authorize advisory/non-binding referendums.",
         note_textreq=NONE, note_timing=NONE, note_pubnotice=NONE,
         note_exception="A certified protest petition does not compel an election if the governing body first rescinds the bond resolution; advisory referendums are not authorized in Tennessee",
         note_nichevote=NONE,
         note_optin="A local government may also voluntarily hold an election to ascertain the will of the electorate (Sec. 9-21-208)",
         note_petition="A petition by at least 10 percent of registered voters, filed within 20 days of publication and certified by the county election commission, is required to force a referendum (Sec. 9-21-207(b))",
         note_votereqbyothergovtlevels="The opinion concerns a county (Lewis County) jail bond; the same procedure applies to counties and other local governments"),

    # ---------------- WISCONSIN (control) ----------------
    dict(stab="WI", state="wisconsin", pilot=1, control=1,
         source=f"Wis. Stat. {SECT} 67.05",
         source_url="https://law.justia.com/codes/wisconsin/chapter-67/section-67-05/",
         source_year=2025,
         source_type="primary", source_filename="WI/wisconsin_chapter-67.txt",
         bond_type="go",
         note_vote="A majority referendum is technically required for city/village general obligation bonds, but only for purposes NOT on a long enumerated list (water, sewer, streets, bridges, parks, schools, hospitals, libraries, etc.); because most municipal purposes are on the list, referendums are rare. Listed-purpose bonds are issued by the governing body's initial resolution without a vote.",
         note_textreq=NONE, note_timing=NONE,
         note_pubnotice="Where a permissive referendum applies, within 15 days after the initial resolution the governing body publishes a class 1 notice stating the purpose and maximum amount and describing the petition/referendum procedure; referendum notices are published under Sec. 10.01 (e.g., a type A notice on the 4th Tuesday before the referendum)",
         note_exception="Long enumerated list of exempt purposes in Sec. 67.05(5)(b) (water systems, lighting, gas, bridges, street improvements, sewerage, garbage disposal, parks, swimming pools, hospitals, airports, libraries, school purposes, etc.) for which no referendum is required",
         note_nichevote=NONE, note_optin=NONE,
         note_petition="For certain bonds (e.g., low-interest mortgage loans under s. 62.237), a petition signed by at least 15 percent of the votes cast for governor at the last general election forces a special election",
         note_votereqbyothergovtlevels="Towns must submit bond resolutions to the electors at a special election (towns vote); counties have a permissive referendum (10 percent petition) for highway/bridge bonds (Sec. 67.05(4)-(5))"),
    dict(stab="WI", state="wisconsin", pilot=1, control=1,
         source=f"Wis. Stat. {SECT} 66.0621 - revenue obligations",
         source_url="https://law.justia.com/codes/wisconsin/chapter-66/section-66-0621/",
         source_year=2025,
         source_type="primary", source_filename="WI/wisconsin_chapter-66.txt",
         bond_type="rev",
         note_vote="No referendum; a municipality provides for revenue bonds (revenue obligations) by action of its governing body (ordinance or resolution). The bonds are payable only from the utility's special redemption fund and are not an indebtedness of the municipality.",
         note_textreq="Each bond must state that it is payable only from the special redemption fund, name the authorizing ordinance/resolution, and recite that it does not constitute an indebtedness of the municipality",
         note_timing=NONE, note_pubnotice=NONE,
         note_exception="Revenue obligations are not counted toward the constitutional debt limitation; the governing body may also issue bond anticipation notes ahead of the revenue bonds (Sec. 66.0621(4)(L))",
         note_nichevote=NONE, note_optin=NONE, note_petition=NONE,
         note_votereqbyothergovtlevels="Available to cities, villages, towns, counties, and various special districts (the statutory definition of 'municipality' in Sec. 66.0621(1)(a))"),
]


def main() -> None:
    import sys
    sys.stdout.reconfigure(encoding="utf-8")
    df = pl.DataFrame(ROWS).select(COLS)

    # Guard: only the section sign (U+00A7) may appear; flag any OTHER non-ASCII
    # char (these mojibake in Excel). The section sign is permitted in the source
    # column per user instruction; the BOM write keeps it clean in Excel.
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
        for s, c, ch, h in bad[:20]:
            print(f"   {s} {c}: {ch!r} {h}")
    else:
        print("ASCII check: clean (section sign allowed in source).")

    # Write UTF-8 with BOM so Excel decodes it (and the section sign) correctly.
    OUT.write_text(df.write_csv(), encoding="utf-8-sig")
    print("Wrote", OUT, "rows:", df.height)


if __name__ == "__main__":
    main()
