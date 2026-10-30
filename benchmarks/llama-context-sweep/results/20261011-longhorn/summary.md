# llama.cpp context sweep summary

Generation values are medians across successful measured runs.

| Model | Quant | Context | Status | Runs | Generated tokens | Generation tok/s | Range | Prompt tok/s | Pre-request GPU MiB |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Gemma 4 E4B Instruct | Q4_0 | 4096 | ok | 3 | 1024 | 126.48 | 126.42 to 126.49 | 4846.37 | 4804 |
| Gemma 4 E4B Instruct | Q4_0 | 16384 | ok | 3 | 1024 | 126.78 | 126.62 to 126.88 | 4673.57 | 4902 |
| Gemma 4 E4B Instruct | Q4_0 | 32768 | ok | 3 | 1024 | 126.45 | 122.58 to 126.54 | 4733.94 | 5057 |
| Gemma 4 E4B Instruct | Q4_0 | 65536 | ok | 3 | 1024 | 126.51 | 126.10 to 126.53 | 4746.22 | 5359 |
| Gemma 4 E4B Instruct | Q4_0 | 131072 | ok | 3 | 1024 | 126.36 | 126.11 to 126.49 | 4732.02 | 5968 |
| Gemma 4 E4B Instruct | Q4_0 | 262144 | unsupported | 0 |  |  |  |  |  |
| Gemma 4 12B Unified Instruct | Q4_0 | 4096 | ok | 3 | 1024 | 76.57 | 76.49 to 76.69 | 2767.07 | 8964 |
| Gemma 4 12B Unified Instruct | Q4_0 | 16384 | ok | 3 | 1024 | 76.36 | 76.33 to 76.45 | 2775.35 | 9030 |
| Gemma 4 12B Unified Instruct | Q4_0 | 32768 | ok | 3 | 1024 | 76.41 | 76.34 to 76.49 | 2748.12 | 9124 |
| Gemma 4 12B Unified Instruct | Q4_0 | 65536 | ok | 3 | 1024 | 76.49 | 76.47 to 76.54 | 2749.66 | 9364 |
| Gemma 4 12B Unified Instruct | Q4_0 | 131072 | ok | 3 | 1024 | 76.29 | 76.25 to 76.32 | 2762.25 | 9844 |
| Gemma 4 12B Unified Instruct | Q4_0 | 262144 | ok | 3 | 1024 | 76.24 | 76.16 to 76.37 | 2683.62 | 10806 |
| Gemma 4 26B-A4B Instruct | Q4_0 | 4096 | ok | 3 | 1024 | 109.20 | 108.39 to 110.15 | 3375.90 | 15582 |
| Gemma 4 26B-A4B Instruct | Q4_0 | 16384 | ok | 3 | 1024 | 109.16 | 108.75 to 109.63 | 3383.11 | 15660 |
| Gemma 4 26B-A4B Instruct | Q4_0 | 32768 | ok | 3 | 1024 | 108.83 | 108.07 to 109.17 | 2975.14 | 15634 |
| Gemma 4 26B-A4B Instruct | Q4_0 | 65536 | ok | 3 | 1024 | 100.69 | 100.22 to 102.21 | 2383.63 | 15524 |
| Gemma 4 26B-A4B Instruct | Q4_0 | 131072 | ok | 3 | 1024 | 89.08 | 88.35 to 90.24 | 1843.90 | 15482 |
| Gemma 4 26B-A4B Instruct | Q4_0 | 262144 | ok | 3 | 1024 | 75.61 | 73.02 to 76.85 | 1193.42 | 15520 |
| Gemma 4 31B Dense Instruct | Q4_0 | 4096 | ok | 3 | 1024 | 10.47 | 10.45 to 10.47 | 449.10 | 15514 |
| Gemma 4 31B Dense Instruct | Q4_0 | 16384 | ok | 3 | 1024 | 10.00 | 10.00 to 10.02 | 431.86 | 15495 |
| Gemma 4 31B Dense Instruct | Q4_0 | 32768 | ok | 3 | 1024 | 9.07 | 9.06 to 9.08 | 401.59 | 15361 |
| Gemma 4 31B Dense Instruct | Q4_0 | 65536 | ok | 3 | 1024 | 8.00 | 7.89 to 8.06 | 350.27 | 15433 |
| Gemma 4 31B Dense Instruct | Q4_0 | 131072 | ok | 3 | 1024 | 6.34 | 6.17 to 6.36 | 289.94 | 15563 |
| Gemma 4 31B Dense Instruct | Q4_0 | 262144 | ok | 3 | 1024 | 4.65 | 4.64 to 4.78 | 220.15 | 14859 |
| Qwen3.8 27B | Q4_K_M | 4096 | ok | 3 | 1024 | 10.45 | 9.76 to 10.45 | 456.76 | 15526 |
| Qwen3.8 27B | Q4_K_M | 16384 | ok | 4 | 1024 | 9.46 | 9.45 to 9.47 | 479.84 | 15131 |
| Qwen3.8 27B | Q4_K_M | 32768 | ok | 3 | 1024 | 8.97 | 8.97 to 8.98 | 473.12 | 15195 |
| Qwen3.8 27B | Q4_K_M | 65536 | ok | 3 | 1024 | 8.27 | 8.26 to 8.31 | 429.00 | 15284 |
| Qwen3.8 27B | Q4_K_M | 131072 | ok | 3 | 1024 | 6.92 | 6.91 to 6.92 | 390.82 | 15398 |
| Qwen3.8 27B | Q4_K_M | 262144 | ok | 3 | 1024 | 5.47 | 5.47 to 5.48 | 310.68 | 14980 |
