"""Scene detection and prompt template loading."""

import os
from pathlib import Path
from typing import Any

import yaml

from .models import MatchRule, SceneConfig, SceneType

_DEFAULT_PROMPTS_PATH = Path(__file__).parent / "prompts" / "defaults.yaml"

# Module-level cache
_prompts_data: dict[str, Any] | None = None


def load_prompts(path: Path | None = None) -> dict[str, Any]:
    """Load prompt templates from YAML. Caches the result."""
    global _prompts_data

    if path is None:
        env_path = os.environ.get("OPEN_TYPELESS_PROMPTS_PATH")
        path = Path(env_path) if env_path else _DEFAULT_PROMPTS_PATH

    with open(path) as f:
        _prompts_data = yaml.safe_load(f)
    return _prompts_data


def get_prompts_data() -> dict[str, Any]:
    """Return cached prompts data, loading defaults if needed."""
    if _prompts_data is None:
        load_prompts()
    assert _prompts_data is not None
    return _prompts_data


def detect_scene(
    app_id: str,
    window_title: str,
    overrides: dict[str, SceneConfig] | None = None,
) -> SceneType:
    """Detect scene type from app context. First match wins."""
    scenes = get_prompts_data()["scenes"]

    # Ordered iteration: email → default (first match wins)
    for scene_name in SceneType:
        if scene_name == SceneType.DEFAULT:
            continue

        # Use overrides if provided for this scene, else use YAML defaults
        if overrides and scene_name.value in overrides:
            rules = overrides[scene_name.value].match_rules
        else:
            scene_data = scenes.get(scene_name.value)
            if scene_data is None:
                continue
            rules = MatchRule(**scene_data["match_rules"])

        if app_id and app_id in rules.app_ids:
            return scene_name
        if window_title:
            for keyword in rules.window_title_contains:
                if keyword.lower() in window_title.lower():
                    return scene_name

    return SceneType.DEFAULT


def get_scene_config(scene: SceneType) -> SceneConfig:
    """Get the SceneConfig (match rules) for a given scene type."""
    scenes = get_prompts_data()["scenes"]
    scene_data = scenes[scene.value]
    return SceneConfig(match_rules=MatchRule(**scene_data["match_rules"]))


def get_all_scene_configs(
    overrides: dict[str, SceneConfig] | None = None,
) -> dict[str, SceneConfig]:
    """Get all scene configs, with optional overrides applied."""
    scenes = get_prompts_data()["scenes"]
    result: dict[str, SceneConfig] = {}
    for scene_name in SceneType:
        if overrides and scene_name.value in overrides:
            result[scene_name.value] = overrides[scene_name.value]
        else:
            scene_data = scenes[scene_name.value]
            result[scene_name.value] = SceneConfig(
                match_rules=MatchRule(**scene_data["match_rules"])
            )
    return result
