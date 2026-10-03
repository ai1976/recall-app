# Evidence folder

Raw results of read-only database checks and other evidence cited by discussion threads.

- Name files `T-NNN_<what>_<dd-mm-yyyy>.md` (or `.csv`), for example `T-001_step0_results_03-10-2026.md`.
- Start each file with: environment (production), execution date, and which numbered blocks of the SQL file were run.
- **Counts-only results** (no names, emails or IDs) go directly in this folder.
- **Anything containing personal data** goes in `raw/` (git-ignored), and only a sanitized summary is saved here.
- The Founder may paste results into the Claude chat; Claude saves them here and cites the file in the thread.
