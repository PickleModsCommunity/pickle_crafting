# pickle_crafting v1.2.4

## Fixes

- Issue bounded server craft permits and validate table access, proximity and routing bucket.
- Check ingredient removals and reward grants and persist per-reward progress.
- Improve queue progression, independent completed items, placed-table persistence and scoped burns.
- Fix blueprint hydration, weapon grants, framework readiness and UI cleanup.

## Upgrade notes

- Use Config.ServerPreCraft for trusted custom pre-craft checks. Generic client minigames use a server-enforced minimum duration.
- Verify inventory, weapon and XP adapters and migration of existing crafting state.

## Package and validation

- The ZIP contains one pickle_crafting/ folder with the complete resource, installation files, license and runtime NUI assets where applicable. Unbuilt web/ sources, node_modules/ and Git metadata are excluded.
- Required local NUI scripts and stylesheets were checked before packaging. Prior remediation validation passed targeted mocked regressions and Lua/JavaScript syntax checks; this is not a live FiveM integration test.
- Test the resource with your installed frameworks, inventory, database and other integrations before use. Transactions spanning framework persistence, SQL and local KVP still have crash-recovery boundaries.

Source: [audit remediation PR #2](https://github.com/PickleModsCommunity/pickle_crafting/pull/2), branch `fix/audit-remediation`. This release includes the PR changes without merging the PR.
