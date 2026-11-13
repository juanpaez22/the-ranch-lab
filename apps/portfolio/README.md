# Portfolio Site

This is a one-off local-LLM experiment for a personal portfolio website.

## Setup
1. Ensure you have the image at the path specified in `local/portfolio/config.json`.
2. Run the build script:
   ```bash
   python3 create_portfolio.py
   ```
3. Deploy to Kubernetes:
   ```bash
   kubectl apply -f portfolio-deployment.yaml
   kubectl rollout restart deployment/portfolio -n portfolio
   ```

## Private-Asset Handling
Personal assets (like headshots) are not stored in this repository. The build script reads the asset from a local path defined in `local/portfolio/config.json` and embeds it as a Base64 string in the final `index.html`.

## Validation
*   **Build**: Check `final_portfolio.html` for embedded image.
*   **Deployment**: `kubectl get pods -n portfolio`

## Rollback/Removal
*   **Rollback**: `kubectl rollout undo deployment/portfolio -n portfolio`
*   **Removal**: `kubectl delete -f portfolio-deployment.yaml` and `kubectl delete namespace portfolio`

## Audit Information
*   **Generated Assets**: `final_portfolio.html`, `portfolio-deployment.yaml`.
*   **Configuration**: `local/portfolio/config.json` (ignored from git).
