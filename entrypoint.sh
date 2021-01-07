#!/bin/bash

set -eu

_main() {
    _switch_to_repository

    if _git_is_dirty || "$INPUT_SKIP_DIRTY_CHECK"; then

        echo "::set-output name=changes_detected::true";

        _switch_to_branch

        _add_files

        _local_commit

        _tag_commit

        _merge_and_push_to_github

        _push_to_github
    else

        echo "::set-output name=changes_detected::false";

        echo "Working tree clean. Nothing to commit.";
    fi
}


_switch_to_repository() {
    echo "INPUT_REPOSITORY value: $INPUT_REPOSITORY";
    cd "$INPUT_REPOSITORY";
}

_git_is_dirty() {
    # shellcheck disable=SC2086
    [ -n "$(git status -s -- $INPUT_FILE_PATTERN)" ]
}

_switch_to_branch() {
    echo "INPUT_BRANCH value: $INPUT_BRANCH";

    # Fetch remote to make sure that repo can be switched to the right branch.
    git fetch;

    # Switch to branch from current Workflow run
    # shellcheck disable=SC2086
    git checkout $INPUT_BRANCH;
}

_add_files() {
    echo "INPUT_FILE_PATTERN: ${INPUT_FILE_PATTERN}";

    # shellcheck disable=SC2086
    git add ${INPUT_FILE_PATTERN};
}

_local_commit() {
    echo "INPUT_COMMIT_OPTIONS: ${INPUT_COMMIT_OPTIONS}";
    echo "::debug::Apply commit options ${INPUT_COMMIT_OPTIONS}";

    # shellcheck disable=SC2206
    INPUT_COMMIT_OPTIONS_ARRAY=( $INPUT_COMMIT_OPTIONS );

    echo "INPUT_COMMIT_USER_NAME: ${INPUT_COMMIT_USER_NAME}";
    echo "INPUT_COMMIT_USER_EMAIL: ${INPUT_COMMIT_USER_EMAIL}";
    echo "INPUT_COMMIT_MESSAGE: ${INPUT_COMMIT_MESSAGE}";
    echo "INPUT_COMMIT_AUTHOR: ${INPUT_COMMIT_AUTHOR}";
    echo "INPUT_DEST_RELEASE_BRANCH: ${INPUT_DEST_RELEASE_BRANCH}";

    git -c user.name="$INPUT_COMMIT_USER_NAME" -c user.email="$INPUT_COMMIT_USER_EMAIL" \
        commit -m "$INPUT_COMMIT_MESSAGE" \
        --author="$INPUT_COMMIT_AUTHOR" \
        ${INPUT_COMMIT_OPTIONS:+"${INPUT_COMMIT_OPTIONS_ARRAY[@]}"};
}

_tag_commit() {
    echo "INPUT_TAGGING_MESSAGE: ${INPUT_TAGGING_MESSAGE}"

    if [ -n "$INPUT_TAGGING_MESSAGE" ]
    then
        echo "::debug::Create tag $INPUT_TAGGING_MESSAGE";
        git -c user.name="$INPUT_COMMIT_USER_NAME" -c user.email="$INPUT_COMMIT_USER_EMAIL" tag -a "$INPUT_TAGGING_MESSAGE" -m "$INPUT_TAGGING_MESSAGE" -f;
    else
        echo "No tagging message supplied. No tag will be added.";
    fi
}

_delete_remote_tag() {
    echo "Deleting INPUT_TAGGING_MESSAGE: ${INPUT_TAGGING_MESSAGE} to attach it to a new commit"
    
    if git rev-parse "$INPUT_TAGGING_MESSAGE" >/dev/null 2>&1; then
        git push --delete origin "$INPUT_TAGGING_MESSAGE";
    else
        echo "INPUT_TAGGING_MESSAGE does not exist"
    fi
}

_push_to_github() {

    echo "INPUT_PUSH_OPTIONS: ${INPUT_PUSH_OPTIONS}";
    echo "::debug::Apply push options ${INPUT_PUSH_OPTIONS}";

    # shellcheck disable=SC2206
    INPUT_PUSH_OPTIONS_ARRAY=( $INPUT_PUSH_OPTIONS );

    if [ -z "$INPUT_BRANCH" ]
    then
        # Only add `--tags` option, if `$INPUT_TAGGING_MESSAGE` is set
        if [ -n "$INPUT_TAGGING_MESSAGE" ]
        then
            echo "::debug::git push origin --tags";
            git push origin --tags ${INPUT_PUSH_OPTIONS:+"${INPUT_PUSH_OPTIONS_ARRAY[@]}"} -f;
        else
            echo "::debug::Something went wrong";
        fi
    fi
}

_merge_and_push_to_github() {

    if [ -n "$INPUT_DEST_RELEASE_BRANCH" ]
    then
        echo "::debug::git push merge";
        git checkout $INPUT_DEST_RELEASE_BRANCH;
        git merge --allow-unrelated-histories $INPUT_BRANCH $INPUT_DEST_RELEASE_BRANCH;
        _local_commit()
        git push -f -u origin $INPUT_DEST_RELEASE_BRANCH;
    else
        echo "::debug::Something went wrong";
    fi
}

_main
