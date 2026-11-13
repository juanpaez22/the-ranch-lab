# llama.cpp context sweep summary

Generation values are medians across successful measured runs.

| Model | Quant | Context | Status | Runs | Generated tokens | Generation tok/s | Range | Prompt tok/s | Pre-request GPU MiB |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Qwen3.8 27B Unsloth | UD-IQ4_XS | 16384 | ok | 3 | 1024 | 48.35 | 48.17 to 48.36 | 1461.33 | 14950 |
| Qwen3.8 27B Unsloth | UD-IQ4_XS | 32768 | ok | 3 | 1024 | 40.41 | 40.14 to 40.56 | 1291.06 | 15157 |
| Qwen3.8 27B Unsloth | UD-IQ4_XS | 65536 | ok | 3 | 1024 | 24.97 | 23.88 to 25.06 | 825.10 | 15147 |
| Qwen3.8 27B Unsloth | UD-IQ4_XS | 131072 | ok | 3 | 1024 | 15.65 | 15.61 to 15.68 | 596.76 | 15238 |
| Qwen3.8 27B Unsloth | UD-IQ4_XS | 262144 | ok | 3 | 1024 | 8.57 | 8.01 to 8.58 | 393.47 | 15239 |
