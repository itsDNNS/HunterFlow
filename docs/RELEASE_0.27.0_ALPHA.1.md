# TrueShot 0.27.0-alpha.1 Release Notes

Date: 2026-04-23
WoW build validated: `12.0.5.67114`
Interface: `120005`

## Release Intent

`0.27.0-alpha.1` is a strict-compliance Hunter validation build for Retail Midnight.

This is not an optimal Hekili-style live solver. The shippable baseline is:

- Blizzard Assisted Combat presentation
- Hunter-focused overlay/trainer behavior
- strict AC-primary output
- experimental override rules disabled in strict mode

## Artifact

Build command:

```sh
scripts/build_package.sh --wow
```

Artifact:

```text
dist/TrueShot-0.27.0-alpha.1.zip
```

Artifact checks:

- Packaged TOC version: `0.27.0-alpha.1`
- Packaged TOC interface: `120005`
- Excludes `tests/`, `scripts/`, `.git/`, `tasks/`, and `dist/`

## Validation Summary

Local release gate:

```sh
scripts/release_gate.sh
```

Live-client release gate:

```sh
scripts/release_gate.sh --wow
```

Both passed.

In-client smoke evidence:

- All six Hunter hero paths passed `/ts smoke`.
- All six Hunter hero paths passed `/ts combat-smoke`.
- Combat smoke reports captured `combat=true`.
- All strict reports used `source=ac` and `reasonCode=AC_PRIMARY`.
- All reports had `strict=true`, `acAvailable=true`, and `queue=2`.

Artifact smoke:

- Installed package artifact into `_retail_/Interface/AddOns/TrueShot`.
- Installed TOC reported `Version: 0.27.0-alpha.1`.
- `/ts smoke` passed on `Hunter.BM.DarkRanger`.
- `/ts combat-smoke` passed on `Hunter.BM.DarkRanger`.

Log scan:

- No TrueShot-specific Lua errors.
- No TrueShot-specific taint entries found.
- No `ADDON_ACTION_FORBIDDEN` entries found.
- No TrueShot-specific blocked/forbidden errors found.

## Known Limits

- Experimental Hunter overrides remain research-only and are not a stable release claim.
- Non-Hunter profiles remain foundation/alpha support.
- Longer dungeon/delve field testing is still pending.
- TrueShot should not be marketed as a perfect rotation solver under Midnight.

## Publish Checklist

- [x] `VERSION` is `0.27.0-alpha.1`.
- [x] `CHANGELOG.md` has `v0.27.0-alpha.1`.
- [x] `scripts/build_package.sh --wow` passes.
- [x] `dist/TrueShot-0.27.0-alpha.1.zip` exists.
- [x] Artifact installed and smoke-tested in client.
- [ ] Commit release changes.
- [ ] Tag release after commit.
- [ ] Push branch/tag.
- [ ] Upload `dist/TrueShot-0.27.0-alpha.1.zip` as alpha/beta artifact.
