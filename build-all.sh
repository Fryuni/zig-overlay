#!/usr/bin/env nix-shell
#! nix-shell -p jq  -i bash

set -exo pipefail

mapfile -t targets < <(
	nix flake show --json --all-systems | jq '
		["packages", "devShells"] as $tops |
		$tops[] as $top |
		.[$top] |
		to_entries[] |
		.key as $arch |
		.value |
		keys[] |
		".#\($top).\($arch).\"\(.)\""
		' -r
)

for target in "${targets[@]}"; do
	{
		nix build --no-link --print-out-paths "$target" || true
	} | cachix push zig-overlay
done
