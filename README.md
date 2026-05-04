# local-llm

A minimal CLI for running small MLX models locally on Apple Silicon Macs as on-demand subagents. One server at a time on `:8080`, swap models with a single command, OpenAI-compatible API under the hood.

Designed to be called by another agent (Claude Code, scripts) to offload mechanical work — bulk text summarization, OCR, code boilerplate — without burning frontier-model tokens. Also fine for direct interactive use.

## Requirements

- **Apple Silicon Mac** (M1/M2/M3/M4) — MLX is Apple-Silicon-only, will not run on Intel Macs
- **macOS 13+**
- **Python 3.10+** (`brew install python` or python.org)
- **16 GB RAM minimum** for 7B models; 8 GB works for the 4B models only
- **~15 GB free disk** if you download all four models

## Install

```bash
git clone https://github.com/JohnHubble/local-llm.git
cd local-llm
./install.sh
```

`install.sh` creates a `venv/` in the repo, installs `mlx-lm`, `mlx-vlm`, `torch`, `torchvision`, `pillow`, and prints PATH instructions.

Add the wrapper to your PATH (one-time):

```bash
echo 'export PATH="'"$PWD"'/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Verify:

```bash
local-llm models
```

## Models

Four "kinds" are wired in. Each one auto-downloads from Hugging Face on first `switch`.

| kind | model | params | disk | RAM | use for |
|---|---|---|---|---|---|
| `daily` | Qwen3-4B-Instruct-2507 (4-bit) | 4 B | 2.1 GB | ~2.5 GB | general chat, summarization, web-search digests |
| `code` | Qwen2.5-Coder-7B-Instruct (4-bit) | 7 B | 4.0 GB | ~4.5 GB | code generation, refactoring, code explanation |
| `vision` | Qwen2.5-VL-7B-Instruct (4-bit) | 7 B | 5.3 GB | ~5 GB | OCR, screenshot parsing, structured-data extraction |
| `gemma` | Gemma 3 4B IT (4-bit) | 4 B | 3.2 GB | ~3 GB | alternate small multimodal — text + vision in one model |

Only one is loaded at a time. Swap takes ~5–10 s once the model is cached locally.

To pick a different model, edit `bin/local-llm` — the `model_for()` function is the only place model IDs live. Anything from `mlx-community/*` on Hugging Face will work; multimodal models go through `mlx_vlm.server`, text-only through `mlx_lm.server`.

## Usage

```bash
# Load a model (downloads on first call).
local-llm switch daily

# Send a prompt.
local-llm prompt "List three Python libraries for HTTP requests."

# See what's running.
local-llm status

# Swap to a different model.
local-llm switch code
local-llm prompt "Write a Python decorator that caches with a 5-minute TTL."

# Vision — switch to a multimodal model first.
local-llm switch vision
local-llm prompt-image ~/Desktop/screenshot.png "Extract the table data as JSON."

# Stop the server (frees RAM).
local-llm stop
```

## Calling from code

The server speaks OpenAI's chat-completions format on `http://127.0.0.1:8080/v1/chat/completions`. Any OpenAI client works — just point the base URL there.

```python
from openai import OpenAI
client = OpenAI(base_url="http://127.0.0.1:8080/v1", api_key="not-used")
resp = client.chat.completions.create(
    model="mlx-community/Qwen3-4B-Instruct-2507-4bit",
    messages=[{"role": "user", "content": "Hello"}],
)
print(resp.choices[0].message.content)
```

```bash
curl -sS http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"mlx-community/Qwen3-4B-Instruct-2507-4bit","messages":[{"role":"user","content":"hello"}]}'
```

## How it works

`local-llm` is a small bash wrapper around two MLX server modules:

- `python -m mlx_lm server` for text-only models (`daily`, `code`)
- `python -m mlx_vlm.server` for multimodal models (`vision`, `gemma`)

State (PID, current kind, current model) lives in `/tmp/local-llm.{pid,kind,model}`. The server logs to `/tmp/local-llm.log` — tail that if a `switch` hangs or a prompt errors.

Both servers expose the same OpenAI-compatible endpoints, so the wrapper's `prompt` command works regardless of which kind is loaded. `prompt-image` adds a base64-encoded `image_url` content block and only works when a multimodal kind is loaded.

## Choosing a model — when to use which

- **`daily`** — your default. Summarize a long doc, digest a few search-result snippets into an answer, draft a commit message, classify or route. Fast, cheap, accurate enough for non-decision work.
- **`code`** — when the output is code. Qwen2.5-Coder-7B is materially better at coding than the 4B general models; the size cost is worth it.
- **`vision`** — for OCR-style tasks or when you need accurate structured extraction from a screenshot. Qwen2.5-VL is the strongest open vision model in this size class.
- **`gemma`** — alternate small multimodal. Slightly faster than `vision`, slightly chattier on text, less accurate on structured-data extraction. Try it if you want a single 4B model that handles both text and images.

## Troubleshooting

- **`switch` hangs or errors** → `tail /tmp/local-llm.log`. First-time switches download the model (2–5 GB), which can take a while on slow connections.
- **`local-llm: command not found`** → PATH not set. Either re-source `~/.zshrc` or symlink `bin/local-llm` into `/usr/local/bin/`.
- **Vision errors with `Qwen2VLVideoProcessor requires PyTorch`** → torch wasn't installed. Re-run `./install.sh`.
- **Memory pressure spikes during a swap** → expected for a few seconds while the old model unloads and the new one loads. If your machine has 8 GB, stick to `daily` or `gemma` and avoid the 7B models.
- **Want to free disk** → models cache to `~/.cache/huggingface/hub/`. Delete folders matching `models--mlx-community--*` to remove specific ones.

## License

MIT
