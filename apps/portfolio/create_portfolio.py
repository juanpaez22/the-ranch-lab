import base64
import os
import json
import re

def indent(text, n):
    return '\n'.join(' ' * n + line for line in text.splitlines() if line.strip())

def generate_site():
    # 1. Read the draft HTML content
    html_file = 'portfolio.html'
    if not os.path.exists(html_file):
        print(f"Error: {html_file} not found.")
        return
    
    with open(html_file, 'r') as f:
        html_content = f.read()

    # 2. Handle Image (Base64)
    # Look for the config file in the parent's local directory
    config_path = '../../local/portfolio/config.json'
    img_src_data = "linkedin_headshot.jpg"
    
    if os.path.exists(config_path):
        with open(config_path, 'r') as f:
            config = json.load(f)
            img_path = config.get('image_path')
            if img_path and os.path.exists(img_path):
                with open(img_path, 'rb') as img_f:
                    img_b64 = base64.b64encode(img_f.read()).decode('utf-8')
                    img_src_data = f"data:image/jpeg;base64,{img_b64}"
                print(f"Successfully encoded image from {img_path}")
            else:
                print(f"Warning: Image not found at {img_path}")
    else:
        print(f"Warning: Config file not found at {config_path}")

    # Replace the image source in the HTML
    html_content = re.sub(r'src="[^"]*"', f'src="{img_src_data}"', html_content, count=1)
    html_content = html_content.replace('https://via.placeholder.com/150', img_src_data)

    # 3. Write the finalized HTML
    with open('final_portfolio.html', 'w') as f:
        f.write(html_content)

    # 4. Generate Kubernetes Deployment YAML
    yaml_template = f"""apiVersion: v1
kind: Namespace
metadata:
  name: portfolio
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: portfolio-html
  namespace: portfolio
data:
  index.html: |
{indent(html_content, 6)}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portfolio
  namespace: portfolio
spec:
  replicas: 1
  selector:
    matchLabels:
      app: portfolio
  template:
    metadata:
      labels:
        app: portfolio
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html-volume
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: html-volume
        configMap:
          name: portfolio-html
          items:
          - key: index.html
            path: index.html
"""

    with open('portfolio-deployment.yaml', 'w') as f:
        f.write(yaml_template)
    print("Successfully created final_portfolio.html and portfolio-deployment.yaml")

if __name__ == "__main__":
    generate_site()
