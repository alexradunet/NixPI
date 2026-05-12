# OwnLoom Web App Plan Stub

The canonical OwnLoom web app plan now lives in the OwnLoom repo:

```text
/root/ownloom/runbooks/OWNLOOM_WEB_APP_PLAN.md
```

Nazar keeps only fleet/orchestration responsibilities: VM inventory, deploy-rs apps, NetBird/private DNS policy, and build compatibility through `.#ownloom-web` and `.#ownloom-qcow2`.

OwnLoom web remains NetBird/private-only unless a new explicit hardening decision changes that posture.
