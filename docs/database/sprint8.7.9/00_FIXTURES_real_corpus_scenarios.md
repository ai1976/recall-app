# Sprint 8.7.9 — real corpus fixtures for `parseRichText`/`<RichText>`

Pulled directly from the live `Integrated_Cases` tab, `Verified_Display_Case_Text`
column, 24/09/2026. Unescaped from the Drive export's markdown-safe rendering
(`\[` → `[`, `\]` → `]`, `\|` → `|` — confirmed none of these three real rows
contain a genuinely escaped literal pipe inside a cell; every `\|` here is a
real column delimiter escaped only for the export's own markdown safety, not
the corpus's own `\|`-for-literal-pipe convention). Do not re-fetch or "clean
up" these values — they are copied verbatim (after unescaping) from the
locked, QA-passed corpus and are the actual Step 0 test data for this sprint.

---

## Fixture A — `CAFA-AUD-SM2-C08-ICS01` (embedded Study Material scenario, 2 tables)

```text
Given below is an extract of abridged financial statements of schemes of “Smart Investment Mutual Fund”. The abridged financial statements have been derived from audited financial statements of the schemes of “Smart Investment Mutual Fund” as at 31St March 20XX and for year ended 31st March,20XX.

Abridged Balance sheet as at 31st March 20XX (in ₹ Lacs)

[[TABLE]]
Liabilities | Smart investment equity and debt fund | Smart investment equity savings fund
Unit Capital | 20000.00 | 15000.00
Reserve and Surplus | 160000.00 | 80000.00
Other current liabilities & provisions | 100.00 | 100.00
Total | 180100.00 | 95100.00
Assets |  | 
Investments | 170000.00 | 90000.00
Deposits | 100.00 | 100.00
Other Current assets | 10000.00 | 5000.00
Total | 180100.00 | 95100.00
[[/TABLE]]

Abridged revenue account for year ended 31st March 20XX (In ₹ Lacs)

[[TABLE]]
Income | Smart investment equity and debt fund | Smart investment equity savings fund
Income | 34000.00 | 1000.00
Expenses and losses | 3400.00 | 1500.00
Net realized gains | 30600.00 | (500.00)
Add: Change in unrealized appreciation in value of investments | 2000.00 | 700.00
Net Surplus | 32600.00 | 200.00
Dividend appropriation | 3000.00 | 50.00
Retained Surplus | 29600.00 | 150.00
[[/TABLE]]

The abridged financial statements of the Schemes of the Fund have been prepared by Board of Trustees of Fund pursuant to SEBI regulations and in accordance with format prescribed by SEBI. Previous year figures have been ignored for purpose of case.

Unmodified opinion has been expressed by auditor in audited financial statements of the schemes of “Smart Investment Mutual Fund” as at 31St March 20XX and for year ended 31st March, 20XX.
```

**Notes:** two tables, both 3 columns. One row (`Assets`) has two genuinely empty cells (`| Assets |  |  |` pattern — the header/subtotal row for the Assets section carries no numeric values) — a real edge case for the table parser: empty cells must render as empty, not collapse the row or shift columns. This is `case_study_mcq` content (an Integrated Case Scenario within SM2-C08's Study Material chapter) — its Question_Master rows are `case_study_mcq`, sharing this one scenario via `case_group`.

---

## Fixture B — `CAFA-AUD-CS-CS013` (Case Study booklet, 2 tables, real prose between and after)

```text
Simran Edible Oil Limited is a public company which has the business of manufacturing cooking oil. The company is in this particular business since last 25 years. The financial results of the company for the previous year FY 2022-23 are as under:

[[TABLE]]
Sr. No. | Particulars | Amount
1 | Aggregate Outstanding Loans, debentures and deposits | ₹ 10 crore
2 | Turnover of the company | ₹ 100 crore
3 | Paid-up capital of the company | ₹ 50 crore
4 | Net Profit (after tax) of the company | ₹ 5 crore
[[/TABLE]]

For the year 2022-23, M/s Pesh & Associates were the auditors of the Company. The auditors found significant deficiencies in internal control and misrepresentation of amounts in the area of Trade Payables. Therefore, the Auditor issued qualified Audit Report.

Next year, management did not wish to re-appoint the same auditors, hence, Board of Director recommended Ms. Mansi as the Statutory Auditor for FY 2023-24 to the members of the Company.

After the appointment, Ms. Mansi went through previous year financials statements, audit report etc. and emphasised the understatement of Trade Payable balance as a significant audit risk. The auditor set the materiality at ₹ 15,00,000 for conducting audit of the year 2023-24.

Further, Ms. Mansi is in process of selecting the samples for testing so as to get the samples on which Vendor Balance Reconciliations can be performed, she is considering the following for the same:

(i) Major Vendors where the confirmation balances agrees to General Ledger.
(ii) Vendors which have high volume of business with Simran Edible Oil Limited.
(iii) Vendors with balances of ₹ 15,00,000 or more outstanding at the year end.
(iv) Vendors with balances of ₹ 15,00,000 or less outstanding at the year-end.

As at March 31st, 2024, the balance of two vendor as per company's General Ledger and as per the balance of the External Confirmation which are received from vendors are as under:-

[[TABLE]]
Vendor Name | Balance as per General Ledger | Balance as per External Confirmation
Pakhi Groundnut Seeds Limited | ₹ 15,00,000 | ₹ 20,00,000
Krishi Sunflower Seeds Limited | ₹ 65,00,000 | ₹ 80,00,000
[[/TABLE]]

Pakhi Groundnut Seeds Ltd.: The difference in the balance is due to one of the order received by the Company. This order is under dispute as the Company claims that the received raw material is of sub-standard quality. The consignment received was sent back to the vendor on March 30, 2023.

Krishi Sunflower Seeds Ltd.: The difference in the balance is due to the reason of two invoices of ₹ 10,00,000 and ₹ 5,00,000 dated March 25, 2024 & March 27, 2024 respectively. As per the Accounts Payable Executive, both the invoices were received on April 03rd, 2024 and therefore, those were not recorded in the financial statement for the year ended March 31st, 2024.

Ms. Mansi took the samples to verify Trade payable balances, which covered 30% of population. During the Audit, she came across 2 errors amounting to ₹ 12,00,000:

• ₹ 4,00,000 was due to one invoice not being recorded due to weak inefficient control mechanism; and
• ₹ 8,00,000 error was made by Mr. Dhruv, an executive who came as a temporary replacement for one week in the place of Ms. Kamini, who is permanent accountant of the company. The mistake was clerical in nature.
```

**Notes:** two tables (3 columns each), a parenthetical roman-numeral list (`(i)`/`(ii)`/`(iii)`/`(iv)`) that must NOT be mistaken for a table by the parser (no pipes on those lines), and trailing `•` bullets after the second table — good coverage of "table detection must not over-trigger on ordinary lists."

---

## Fixture C — `CAFA-AUD-CS-CS045` (Case Study booklet, 3 tables — the stress test)

```text
CA Kunal is in the midst of conducting statutory audit for the year 2023-24 of “TSG Chemicals Limited”, a listed company. He is collecting information required for reporting under CARO, 2020 from the management. Audit procedures, as are necessary in the circumstances will be performed on the information obtained. The company’s revenue from sales of products is ₹ 15,000 crore. During this exercise, he obtained the following information:

A. The management has provided the following details of dues that have not been deposited on 31st March, 2024 on account of disputes: -

[[TABLE]]
Name of Statute | Nature of dues | Forum where the dispute is pending | Period to which the amount relates | Amount involved (₹ in crore) | Amount unpaid (₹ in crore) | Other comments
Municipal Corporation Act | Property tax | Hon’ble High Court of Rajasthan | FY 2018-19 | 0.15 | 0.15 | 
Income-tax Act, 1961 | Income-tax | CIT (Appeals) | AY 2019-20 | 50.00 | 50.00 | 
Income-tax Act, 1961 | Income-tax | ITAT | AY 2021-22 | 10.00 | 10.00 | 
EPF Act | PF contribution | Hon’ble High Court of Rajasthan | FY 2020-21 | 0.10 | 0.10 | 
[[/TABLE]]

The company has already made a provision of ₹10 crore in its financial statements considering the likely outcome of ongoing matters under dispute at ITAT. However, no provision has been made in respect of income-tax matters pending before CIT(Appeals), PF contribution matter and property tax matter pending before Hon’ble High Court.

B. The following information is available from financial statements / records of the company. (₹ in crore)

[[TABLE]]
Non-Current assets | As at 31/03/24 | As at 31/03/23
Property, Plant and Equipment | 3,500 | 4,000
Right-of-use assets | 750 | 700
Intangible assets | 42 | 40
[[/TABLE]]

Values stated above are as per gross block.

Right-of-use assets consist of leases where the company has obtained the right-of-use asset under lease agreement in accordance with Ind AS 116.

TSG Chemicals Limited produces goods for which the Central Government has specified maintenance of cost records. Besides, cost audit has also been mandated under section 148(2) of the Companies Act. The cost auditor has already examined cost records and issued the cost audit report.

During the audit, CA Kunal has found that physical verification of inventories of the company has been conducted during the year by management. The following is a summary of inventory as per physical verification conducted by management vis-à-vis its books of accounts as at the year-end:

(Amount ₹ in crores)

[[TABLE]]
Particulars | As per physical verification | As per books of accounts
Raw material | 1,160 | 1,180
Work-in-progress | 410 | 430
Finished goods | 2500 | 2790
Stores and spares | 220 | 180
Total | 4,290 | 4,580
[[/TABLE]]

During the course of audit, he is informed by management that two supervisory employees have been dismissed from service due to fraud of ₹ 47 lakh committed by them during the year 2023-24. The amount has also been subsequently recovered from them during the year itself.
```

**Notes:** three tables in one scenario — the real stress test. First table is 7 columns (the widest in the corpus) with trailing empty cells in the "Other comments" column on every data row — another real empty-cell case, this time an entire trailing column. Second and third tables are 3 columns each. Real paragraph breaks between all three tables, letter-labelled sections (`A.`/`B.`) that must not be parsed as tables.

---

## Fixture D — synthetic, escaped-pipe edge case (no real corpus example exists yet)

Not pulled from the corpus — Display Contract v1 defines `\|` as the escape for
a literal pipe inside a cell, but none of the 20 real scenario tables happens
to contain one. Needed as a fixture anyway so the parser's escape-handling is
actually exercised, not just specified. Kept clearly synthetic, never to be
confused with real corpus content:

```text
[SYNTHETIC — escape-handling test only, not real corpus content]

[[TABLE]]
Ratio | Formula
Current Ratio | Current Assets \| Current Liabilities
[[/TABLE]]
```

**Expected:** the cell renders as `Current Assets | Current Liabilities` (a
literal pipe, since that's a plausible real ratio-formula notation), not as
two separate cells.

---

## Fixture E — plain scenario, no table (regression baseline)

`CAFA-AUD-SM2-C09-ICS01`, pulled earlier in this project (24/09/2026 pre-flight)
— five-item bracketed list `[1]`...`[5]`, prose only, no `[[TABLE]]` block.
Confirms old-format scenarios still render exactly as they do today, unaffected.
Full text already on file from the earlier corpus inspection; not re-pasted
here to avoid duplication — re-fetch from that inspection if the sprint needs
it verbatim, or treat any current live `case_study_mcq` scenario with no
`[[TABLE]]` marker as an equivalent regression check.
