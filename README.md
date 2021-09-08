# Dagger Universe

This repo is a collection of Dagger standard lib packages which are shipped with the Dagger binary. We separated it
to have better control over versioning and also to test our package manager.

It has 2 directories: `stdlib` that contains all the packages and `tests` that has the integration tests.

## How it's used in Dagger

With every release of Dagger we specify a version of stdlib. Using our package manager stdlib is pulled on `dagger init`
and can be updated using `dagger mod get`.

## Versioning

Every version of `universe` is tested with a specific version of Cue and Dagger. You can see the versions in 
`.github/workflows/ci.yml` under `env`. 

Stable versions are git tagged with appropriate versions following semantic versioning. 

## Supporting older versions

For every new version we could move the previous stable version to a separate branch and continue to support them that 
way.
