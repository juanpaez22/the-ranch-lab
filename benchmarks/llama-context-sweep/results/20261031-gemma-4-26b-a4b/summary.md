# llama.cpp context sweep summary

Generation values are medians across successful measured runs.

| Model | Quant | Context | Status | Runs | Generated tokens | Generation tok/s | Range | Prompt tok/s | Pre-request GPU MiB |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Gemma 4 26B-A4B Instruct | Q4_0 | 4096 | ok | 3 | 1024 | 103.50 | 103.39 to 105.78 | 3123.44 | 15195 |
| Gemma 4 26B-A4B Instruct | Q4_0 | 131072 | ok | 3 | 1024 | 84.75 | 82.61 to 85.44 | 1667.13 | 15235 |
