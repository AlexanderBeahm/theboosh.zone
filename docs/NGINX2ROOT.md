# nginx2root (November 2026): status and runbook

On 2026-11-18 nginx **1.31.9** (mainline) and **1.30.7** (stable) fixed a batch of memory-safety
bugs known as **nginx2root**. The lead bug, **CVE-2026-123007** (memory corruption in HTTP/2 flow
control), lets an unauthenticated remote attacker run code as the nginx worker user. Researchers
chained it with a **separate Linux kernel bug in SCTP** to get **root on the host, including from
inside a Docker container**.

These are two problems with two different fixes:

| Layer | Status (as reported at disclosure, 2026-11-18) | What to do |
|---|---|---|
| nginx remote code execution | Fixed by upgrading | Run nginx >= 1.31.9 (mainline) or >= 1.30.7 (stable) |
| Linux kernel SCTP bug (worker to root) | **No CVE and no kernel patch yet** | Block the `sctp` module now; patch the kernel when a fix ships |

Upgrading nginx alone does **not** close the root-escalation path, and nginx runs in Docker here,
where containers share the host kernel.

## Are we exposed?

Yes. `nginx/production.conf` and `nginx/staging.conf` both serve `listen 443 ssl http2`, the
precondition for CVE-2026-123007. Which nginx version a host was running used to depend on when it
last pulled the floating `nginx:alpine` tag.

Based on the configs in this repo (the nginx.org advisory gives only titles, so this is inferred):

- **Applies:** CVE-2026-123007 and CVE-2026-123633 (HTTP/2), CVE-2026-118899 (TLS 1.3 is enabled).
- **Does not apply** (no `resolver`, HTTP/3, mail, `stream`, PROXY protocol or `try_files`):
  CVE-2026-123634, -121810, -113425, -125283, -120993, -120967, -123640.

The upgrade fixes all of them regardless.

## What this repo does

1. **Pins nginx** to `nginx:1.31.9-alpine` in `docker-compose.production.yml` and
   `docker-compose.staging.yml`. `deploy.sh` recreates the containers on every deploy, which is
   required: a reload keeps the old binary in memory.
2. **Verifies the version after every deploy.** `deploy/check-nginx-version.sh` fails the deploy
   (exit 1) if the running nginx is vulnerable. If it merely cannot tell (nginx not up yet) it only
   warns, so the workflow's health check and rollback still run.
3. **Blocks the SCTP kernel module.** `deploy/harden-host.sh` writes
   `/etc/modprobe.d/disable-sctp.conf` (`install sctp /bin/false`), unloads `sctp` if loaded, and
   warns if SCTP is compiled into the kernel (the block cannot help there). It needs root or
   passwordless sudo; if the deploy user has neither, it prints the command to run manually and the
   deploy continues. Nothing on these hosts uses SCTP.

## Rollout

Normal flow, no special steps: PR to `dev` (staging deploys) → verify → merge `dev` to `main`
(production deploys after approval). Read the deploy log for `OK: nginx 1.31.9 ...` and
`Verified: 'modprobe sctp' is blocked`.

## Verify

```bash
# From anywhere. The production bot filter drops curl's default User-Agent, so send another.
curl -s -A 'Mozilla/5.0' -D - -o /dev/null https://theboosh.zone/health | grep -i '^server:'
curl -s -A 'Mozilla/5.0' -D - -o /dev/null https://staging.theboosh.zone/health | grep -i '^server:'
# expect: server: nginx/1.31.9

# On the server
cd /opt/theboosh-zone
./deploy/check-nginx-version.sh docker-compose.production.yml   # exit 0 = patched
./deploy/harden-host.sh          # expect: Verified: 'modprobe sctp' is blocked
lsmod | grep sctp                # expect: no output
systemctl is-active nginx        # expect: inactive. nginx must only run in Docker; distro nginx
                                 # packages were still unpatched at disclosure
```

## When a kernel fix is released

Check your distro's kernel security tracker for the fix; the researchers' write-ups give no CVE or
fixed version yet, and a current kernel does not by itself mean it is fixed.

```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo reboot            # a kernel update does not take effect until reboot (unless livepatched)
uname -r               # confirm the new kernel is running
```

Containers come back on their own (`restart: always` in production, `unless-stopped` in staging);
plan the reboot as a short outage. The SCTP block is harmless to keep. To remove it permanently,
delete `/etc/modprobe.d/disable-sctp.conf` **and** the `harden-host.sh` call in `deploy/deploy.sh`,
which otherwise recreates it on every deploy.

## Stopgap if a deploy cannot go out immediately

Remove `http2` from the `listen 443 ssl http2;` lines in `nginx/<env>.conf` and restart nginx
(`docker compose -f docker-compose.<env>.yml restart nginx`). This covers only the HTTP/2 CVEs
(CVE-2026-123007, CVE-2026-123633), is **not** a substitute for upgrading, and clients fall back to
HTTP/1.1. The next deploy replaces the edited file.

## Maintenance and known gaps

- The pin does not update itself. Bump it for future nginx security releases
  (consider Dependabot's `docker-compose` ecosystem).
- OS patching is not automated: `setup-server.sh` runs `apt-get upgrade` once at provisioning.
  Consider `unattended-upgrades` for security updates, with a planned reboot policy for kernels.

## Sources

Secondary sources; confirm against the vendor advisories.

- [nginx.org security advisories](https://nginx.org/en/security_advisories.html)
- [Qualys: NGINX2Root, how to find, mitigate and patch](https://blog.qualys.com/product-tech/patch-management/2026/11/18/nginx2root-five-nginx-flaws-led-by-cve-2026-123007-how-to-find-mitigate-and-patch-now)
- [Xint: NGINX2Root write-up](https://xint.io/blog/nginx2root-remote-code-execution)
- [Kudelski: nginx2root exploit chain](https://kudelskisecurity.com/research/nginx2root-no-auth-nginx-linux-kernel-root-rce-chain)
- [Laravel Forge advisory](https://laravel.com/forge/docs/knowledge-base/nginx-to-root)
