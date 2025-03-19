# **Changelog**
Changes to the ComputeSphere Build and Deploy Image Action will be documented in this file.

## **Versioning**
ComputeSphere Build and Deploy Image Action follows [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`):  
- **MAJOR**: Breaking changes (incompatible API/usage changes).  
- **MINOR**: New features that are backward compatible.  
- **PATCH**: Bug fixes, documentation updates, and minor improvements.  

---

## **[v1.0.0] - 2025-03-19**  
### Initial Release  
- Supports **building**, **pushing**, and **deploying** private and public container images to ComputeSphere.  
- Introduces four modes:  
  - **`build-only`** → Build an image locally without pushing or deploying.  
  - **`build-and-push`** → Build and push an image to a registry without deploying.  
  - **`deploy-only`** → Deploy an existing image to ComputeSphere without building.  
  - **`build-and-deploy`** → Build, push, and deploy an image in a single workflow.  
- Accepts authentication credentials (`username`, `password`) for **private registries**.  
- Supports **multiple registry providers** (`ecr`, `gcr`, `other`).  
- Allows specifying **container image type** (`private` or `public`).  
- Supports **custom Docker build arguments** via `extra_build_args`.  
- Ensures **semantic version validation** for tags in production workflows.  
- Provides **detailed deployment logs** upon completion.  

---

## **How to Upgrade**
To upgrade to the latest version, update your workflow file:

```yaml
uses: computesphere/build-and-deploy-image-action@v1
```
