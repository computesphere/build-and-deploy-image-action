<p align="right">
    <a href="https://computesphere.com/"><img src="assets/logo.svg" width="50px" /></a>
</p>

# **ComputeSphere Build and Deploy Image GitHub Action**

This GitHub Action allows you to **build and deploy a container image** to your [ComputeSphere](https://computesphere.com) environment. It supports building, pushing, and deploying images with both public and private container registries.


---

## **Usage Examples**

### **Build and Deploy a Private Image to ComputeSphere**

This example **builds and deploys a private image** from a container registry that requires authentication.

```yaml
- uses: actions/checkout@v4
- name: Build and Deploy Private Image to ComputeSphere
  uses: computesphere/build-and-deploy-image-action@v1
  with:
    mode: build-and-deploy
    name: ${{ vars.IMAGE }}
    account_id: ${{ vars.COMPUTESPHERE_ACCOUNT_ID }}
    token: ${{ vars.COMPUTESPHERE_API_TOKEN }}
    deployment_id: ${{ vars.DEPLOYMENT_ID }}
    registry: ${{ vars.REGISTRY }}
    type: private
    username: ${{ vars.REGISTRY_USERNAME }}
    password: ${{ vars.REGISTRY_PASSWORD }}
```

### **Build and Deploy a Public Image to ComputeSphere**

This example **builds and deploys a public image** to a public container registry without requiring registry authentication.

```yaml
- uses: actions/checkout@v4
- name: Build and Deploy Private Image to ComputeSphere
  uses: computesphere/build-and-deploy-image-action@v1
  with:
    mode: build-and-deploy
    name: ${{ vars.IMAGE }}
    account_id: ${{ vars.COMPUTESPHERE_ACCOUNT_ID }}
    token: ${{ vars.COMPUTESPHERE_API_TOKEN }}
    deployment_id: ${{ vars.DEPLOYMENT_ID }}
    registry: ${{ vars.REGISTRY }}
```

**`username` & `password`** can be passed if required for a public registry.

### **Build and Push a Private Image (Without Deployment)**

This example **builds and pushes a private image** to a container registry that requires authentication.

```yaml
- uses: actions/checkout@v4
- name: Build and Push Private Image to ComputeSphere
  uses: computesphere/build-and-deploy-image-action@v1
  with:
    mode: build-and-push
    name: ${{ vars.IMAGE }}
    registry: ${{ vars.REGISTRY }}
    type: private
    username: ${{ vars.REGISTRY_USERNAME }}
    password: ${{ vars.REGISTRY_PASSWORD }}
```

### **Build and Push a Public Image (Without Deployment)**

This example **builds and pushes a public image** to a public container registry.

```yaml
- uses: actions/checkout@v4
- name: Build and Push Public Image to ComputeSphere
  uses: computesphere/build-and-deploy-image-action@v1
  with:
    mode: build-and-push
    name: ${{ vars.IMAGE }}
    registry: ${{ vars.REGISTRY }}
```

**`username` & `password`** can be passed for public container registry if needed.

### **Build Image Only (No Push or Deployment)**

This example **builds an image only**, useful for validation.

```yaml
- uses: actions/checkout@v4
- name: Build Image
  uses: computesphere/build-and-deploy-image-action@v1
  with:
    mode: build-only
    name: ${{ vars.IMAGE }}
```

### **Deploy a Private Image Only**

This example **deploys a private image** to ComputeSphere without rebuilding.

```yaml
- uses: actions/checkout@v4
- name: Deploy Image
  uses: computesphere/build-and-deploy-image-action@v1
  with:
    mode: deploy-only
    name: ${{ vars.IMAGE }}
    registry: ${{ vars.REGISTRY }}
    type: private
    username: ${{ vars.REGISTRY_USERNAME }}
    password: ${{ vars.REGISTRY_PASSWORD }}
```

### **Deploy a Public Image Only**

This example **deploys a public image** to ComputeSphere.

```yaml
- uses: actions/checkout@v4
- name: Deploy Image
  uses: computesphere/build-and-deploy-image-action@v1
  with:
    mode: deploy-only
    name: ${{ vars.IMAGE }}
    registry: ${{ vars.REGISTRY }}
```

**`username` & `password`** can be passed if required.

---

## **Inputs Table**

| Input              | Description                                                                                     | Required | Default            |
| ------------------ | ----------------------------------------------------------------------------------------------- | -------- | ------------------ |
| `mode`             | Specifies the action mode: `build-only`, `build-and-push`, `deploy-only`, or `build-and-deploy` | ✅ Yes   | `build-and-deploy` |
| `name`             | Full image name with tag (e.g., `quay.io/computesphere/computesphere-nodejs-example:v0.0.1`)    | ✅ Yes   | -                  |
| `account_id`       | ComputeSphere account ID (`X-Account-ID` header)                                                | ❌ No    | -                  |
| `token`            | ComputeSphere API token (`X-User-Token` header)                                                 | ❌ No    | -                  |
| `deployment_id`    | ComputeSphere Deployment ID                                                                     | ❌ No    | -                  |
| `registry`         | Container registry URL (e.g., `quay.io`)                                                        | ✅ Yes   | -                  |
| `provider`         | Image provider (`other`, `ecr`, `gcr`)                                                          | ❌ No    | `other`            |
| `type`             | Image type (`private` or `public`)                                                              | ❌ No    | `public`           |
| `username`         | Container registry username (for private images)                                                | ❌ No    | `''` (empty)       |
| `password`         | Container registry password (for private images)                                                | ❌ No    | `''` (empty)       |
| `dockerfile`       | Path to the Dockerfile                                                                          | ❌ No    | `Dockerfile`       |
| `extra_build_args` | Additional build arguments for `docker build`                                                   | ❌ No    | `''` (empty)       |

> **Note:** If `type` is `public`, `username` and `password` are ignored.

---

<a href="https://console.computesphere.com"> <img src="https://cdn.sanity.io/images/5jct4wv7/production/a3a823db7833f9274fc723b1223084b51c7ed160-1103x160.png" width="350px" alt="ComputeSphere Logo"> </a>

[Explore ComputeSphere Documentation](https://docs.computesphere.com)
[GitHub Actions Guide](https://docs.github.com/en/actions)

**Contact Us:**  
[support@computesphere.com](mailto:support@computesphere.com)  
[Support Portal](https://support.computesphere.com/portal)

&copy; 2025 ComputeSphere LLC. All Rights Reserved.
