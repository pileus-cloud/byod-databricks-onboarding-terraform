## What does this PR do?

<!-- Describe the change and why it's needed. -->

## Type of change

- [ ] `feat` — new feature
- [ ] `fix` — bug fix
- [ ] `docs` — documentation only
- [ ] `refactor` — no functional change
- [ ] `ci` — CI/CD configuration
- [ ] `chore` — maintenance / dependency update

## How was this tested?

<!-- e.g. terraform plan output, terraform apply against a test workspace, tflint/checkov run locally -->

## Checklist

- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (see `CONTRIBUTING.md`)
- [ ] `terraform fmt` and `tflint` pass
- [ ] Checkov findings addressed or explicitly accepted (with an inline `checkov:skip=CKV_*` comment and reason)
- [ ] `TERRAFORM_DOCS.md` regenerated if inputs/outputs changed (`pre-commit run terraform_docs --all-files`)
