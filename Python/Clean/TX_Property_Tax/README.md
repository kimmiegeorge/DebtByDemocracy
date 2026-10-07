# Texas Comptroller city property-tax rates

This self-contained pipeline downloads and harmonizes the Texas Comptroller's
annual **City Rates and Levies** workbooks.  The resulting measure is the
city government's total property-tax rate (M&O plus I&S), expressed in dollars
per $100 of taxable value.  It is not a household's total tax bill across a
city, school district, county, and special districts.

The current Comptroller page links directly to 2021 onward.  Older files
remain official Comptroller workbooks but are no longer linked there, so the
script obtains their preserved copies through the Internet Archive's index.
Each output retains its source URL and the access route.

Run from the repository root:

```sh
python3 Code/Python/Clean/TX_Property_Tax/pull_merge_analyze_tx_property_tax.py
```

Raw workbooks are cached in `Data/TX/Property Tax/raw/`.  The main derived
outputs are:

* `Data/TX/Property Tax/tx_city_property_tax_rates_2011_2025.csv`
* `Data/TX/Property Tax/tx_website_disclosure_with_property_tax.csv`
* `Results/TX Property Tax Rejection Risk/tx_property_tax_disclosure_models.csv`
* `Results/TX Property Tax Rejection Risk/tx_property_tax_disclosure_summary.md`

For the disclosure test, the tax-rate moderator is the tax rate in the prior
calendar year.  That conservative timing prevents the contemporaneous,
election-year rate from being treated as predetermined.  The regression is a
city- and year-fixed-effects linear probability model of an increase in a
city website's bond-text count, with county-clustered standard errors.
