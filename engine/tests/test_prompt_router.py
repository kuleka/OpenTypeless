"""Tests for prompt_router: scene detection, YAML loading, match rules."""

from open_typeless.models import MatchRule, SceneConfig, SceneType
from open_typeless.prompt_router import (
    detect_scene,
    get_all_scene_configs,
    get_scene_config,
    load_prompts,
)


def setup_module() -> None:
    load_prompts()


# ── YAML loading ───────────────────────────────────────


def test_load_prompts_has_system_prompt() -> None:
    data = load_prompts()
    assert "system_prompt" in data
    assert len(data["system_prompt"]) > 0


def test_load_prompts_has_all_scenes() -> None:
    data = load_prompts()
    for scene in SceneType:
        assert scene.value in data["scenes"]


# ── Scene detection by app_id ──────────────────────────


def test_detect_email_by_app_id() -> None:
    assert detect_scene("com.apple.mail", "") == SceneType.EMAIL


def test_detect_chat_by_app_id() -> None:
    assert detect_scene("com.tinyspeck.slackmacgap", "") == SceneType.CHAT


def test_detect_document_by_app_id() -> None:
    assert detect_scene("com.apple.Notes", "") == SceneType.DOCUMENT


def test_detect_code_by_app_id() -> None:
    assert detect_scene("com.microsoft.VSCode", "") == SceneType.CODE


# ── Scene detection by window_title ────────────────────


def test_detect_email_by_window_title() -> None:
    assert detect_scene("", "Inbox - Gmail - Google Chrome") == SceneType.EMAIL


def test_detect_ai_chat_by_window_title() -> None:
    assert detect_scene("", "ChatGPT - Chrome") == SceneType.AI_CHAT


def test_detect_code_by_window_title() -> None:
    assert detect_scene("", "MyProject — Xcode") == SceneType.CODE


def test_window_title_case_insensitive() -> None:
    assert detect_scene("", "chatgpt session") == SceneType.AI_CHAT


# ── Default fallback ──────────────────────────────────


def test_default_fallback_unknown_app() -> None:
    assert detect_scene("com.unknown.app", "Random Window") == SceneType.DEFAULT


def test_default_fallback_empty_context() -> None:
    assert detect_scene("", "") == SceneType.DEFAULT


# ── First match wins ──────────────────────────────────


def test_first_match_wins() -> None:
    # Outlook is in email app_ids; window title also contains "Slack"
    # app_id match on email should win since email is checked first
    assert detect_scene("com.microsoft.Outlook", "Slack channel") == SceneType.EMAIL


# ── get_scene_config ──────────────────────────────────


def test_get_scene_config_returns_rules() -> None:
    config = get_scene_config(SceneType.EMAIL)
    assert "com.apple.mail" in config.match_rules.app_ids


# ── get_all_scene_configs ─────────────────────────────


def test_get_all_scene_configs_returns_all() -> None:
    configs = get_all_scene_configs()
    for scene in SceneType:
        assert scene.value in configs


# ── Overrides ─────────────────────────────────────────


def test_detect_scene_with_override() -> None:
    overrides = {
        "email": SceneConfig(
            match_rules=MatchRule(app_ids=["com.custom.mail"], window_title_contains=[])
        )
    }
    assert detect_scene("com.custom.mail", "", overrides=overrides) == SceneType.EMAIL
    # Original should no longer match via override
    assert detect_scene("com.apple.mail", "", overrides=overrides) == SceneType.DEFAULT
