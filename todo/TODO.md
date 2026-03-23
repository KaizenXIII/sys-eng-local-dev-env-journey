# TODO: PR-Agent Integration

## Tasks

- [ ] Create `.github/workflows/pr_agent.yml` workflow file
- [ ] Add `ANTHROPIC_API_KEY` as a GitHub repository secret
- [ ] (Optional) Create `.pr_agent.toml` for custom PR-Agent configuration
- [ ] Commit and push workflow to repo
- [ ] Open a test PR to verify PR-Agent runs automatically
- [ ] Confirm `/describe` generates a PR description
- [ ] Confirm `/review` posts a code review comment
- [ ] Test manual commands (`/improve`, `/ask`) in a PR comment

## Reference
- [Plan details](./pr-agent-plan.md)
- [PR-Agent docs](https://github.com/qodo-ai/pr-agent)
