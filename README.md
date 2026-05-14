# Hermes Skills — m4xx101

A catalog of production-grade [Hermes Agent](https://hermes-agent.nousresearch.com/docs) skills.

## Available Skills

| Skill | Description | Install |
|---|---|---|
| [`dokploy`](dokploy/) | Full Dokploy PaaS management — deploy, debug, diagnose, manage | See [dokploy/README.md](dokploy/README.md) |

## Quick Install — All Skills

```bash
git clone https://github.com/m4xx101/hermes-skills.git
cp -r hermes-skills/* ~/.hermes/skills/devops/
```

## Single Skill Install

Each skill directory is self-contained. Copy just the one you need:

```bash
# Example: just the dokploy suite
cp -r hermes-skills/dokploy ~/.hermes/skills/devops/
```

## Contributing

Skills are self-evolving. When you discover a novel root cause or fix, patch the skill via `skill_manage(action='patch', ...)` and submit a PR.

## License

MIT
