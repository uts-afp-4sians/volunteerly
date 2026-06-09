# 001 — Cloudflare R2 Image Upload

## Context

`Program.banner_image_url` and `UserProfile.profile_image_url` are nullable string
columns that need real values. The iOS client already resizes and converts images to
WebP before upload, so no server-side transformation is needed.

**Decision:** Cloudflare R2 (existing account, zero egress cost, S3-compatible API).

---

## Upload Flow

```
iOS App
  │
  │ ① POST /uploads/presign?kind=profile_image  (Bearer JWT)
  ▼
FastAPI (Fly.io)
  │  boto3 → R2 pre-signed PUT URL (TTL 300s)
  │  returns { upload_url, public_url, expires_in }
  ▼
iOS App
  │ ② PUT <upload_url>  (direct to R2, no JWT)
  │   Content-Type: image/webp
  │   success = HTTP 200 or 204
  ▼
Cloudflare R2 Bucket
  │
  │ ③ PATCH /me/profile  { profile_image_url: public_url }
  │   (or PATCH /programs/{id} for banner)
  ▼
FastAPI → Turso DB
```

Direct upload avoids double bandwidth through Fly.io and keeps the API server stateless.

---

## New Module: `api/src/uploads/`

```
api/src/uploads/
├── __init__.py
├── router.py    # POST /uploads/presign
├── service.py   # R2 boto3 client + presign logic
└── schema.py    # UploadKind enum, PresignResponse
```

### Endpoint

```
POST /uploads/presign
Auth:   Bearer JWT (required)
Query:  kind       = "profile_image" | "program_banner"
        program_id = int (optional, required when kind=program_banner)
200:    { upload_url: str, public_url: str, expires_in: 300 }
```

OpenAPI tag: `uploads` — add to `openapi-generator-config.yaml` so swift-openapi-generator picks it up.

### Object Key Schema

```
{kind}/{user_id}/{uuid4()}.webp                           # profile_image
{kind}/{user_id}/{program_id|0}/{uuid4()}.webp            # program_banner
```

Including `user_id` (and `program_id`) namespaces keys and enables future ownership-based cleanup.

### R2 Client (service.py)

```python
from functools import lru_cache
import boto3

@lru_cache(maxsize=1)
def _r2_client():
    return boto3.client(
        "s3",
        endpoint_url=f"https://{settings.R2_ACCOUNT_ID}.r2.cloudflarestorage.com",
        aws_access_key_id=settings.R2_ACCESS_KEY_ID,
        aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
        region_name="auto",
    )
```

Client is initialised once at first call and reused across requests.

Local dev fallback when `R2_ACCESS_KEY_ID` is empty:
```python
# TODO(oma-deferred): integrate R2 when key is provisioned
return PresignResponse(upload_url="", public_url="", expires_in=0)
```

### Pre-sign Parameters

```python
_r2_client().generate_presigned_url(
    "put_object",
    Params={
        "Bucket": settings.R2_BUCKET,
        "Key": object_key,
        "ContentType": "image/webp",
    },
    ExpiresIn=300,
)
```

`ContentType` is locked in the signature — uploading a different content-type invalidates the signature.

---

## Dependency

```toml
# pyproject.toml
dependencies = [
    ...
    "boto3>=1.35",
]
```

---

## Config (`lib/config.py`)

```python
R2_ACCOUNT_ID: str = ""
R2_ACCESS_KEY_ID: str = ""
R2_SECRET_ACCESS_KEY: str = ""
R2_BUCKET: str = ""
R2_PUBLIC_URL: str = ""   # https://pub-xxx.r2.dev or custom domain
```

### Fly.io secrets

```bash
fly secrets set \
  R2_ACCOUNT_ID=xxx \
  R2_ACCESS_KEY_ID=xxx \
  R2_SECRET_ACCESS_KEY=xxx \
  R2_BUCKET=volunteerly-media \
  R2_PUBLIC_URL=https://pub-xxx.r2.dev
```

Use a **write-only** R2 API token (Object Write permission, no Delete/Read) to limit blast radius.

---

## iOS Integration Sketch

```swift
// 1. presign
let presign = try await client.postUploadsPresign(
    query: .init(kind: .profileImage)
).ok.body.json

// 2. direct PUT to R2
var req = URLRequest(url: URL(string: presign.uploadUrl)!)
req.httpMethod = "PUT"
req.setValue("image/webp", forHTTPHeaderField: "Content-Type")
req.httpBody = webpData
let (_, res) = try await URLSession.shared.data(for: req)
guard (res as? HTTPURLResponse).map({ $0.statusCode == 200 || $0.statusCode == 204 }) == true else {
    throw UploadError.r2Failure
}

// 3. persist URL
try await client.patchMeProfile(
    body: .json(.init(profileImageUrl: presign.publicUrl))
)
```

R2 returns **204** on successful PUT. Accept both 200 and 204.

---

## Security Notes

| Concern | Mitigation |
|---------|------------|
| Public URL permanence | Tier 3 — tombstone cleanup on account deletion (defer) |
| Presigned URL hijack | TTL 300s; object key includes user_id to prevent cross-user targeting |
| R2 token scope | Use write-only token (no delete/list) |
| File size | iOS enforces ≤ 5 MB before upload (R2 presigned PUT has no server-side policy) |

---

## Out of Scope (MVP)

- Old image deletion on profile update (orphan objects accumulate; acceptable at < 1 GB scale)
- Account-deletion image purge (Tier 3, required before GDPR compliance milestone)
- Image CDN caching headers (R2 public bucket default headers are sufficient for MVP)
