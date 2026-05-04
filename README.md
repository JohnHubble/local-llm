# local-llm

**Local MLX subagents for Claude Code on Apple Silicon.**

One server at a time on `:8080`. Swap models with a single command. OpenAI-compatible API so anything that talks to `gpt-4o` already talks to your local model.

![demo](assets/demo.gif)

## Why this exists

Coding agents like Claude Code are excellent at high-leverage work — architectural judgment, tricky debugging, gnarly refactors — and expensive when you ask them to do mechanical work. Reading a 10K-line log, OCRing a screenshot, generating boilerplate, summarizing search results: every one of those tasks burns frontier-model tokens that you'd rather save for decisions that need them.

`local-llm` is the thinnest possible orchestrator over MLX so a coding agent can offload that work to a small local model with one Bash call. No model registry to manage, no GUI, no daemon you have to remember is running. One stable endpoint, one resident model at a time, swap on demand.

If you're already happy with Ollama or LM Studio, this isn't going to change your life. If you're driving a coding agent on a Mac and want a local helper model it can dispatch to without you babysitting, this is the right shape.

## Works with

The server speaks OpenAI's chat-completions format on `http://127.0.0.1:8080/v1/chat/completions`. Any client that supports a custom base URL works — no special integration code.

### Claude Code (primary use case)

Tell Claude to drive `local-llm` via Bash. Each call burns ~zero Claude tokens; the local model does the work.

```text
You: Use local-llm to OCR ~/Desktop/screenshot.png and extract the table as JSON.

Claude: [runs] local-llm switch vision
        [runs] local-llm prompt-image ~/Desktop/screenshot.png "Extract the table as JSON."
        [returns the JSON to you]
```

A handy CLAUDE.md snippet to drop in your project:

```markdown
## Local subagent

For mechanical work — bulk summarization, OCR, simple code gen, classification —
prefer dispatching to `local-llm` instead of doing it yourself:

  local-llm switch {daily|code|vision}    # load a model
  local-llm prompt "<text>"               # text completion
  local-llm prompt-image <img> "<prompt>" # vision (after switch vision)
  local-llm stop                          # free RAM when done

Use `daily` for general tasks, `code` for code, `vision` for OCR/screenshots.
Don't dispatch decision-quality work — keep that for yourself.
```

### Codex

Use `local-llm` from an interactive terminal/PTY inside Codex. The server is a background process; one-off non-interactive commands may clean it up as soon as `switch` exits.

Working pattern:

```bash
local-llm switch daily
local-llm prompt "Summarize this log in five bullets: ..."
local-llm stop
```

If `switch` prints `ready at http://127.0.0.1:8080` but the next command says `no server running`, you are not in an interactive terminal/PTY. Open an interactive shell in Codex and run the commands there, or use a normal macOS terminal.

MLX also needs access to Apple's Metal GPU. If you see `No Metal device available`, the current agent/sandbox/session cannot access Metal; run from a normal terminal or a Codex session that grants local command access to the process.

### Cursor / Continue / any OpenAI-compatible client

