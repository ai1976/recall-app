import { describe, it, expect } from 'vitest';
import { parseRichText } from './parseRichText';

// Fixtures A/B/C are copied verbatim from
// docs/database/sprint8.7.9/00_FIXTURES_real_corpus_scenarios.md (real,
// QA-locked corpus content). Fixture D is explicitly synthetic (escaped-pipe
// parser exercise only). Fixture E is a plain regression baseline.

const FIXTURE_A = `Given below is an extract of abridged financial statements of schemes of “Smart Investment Mutual Fund”. The abridged financial statements have been derived from audited financial statements of the schemes of “Smart Investment Mutual Fund” as at 31St March 20XX and for year ended 31st March,20XX.

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

Unmodified opinion has been expressed by auditor in audited financial statements of the schemes of “Smart Investment Mutual Fund” as at 31St March 20XX and for year ended 31st March, 20XX.`;

const FIXTURE_B = `Simran Edible Oil Limited is a public company which has the business of manufacturing cooking oil. The company is in this particular business since last 25 years. The financial results of the company for the previous year FY 2022-23 are as under:

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
• ₹ 8,00,000 error was made by Mr. Dhruv, an executive who came as a temporary replacement for one week in the place of Ms. Kamini, who is permanent accountant of the company. The mistake was clerical in nature.`;

const FIXTURE_C = `CA Kunal is in the midst of conducting statutory audit for the year 2023-24 of “TSG Chemicals Limited”, a listed company. He is collecting information required for reporting under CARO, 2020 from the management. Audit procedures, as are necessary in the circumstances will be performed on the information obtained. The company’s revenue from sales of products is ₹ 15,000 crore. During this exercise, he obtained the following information:

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

During the course of audit, he is informed by management that two supervisory employees have been dismissed from service due to fraud of ₹ 47 lakh committed by them during the year 2023-24. The amount has also been subsequently recovered from them during the year itself.`;

const FIXTURE_D = `[SYNTHETIC — escape-handling test only, not real corpus content]

[[TABLE]]
Ratio | Formula
Current Ratio | Current Assets \\| Current Liabilities
[[/TABLE]]`;

const FIXTURE_E = `Confirms old-format scenarios still render exactly as they do today, unaffected.
[1] first item
[2] second item
[3] third item
[4] fourth item
[5] fifth item`;

