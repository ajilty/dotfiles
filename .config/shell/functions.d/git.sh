#!/bin/bash
# git: Enhanced git workflows and shortcuts
#
# Functions:
#   git         - Override default clone to organize by source URL
#   git-unstage - Unstage files from git index
#   git-discard - Unstage and discard changes
#   git-quick   - Interactive commit workflow with branch management
#   git-pr      - Create and manage pull requests (GitHub/GitLab)

function git() {
    # override default clone behavior
    # clone git repositories into a directory path that matches source URL

    if [[ "$1" == "clone" ]]; then
        # Handle GitHub shorthand notation (gh:user/repo)
        if [[ $2 == gh:* ]]; then
            github_path=${2#gh:}  # Remove 'gh:' prefix
            git_src="https://github.com/${github_path}.git"
            echo "Expanding Github notation ${git_src}"
        elif [[ $2 == https://* ]] || [[ $2 == git://* ]] || [[ $2 == ssh://* ]] || [[ $2 == git@* ]] ; then
            git_src=$2;
        else
            # handle unknown repo source types directly
            command git "$@";
            return
        fi

        # Process the git source URL
        front_trimmed_protocl=${git_src/#*\/\/};
        front_trimed_ssh_user=${front_trimmed_protocl/#*@};
        end_trimmed=${front_trimed_ssh_user%.*};
        replace_colon=${end_trimmed/:/\/};
        git_clone_destination=~/gits/$replace_colon;

            if [[ -d $git_clone_destination ]]; then
                echo "Clone destination already exists. Changing to directory. $git_clone_destination"
                cd $git_clone_destination
                return
            fi

            if [[ -n $3 ]]; then
                git_clone_destination=$3
            else
                echo "Where should git clone to? [$git_clone_destination]?"
                read -r response
                if [[ -z $response ]]; then
                    response=$git_clone_destination
                else
                    git_clone_destination=$response
                fi
            fi

            echo $git_clone_destination;
            if command git clone $git_src $git_clone_destination; then
                cd $git_clone_destination;
            else
                echo "Clone failed. Not changing directory."
                return 1
            fi
    else
        # handle other git commands directly
        command git "$@";
    fi
}

function git-unstage() {
    git reset HEAD "$@"
}

# For a given file, unstage(if staged) and discard changes
function git-discard() {
    git reset HEAD "$@"
    git checkout -- "$@"
}

# Quickly commit and push changes to a Git repository
function git-quick() {
    # Initial status check for tracked and staged changes
    if [[ -z $(git status --porcelain --untracked-files=no) ]]; then
        echo "\nNo tracked changes or staged changes."
        return
    fi

    # Fetch updates
    git fetch --quiet || return

    # Determine current and default branches
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    default_branch=$(git remote show origin | grep "HEAD branch" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//')
    echo -e "\nCurrent branch: \033[1m$current_branch\033[0m"

    # Branch creation if on default branch
    if [ "$current_branch" = "$default_branch" ]; then
        echo "\nYou're on the default branch. Creating a new branch..."
        echo "\nEnter new branch name:"
        read -r new_branch
        new_branch=${new_branch:-$current_branch}
        new_branch=$(echo $new_branch | tr '[:upper:]' '[:lower:]' | tr ' ' '-') # Format branch name

        git checkout -b "$new_branch" || return

    fi

    # Show currently staged changes
    git status

    # Offer to stage modified files
    echo "\nStage modified files? (y/n)"
    read -r confirm
    confirm=${confirm:-y}
    if [ "$confirm" = "y" ]; then
        git add -u || return
        echo "\nStaged all modified files."
        git status
    fi

    ## If there are staged changes, ask for commit message
    if [[ -z $(git diff --cached --name-only) ]]; then
        echo "\nNo staged changes."
    else
        # Commit changes
        echo "\nEnter commit message:"
        read -r commit_message
        commit_message=${commit_message:-"Update on $current_branch"}

        git commit --quiet -m "$commit_message" || return
    fi

    # Push changes
    echo "\nPush to origin? (y/n)"
    read -r confirm
    confirm=${confirm:-y}
    if [ "$confirm" = "y" ]; then
        git push --quiet || return
        echo "\nPushed to origin."

        git-pr

    else
        echo "Push cancelled."
    fi
}

# Create a PR for the current branch
function git-pr() {

    current_branch=$(git rev-parse --abbrev-ref HEAD)
    default_branch=$(git remote show origin | grep "HEAD branch" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//')
    origin_url=$(git remote get-url origin)
    origin_service=$(echo $origin_url | cut -d '/' -f 3)

    # Connect PR

    if [[ "$origin_url" =~ github.com ]]; then
        # Check if GitHub CLI is installed and authenticated
        if command -v gh &> /dev/null; then
            # Check that the user is logged in to github.com using gh status command and login if not
            gh auth status --hostname github.com || gh auth login --hostname github.com --git-protocol https --web
        else
            echo "\nGitHub CLI (gh) is not installed. Exiting."
            return 1
        fi
    elif [[ "$origin_url" =~ gitlab.com ]]; then
        echo "\nGitLab functionality is not implemented yet."
        return 1
    else
        echo "\nRemote origin is not supported. Exiting."
        return 1
    fi
    echo "Connected to $origin_service."

    pr_exists="null"
    if [[ "$origin_url" =~ github.com ]]; then
        # gh pr list --head $current_branch --base $default_branch --json id --limit 1
        pr_exists=$(gh pr list --head $current_branch --base $default_branch --json id --limit 1 | jq -r '.[0].id')
    fi

    # Create PR

    if [ "$pr_exists" != "null" ]; then
        echo "\nPR already exists for $current_branch."
    else
        echo "\nCreate PR? (y/n)"
        read -r confirm
        confirm=${confirm:-y}
        if [ "$confirm" = "y" ]; then

            pr_title_default=$(git log -1 --pretty=%B) # Set the default PR title to the last commit message

            echo "\nEnter PR title (default: '$pr_title_default'):"
            read -r pr_title
            pr_title=${pr_title:-$pr_title_default}

            echo "\nEnter PR body (optional):"
            read -r pr_body
            pr_body=${pr_body:-"Automated PR"}

            if [[ "$origin_url" =~ github.com ]]; then
                echo "\nCreating GitHub PR..."
                gh pr create --title "$pr_title" --body "$pr_body" --base $default_branch --head $current_branch

                echo "\nWaiting before checking PR status..."
                for i in {10..1}; do echo -ne "$i... \r"; sleep 1; done; echo -ne "Ready to check! \n"

            elif [[ "$origin_url" =~ gitlab.com ]]; then
                echo "\nGitLab functionality is not implemented yet."
                return 1
            else
                echo "\nRemote origin is not supported. Exiting."
                return 1
            fi
        else
            echo "PR creation cancelled."
        fi
    fi

    # View PR

    if [[ "$origin_url" =~ github.com ]]; then
        echo "Checking PR status...\n"
        gh pr checks --watch --fail-fast
        gh pr view

        echo "\nView PR on GitHub.com? (y/n)"
        read -r confirm
        confirm=${confirm:-y}
        if [ "$confirm" = "y" ]; then
            gh pr view --web
        fi

    elif [[ "$origin_url" =~ gitlab.com ]]; then
        echo "\nGitLab functionality is not implemented yet."
        return 1
    else
        echo "\nRemote origin is not supported. Exiting."
        return 1
    fi

}