Point the base URL at `http://127.0.0.1:8080/v1` and use `mlx-community/...` as the model name (whatever's currently loaded — `local-llm status` will tell you).

### OpenAI Python SDK

```python
from openai import OpenAI
client = OpenAI(base_url="http://127.0.0.1:8080/v1", api_key="not-used")
resp = client.chat.completions.create(
    model="mlx-community/Qwen3-4B-Instruct-2507-4bit",
    messages=[{"role": "user", "content": "Hello"}],
)
print(resp.choices[0].message.content)
```

### curl

```bash
curl -sS http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"mlx-community/Qwen3-4B-Instruct-2507-4bit",
       "messages":[{"role":"user","content":"hello"}]}'
```

## Requirements

- **Apple Silicon Mac** (M1/M2/M3/M4/M5) — MLX is Apple-Silicon-only; will not run on Intel
- **macOS 13+**
- **Python 3.10+** (`brew install python@3.12` if you only have macOS's stale 3.9)
- **16 GB RAM** for the default 7B models; 8 GB works if you stick to the 4B kinds
- **~15 GB free disk** if you download all four default models

## Known tested on

Last verified by the maintainer. If your setup is close to this, install should be smooth; further away, expect to debug.

| | |
|---|---|
| macOS | 26.4.1 (Tahoe) |
| Chip | Apple M5 |
| RAM | 16 GB |
| Python | 3.12.13 |
| `mlx-lm` | 0.31.3 |
| `mlx-vlm` | 0.4.4 |
| `torch` | 2.11.0 |
| Tested | 2026-05-04 |

Versions are pinned in `requirements.txt`. Earlier Apple Silicon (M1/M2/M3/M4) and macOS 13+ should work fine; the install script does not assume a specific chip generation.

## Security and privacy

- **Models run entirely on your machine.** No prompts or responses are sent to any remote service at inference time.
- **The server binds to `127.0.0.1` only** — not reachable from your LAN. If you want to expose it, set `LOCAL_LLM_HOST=0.0.0.0` and add your own auth in front (this isn't recommended).
- **First-time `switch` downloads model weights from Hugging Face** (`huggingface.co/mlx-community/...`). After that the model is cached locally at `~/.cache/huggingface/hub/` and runs offline.
- **No telemetry.** This wrapper makes no outbound network calls beyond what `mlx-lm`/`mlx-vlm` make to fetch weights, and what the local OpenAI-compatible client makes to `127.0.0.1:8080`.

## Install

```bash
git clone https://github.com/JohnHubble/local-llm.git
cd local-llm
./install.sh
```

`install.sh` auto-detects a Python 3.10+ interpreter, creates `./venv`, and installs the pinned dependencies from `requirements.txt`. Then add the wrapper to your PATH:

```bash
echo 'export PATH="'"$PWD"'/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
local-llm models    # verify
```

### Smoke test

Run this once after install to confirm everything works end-to-end (downloads ~2.1 GB on first call):

```bash
local-llm switch daily
local-llm prompt "Say OK and nothing else."
local-llm stop
```

You should see `OK` (or close to it) in under 30 seconds. If it hangs or errors, see [Troubleshooting](#troubleshooting).

## Models

Four "kinds" are wired in. Each one auto-downloads from Hugging Face on first `switch`.

| kind | model | params | disk | RAM | use for |
|---|---|---|---|---|---|
| `daily` | Qwen3-4B-Instruct-2507 (4-bit) | 4 B | 2.1 GB | ~2.5 GB | general chat, summarization, web-search digests |
| `code` | Qwen2.5-Coder-7B-Instruct (4-bit) | 7 B | 4.0 GB | ~4.5 GB | code generation, refactoring, code explanation |
| `vision` | Qwen2.5-VL-7B-Instruct (4-bit) | 7 B | 5.3 GB | ~5 GB | OCR, screenshot parsing, structured extraction |
| `gemma` | Gemma 3 4B IT (4-bit) | 4 B | 3.2 GB | ~3 GB | alternate small multimodal — text + vision in one |

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

**Where to find them:** browse [huggingface.co/mlx-community](https://huggingface.co/mlx-community) — the `mlx-community` org keeps pre-quantized MLX builds of most popular open models. Look for `*-4bit` or `*-8bit` suffixes. Multimodal models go through `mlx_vlm.server` (already wired in for `vision`/`gemma` kinds); text-only models go through `mlx_lm.server`.

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

## How it works

`local-llm` is a small bash wrapper around two MLX server modules:

- `python -m mlx_lm server` for text-only models (`daily`, `code`)
- `python -m mlx_vlm.server` for multimodal models (`vision`, `gemma`)

State (PID, current kind, current model) lives in `/tmp/local-llm.{pid,kind,model}`. The server logs to `/tmp/local-llm.log` — tail that if a `switch` hangs or a prompt errors.

Both servers expose the same OpenAI-compatible endpoints, so the wrapper's `prompt` command works regardless of which kind is loaded. `prompt-image` adds a base64-encoded `image_url` content block and only works when a multimodal kind is loaded.

## Comparison

| | **local-llm** | Ollama | LM Studio | raw `mlx_lm` |
|---|---|---|---|---|
| Apple Silicon native via MLX | ✓ | partial (llama.cpp/Metal) | ✓ (MLX or GGUF) | ✓ |
| OpenAI-compatible API | ✓ | ✓ | ✓ | ✓ |
| GUI | — | — | ✓ | — |
| Multimodal (vision) | ✓ | partial | ✓ | text-only |
| Single-command swap | `local-llm switch X` | `ollama run X` | UI click | manual restart |
| One model resident at a time | ✓ enforced | runs many | runs many | one per process |
| Model registry / community library | small (4 default kinds, edit to add) | huge | huge | — |
| Setup complexity | one script (~200 lines) | one binary | one app (~hundreds of MB) | venv + you wire it up |
| Designed for agent subagents | ✓ primary use case | works | works (heavier) | possible but DIY |

`local-llm` is not trying to replace Ollama or LM Studio. If you want a model registry, Ollama is the right pick. If you want a chat UI to play with models, LM Studio is the right pick. If you're driving a coding agent and want it to offload mechanical work to a small local model with minimal ceremony, `local-llm` is what this is for.

## Choosing a model — when to use which

- **`daily`** — your default. Summarize a long doc, digest a few search-result snippets into an answer, draft a commit message, classify or route. Fast, cheap, accurate enough for non-decision work.
- **`code`** — when the output is code. Qwen2.5-Coder-7B is materially better at coding than the 4B general models; the size cost is worth it.
- **`vision`** — for OCR-style tasks or when you need accurate structured extraction from a screenshot. Qwen2.5-VL is the strongest open vision model in this size class.
- **`gemma`** — alternate small multimodal. Slightly faster than `vision`, slightly chattier on text, less accurate on structured-data extraction. Try it if you want a single 4B model that handles both text and images.

## Roadmap

Believable next steps, in rough priority order:

1. **Streaming responses (SSE)** — `local-llm prompt --stream "..."` will pipe tokens as they arrive instead of buffering the full response. Big latency win for long generations and for agents that show partial output.
2. **`local-llm bench`** — runs a fixed prompt across each available kind, reports tokens/sec on your hardware, and recommends a tier. Removes guesswork from the "Scaling up" section.
3. **Config file at `~/.config/local-llm/models.toml`** — add or override kinds without editing `bin/local-llm`. Per-kind defaults for temperature, max tokens, system prompt.

Not on the roadmap (and unlikely to be):

- A GUI. Use LM Studio.
- A model registry. Use Ollama or browse `huggingface.co/mlx-community` directly.
- Linux / NVIDIA support. MLX is Apple-Silicon only by design; if you're on Linux, use vLLM or Ollama.

## Troubleshooting

- **`switch` hangs or errors** → `tail /tmp/local-llm.log`. First-time switches download the model (2–5 GB), which can take a while on slow connections.
- **`local-llm: command not found`** → PATH not set. Either re-source `~/.zshrc` or symlink `bin/local-llm` into `/usr/local/bin/`.
- **Vision errors with `Qwen2VLVideoProcessor requires PyTorch`** → torch wasn't installed. Re-run `./install.sh`.
- **Memory pressure spikes during a swap** → expected for a few seconds while the old model unloads and the new one loads. If your machine has 8 GB, stick to `daily` or `gemma` and avoid the 7B models.
- **Want to free disk** → models cache to `~/.cache/huggingface/hub/`. Delete folders matching `models--mlx-community--*` to remove specific ones.

## License

MIT
