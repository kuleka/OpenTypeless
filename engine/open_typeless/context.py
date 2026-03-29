"""Three-layer prompt assembly: system + scene context + user transcript."""

from .models import PromptMessages, SceneType, TaskType
from .prompt_router import get_prompts_data


def assemble_prompt(
    scene: SceneType,
    raw_transcript: str,
    task: TaskType = TaskType.POLISH,
    output_language: str | None = None,
) -> PromptMessages:
    """Build the prompt messages for the LLM.

    Layer 1: System prompt (shared rules)
    Layer 2: Scene context prompt (scene-specific style)
    Layer 3: User message (raw transcript)
    """
    data = get_prompts_data()
    system_prompt = data["system_prompt"].strip()
    scene_data = data["scenes"][scene.value]
    context_prompt = scene_data["context_prompt"].strip()

    if task == TaskType.TRANSLATE:
        translate_template = data["translate_prompt"].strip()
        context_prompt = translate_template.format(
            output_language=output_language or "English"
        )

    # Combine system + context into a single system message
    combined_system = f"{system_prompt}\n\n{context_prompt}"

    return PromptMessages(system=combined_system, user=raw_transcript)
