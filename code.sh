#!/bin/bash

AUTO_MODE=false
if [[ "$1" == "--auto" ]]; then
	AUTO_MODE=true
fi

LNXUSER=$USER
BASE_DIR="/home/$LNXUSER"
REPOS_DIR="$BASE_DIR/GitHub"
SCRIPT_DIR="$BASE_DIR/scripts"
CURRENT_PROJECT=$(cat "$SCRIPT_DIR/current_project.txt")

# response messages
no_compose_file_found="No docker-compose file found."
containers_already_running="Containers already running."
open_vscode="Launching VS code..."
open_app="Launching App in browser..."
project_not_found="Project not found."

# Wait for Windows GUI to be ready (explorer.exe signals desktop is loaded)
echo "Waiting for Windows desktop..."
until powershell.exe -Command "Get-Process explorer -ErrorAction SilentlyContinue" > /dev/null 2>&1; do
	sleep 2
done
echo "Windows desktop ready"

echo "Waiting for docker..."
until docker info > /dev/null 2>&1; do
	sleep 1
done
echo "Docker ready"
printf "\n"

select_project() {
	#get projects
	readarray -t projects_array < <(ls -1 "$REPOS_DIR")

	echo "Projects list"
	PS3="Select a project to run [number]: "
	select selected_project in ${projects_array[@]}; do
		if [[ -n "$selected_project" ]]; then
			run_project "$selected_project"
			read -p $'Set \033[1m'"$selected_project"$'\033[0m as current project? (y/n): ' confirm
			if [[ $confirm =~ ^[yY]([eE][sS])?$ ]]; then
				echo "$selected_project" > "$SCRIPT_DIR/current_project.txt"
				CURRENT_PROJECT=$(cat "$SCRIPT_DIR/current_project.txt")
				echo "Current Project: $CURRENT_PROJECT"
				break
			fi
			break
		else
			echo "Invalid selection..."
			continue
		fi
	done
}

run_project() {
	project=$1

	# Find project directory
	if [[ -z "$project" || ! -d "$REPOS_DIR/$project" ]]; then
		echo $project_not_found
		return 1
	fi

	# Prompt user to run project (skip in auto mode)
	if [[ "$AUTO_MODE" != true ]]; then
		read -p $'Run \033[1m'"$project"$'\033[0m? (y/n): ' confirm
		if [[ ! $confirm =~ ^[yY]([eE][sS])?$ ]]; then
			select_project
			return $?
		fi
	fi

	cd "$REPOS_DIR/$project" || {
		echo "Failed to redirect to project directory"
		return 1
	}

	# Check for docker-compose.yml file
	if [[ ! -f docker-compose.yml ]]; then
		echo $no_compose_file_found
		return 1
	fi

	# Open VS Code first and wait for it to be ready
	echo $open_vscode
	local retries=0
	until code . 2>/dev/null; do
		retries=$((retries + 1))
		if [[ $retries -ge 15 ]]; then
			echo "Failed to open VS Code after $retries attempts."
			return 1
		fi
		echo "VS Code not ready, retrying ($retries/15)..."
		sleep 3
	done
	sleep 5  # give VS Code time to fully initialize the WSL connection

	# Run services
	if [[ $(docker compose ps --status=running --services) ]]; then
		echo $containers_already_running
	else
		docker compose up -d
	fi

	# Verify containers are actually running
	sleep 3
	local running
	running=$(docker compose ps --status=running --services)
	if [[ -z "$running" ]]; then
		echo "Containers failed to stay running. Retrying..."
		docker compose down > /dev/null 2>&1
		docker compose up -d
		sleep 3
		running=$(docker compose ps --status=running --services)
		if [[ -z "$running" ]]; then
			echo "Containers failed to start after retry."
			return 1
		fi
	fi
	echo "Containers running: $running"

	echo "Waiting for app to compile..."

	local app_domain app_port app_url
	app_domain=$(grep -m1 '^VITE_APP_DOMAIN=' .env | cut -d "=" -f2)
	app_port=$(grep -m1 '^VITE_PORT=' .env | cut -d "=" -f2)

	app_url="http://$app_domain"
	if [[ -n "$app_port" ]]; then
		app_url="$app_url:$app_port"
	fi

	# Process substitution keeps the while loop in the current shell
	# so break actually exits cleanly
	while IFS= read -r line; do
		shopt -s nocasematch
		if [[ "$line" == *"webpack compiled successfully"* ]]; then
			echo "$line"
			echo "$open_app"
			explorer.exe "$app_url" &
			shopt -u nocasematch
			break
		fi
		shopt -u nocasematch
	done < <(docker compose logs -f node 2>/dev/null)
	# Kill any lingering log follow process
	pkill -f "docker compose logs -f node" >/dev/null 2>&1
}

# redirect to project if not empty
if [[ -n "$CURRENT_PROJECT" ]]; then
	run_project $CURRENT_PROJECT
	exit 0
else
	select_project
	exit 0
fi

