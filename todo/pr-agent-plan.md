# Plan: Add PR-Agent to infra-local-dev-env

## Context
Add Qodo's PR-Agent to the `infra-local-dev-env` repository (`KaizenXIII/infra-local-dev-env`) using a GitHub Action workflow. PR-Agent will use **Claude (Anthropic)** as the LLM and auto-run **review + describe** on new PRs. The project currently has no GitHub Actions workflows.

## Steps

### 1. Create GitHub Actions workflow directory and file
- Create `.github/workflows/pr_agent.yml` in the repo root
- Workflow triggers on `pull_request` events (opened, reopened, ready_for_review)
- Uses the `qodo-ai/pr-agent` Docker action
- Configures Claude as the LLM provider
- Runs `/describe` and `/review` commands automatically

**Workflow file contents:**
```yaml
name: PR Agent

on:
  pull_request:
    types: [opened, reopened, ready_for_review]

jobs:
  pr_agent:
    runs-on: ubuntu-latest
    name: PR Agent
    if: ${{ github.event.pull_request.draft == false }}
    permissions:
      issues: write
      pull-requests: write
      contents: read
    steps:
      - name: PR Describe
        uses: qodo-ai/pr-agent@main
        with:
          command: describe
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          config.model: "anthropic/claude-sonnet-4-6"

      - name: PR Review
        uses: qodo-ai/pr-agent@main
        with:
          command: review
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          config.model: "anthropic/claude-sonnet-4-6"
```

### 2. (Optional) Add per-repo config file
- Create `.pr_agent.toml` in the repo root for custom settings (review depth, ignored paths, etc.)

### 3. Add Anthropic API key as GitHub secret
- Manually add `ANTHROPIC_API_KEY` as a repository secret at:
  `https://github.com/KaizenXIII/infra-local-dev-env/settings/secrets/actions`
- `GITHUB_TOKEN` is provided automatically by GitHub Actions

## Files to create
- `.github/workflows/pr_agent.yml`
- `.pr_agent.toml` (optional)

## Verification
1. Commit and push the workflow file to the repo
2. Add `ANTHROPIC_API_KEY` secret in GitHub repo settings
3. Open a test PR -- PR-Agent should automatically comment with a description and review
4. Verify you can also use `/improve` and `/ask` commands manually in PR comments
