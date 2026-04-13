# NixPI Pi Core

A small always-on local API service that owns Pi SDK session prompting for other local services such as `pi-gateway`.

## API

- `GET /api/v1/health`
- `POST /api/v1/prompt`

Request body for `POST /api/v1/prompt`:

```json
{
  "prompt": "hello",
  "sessionPath": "/optional/existing/session.jsonl"
}
```

Response:

```json
{
  "text": "assistant reply",
  "sessionPath": "/path/to/session.jsonl"
}
```
