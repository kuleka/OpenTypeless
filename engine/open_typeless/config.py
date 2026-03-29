"""In-memory configuration store."""

from .models import ConfigRequest, ConfigResponse, MaskedLLMConfig, MaskedSTTConfig

_config: ConfigRequest | None = None


def set_config(config: ConfigRequest) -> None:
    global _config
    _config = config


def get_config() -> ConfigRequest | None:
    return _config


def is_configured() -> bool:
    return _config is not None


def mask_api_key(key: str) -> str:
    """Mask API key: preserve prefix + **** + last 4 chars.

    Prefix is the non-secret part before the main secret body, identified
    by scanning for letter/digit-only suffix. Everything before that suffix
    (including trailing separators) is the prefix.

    Examples:
        gsk_abc123xyz  → gsk_****3xyz
        sk-or-abc123xyz → sk-or-****3xyz
        short          → ****hort
    """
    if len(key) <= 4:
        return "****" + key

    # Find where the secret body starts: scan backwards from the end
    # to find the longest alphanumeric-only suffix — that's the secret.
    # Everything before it is the prefix (including separators like _ or -).
    i = len(key)
    while i > 0 and key[i - 1].isalnum():
        i -= 1

    prefix = key[:i]  # e.g. "gsk_", "sk-or-", ""
    return f"{prefix}****{key[-4:]}"


def get_masked_config() -> ConfigResponse:
    if _config is None:
        return ConfigResponse(configured=False)

    return ConfigResponse(
        configured=True,
        stt=MaskedSTTConfig(
            api_base=_config.stt.api_base,
            api_key=mask_api_key(_config.stt.api_key),
            model=_config.stt.model,
        ),
        llm=MaskedLLMConfig(
            api_base=_config.llm.api_base,
            api_key=mask_api_key(_config.llm.api_key),
            model=_config.llm.model,
        ),
        default_language=_config.default_language,
    )
