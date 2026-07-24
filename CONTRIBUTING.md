# Contributing to byod-databricks-onboarding-terraform

To contribute please fork the repository, push your changes to your forked version, and open a pull request between your fork and this repository.

## Forking the Repository

Fork the repository on GitHub and clone your forked repository to your local machine:

```shell
git clone https://github.com/your-github-username/byod-databricks-onboarding-terraform.git
```

## Making Changes

Make changes to the codebase and commit them to your local repository.

### Commit Message Format

This repository uses [Conventional Commits](https://www.conventionalcommits.org/) for commit messages. All commits must follow this format:

```text
<type>: <description>

[optional body]

[optional footer]
```

**Types:**

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, missing semi-colons, etc.)
- `refactor`: Code refactoring without changing functionality
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependency updates
- `ci`: CI/CD configuration changes

**Examples:**

```text
feat: add support for ip allowlisting
fix: correct grant scope for system.access
docs: update README with onboarding steps
```

Commits are validated automatically on pull requests. Non-conventional commits will cause the PR checks to fail.

## Submitting a Pull Request

Push your changes to your forked repository on GitHub and submit a pull request:

1. Navigate to your forked repository on GitHub
2. Click on the "New pull request" button
3. Select the branch containing your changes
4. Click "Create pull request"
5. Add a description of your changes and any additional context that may be helpful to the maintainers
6. Click "Create pull request" to submit your contribution
