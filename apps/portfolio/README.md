# Portfolio experiment

This disposable portfolio is a one-off local-LLM experiment, not a core Ranch service. `portfolio.html` and the Kubernetes resources in this directory are the versioned source of truth. Kustomize generates a content-hashed ConfigMap so HTML changes trigger a rollout.

The page loads Tailwind CSS and Google Fonts from the Internet at runtime. Without those services, the content remains available but styling may be incomplete.

## Prerequisites and private asset

- A working Ranch `kubectl` context.
- Optional headshot at ignored path `local/portfolio/headshot.jpg`.

Never embed private assets in HTML or committed manifests. If the optional image exists, create or update its Secret:

```bash
kubectl apply -f apps/portfolio/namespace.yaml
kubectl -n portfolio create secret generic portfolio-private-assets \
  --from-file=headshot.jpg=local/portfolio/headshot.jpg \
  --dry-run=client -o yaml | kubectl apply -f -
```

Without the Secret, the page displays initials instead.

## Preview, apply, and validate

```bash
kubectl kustomize apps/portfolio
kubectl diff -k apps/portfolio
kubectl apply -k apps/portfolio
kubectl -n portfolio rollout status deployment/portfolio --timeout=180s
kubectl -n portfolio get deployment,pod,service -o wide
curl --fail --show-error --head http://bronco.local:32627/
```

The fixed NodePort is available through either cluster node. WSL may require a private address from ignored local configuration when mDNS is unavailable.

## Update, rollback, and removal

Edit `portfolio.html`, inspect `kubectl diff -k apps/portfolio`, and apply the kustomization. To roll back, restore the prior Git revision and reapply it.

Remove the experiment and its optional Secret with:

```bash
kubectl delete -k apps/portfolio
kubectl -n portfolio delete secret portfolio-private-assets --ignore-not-found
```
