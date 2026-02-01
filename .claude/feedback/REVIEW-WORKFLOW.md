# Weekly Feedback Review Workflow

This document outlines the process for reviewing feedback entries and improving skills/agents.

## Schedule

- **When**: Weekly 
- **Duration**: 15-30 minutes
- **Trigger**: `claude "Run weekly feedback review"`

## Pre-Review: Generate Summary

Run this command to generate a weekly summary:

```bash
claude "Generate weekly feedback summary for the past 7 days"
```

The summary should include:
- Total executions by agent/skill
- Success/failure rates
- Common error types
- Protocols worked on
- Patterns detected

## Review Checklist

### 1. Review Failed Executions

For each failed execution:
- [ ] What was the root cause?
- [ ] Was it a known pattern? (check error-patterns.md)
- [ ] If new pattern, add to pattern library
- [ ] Could it have been prevented with better guidance?

### 2. Identify Patterns

Look for patterns appearing 3+ times:
- [ ] Same error type across protocols
- [ ] Same fix applied multiple times
- [ ] Similar data source issues
- [ ] Common calculation mistakes

For each pattern:
- [ ] Is it documented in patterns/?
- [ ] Should a skill be updated?
- [ ] Should the verify hook catch this?

### 3. Review Partial Successes

For partial successes:
- [ ] What caused incompleteness?
- [ ] Are there missing steps in skills?
- [ ] Was the protocol category correctly identified?

### 4. Assess Skill Gaps

Look for:
- [ ] Cases where skill guidance was missing
- [ ] Protocols that didn't fit existing categories
- [ ] Data sources not covered in skills
- [ ] Edge cases not documented

### 5. Prioritize Improvements

Create improvement tasks ranked by:
1. Frequency (how often the issue occurs)
2. Impact (how much time it wastes)
3. Ease of fix (quick wins first)

## Improvement Actions

### Update Pattern Library

Add new patterns to:
- `.claude/feedback/patterns/error-patterns.md`
- `.claude/feedback/patterns/data-source-patterns.md`

Format:
```markdown
### ERR-XXX-NNN: Pattern Name
**Error**: Error message
**Cause**: What causes this
**Fix**: How to resolve
**Affected**: Which agents/skills
```

### Update Skills

For skill improvements:
1. Identify the specific skill file
2. Add guidance to prevent the issue
3. Add example if helpful
4. Update related error-reference.md

### Update Agents

For agent improvements:
1. Add pre-checks for known patterns
2. Update workflow steps if needed
3. Add links to pattern documentation

### Update Verify Hook

For issues that should be caught automatically:
1. Edit `.claude/hooks/verify-adapter-output.sh`
2. Add new validation check
3. Test with known failing cases

## Post-Review: Archive

After review:
1. Create weekly summary in `.claude/feedback/weekly/YYYY-W{nn}-summary.md`
2. Archive processed entries (keep for reference)
3. Update SKILL-LOG.md with key learnings

## Weekly Summary Template

```markdown
# Week {N} Feedback Summary ({date range})

## Overview
- **Total Executions**: {n}
- **Success Rate**: {pct}%
- **Protocols Covered**: {list}

## By Agent/Skill
| Agent/Skill | Executions | Success | Partial | Failed |
|-------------|------------|---------|---------|--------|
| build-adapter | n | n | n | n |
| fix-adapter | n | n | n | n |
| ... | | | | |

## Common Issues
1. **{Issue}** - {count} occurrences
   - Root cause: {description}
   - Action taken: {what was done}

## Patterns Added
- {New patterns added to library}

## Skill Updates
- {Changes made to skills}

## Carry-Forward
- {Issues not yet resolved}
```

## Automation Opportunities

Consider automating:
- [ ] Feedback entry creation (via hooks)
- [ ] Weekly summary generation
- [ ] Pattern frequency counting
- [ ] Staleness alerts for pattern library

## Feedback Loop Metrics

Track over time:
- Success rate trend
- Time to resolve issues
- Pattern recurrence (should decrease)
- Skill coverage gaps
