#!/usr/bin/env nix-shell
#! nix-shell -p jq  -i bash

set -exo pipefail

mapfile -t targets < <(
	nix flake show --json --all-systems | jq '
		["packages", "devShells"] as $tops |
		"x86_64-linux" as $arch |
		$tops[] as $top |
		.[$top][$arch] |
		keys[] |
		".#\($top).\($arch).\"\(.)\""
		' -r
)

for target in "${targets[@]}"; do
	{
		nix build --no-link --print-out-paths "$target" || true
		nix build --no-link --print-out-paths "$target.zls" || true
	} | cachix push zig-overlay
done
