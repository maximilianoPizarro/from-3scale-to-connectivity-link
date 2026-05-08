# Showroom diagram sources

`.mmd` files here are compiled to SVG in `showroom/content/modules/ROOT/images/` using [@mermaid-js/mermaid-cli](https://github.com/mermaid-js/mermaid-cli).

From this directory:

```bash
for f in *.mmd; do
  base="${f%.mmd}"
  npx @mermaid-js/mermaid-cli -i "$f" -o "../../content/modules/ROOT/images/${base}.svg" -t dark -b transparent
done
```
