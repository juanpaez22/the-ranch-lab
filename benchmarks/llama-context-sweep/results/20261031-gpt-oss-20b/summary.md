# llama.cpp context sweep summary

Generation values are medians across successful measured runs.

| Model | Quant | Context | Status | Runs | Generated tokens | Generation tok/s | Range | Prompt tok/s | Pre-request GPU MiB |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| GPT-OSS 20B | MXFP4 | 4096 | ok | 3 | 1024 | 176.82 | 168.85 to 179.22 | 4372.41 | 12515 |
| GPT-OSS 20B | MXFP4 | 131072 | ok | 3 | 1024 | 177.90 | 175.72 to 179.27 | 4509.29 | 13743 |
