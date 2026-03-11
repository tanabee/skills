# Execute Webhook

> https://docs.discord.com/developers/resources/webhook#execute-webhook

## Endpoint

**POST** `/webhooks/{webhook.id}/{webhook.token}`

## Query String Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `wait` | boolean | Waits for server confirmation of message send before response, and returns the created message body (defaults to false) |
| `thread_id` | snowflake | Send a message to the specified thread within a webhook's channel; thread will automatically be unarchived |
| `with_components` | boolean | Respects the components field; app webhooks can always use, others need this param (defaults to false) |

## JSON/Form Body Fields

At least one of `content`, `embeds`, `components`, `files[n]`, or `poll` is required.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `content` | string | one of | Message contents (up to 2000 characters) |
| `username` | string | false | Override the default username of the webhook |
| `avatar_url` | string | false | Override the default avatar of the webhook |
| `tts` | boolean | false | True if this is a TTS message |
| `embeds` | array | one of | Embedded rich content; up to 10 embeds |
| `allowed_mentions` | object | false | Allowed mentions for the message |
| `components` | array | false | Message components |
| `files[n]` | file contents | one of | Contents of the file being sent |
| `payload_json` | string | false | JSON-encoded body of non-file params (multipart/form-data only) |
| `attachments` | array | false | Attachment objects with filename and description |
| `flags` | integer | false | Message flags bitfield; only `SUPPRESS_EMBEDS`, `SUPPRESS_NOTIFICATIONS`, `IS_COMPONENTS_V2` are allowed |
| `thread_name` | string | false | Name of thread to create (forum and media channels only) |
| `applied_tags` | array | false | Array of tag IDs to apply to thread (forum and media channels only) |
| `poll` | object | one of | A poll request object |

## Response

| Condition | Response |
|-----------|----------|
| `wait=true` | `200 OK` + created message object |
| `wait=false` (default) | `204 No Content` |

## Notes

- For forum/media channels, provide either `thread_id` or `thread_name`
- When `IS_COMPONENTS_V2` flag is set, including `content`, `embeds`, `files`, or `poll` results in `400 BAD REQUEST`
- Discord may strip certain characters from content (invalid unicode, formatting-affecting characters)
- If passing user-generated strings into message content, consider sanitizing the data
