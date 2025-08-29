#!/bin/bash
# Script to commit each GitHub Actions workflow atomically

cd /Users/chris/Dropbox/dev/ai/claude-code-cfg/mcp/workspace-qdrant-mcp

# Commit main CI/CD pipeline
git add .github/workflows/ci.yml
git commit -m "feat: Add comprehensive CI/CD pipeline with evidence-based quality gates

- Multi-Python version testing (3.8-3.12)
- Evidence-based thresholds from 21,930-query benchmark
- Symbol Search: ≥90% precision/recall (measured: 100%)
- Exact Search: ≥90% precision/recall (measured: 100%)  
- Semantic Search: ≥84% precision, ≥70% recall (measured: 94.2%/78.3%)
- Comprehensive test suite with coverage reporting
- Security scanning with bandit and safety
- Build and package validation
- Console script testing
- Automatic PyPI publishing on releases"

# Commit quality assurance workflow
git add .github/workflows/quality.yml
git commit -m "feat: Add quality assurance workflow

- Comprehensive code quality analysis with ruff and mypy
- Security scanning with bandit, safety, and dependency audits
- Performance monitoring with benchmark execution
- Documentation quality checks
- Automated PR comments with quality reports
- Daily scheduled quality assessments"

# Commit performance benchmark workflow
git add .github/workflows/benchmark.yml  
git commit -m "feat: Add performance benchmark workflow

- Simple benchmark validation for quick feedback
- Comprehensive benchmarks with Qdrant integration
- Large-scale benchmarks (21,930-query equivalent)
- Evidence-based threshold validation
- Performance trend monitoring
- Memory profiling and resource monitoring
- Automated benchmark result comparisons"

# Commit release automation workflow
git add .github/workflows/release.yml
git commit -m "feat: Add release automation workflow

- Semantic version validation
- Multi-version compatibility testing
- Performance validation before release
- Automated GitHub release creation with rich notes
- PyPI publishing for stable releases
- Test PyPI publishing for prereleases
- Post-release version bumping
- Comprehensive release readiness validation"

# Commit security scanning workflow
git add .github/workflows/security.yml
git commit -m "feat: Add comprehensive security scanning workflow

- Static security analysis with Bandit and Semgrep
- Dependency vulnerability scanning with Safety and pip-audit
- Secrets detection with TruffleHog and Gitleaks
- Code quality security checks
- Daily security monitoring
- Automated security report generation
- PR security summaries"

# Commit Dependabot configuration
git add .github/dependabot.yml
git commit -m "feat: Add Dependabot configuration for automated dependency updates

- Daily Python dependency updates grouped by type
- Weekly GitHub Actions updates
- Security-focused update prioritization
- Automated merging for patch and security updates
- Comprehensive dependency management"

# Commit documentation
git add .github/README.md
git commit -m "docs: Add comprehensive CI/CD pipeline documentation

- Complete workflow documentation with evidence-based thresholds
- Troubleshooting guides and maintenance procedures
- Performance optimization strategies
- Security features and monitoring setup
- Artifact and reporting documentation"

echo "✅ All GitHub Actions workflows committed atomically"