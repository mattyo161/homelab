# Homelab documentation

| Path | Purpose |
|------|---------|
| [SETUP.md](SETUP.md) | **Paved path** — ordered steps to reproduce the environment from scratch. |
| [NOTES.md](NOTES.md) | **Running notes** — Q&A, practices, and reminders from day-to-day work. |
| [runbooks/](runbooks/) | **Operational runbooks** — reset, recovery, and similar procedures. |
| [design_decision_documents/](design_decision_documents/) | **DDD** — decisions, rationale, alternatives, and follow-ups. |
| [ddd/](ddd/) | Pointer to the same DDD folder (optional short path). |

## Design decision documents

Number files with a zero-padded prefix so they sort chronologically:

- `001-secrets-and-ansible-vault.md`
- `002-k3s-ansible-collection-vs-custom-roles.md`
- Add `003-...` as new decisions arise.

When adding a DDD, include **status**, **context**, **decision**, **rationale**, **alternatives**, and **follow-up suggestions** where relevant.