describe('parseRichText', () => {
  it('Fixture A: parses two tables correctly with genuinely empty cells preserved', () => {
    const blocks = parseRichText(FIXTURE_A);
    const tables = blocks.filter((b) => b.type === 'table');
    expect(tables).toHaveLength(2);

    expect(tables[0].headers).toEqual([
      'Liabilities',
      'Smart investment equity and debt fund',
      'Smart investment equity savings fund',
    ]);
    expect(tables[0].rows).toHaveLength(9);
    // "Assets |  | " row — two genuinely empty cells, not collapsed/shifted
    const assetsRow = tables[0].rows.find((r) => r[0] === 'Assets');
    expect(assetsRow).toEqual(['Assets', '', '']);

    expect(tables[1].headers[0]).toBe('Income');
    expect(tables[1].rows).toHaveLength(7);
  });

  it('Fixture B: roman-numeral list and bullets remain paragraph content, not tables', () => {
    const blocks = parseRichText(FIXTURE_B);
    const tables = blocks.filter((b) => b.type === 'table');
    expect(tables).toHaveLength(2);

    const paragraphs = blocks.filter((b) => b.type === 'paragraph');
    const fullParagraphText = paragraphs.map((p) => p.text).join('\n');
    expect(fullParagraphText).toContain('(i) Major Vendors');
    expect(fullParagraphText).toContain('(iv) Vendors with balances');
    expect(fullParagraphText).toContain('• ₹ 4,00,000 was due to one invoice');
    expect(fullParagraphText).toContain('• ₹ 8,00,000 error was made by Mr. Dhruv');
  });

  it('Fixture C: parses all three tables in order and retains the 7th empty trailing column', () => {
    const blocks = parseRichText(FIXTURE_C);
    const tables = blocks.filter((b) => b.type === 'table');
    expect(tables).toHaveLength(3);

    expect(tables[0].headers).toHaveLength(7);
    for (const row of tables[0].rows) {
      expect(row).toHaveLength(7);
      expect(row[6]).toBe(''); // "Other comments" column is empty on every data row
    }

    expect(tables[1].headers).toEqual(['Non-Current assets', 'As at 31/03/24', 'As at 31/03/23']);
    expect(tables[2].headers).toEqual(['Particulars', 'As per physical verification', 'As per books of accounts']);
  });

  it('Fixture D: escaped pipe produces a single cell containing the literal |', () => {
    const blocks = parseRichText(FIXTURE_D);
    const table = blocks.find((b) => b.type === 'table');
    expect(table).toBeDefined();
    expect(table.rows[0]).toEqual(['Current Ratio', 'Current Assets | Current Liabilities']);
  });

  it('Fixture E: plain text with no table markers remains exact single paragraph', () => {
    const blocks = parseRichText(FIXTURE_E);
    expect(blocks).toEqual([{ type: 'paragraph', text: FIXTURE_E }]);
  });

  it('unclosed [[TABLE]] falls back to the entire original text', () => {
    const text = 'Some prose\n\n[[TABLE]]\nA | B\n1 | 2';
    expect(parseRichText(text)).toEqual([{ type: 'paragraph', text }]);
  });

  it('orphan [[/TABLE]] falls back to the entire original text', () => {
    const text = 'Some prose\n[[/TABLE]]\nmore prose';
    expect(parseRichText(text)).toEqual([{ type: 'paragraph', text }]);
  });

  it('nested opening markers fall back to the entire original text', () => {
    const text = '[[TABLE]]\nA | B\n[[TABLE]]\nC | D\n[[/TABLE]]\n[[/TABLE]]';
    expect(parseRichText(text)).toEqual([{ type: 'paragraph', text }]);
  });

  it('multiple valid table blocks retain source order', () => {
    const text = 'intro\n[[TABLE]]\nA | B\n1 | 2\n[[/TABLE]]\nmiddle\n[[TABLE]]\nC | D\n3 | 4\n[[/TABLE]]\nend';
    const blocks = parseRichText(text);
    expect(blocks.map((b) => b.type)).toEqual(['paragraph', 'table', 'paragraph', 'table', 'paragraph']);
    expect(blocks[1].headers).toEqual(['A', 'B']);
    expect(blocks[3].headers).toEqual(['C', 'D']);
  });

  it('CRLF input behaves equivalently to LF input', () => {
    const lf = 'intro\n[[TABLE]]\nA | B\n1 | 2\n[[/TABLE]]\nend';
    const crlf = lf.replace(/\n/g, '\r\n');
    const blocksLf = parseRichText(lf);
    const blocksCrlf = parseRichText(crlf);
    expect(blocksCrlf.map((b) => b.type)).toEqual(blocksLf.map((b) => b.type));
    const tableLf = blocksLf.find((b) => b.type === 'table');
    const tableCrlf = blocksCrlf.find((b) => b.type === 'table');
    expect(tableCrlf.headers).toEqual(tableLf.headers);
    expect(tableCrlf.rows).toEqual(tableLf.rows);
  });

  it('plain text containing a normal | outside table markers is never treated as a table', () => {
    const text = 'Current Ratio = Current Assets | Current Liabilities, a liquidity measure.';
    expect(parseRichText(text)).toEqual([{ type: 'paragraph', text }]);
  });

  it('a marker-like substring embedded in prose is not detected as a marker', () => {
    const text = 'The tag [[TABLE]] appears mid-sentence here, not on its own line.';
    // trimmed line IS exactly "[[TABLE]]"? No — the whole line is prose containing it, so this is a single unclosed-looking non-marker line.
    expect(parseRichText(text)).toEqual([{ type: 'paragraph', text }]);
  });
});
