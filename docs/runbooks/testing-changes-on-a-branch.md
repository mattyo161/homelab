# Runbook: testing a change on a branch before merging

How to point a single ArgoCD-managed app at a feature branch to verify a
change against the live cluster before merging to `main`. This was used to
debug the plantuml crash loop (PR #10) — the probe and ingress fixes were
verified live from the branch before the PR was merged.

## When to use this

- A values change needs verification against the real cluster (probes,
  resources, ingress) and `helm template` / kubeconform in CI can't prove it
- The app is currently broken and you want to confirm the fix before merge
- Routine low-risk tweaks don't need this — merge and let ArgoCD sync

## How it works

Every child app has two sources: the Helm chart repo, and this git repo
(`ref: values`) pinned to `targetRevision: HEAD`. Switching that second
source to a branch makes ArgoCD render the app using the branch's values.

The catch: child apps are owned by app-of-apps, which has
`selfHeal: true`. If you edit a child app while app-of-apps auto-sync is
active, it reverts your edit within its sync cycle. So pause app-of-apps
first.

## Steps

### 1. Push the change to a branch

```bash
git checkout -b fix/my-app-change
# edit apps/<app>/values.yml
git commit -am "fix(app): ..."
git push -u origin fix/my-app-change
```

### 2. Pause app-of-apps auto-sync

```bash
kubectl patch application app-of-apps -n argocd --type merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'
```

### 3. Point the app's values source at the branch

The values source is index `1` in `spec.sources` (the chart is index `0`).
For raw-manifest apps with a single `spec.source`, patch
`/spec/source/targetRevision` instead.

```bash
app=plantuml
branch="$(git rev-parse --abbrev-ref HEAD)"
kubectl patch application "${app}" -n argocd --type json \
  -p '[{"op":"replace","path":"/spec/sources/1/targetRevision","value":"'"${branch}"'"}]'
```

### 4. Sync and verify

ArgoCD picks up the change on its next refresh; to force it:

```bash
kubectl annotate application "${app}" -n argocd \
  argocd.argoproj.io/refresh=normal --overwrite
```

Then verify:

```bash
namespace=plantuml
kubectl get application "${app}" -n argocd \
  -o jsonpath='{.status.sync.status} {.status.health.status}'
kubectl get pods -n "${namespace}"
kubectl get events -n "${namespace}" --sort-by='.lastTimestamp' | tail -20
```

Iterate: push more commits to the branch and re-trigger the refresh until
the app is healthy.

### 5. Merge the PR **before** restoring auto-sync

Order matters. If you restore app-of-apps auto-sync before the PR merges,
it reverts the app to `HEAD` — which still has the broken config — and the
app redeploys broken.

Open the PR, let CI pass, merge.

### 6. Restore app-of-apps auto-sync

```bash
kubectl patch application app-of-apps -n argocd --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
```

App-of-apps then self-heals the child app back to `targetRevision: HEAD`.
Since `HEAD` now contains the merged fix, the rendered manifests are
identical to what was tested — ArgoCD detects no diff and the pods are not
restarted.

### 7. Confirm everything is back to normal

```bash
# Child app should be back on HEAD
kubectl get application "${app}" -n argocd \
  -o jsonpath='{.spec.sources[1].targetRevision}'

# Everything Synced / Healthy
kubectl get applications -n argocd
```

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Your targetRevision edit keeps reverting | app-of-apps auto-sync still active | Step 2 — pause it first |
| App redeploys broken config after testing | Auto-sync restored before PR merge | Merge first (step 5), then restore (step 6) |
| App stuck OutOfSync on the branch | Branch not pushed, or typo in branch name | `git push` and re-check the patch value |
| Cluster left in test mode | Session ended mid-test | Run steps 6–7; app-of-apps reconciles everything |

## Alternative: ArgoCD UI

The same flow works in the UI: **App Details → Edit** on the child app,
change the second source's `Target Revision` to the branch. The
app-of-apps pause (step 2) is still required, and the same merge-before-
restore ordering applies.
