docker run --name xngllamasearch-cont -d \
  --network host
  --device=/dev/dri \
  --group-add video \
  -v "$PWD/config:/etc/searxng" \
  -v "$PWD/data:/var/cache/searxng" \
  -e INSTANCE_NAME="SearXNG" \
  -e BASE_URL="http://localhost:8080/" \
  -e SEARXNG_URL=http://127.0.0.1:8080 \
  -e AUTH_USERNAME= \
  -e AUTH_PASSWORD= \
  -e OPENAI_API_BASE=http://localhost:1234/v1 \
  -e LMSTUDIO_API_BASE="http://localhost:1234/v1" \
  -e OPENAI_API_KEY="sk-proj-xxxxx-x-x-x-hwA" \
  -e OPENROUTER_API_KEY="sk-oxxxxr-xx-xxxx" \
  -e GOOGLE_API_KEY="xxxxx" \
  -e MODEL="bartowski/Llama-3.2-1B-Instruct-GGUF:Q4_K_M" \
  mrhappynice/bplus-xngllamasearch 
