# GitHub Actions Workflows

This directory contains the CI/CD workflows for TheBoosh.Zone. This document explains the workflow architecture, test execution strategy, and when each workflow runs.

## Workflow Architecture

### Workflow Relationships

```
┌─────────────┐
│  test.yml   │◄─────────────┐
└─────────────┘              │
       ▲                     │
       │ (called by)         │ (called by)
       │                     │
┌─────────────┐         ┌────┴──────────┐
│   ci.yml    │◄────────│ deploy-*.yml  │
└─────────────┘         └───────────────┘
```

### Workflow Files

1. **`test.yml`** - Test execution (reusable workflow)
2. **`ci.yml`** - Main CI pipeline (build and push)
3. **`deploy-staging.yml`** - Staging deployment
4. **`deploy-production.yml`** - Production deployment
5. **`claude.yml`** - Claude AI code assistance
6. **`claude-code-review.yml`** - Automated code reviews

## Test Execution Strategy

### Goals

1. **Fast feedback** on all pull requests (including feature branches)
2. **No duplicate test runs** - tests should run exactly once per event
3. **Always test before deployment** - deployments must run tests
4. **Efficient CI** - Skip redundant work when tests already ran

### Test Execution Matrix

| Event Type | test.yml Runs? | ci.yml Calls test.yml? | Result |
|------------|----------------|------------------------|---------|
| Push to `dev` or `main` | ✓ Direct trigger | ✗ Skipped (redundant) | 1 test run |
| PR to `dev` or `main` | ✓ Direct trigger | ✗ Skipped (redundant) | 1 test run |
| PR to feature branch | ✓ Direct trigger | - Not triggered | 1 test run |
| Manual deployment | - | ✓ Via workflow_call | 1 test run |
| Manual build trigger | - | ✓ Direct trigger | 1 test run |

### Why This Design?

**Problem:** Without deduplication, tests would run twice:
- Event triggers `test.yml` directly (push/PR)
- Event also triggers `ci.yml`, which calls `test.yml` again

**Solution:** Conditional test execution in `ci.yml`
```yaml
# ci.yml line 30-32
test:
  name: Run Tests
  if: github.event_name == 'workflow_call' || github.event_name == 'workflow_dispatch'
  uses: ./.github/workflows/test.yml
```

**Logic:**
- **Skip tests** when ci.yml is triggered by push/PR (tests already ran directly)
- **Run tests** when ci.yml is called by deployment workflows (workflow_call)
- **Run tests** when ci.yml is manually triggered (workflow_dispatch)

## Workflow Details

### test.yml

**Purpose:** Run backend (Perl) and frontend (Vue/Vitest) tests

**Triggers:**
- Push to `dev` or `main` branches
- Pull requests to `dev` or `main` branches  
- Called by other workflows (`workflow_call`)

**Jobs:**
- `backend-tests` - Perl tests with Docker Compose
- `frontend-tests` - Vue/Vitest tests with coverage

**Outputs:** None

**Usage:** Provides fast feedback on all code changes

---

### ci.yml

**Purpose:** Main CI pipeline - test, build, and push Docker images

**Triggers:**
- Push to `dev` or `main` branches
- Pull requests to `dev` or `main` branches
- Version tags (`v*`)
- Manual trigger (`workflow_dispatch`)
- Called by deployment workflows (`workflow_call`)

**Jobs:**
1. `test` - Conditionally run tests (see Test Execution Strategy)
2. `build-and-push` - Build Docker image and push to DigitalOcean Container Registry

**Environment Detection:**
- PRs use target branch (`github.base_ref`) to determine environment
- Push events use current branch (`github.ref`)
- Maps to build environments:
  - `main` or tags → `BUILD_ENV=prod` (runs `npm run build:prod`)
  - `dev` → `BUILD_ENV=staging` (runs `npm run build:staging`)
  - Other branches → `BUILD_ENV=dev` (runs `npm run build:dev`)

**Push Behavior:**
- **PRs:** Build image but DON'T push to registry (validation only)
- **Push events:** Build image AND push to registry
- **Manual:** Build image AND push to registry

**Outputs:**
- `image_tags` - Docker image tags that were built
- `image_digest` - Docker image digest (SHA256)
- `build_env` - Build environment used (prod/staging/dev)

---

### deploy-staging.yml

