# Run extracts of the approved TEST files (07/10/2026)

Each file below is a **verbatim, contiguous piece** of the approved TEST file named in the second column (Gate 2 and Gate 3, Round 105): from the run's `-- ===== RUN` banner line to its closing `SELECT ... AS result;` line, with nothing added, removed or reordered (a script checked that every piece occurs byte for byte in the approved file). They exist only so that a run can be copied with Ctrl+A and Ctrl+C instead of a mouse selection, which truncated T3 on its first attempt (the SQL Editor reported an unterminated dollar-quoted string because the pasted text ended in the middle of the function). The approved files themselves are unchanged. Run one extract at a time.

| Run | Approved file (short sha256) | Extract file | Extract sha256 | Lines in approved file |
|---|---|---|---|---|
| T1 | C-01_TEST v4 `bf84bea6a8e8` | `RUN_T1_from_C-01_TEST_v4.sql` | `927af522bb4f8b8ecf0b533f0b11bf59a34d5fa57a5ff32163dfcb76cf0ca242` | 44 to 97 |
| T2 | C-01_TEST v4 `bf84bea6a8e8` | `RUN_T2_from_C-01_TEST_v4.sql` | `4fe232e4f5b1a7fb616a3a7eebbfe7110aa4ac36890fd1850736c37eb28f982c` | 99 to 163 |
| T3 | C-01_TEST v4 `bf84bea6a8e8` | `RUN_T3_from_C-01_TEST_v4.sql` | `2c820e6f516ca9de0a539ce4895ba3900b20ab446738a23c9097659ae5e1292d` | 165 to 300 |
| T4 | C-01_TEST v4 `bf84bea6a8e8` | `RUN_T4_from_C-01_TEST_v4.sql` | `bfed47efc970751adbb4fa66874051940773d226ce5e610ce40b4ef22a2dcfff` | 302 to 325 |
| T5 | C-01_TEST v4 `bf84bea6a8e8` | `RUN_T5_from_C-01_TEST_v4.sql` | `1e57e3697d9d83557a65d0d1fe634a7690dcb8ace21f33fb6524a56754d11663` | 327 to 410 |
| U1 | C-02_TEST v4 `250bbba91b2b` | `RUN_U1_from_C-02_TEST_v4.sql` | `64e2fd3abb15d87071eaed87bdb98547e6e3b14815fe265ecb374e3cc686fe7e` | 45 to 82 |
| U2 | C-02_TEST v4 `250bbba91b2b` | `RUN_U2_from_C-02_TEST_v4.sql` | `8aaa63f9134a8d0f77b028bca228ae17f837a7378dd368ee069755a1a2e83370` | 84 to 128 |
| U3 | C-02_TEST v4 `250bbba91b2b` | `RUN_U3_from_C-02_TEST_v4.sql` | `508a477693bd17bc78be739bdd16570e49bc56729807888e55ef4a343c2c6146` | 130 to 305 |
| U4 | C-02_TEST v4 `250bbba91b2b` | `RUN_U4_from_C-02_TEST_v4.sql` | `a4a0d2f64df741b6b2791c1c9093433a12e6b6900c68e8ed36800e04a8151f30` | 307 to 431 |
