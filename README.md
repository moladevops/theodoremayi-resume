# www.theodoremayi.com

Online resume of **Théodore MAYI MOLA**, Cloud Engineer — French and English.

Hosted on AWS: private **S3** bucket → **CloudFront** (HTTPS with ACM, Origin Access Control) → **Cloudflare DNS**.
Every change pushed to `main` is checked and deployed automatically by GitHub Actions.

## Update the resume

1. Edit the files in [`site/`](site/) — directly on GitHub (pencil icon) or locally.
2. Commit to `main` (or open a pull request: the checks run, nothing is deployed until it is merged).
3. GitHub Actions deploys within about a minute: **Actions** tab → *Deploy site*.

| Path | Content |
|---|---|
| `site/index.html` | French page |
| `site/en.html` | English page |
| `site/assets/` | Stylesheet, favicon, photo |
| `site/cv/` | Downloadable PDF resumes (FR / EN) |
| `site/robots.txt`, `site/sitemap.xml` | Search engine indexing |

## Pipeline

```
push / pull request ──► check
                         ├─ required files present
                         ├─ no broken local links, images or PDFs
                         └─ no phone number published
push to main ─────────► deploy (environment: production)
                         ├─ assume an AWS IAM role through GitHub OIDC (no stored AWS keys)
                         ├─ aws s3 sync site/ → S3 (pages revalidated, assets cached 1 day)
                         ├─ CloudFront invalidation /*
                         └─ smoke test: pages and PDF answer 200
```

Run the checks locally: `python3 scripts/check_site.py site`

## One-time setup

The deploy role lets GitHub Actions write to this bucket and invalidate this distribution, nothing else.

```bash
cd infra
terraform init
terraform apply
```

Then in GitHub → *Settings → Secrets and variables → Actions*, create the secret **`AWS_DEPLOY_ROLE_ARN`** with the `github_secret_AWS_DEPLOY_ROLE_ARN` output.

If the AWS account already has the GitHub OIDC provider: `terraform apply -var create_github_oidc_provider=false`.

Bucket and distribution default to `s3schoolstatic` / `E1G4CZAO00R8D6`; override them with the repository variables `S3_BUCKET` and `CLOUDFRONT_DISTRIBUTION_ID`.