**Purpose:** Deploy to staging environment (https://staging.theboosh.zone)

**Triggers:**
- Manual only (`workflow_dispatch`)
- *Note: Can be enabled for automatic deployment on push to `dev`*

**Jobs:**
1. `build` - Calls `ci.yml` (which runs tests and builds)
2. `deploy` - SSH to server, pull image, deploy, health check

**Environment:** `staging`

**Security:**
- Uses base64-encoded Docker credentials for safe transport
- Credentials automatically cleaned up via bash `trap` (even on failure)
- Registry URL uses environment variable for consistency

---

### deploy-production.yml

**Purpose:** Deploy to production environment (https://theboosh.zone)

**Triggers:**
- Manual only (`workflow_dispatch`)
- *Note: Can be enabled for automatic deployment on push to `main` or tags*

**Jobs:**
1. `build` - Calls `ci.yml` (which runs tests and builds)
2. `deploy` - SSH to server, backup, deploy with rollback on failure

**Environment:** `production` (requires manual approval in GitHub)

**Security:**
- Same credential handling as staging
- Creates database backup before deployment
- Automatic rollback if health check fails

**Additional Features:**
- Creates GitHub Release for version tags (`v*`)
- Extended health check timeout (15s vs 10s)

---

### claude.yml

**Purpose:** Claude AI assistance via comments

**Triggers:**
- Issue comments containing `@claude`
- PR review comments containing `@claude`
- PR reviews containing `@claude`
- New issues containing `@claude`

**Permissions:**
- `contents: read`
- `pull-requests: read`
- `issues: read`
- `id-token: write`
- `actions: read` (for reading CI results)

---

### claude-code-review.yml

**Purpose:** Automated code review using Claude AI

**Triggers:**
- PR opened
- PR synchronized (new commits)

**Permissions:**
- `contents: read`
- `pull-requests: read`
- `issues: read`
- `id-token: write`

**Note:** Can be filtered by PR author or file paths

## Best Practices

### Adding New Workflows

1. **Document purpose** - Add header comment explaining what it does
2. **Specify permissions** - Use least-privilege principle
3. **Consider reusability** - Use `workflow_call` if other workflows might need it
4. **Add outputs** - If other workflows need information from this one
5. **Update this README** - Document the new workflow

### Modifying Existing Workflows

1. **Consider dependencies** - Check if other workflows call this one
2. **Test locally** - Use `act` to test changes locally when possible
3. **Check permissions** - Ensure sufficient permissions for new features
4. **Update documentation** - Keep this README in sync with changes

### Debugging Workflows

1. **Check workflow runs** - GitHub Actions tab shows all runs
2. **Review logs** - Click into failed jobs to see detailed logs
3. **Test job conditions** - Verify `if:` expressions evaluate correctly
4. **Check secrets** - Ensure required secrets are set in repository settings
5. **Validate YAML** - Use `yamllint` or online validators

## Environment Variables

### ci.yml
- `REGISTRY` - Container registry URL (registry.digitalocean.com)
- `DO_REGISTRY_NAME` - Registry name (from secrets)
- `IMAGE_NAME` - Docker image name (theboosh-zone)

### Deployment Workflows
- `DOCKER_CONFIG_B64` - Base64-encoded Docker credentials
- `DO_REGISTRY_NAME` - Registry name (from secrets)
- `REGISTRY` - Container registry URL (registry.digitalocean.com)

## Secrets Required

### Container Registry
- `DIGITALOCEAN_ACCESS_TOKEN` - DigitalOcean API token
- `DO_REGISTRY_NAME` - DigitalOcean registry name

### Deployment
- `STAGING_HOST` - Staging server hostname/IP
- `STAGING_USER` - SSH username for staging
- `STAGING_SSH_KEY` - SSH private key for staging
- `PRODUCTION_HOST` - Production server hostname/IP
- `PRODUCTION_USER` - SSH username for production
- `PRODUCTION_SSH_KEY` - SSH private key for production

### Claude AI
- `CLAUDE_CODE_OAUTH_TOKEN` - OAuth token for Claude Code Action

## Security Considerations

### Credential Handling

Docker registry credentials are passed to remote servers for image pulling. Here's how we handle this securely:

**Method:**
- Credentials generated as short-lived tokens (20 minute expiry)
- Base64-encoded for safe transport through SSH environment variables
- Automatically cleaned up via bash `trap` (even on failure)
- Only visible during deployment process

**Risk:** During the deployment window, credentials are present in:
- Environment variables (visible via `ps auxeww` on remote server)
- Temporary file `~/.docker/config.json` (removed after use)

**Mitigations:**
- ✅ Tokens expire after 20 minutes
- ✅ Cleanup trap ensures removal even on failure
- ✅ Only accessible by deployment user on remote server
- ✅ SSH connection encrypts all traffic
- ✅ Base64 encoding prevents accidental logging

**Residual Risk:** Users with root/sudo access on remote servers could theoretically inspect the deployment process and capture credentials during the brief window they exist.

**For Higher Security:** Consider using:
- HashiCorp Vault for secret injection
- Kubernetes secrets with sealed-secrets
- Cloud-native secret management (AWS Secrets Manager, Google Secret Manager, etc.)
- OIDC-based authentication with workload identity

### Secret Validation

All deployment workflows validate that required secrets are configured before attempting deployment. This fails fast with clear error messages instead of cryptic SSH or authentication errors.

If secrets are missing, you'll see:
```
Error: Missing required secrets: PRODUCTION_HOST PRODUCTION_SSH_KEY
Please configure these secrets in repository settings:
Settings → Secrets and variables → Actions → New repository secret
```

### Permissions

Workflows follow the principle of least privilege:

- **test.yml**: `contents: read` - Only needs to checkout code
- **ci.yml**: `contents: read`, `id-token: write` - Needs to push to registry
- **deploy-staging.yml**: `contents: read`, `id-token: write` - Deploy only
- **deploy-production.yml**: `contents: write`, `id-token: write` - Can create releases

### Best Practices

1. **Rotate secrets regularly** - Update SSH keys and tokens periodically
2. **Use environment protection** - Require approval for production deployments
3. **Monitor deployment logs** - Watch for unusual activity
4. **Limit server access** - Only deployment user should have write access
5. **Enable 2FA** - Require two-factor authentication for GitHub account
6. **Audit secret access** - Review who has access to repository secrets

## Future Improvements

### Potential Enhancements

1. **Caching** - Cache Docker layers between builds
2. **Matrix Testing** - Test against multiple Node.js/Perl versions
3. **Security Scanning** - Add container security scanning (Trivy, Snyk)
4. **SBOM Generation** - Generate Software Bill of Materials
5. **Deployment Previews** - Deploy PRs to temporary preview environments
6. **Notification Integration** - Slack/Discord notifications for deployments
7. **Performance Testing** - Add automated performance regression tests

### Known Limitations

1. **No automatic staging deployment** - Currently manual only
2. **No automatic production deployment** - Currently manual only
3. **Limited error notifications** - Only console output
4. **No deployment metrics** - Could add deployment duration tracking

## Troubleshooting

### Tests Running Twice

**Symptom:** See duplicate test runs for same commit

**Cause:** Both `test.yml` and `ci.yml` are running tests

**Solution:** Check ci.yml line 30-32 condition is correct

### Docker Push Fails

**Symptom:** "unauthorized" or "denied" when pushing image

**Cause:** DigitalOcean token expired or insufficient permissions

**Solution:** 
1. Verify `DIGITALOCEAN_ACCESS_TOKEN` secret is set
2. Ensure token has registry write permissions
3. Check token hasn't expired

### Deployment Fails with Auth Error

**Symptom:** "unauthorized" when pulling image on remote server

**Cause:** Docker credentials not properly transferred

**Solution:**
1. Check base64 encoding/decoding works
2. Verify `doctl registry docker-config` generates valid config
3. Ensure cleanup trap isn't removing credentials too early

### Environment Detection Wrong

**Symptom:** PR builds with wrong environment (e.g., dev instead of prod)

**Cause:** Logic error in environment detection

**Solution:**
1. Check ci.yml lines 67-85 (environment detection logic)
2. Verify `github.base_ref` is set for PRs
3. Add debug output to see detected values

### Missing Secrets Error

**Symptom:** Deployment fails with "Missing required secrets" error

**Cause:** Required secrets not configured in repository settings

**Solution:**
1. Go to repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each missing secret listed in the error message
4. For SSH keys, paste the entire private key including header/footer
5. Re-run the workflow

### Deployment Directory Not Found

**Symptom:** "Deployment directory /opt/theboosh-zone does not exist!"

**Cause:** Server not initialized or incorrect path

**Solution:**
1. SSH to the server: `ssh user@server-hostname`
2. Check if directory exists: `ls -la /opt/theboosh-zone`
3. If missing, run initial server setup script
4. Verify user has access: `cd /opt/theboosh-zone`
5. Check deployment documentation for setup instructions

### Rollback Failed (Exit Code 2)

**Symptom:** "CRITICAL: Rollback failed! Manual intervention required!"

**Cause:** Rollback script encountered error during recovery

**Solution:**
1. Immediately SSH to production server
2. Check Docker containers: `docker ps -a`
3. Check rollback script logs
4. Manually inspect last backup: `ls -la deploy/backups/`
5. Consider manual restore from backup
6. Contact system administrator if unsure

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Syntax Reference](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)
- [DigitalOcean Container Registry](https://docs.digitalocean.com/products/container-registry/)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
