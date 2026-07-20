#!/usr/bin/env python3
# =============================================================================
# minio_s3.py — authenticated MinIO S3 check.
# Connects to the MinIO S3 API with credentials, confirms the seeded bucket
# exists, and reads a known object. This proves the object store is functional
# WITH credentials and that the seeded data is intact — deeper than an
# unauthenticated health/TCP probe. Requires the `minio` python package (added
# to custom-checks/requirements.txt and installed into the runner image).
#
# argv: <round> <target> <port> <access_key> <secret_key> <bucket> <object>
# Prints SUCCESS/FAILED (paired with Regex="SUCCESS" in event.conf).
# =============================================================================
import sys

try:
    from minio import Minio
except Exception as e:  # pragma: no cover - dependency missing
    print(f"FAILED: minio SDK not available: {e}")
    sys.exit(1)

try:
    _, _round, target, port, access_key, secret_key, bucket, obj = sys.argv[:8]
except ValueError:
    print("FAILED: usage: minio_s3.py <round> <target> <port> <ak> <sk> <bucket> <object>")
    sys.exit(1)

try:
    client = Minio(f"{target}:{port}", access_key=access_key, secret_key=secret_key, secure=False)
    if not client.bucket_exists(bucket):
        print(f"FAILED: bucket '{bucket}' not found for {access_key}")
        sys.exit(1)
    data = client.get_object(bucket, obj).read()
    print(f"SUCCESS: read s3://{bucket}/{obj} ({len(data)} bytes) as {access_key}")
    sys.exit(0)
except Exception as e:
    print(f"FAILED: {type(e).__name__}: {e}")
    sys.exit(1)
