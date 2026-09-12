-- Comm-Log Send Reconciliation
-- Computes target_base for merchant 501, Diwali campaigns, October 2026.
-- Expected result: 22

WITH RECURSIVE roots AS (
    -- Walk every campaign up to its ultimate root (top of its retry chain, if any)
    SELECT id, id AS root_id FROM campaign WHERE parent_id IS NULL
    UNION ALL
    SELECT c.id, r.root_id
    FROM campaign c
    JOIN roots r ON c.parent_id = r.id
),
family_sizes AS (
    -- How many campaigns sit under each root (1 = standalone, >1 = has retries)
    SELECT root_id, COUNT(*) AS family_size
    FROM roots
    GROUP BY root_id
),
eligible AS (
    -- Only campaigns whose approval AND processing have finalized count for reporting
    SELECT id FROM campaign
    WHERE merchant_id = 501
      AND creation_status IN ('approved', 'aborted', 'resumed', 'stopped')
      AND processing_status = 'processed'
),
scoped_logs AS (
    SELECT cl.*, r.root_id, fs.family_size
    FROM communication_log cl
    JOIN eligible e ON cl.communication_id = e.id
    JOIN roots r ON r.id = cl.communication_id
    JOIN family_sizes fs ON fs.root_id = r.root_id
    WHERE cl.merchant_id = 501
      AND cl.communication_type = '2'
      AND cl.sent_time BETWEEN '2026-10-01' AND '2026-10-31 23:59:59'
)
SELECT SUM(cnt) AS target_base
FROM (
    SELECT root_id,
           CASE WHEN family_size = 1 THEN COUNT(*)                  -- standalone: every send is its own event
                ELSE COUNT(DISTINCT customer_id)                    -- retry chain: dedupe to distinct customers reached
           END AS cnt
    FROM scoped_logs
    GROUP BY root_id, family_size
);
