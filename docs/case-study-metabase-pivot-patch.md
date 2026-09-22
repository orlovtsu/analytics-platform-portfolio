# Case Study: Fixing Metabase's Pivot-Table Row Cap

## The problem

Analysts were exporting pivot tables with several metric columns (e.g. a pivot with three aggregations) and consistently getting truncated results — far fewer rows than the data actually contained, with no error or warning in the UI.

## Root cause

Metabase's pivot query processor caps the number of rows a pivot sub-query can return, then **divides that cap by the number of aggregation columns** in the query, on the theory that more aggregation columns means more output cells per row so a lower row cap keeps total cell volume bounded:

```clojure
;; metabase/src/metabase/query_processor/pivot.clj (upstream)
(def ^:dynamic ^:private *pivot-max-result-rows*
  "Maximum number of result rows for each pivot sub-query. Divided by the number of aggregations since each aggregation
  adds a column to the output, so fewer rows are needed to fill the pivot table."
  200000)

(defn- pivot-query-max-rows
  "Calculate the per-sub-query row limit for pivot queries: `floor(pivot-max-result-rows / num-aggregations)`.
  Falls back to `pivot-max-result-rows` if there are no aggregations (shouldn't happen for pivot queries)."
  [query]
  (let [num-aggs (count (lib/aggregations query))]
    (if (pos? num-aggs)
      (quot *pivot-max-result-rows* num-aggs)
      *pivot-max-result-rows*)))
```

In practice, this meant a pivot with 3 aggregation columns silently capped at ~66,000 rows instead of 200,000 — with the division being invisible to the end user, who just sees a truncated export and no indication why.

## The fix

I patched `pivot-query-max-rows` to stop dividing by aggregation count, and raised the base cap from 200,000 to 250,000 rows (validated against realistic query shapes and export times before settling on that number — an earlier experiment at 1,000,000 rows was tested and rejected as unstable/too slow for interactive use):

```diff
 (def ^:dynamic ^:private *pivot-max-result-rows*
-  "Maximum number of result rows for each pivot sub-query. Divided by the number of aggregations since each aggregation
-  adds a column to the output, so fewer rows are needed to fill the pivot table."
-  200000)
+  "Maximum number of result rows for each pivot table."
+  250000)

 (defn- pivot-query-max-rows
-  "Calculate the per-sub-query row limit for pivot queries: `floor(pivot-max-result-rows / num-aggregations)`.
-  Falls back to `pivot-max-result-rows` if there are no aggregations (shouldn't happen for pivot queries)."
-  [query]
-  (let [num-aggs (count (lib/aggregations query))]
-    (if (pos? num-aggs)
-      (quot *pivot-max-result-rows* num-aggs)
-      *pivot-max-result-rows*)))
+  "Maximum number of result rows for each pivot table."
+  [_query]
+  *pivot-max-result-rows*)
```

## Getting it to production safely

Since Metabase Cloud/Enterprise wasn't an option here, "patch and redeploy" meant a full from-source build:

1. **Built from source** — Metabase is a Clojure/ClojureScript backend + React frontend; the build pipeline needs JDK, the Clojure CLI, Node and Bun. A multi-stage Dockerfile handles this: stage 1 compiles the uberjar with `bin/build.sh`, stage 2 copies just the jar into a slim `eclipse-temurin-jre-alpine` runtime image (plus the CA certificate bundles the runtime needs for outbound TLS).
2. **Versioned images, not in-place upgrades** — every build got its own tagged image (`...-pivot1m` for the rejected 1M-row experiment, `...-pivot250k-fixed` for the version that shipped), and prior working images were kept running/available rather than deleted, so a bad build is a one-command rollback, not an incident.
3. **Scheduled backups** of Metabase's application database before each cutover, so dashboards/questions/permissions metadata could be restored independently of the Docker image itself.

## Why this is worth doing in-house

Upgrading to a paid tier or switching BI tools would have "solved" this too, but the actual defect was a five-line, well-isolated calculation in an open-source codebase. Reading the query processor, understanding *why* the limit existed (it's a reasonable safeguard, just miscalibrated for this workload), and shipping a minimal, explainable patch was faster and cheaper than a tooling migration — and it's the kind of fix that's easy to justify to a non-technical stakeholder ("we found the exact line capping your export and fixed the math").

---

*The Metabase source excerpts above are from the [Metabase open-source project](https://github.com/metabase/metabase), licensed AGPL-3.0, reproduced here for commentary/documentation purposes only. No proprietary code is included.*
