#!/usr/bin/env nix-shell
#! nix-shell -p cachix jq  -i bash

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

echo "Targets:" "${targets[@]}"

nix build --no-link --print-out-paths "${targets[@]}" "${@:2}" |
	cachix push zig-overlay
