package testing

import "alpha.dagger.io/dagger/op"

#up: [
	op.#FetchHTTP & {
		url: "https://releases.dagger.io/dagger/nonexistent_version"
	},
]
