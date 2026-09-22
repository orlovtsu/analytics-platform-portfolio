# BI Engineering: Investigating Result Limits

This page is a general engineering discussion. It does not publish an employer patch, production setting, deployment history, or benchmark. The existing filename is retained for link compatibility.

## The engineering question

How should an engineer investigate a report or export that returns fewer records than expected? A useful starting point is to distinguish a limit on rows, output cells, query results, and export serialization. Increasing a limit without understanding its purpose can shift the problem into memory use, latency, or client rendering.

## A review approach

1. Build a minimal reproduction with synthetic records and an explicit expected result.
2. Compare the query result, displayed result, and export independently.
3. Inspect the relevant version of the BI tool's public source and documentation.
4. Vary query shape and aggregation count while keeping the input fixed.
5. Measure correctness, memory use, and latency before considering a change.
6. Preserve safeguards and define regression checks for both normal and boundary cases.

## Release considerations

For any maintained customization, review licensing, isolate the change, document its assumptions, and plan for upstream upgrades. Reproducible builds, versioned artifacts, and tested rollback procedures make a change easier to assess and maintain.

[Metabase's public repository](https://github.com/metabase/metabase) is one place to study BI query processing. Consult the license and implementation for the exact version being examined. No claim about a current upstream default or a tested production limit is made here.
