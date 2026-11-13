import os

def indent(text, n):
    return '\n'.join(' ' * n + line for line in text.splitlines())

with open('portfolio.html', 'r') as f:
    html_content = f.read()

yaml_content = f"""apiVersion: v1
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
---
apiVersion: v1
kind: Service
metadata:
  name: portfolio-service
  namespace: portfolio
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: portfolio
"""

with open('portfolio-deployment.yaml', 'w') as f:
    f.write(yaml_content)
print("File portfolio-deployment.yaml written successfully")
