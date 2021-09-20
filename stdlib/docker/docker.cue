// Docker container operations
package docker

import (
	"alpha.dagger.io/dagger"
	"alpha.dagger.io/dagger/op"
)

// Build a Docker image from source
#Build: {
	// Build context
	source: dagger.#Input & {dagger.#Artifact}

	// Dockerfile passed as a string
	dockerfile: dagger.#Input & {*null | string}

	args?: [string]: string

	#up: [
		op.#DockerBuild & {
			context: source
			if dockerfile != null {
				"dockerfile": dockerfile
			}
			if args != _|_ {
				buildArg: args
			}
		},
	]

}

// Pull a docker container
#Pull: {
	// Remote ref (example: "index.docker.io/alpine:latest")
	from: dagger.#Input & {string}

	#up: [
		op.#FetchContainer & {ref: from},
	]
}

// Push a docker image to a remote registry
#Push: {
	// Remote target (example: "index.docker.io/alpine:latest")
	target: dagger.#Input & {string}

	// Image source
	source: dagger.#Input & {dagger.#Artifact}

	// Registry auth
	auth?: {
		// Username
		username: dagger.#Input & {string}

		// Password or secret
		secret: dagger.#Input & {dagger.#Secret | string}
	}

	push: #up: [
		op.#Load & {from: source},

		if auth != _|_ {
			op.#DockerLogin & {
				"target": target
				username: auth.username
				secret:   auth.secret
			}
		},

		op.#PushContainer & {ref: target},

		op.#Subdir & {dir: "/dagger"},
	]

	// Image ref
	ref: {
		string

		#up: [
			op.#Load & {from: push},

			op.#Export & {
				source: "/image_ref"
			},
		]
	} & dagger.#Output

	// Image digest
	digest: {
		string

		#up: [
			op.#Load & {from: push},

			op.#Export & {
				source: "/image_digest"
			},
		]
	} & dagger.#Output
}

#Run: {
	// Connect to a remote SSH server
	ssh: {
		// ssh host
		host: dagger.#Input & {string}

		// ssh user
		user: dagger.#Input & {string}

		// ssh port
		port: dagger.#Input & {*22 | int}

		// private key
		key: dagger.#Input & {dagger.#Secret}

		// fingerprint
		fingerprint?: dagger.#Input & {string}

		// ssh key passphrase
		keyPassphrase?: dagger.#Input & {dagger.#Secret}
	}

	// Image reference (e.g: nginx:alpine)
	ref: dagger.#Input & {string}

	// Container name
	name?: dagger.#Input & {string}

	// Image registry
	registry?: {
		target:   string
		username: string
		secret:   dagger.#Secret
	} & dagger.#Input

	#command: #"""
		# Run detach container
		OPTS=""

		if [ ! -z "$CONTAINER_NAME" ]; then
			OPTS="$OPTS --name $CONTAINER_NAME"
		fi

		docker container run -d $OPTS "$IMAGE_REF"
		"""#

	run: #Command & {
		"ssh":   ssh
		command: #command
		env: {
			IMAGE_REF: ref
			if name != _|_ {
				CONTAINER_NAME: name
			}
		}
	}
}
