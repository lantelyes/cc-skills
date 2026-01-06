---
description: "Run OpenAI Codex CLI review against a base branch, verify findings, and summarize results"
---

# Codex Review, Verify & Summarize

Run the OpenAI Codex CLI to review the current branch against a base branch, then verify each finding and provide a summary.

## Arguments

- Base branch: $ARGUMENTS (if not provided, auto-detect by checking for "main" or "master")

## Steps

1. **Run Codex Review**
   - If no base branch argument provided, detect the default branch:
     - Run `git branch -l main master --format='%(refname:short)'` to see which exists
     - Prefer "main" if both exist
   - Execute `codex review --base <branch>` against the determined base branch
   - Capture the full output including all findings

2. **For Each Finding, Verify**
   - Read the relevant code sections mentioned in the finding
   - Trace the data flow to understand if the issue is reachable
   - Check if there are existing safeguards (validation, type constraints, etc.)
   - Determine the actual severity: Critical, High, Medium, Low, or False Positive

3. **Provide Summary Report**
   Format the results as:

   ```
   ## Codex Review Summary

   **Branch:** <current-branch>
   **Base:** <base-branch>
   **Findings:** <count>

   ### Verified Findings

   For each finding:
   - **[Severity] Title** (file:lines)
     - Codex said: <brief summary>
     - Verification: <your analysis>
     - Recommendation: <actionable next step>

   ### False Positives / Low Risk

   List any findings that were determined to be false positives or acceptably low risk after verification, with reasoning.

   ### Overall Assessment

   Brief summary of whether the PR is safe to merge and any blocking issues.
   ```

## Notes

- Focus verification on security issues, correctness bugs, and performance regressions
- For security findings, trace the data flow from user input to the vulnerable code
- Consider the context of the codebase (internal APIs vs public endpoints, etc.)
