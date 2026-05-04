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

The defaults are tuned for **16 GB RAM**. If you have more, see the next section.

## Scaling up — bigger models on 32 GB / 64 GB / 96 GB+

The defaults leave a lot on the table on bigger machines. With more unified memory you can move up to 32B or 70B class models, which are meaningfully smarter than the 4B/7B defaults — especially at coding, vision, and long-context reasoning.

**Resident-memory rules of thumb (4-bit MLX):**

| Model size | 4-bit RAM | 8-bit RAM | Fits on |
|---|---|---|---|
| 7–8 B | ~5 GB | ~9 GB | 16 GB |
| 14 B | ~9 GB | ~16 GB | 24 GB+ |
| 32 B | ~19 GB | ~34 GB | 32 GB+ (4-bit) / 48 GB+ (8-bit) |
| 70–72 B | ~42 GB | ~75 GB | 64 GB+ (4-bit) / 96 GB+ (8-bit) |

Add ~2–4 GB for KV cache at long contexts, and leave at least 8 GB headroom for the OS and apps. On a 64 GB MacBook Pro that means 32B at 8-bit (high quality) or 70B at 4-bit (more capability) are both realistic — pick one to keep resident, swap as needed.

**Recommended upgrades (drop-in: edit `bin/local-llm` `model_for()` and change the model IDs):**

| Default (16 GB) | Step up (32 GB) | Top end (64 GB) |
|---|---|---|
| `daily` Qwen3-4B | Qwen3-14B-4bit (~9 GB) | Qwen3-32B-4bit (~19 GB) or Qwen2.5-72B-Instruct-4bit (~42 GB) |
| `code` Qwen2.5-Coder-7B | Qwen2.5-Coder-14B-Instruct-4bit (~9 GB) | Qwen2.5-Coder-32B-Instruct-4bit (~19 GB) — big quality jump |
| `vision` Qwen2.5-VL-7B | Qwen2.5-VL-32B-Instruct-4bit (~19 GB) | Qwen2.5-VL-72B-Instruct-4bit (~42 GB) |

**Specialty picks worth trying on 64 GB:**

- **Reasoning / chain-of-thought:** `mlx-community/QwQ-32B-4bit` or `mlx-community/DeepSeek-R1-Distill-Qwen-32B-4bit` — slow but strong on math and multi-step problems.
- **Long context:** Qwen2.5-Coder-32B has 128K context; useful for "read this whole codebase" tasks.
- **Higher precision instead of bigger params:** swap `*-4bit` for `*-8bit` (where available) on the same model. 8-bit is usually a notable quality bump for the same model — especially on coding tasks. Qwen2.5-Coder-32B-Instruct in 8-bit (~34 GB) is excellent on a 64 GB machine.

**Where to find them:** browse [huggingface.co/mlx-community](https://huggingface.co/mlx-community) — the `mlx-community` org keeps pre-quantized MLX builds of most popular open models. Look for `*-4bit` or `*-8bit` suffixes. Multimodal models (vision, audio) go through `mlx_vlm.server` (already wired in for `vision`/`gemma` kinds); text-only models go through `mlx_lm.server`.

**How to evaluate which is better for you:**

1. Add a new kind to `bin/local-llm` (e.g., `daily-big` -> `Qwen3-32B-4bit`).
2. Run the same prompt on the small and big version: `local-llm switch daily && local-llm prompt "..."`, then `local-llm switch daily-big && local-llm prompt "..."`.
3. Compare on your real workload — code review, summarization of your actual docs, vision tasks on your actual screenshots — not on benchmarks.
4. Watch tokens/sec via the server log (`/tmp/local-llm.log`). The 4B class runs at 30–60 tok/s on M-series; 32B class drops to 8–15 tok/s; 72B class to 3–6 tok/s. The right pick is the largest model that's still fast enough for the loop you're actually in.

**What still doesn't fit on 64 GB:** full-precision (FP16) versions of any 32B+ model, and 4-bit versions of 100B+ models (Llama 3.1 405B, DeepSeek-V3 671B). For those you need 128 GB+ or split inference across machines.

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
