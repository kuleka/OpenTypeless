"""Provider-agnostic STT integration (OpenAI Whisper-compatible API)."""

import httpx

from .config import get_config


class STTError(Exception):
    pass


async def transcribe(audio_bytes: bytes, language: str = "auto") -> str:
    """Transcribe audio bytes via the configured STT API.

    Calls {stt.api_base}/audio/transcriptions with multipart form data.
    """
    config = get_config()
    if config is None or config.stt is None:
        raise STTError("STT is not configured. Call POST /config with stt settings first, or use local STT on the client.")

    stt = config.stt
    url = f"{stt.api_base.rstrip('/')}/audio/transcriptions"

    files = {"file": ("audio.wav", audio_bytes, "audio/wav")}
    data: dict[str, str] = {"model": stt.model}
    if language and language != "auto":
        data["language"] = language

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                url,
                headers={"Authorization": f"Bearer {stt.api_key}"},
                files=files,
                data=data,
            )
    except httpx.TimeoutException:
        raise STTError(f"STT API request to {stt.api_base} timed out after 30 seconds")
    except httpx.RequestError as e:
        raise STTError(f"STT API request failed: {e}")

    if resp.status_code != 200:
        raise STTError(
            f"STT API returned {resp.status_code}: {resp.text}"
        )

    result = resp.json()
    return result.get("text", "")
