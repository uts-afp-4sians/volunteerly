# API Contract: POST /uploads/presign

**Plan**: `docs/plans/work/001-r2-image-upload.md`
**Date**: 2026-06-09

## Endpoint

```
Method: POST
Path:   /uploads/presign
Tag:    uploads
Auth:   Bearer JWT (required)
```

## Query Parameters

| Name       | Type    | Required | Description |
|------------|---------|----------|-------------|
| kind       | string  | Yes      | `"profile_image"` or `"program_banner"` |
| program_id | integer | No       | Recommended when `kind=program_banner` for key namespacing |

## Response 200

```json
{
  "upload_url": "https://<account>.r2.cloudflarestorage.com/...?X-Amz-Signature=...",
  "public_url": "https://pub-xxx.r2.dev/profile_image/42/a1b2c3d4.webp",
  "expires_in": 300
}
```

| Field      | Type    | Description |
|------------|---------|-------------|
| upload_url | string  | Pre-signed PUT URL (TTL 300s). Empty string in local dev without R2 keys. |
| public_url | string  | Public CDN URL to persist in DB. Empty string in local dev. |
| expires_in | integer | Seconds until upload_url expires. Always 300. |

## Error Responses

| Status | Error | Condition |
|--------|-------|-----------|
| 401    | Unauthorized | Missing or expired JWT |
| 422    | Unprocessable Entity | `kind` is not a valid enum value |

## iOS Upload Sequence

1. `POST /uploads/presign?kind=...` → get `{ upload_url, public_url }`
2. `PUT <upload_url>` with `Content-Type: image/webp` body
   - Accept success: HTTP **200** or **204**
3. `PATCH /me/profile` with `{ "profile_image_url": "<public_url>" }`
   or `PATCH /programs/{id}` with `{ "banner_image_url": "<public_url>" }`

## Object Key Schema

```
profile_image/{user_id}/{uuid4()}.webp
program_banner/{user_id}/{program_id|0}/{uuid4()}.webp
```

## Notes

- `ContentType: image/webp` is locked in the presign signature — uploads with a different content-type will fail with 403
- R2 returns **204** (not 200) on successful PUT; iOS must accept both
- `public_url` is what gets stored in the database, not `upload_url`
