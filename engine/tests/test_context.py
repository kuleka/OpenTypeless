"""Tests for context assembler: 3-layer prompt assembly."""

from open_typeless.context import assemble_prompt
from open_typeless.models import SceneType, TaskType
from open_typeless.prompt_router import load_prompts


def setup_module() -> None:
    load_prompts()


def test_assemble_email_scene() -> None:
    result = assemble_prompt(SceneType.EMAIL, "hi tom thanks for the report")
    assert "hi tom thanks for the report" == result.user
    assert "email" in result.system.lower() or "professional" in result.system.lower()
    # System prompt rules should always be present
    assert "voice-to-text" in result.system.lower()


def test_assemble_default_scene() -> None:
    result = assemble_prompt(SceneType.DEFAULT, "some text here")
    assert "some text here" == result.user
    assert "voice-to-text" in result.system.lower()


def test_assemble_all_scenes_have_system_prompt() -> None:
    for scene in SceneType:
        result = assemble_prompt(scene, "test")
        assert "voice-to-text" in result.system.lower()
        assert result.user == "test"


def test_assemble_translate_task() -> None:
    result = assemble_prompt(
        SceneType.DEFAULT,
        "你好世界",
        task=TaskType.TRANSLATE,
        output_language="en",
    )
    assert "en" in result.system.lower() or "english" in result.system.lower()
    assert result.user == "你好世界"


def test_assemble_translate_uses_output_language() -> None:
    result = assemble_prompt(
        SceneType.DEFAULT,
        "hello world",
        task=TaskType.TRANSLATE,
        output_language="ja",
    )
    assert "ja" in result.system.lower()
