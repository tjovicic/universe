package testing

import "alpha.dagger.io/dagger/op"

TestSimpleSubdir: {
	string

	#up: [
		op.#FetchContainer & {
			ref: "alpine"
		},
		op.#Exec & {
			args: ["mkdir", "-p", "/tmp/foo"]
		},
		op.#Exec & {
			args: ["sh", "-c", "echo -n world > /tmp/foo/hello"]
		},
		op.#Subdir & {
			dir: "/tmp/foo"
		},
		op.#Export & {
			source: "./hello"
			format: "string"
		},
	]
}
