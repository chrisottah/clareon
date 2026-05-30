import boto3
import logging
import os
from botocore.config import Config
from app.core.config import settings

logger = logging.getLogger(__name__)


def _get_r2_client():
    return boto3.client(
        "s3",
        endpoint_url=f"https://{settings.R2_ACCOUNT_ID}.r2.cloudflarestorage.com",
        aws_access_key_id=settings.R2_ACCESS_KEY_ID,
        aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )


def upload_audio(local_path: str, r2_key: str) -> str:
    """Upload audio file to R2. Returns the r2_key."""
    client = _get_r2_client()
    logger.info(f"Uploading {local_path} to R2 as {r2_key}")
    client.upload_file(local_path, settings.R2_BUCKET_NAME, r2_key)
    logger.info(f"Upload complete: {r2_key}")
    return r2_key


def download_audio(r2_key: str, local_path: str) -> None:
    """Download audio file from R2 to local path."""
    client = _get_r2_client()
    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    logger.info(f"Downloading {r2_key} from R2 to {local_path}")
    client.download_file(settings.R2_BUCKET_NAME, r2_key, local_path)
    logger.info(f"Download complete: {local_path}")


def delete_audio(r2_key: str) -> None:
    """Delete audio file from R2 after processing."""
    try:
        client = _get_r2_client()
        client.delete_object(Bucket=settings.R2_BUCKET_NAME, Key=r2_key)
        logger.info(f"Deleted from R2: {r2_key}")
    except Exception as e:
        logger.warning(f"Failed to delete {r2_key} from R2: {e}")