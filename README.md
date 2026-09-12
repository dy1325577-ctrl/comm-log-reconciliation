
# Comm-Log Send Reconciliation

## Problem

Finance's `target_base` metric for merchant 501, Diwali campaigns, October 2026 is reported as **22**.
This repo reproduces that number from raw data and documents the gap between it and a naive query.

## Reconciliation Bridge

| Step  | Description                                                                                                          | Result | Reason                                                                                                     |
|-------|-----------------------------------------------------------------------------------------------------------------------|--------|--------------------------------------------------------------------------------------------------------------|
| 0     | Naive count — all `communication_log` rows for merchant 501, Oct 2026, `communication_type = '2'`                    | 30     | Starting point; treats every row as an equally valid qualifying send                                        |
| 1     | Excluded campaign 9004 (`creation_status = 'approval_awaiting'`)                                                      | 26     | The send pipeline had already run for this campaign, but it hadn't cleared approval — not yet reportable    |
| 2     | Deduped repeated customer attempts *within* retry chains (9001→9002→9003 and 9201→9202); did **not** dedupe the standalone campaign (9101), where a repeated customer is a legitimate separate re-targeting event | 22     | A customer retried multiple times within one underlying communication should count once, not once per attempt |
| final |                                                                                                                       | **22** |                                                                                                                |

### Per-family breakdown (for reference)

| Root campaign | Family size | Qualifying sends |
|---|---|---|
| 9001 (retry chain: 9001→9002→9003) | 3 | 10 (distinct customers) |
| 9101 (standalone) | 1 | 7 (every send counted) |
| 9201 (retry chain: 9201→9202) | 2 | 5 (distinct customers) |
| **Total** | | **22** |

## How to run

```bash
sqlite3 data/comm_log.db < reconciliation.sql
```

Or with Python:
```python
import sqlite3
conn = sqlite3.connect("data/comm_log.db")
print(conn.execute(open("reconciliation.sql").read()).fetchone())
```

## Data

- `data/comm_log.db` — SQLite database (recommended)
- `data/campaign.csv`, `data/communication_log.csv` — same data as CSVs

## Surprises

[The surprising thing was that a repeated customer entry could mean two different things depending on the situation. For a standalone campaign when the same customer appeared twice that was a separate re-targeting event.. For a retry chain that same customer was simply being tried again and should only be counted once. I also did not expect to see communication_log rows that were already created for a campaign that had not yet cleared approval (creation_status = 'approval_awaiting'). The send pipeline had moved ahead of the approval workflow. A simple query would not have caught that without checking the campaign table. Finally retry chains were not always one step. One retry chain went three levels deep so a simple parent-child join was not enough. I had to walk the chain all the way to its root.]

