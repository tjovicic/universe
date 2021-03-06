setup() {
    load 'helpers'

    common_setup
}

@test "dagger init" {
    run "$DAGGER" init
    assert_success

    run "$DAGGER" list
    assert_success
    refute_output

    run "$DAGGER" init
    assert_failure
}

@test "dagger new" {
    run "$DAGGER" new "test"
    assert_failure

    run "$DAGGER" init
    assert_success

    run "$DAGGER" list
    assert_success
    refute_output

    run "$DAGGER" new "test"
    assert_success

    run "$DAGGER" list
    assert_success
    assert_output --partial "test"

    run "$DAGGER" new "test"
    assert_failure
}

# create different environments from the same module
@test "dagger new: modules" {
    "$DAGGER" init

    cp -a "$TESTDIR"/cli/input/simple/* "$DAGGER_WORKSPACE"

    "$DAGGER" new "a"
    "$DAGGER" new "b"

    "$DAGGER" input -e "a" text "input" "a"
    "$DAGGER" input -e "b" text "input" "b"

    "$DAGGER" up -e "a"
    "$DAGGER" up -e "b"

    run "$DAGGER" query -l error -e "a" input -f text
    assert_success
    assert_output "a"

    run "$DAGGER" query -l error -e "b" input -f text
    assert_success
    assert_output "b"

    # run ls -la "$DAGGER_WORKSPACE"
    # assert_failure
}

# create different environments from the same module,
# using different packages.
@test "dagger new: packages" {
    "$DAGGER" init

    cp -a "$TESTDIR"/cli/packages/* "$DAGGER_WORKSPACE"

    "$DAGGER" new "a" --package alpha.dagger.io/test/a
    "$DAGGER" new "b" --package alpha.dagger.io/test/b

    "$DAGGER" up -e "a"
    "$DAGGER" up -e "b"

    run "$DAGGER" query -l error -e "a" exp -f text
    assert_success
    assert_output "a"

    run "$DAGGER" query -l error -e "b" exp -f text
    assert_success
    assert_output "b"
}

@test "dagger query" {
    "$DAGGER" init

    dagger_new_with_plan simple "$TESTDIR"/cli/simple

    run "$DAGGER" query -l error -e "simple"
    assert_success
    assert_output '{
  "bar": "another value",
  "foo": "value"
}'
    # concrete should fail at this point since we haven't up'd
    run "$DAGGER" query -e "simple" -c
    assert_failure

    # target
    run "$DAGGER" -l error query -e "simple" foo
    assert_success
    assert_output '"value"'

    # ensure computed values show up
    "$DAGGER" up -e "simple"
    run "$DAGGER" -l error query -e "simple"
    assert_success
    assert_output --partial '"computed": "test"'

    # concrete should now work
    "$DAGGER" query -e "simple" -c

    # --no-computed should yield the same result as before
    run "$DAGGER" query -l error --no-computed -e "simple"
    assert_success
    assert_output '{
  "bar": "another value",
  "foo": "value"
}'

    # --no-plan should give us only the computed values
    run "$DAGGER" query -l error --no-plan -e "simple"
    assert_success
    assert_output '{
  "computed": "test"
}'
}

@test "dagger input text" {
    "$DAGGER" init

    dagger_new_with_plan input "$TESTDIR"/cli/input/simple

    # wrong input type
    run "$DAGGER" input -e "input" secret "input" "my input"
    assert_failure

    # invalid input
    run "$DAGGER" input -e "input" secret "input.notexist" "my input"
    assert_failure

    # simple input
    "$DAGGER" input -e "input" text "input" "my input"
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" input
    assert_success
    assert_output '"my input"'

    # unset simple input
    "$DAGGER" input -e "input" unset "input"
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" input
    assert_success
    assert_output 'null'

    # nested input
    "$DAGGER" input -e "input" text "nested.input" "nested input"
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" nested
    assert_success
    assert_output '{
  "input": "nested input"
}'

    # unset nested input
    "$DAGGER" input -e "input" unset "nested.input"
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" nested
    assert_success
    assert_output 'null'

    # file input
    "$DAGGER" input -e "input" text "input" -f "$TESTDIR"/cli/input/simple/testdata/input.txt
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" input
    assert_success
    assert_output '"from file\n"'

    # unset file input
    "$DAGGER" input -e "input" unset "input"
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" input
    assert_success
    assert_output 'null'

    # invalid file
    run "$DAGGER" input -e "input" text "input" -f "$TESTDIR"/cli/input/simple/testdata/notexist
    assert_failure

    # stdin input
    echo -n "from stdin" | "$DAGGER" input -e "input" text "input" -f -
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" input
    assert_success
    assert_output '"from stdin"'

    # unset stdin input
    "$DAGGER" input -e "input" unset "input"
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" input
    assert_success
    assert_output 'null'
}

@test "dagger input json" {
    "$DAGGER" init

    dagger_new_with_plan input "$TESTDIR"/cli/input/simple

    # simple json
    "$DAGGER" input -e "input" json "structured" '{"a": "foo", "b": 42}'
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" structured
    assert_success
    assert_output '{
  "a": "foo",
  "b": 42
}'

    # unset simple json
    "$DAGGER" input -e "input" unset "structured"
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" structured
    assert_success
    assert_output 'null'

    # json from file
    "$DAGGER" input -e "input" json "structured" -f "$TESTDIR"/cli/input/simple/testdata/input.json
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" structured
    assert_success
    assert_output '{
  "a": "from file",
  "b": 42
}'

    # unset json from file
    "$DAGGER" input -e "input" unset "structured"
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" structured
    assert_success
    assert_output 'null'
}

@test "dagger input yaml" {
    "$DAGGER" init

    dagger_new_with_plan input "$TESTDIR"/cli/input/simple

    # simple yaml
    "$DAGGER" input -e "input" yaml "structured" '{"a": "foo", "b": 42}'
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" structured
    assert_success
    assert_output '{
  "a": "foo",
  "b": 42
}'

    # unset simple yaml
    "$DAGGER" input -e "input" unset "structured"
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" structured
    assert_success
    assert_output 'null'

    # yaml from file
    "$DAGGER" input -e "input" yaml "structured" -f "$TESTDIR"/cli/input/simple/testdata/input.yaml
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" structured
    assert_success
    assert_output '{
  "a": "from file",
  "b": 42
}'

    # unset yaml from file
    "$DAGGER" input -e "input" unset "structured"
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input" structured
    assert_success
    assert_output 'null'
}

@test "dagger input dir" {
    "$DAGGER" init

    dagger_new_with_plan input "$TESTDIR"/cli/input/artifact

    # input dir outside the workspace
    run "$DAGGER" input -e "input" dir "source" /tmp
    assert_failure

    # input dir inside the workspace
    cp -R "$TESTDIR"/cli/input/artifact/testdata/ "$DAGGER_WORKSPACE"/testdata
    "$DAGGER" input -e "input" dir "source" "$DAGGER_WORKSPACE"/testdata
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input"
    assert_success
    assert_output '{
  "bar": "thisisatest\n",
  "foo": "bar",
  "source": {}
}'

    # unset dir
    "$DAGGER" input -e "input" unset "source"
    "$DAGGER" up -e "input"
    run "$DAGGER" -l error query -e "input"
    assert_success
    assert_output '{
  "foo": "bar"
}'
}

@test "dagger input dir: ignore .dagger" {
    "$DAGGER" init

    dagger_new_with_plan input "$TESTDIR"/cli/input/ignore

    run [ -d "$TESTDIR"/cli/input/ignore/testdata/.dagger ]
    assert_success

    cp -R "$TESTDIR"/cli/input/ignore/testdata/ "$DAGGER_WORKSPACE"/testdata
    "$DAGGER" input -e "input" dir "source" "$DAGGER_WORKSPACE"/testdata
    "$DAGGER" up -e "input"
    assert_success
}

@test "dagger input git" {
    "$DAGGER" init

    ## Test simple input git
    dagger_new_with_plan "input-simple-git" "$TESTDIR"/cli/input/artifact

    # input git
    "$DAGGER" -e "input-simple-git" input list
    "$DAGGER" -e "input-simple-git" input git source "https://github.com/samalba/dagger-test-simple"
    "$DAGGER" -e "input-simple-git" input list
    "$DAGGER" -e "input-simple-git" up --no-cache
    run "$DAGGER" -l error query -e "input-simple-git"
    assert_output '{
  "bar": "testgit\n",
  "foo": "bar",
  "source": {}
}'

    # unset input git
    "$DAGGER" input -e "input-simple-git" unset "source"
    "$DAGGER" up -e "input-simple-git"
    run "$DAGGER" -l error query -e "input-simple-git"
    assert_output '{
  "foo": "bar"
}'

    ## Test input git with subdir
    dagger_new_with_plan "input-subdir-git" "$TESTDIR"/cli/input/git

    # input git
    "$DAGGER" -e "input-subdir-git" input git TestRepo "https://github.com/dagger/examples" "main" "todoapp"

    # Assert success (test is directly in the cue file)
    "$DAGGER" -e "input-subdir-git" up
}

@test "dagger input bool" {
    "$DAGGER" init

    ## Test simple input git
    dagger_new_with_plan "input-simple-bool" "$TESTDIR"/cli/input/bool

    # input git
    "$DAGGER" -e "input-simple-bool" input list --show-optional
    run "$DAGGER" -e "input-simple-bool" query first
    assert_output 'false'
    run "$DAGGER" -e "input-simple-bool" query second
    assert_output '{}'

    "$DAGGER" -e "input-simple-bool" input bool first true
    run "$DAGGER" -e "input-simple-bool" query first
    assert_output 'true'
    run "$DAGGER" -e "input-simple-bool" query second
    assert_output 'true'

    "$DAGGER" -e "input-simple-bool" input bool first false
    run "$DAGGER" -e "input-simple-bool" query first
    assert_output 'false'
    run "$DAGGER" -e "input-simple-bool" query second
    assert_output '{}'

    run "$DAGGER" -e "input-simple-bool" input bool first Anything
    assert_failure
}

@test "dagger input list" {
    "$DAGGER" init

    dagger_new_with_plan list "$TESTDIR"/cli/input/list
    "$DAGGER" input text cfg.str "foobar" -e "list"

    out="$("$DAGGER" input list -e "list")"
    outOpt="$("$DAGGER" input list --show-optional -e "list")"
    outAll="$("$DAGGER" input list --all -e "list")"

    #note: this is the recommended way to use pipes with bats
    run bash -c "echo \"$out\" | grep awsConfig.accessKey | grep 'dagger.#Secret' | grep false | grep 'AWS access key'"
    assert_success

    run bash -c "echo \"$out\" | grep cfgInline.source | grep 'dagger.#Artifact' | grep false | grep 'source dir'"
    assert_success

    run bash -c "echo \"$outOpt\" | grep awsConfig.accessKey | grep 'dagger.#Secret' | grep 'AWS access key'"
    assert_success

    run bash -c "echo \"$outOpt\" | grep cfgInline.source | grep 'dagger.#Artifact' | grep false | grep 'source dir'"
    assert_success

    run bash -c "echo \"$outAll\" | grep cfg2"
    assert_failure

    run bash -c "echo \"$out\" | grep cfgInline.strDef | grep '*yolo | string' | grep false"
    assert_failure

    run bash -c "echo \"$outOpt\" | grep cfgInline.strDef | grep '*yolo | string' | grep false"
    assert_success

    run bash -c "echo \"$out\" | grep cfg.num"
    assert_failure

    run bash -c "echo \"$outOpt\" | grep cfg.num"
    assert_failure

    run bash -c "echo \"$outAll\" | grep cfg.num | grep 21 | grep -v int"
    assert_success

    run bash -c "echo \"$outOpt\" | grep cfg.strSet"
    assert_failure

    run bash -c "echo \"$outAll\" | grep cfg.strSet | grep pipo"
    assert_success
}

@test "dagger output list" {
    "$DAGGER" init

    dagger_new_with_plan list "$TESTDIR"/cli/output/list

    out="$("$DAGGER" output list -e "list")"

    run bash -c "echo \"$out\" | grep cfgInline.url | grep 'http://this.is.a.test/' | grep 'test url description'"
    assert_success

    run bash -c "echo \"$out\" | grep cfg.url | grep 'http://this.is.a.test/' | grep 'test url description'"
    assert_success

    run bash -c "echo \"$out\" | grep cfg2.url | grep 'http://this.is.a.test/' | grep 'test url description'"
    assert_success

    run bash -c "echo \"$out\" | grep cfg.foo | grep '*42 | int'"
    assert_success

    run bash -c "echo \"$out\" | grep cfg2.bar | grep 'dagger.#Artifact'"
    assert_success

    run bash -c "echo \"$out\" | grep cfg2.str | grep 'string'"
    assert_success
}
