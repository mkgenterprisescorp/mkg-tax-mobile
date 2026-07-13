# Figma design source of truth

- **File:** [tax-filling-app-v2](https://www.figma.com/design/7qoVoDkkHlANDeXChDESSK/tax-filling-app-v2?node-id=19-2&t=AKGTVqjY25mXMaQi-1)
- **File key:** `7qoVoDkkHlANDeXChDESSK`
- **Entry node:** `19:2` (URL `node-id=19-2`)

## Usage for Flutter SoT
1. Visual layouts, spacing, typography, and component states come from this Figma file.
2. Runtime data and auth still go to **financemkgtaxpro** at `https://financemkgtax.com/api/*`.
3. Agents need a Figma personal access token secret `FIGMA_TOKEN` (scope: file content read) to export frames via the Figma REST API.

## Export commands (once FIGMA_TOKEN is set)
```bash
curl -sH "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/7qoVoDkkHlANDeXChDESSK?depth=2" | head
curl -sH "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/images/7qoVoDkkHlANDeXChDESSK?ids=19:2&format=png&scale=2"
```
