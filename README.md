## Template

### Running notebooks
Run notebooks and workflow interactively in Jupyter Lab:
```bash
bash run.sh --interactive
```

Automatically run all the notebooks from command line:
```bash
bash run.sh
```

<br />

### Setting up [GitLab CI/CD](https://docs.gitlab.com/ee/ci/)

#### 1. Setting up a runner

1.1. View a list of runners available for your project: repository page > **Settings** > **CI/CD** -> Expand **Runners**.  

1.2. Set up a specific runner for the project: **Show Runner installation instructions** > select the desired environment (and architecture) > copy and paste the code into terminal.  

1.3 Register runner: 
```bash
sudo gitlab-runner register --url <URL> --registration-token <REGISTRATION_TOKEK>
```
Replace `<URL>` and `<REGISTRATION_TOKEN>` by the URL and registration token displayed under **Runners** > **Specific runners**. `tags` are used to match jobs to appropriate runners. For example, they can be `gpu`, `shell`, etc. Choose `shell` as the executor in order to run the bash script that we already set up (`run.sh`) directly on the runner. Runner configurations are stored in `/etc/gitlab-runner/config.toml` on *nix systems executed as root or service, `~/.gitlab-runner/config.toml` on *nix systems executed as non-root, and `./config.toml` on other systems. They can be changed at any later point in time.  

1.4. Validate setup: if your runner is set up successfully, you should see it under **Runners** > **Specific runners** > **Available specific runners** with a green circle in front of it.

#### 2. Create a `.gitlab-ci.yml` at the root of the repository

Use GitLab pipeline editor: **CI/CD** > **Editor** or simply create a file named `.gitlab-ci.yml` from the GitLab web interface, local code editor, etc.

#### 3. Monitor CI/CD jobs and pipelines.

Navigate to **CI/CD** > **Pipelines** or **CI/CD** > **Editor** from the repository page.

<br />

### Troubleshoot:

#### 1. Prepare environment fails.
```
ERROR: Job failed: prepare environment: exit status 1. Check https://docs.gitlab.com/runner/shells/index.html#shell-profile-loading for more information
```
> If a job fails on the Prepare environment stage, it is likely that something in the shell profile is causing the failure. A common failure is when you have a .bash_logout that tries to clear the console. 
\[[Reference](https://docs.gitlab.com/runner/shells/index.html#shell-profile-loading)\]

Solution: Remove or comment out `/home/gitlab-runner/.bash_logout` as:
```bash
# ~/.bash_logout: executed by bash(1) when login shell exits.

# when leaving the console clear the screen to increase privacy

# if [ "$SHLVL" = 1 ]; then
#     [ -x /usr/bin/clear_console ] && /usr/bin/clear_console -q
# fi

```

#### 2. Permission denied.
```
Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock: Post "http://%2Fvar%2Frun%2Fdocker.sock/v1.24/containers/cugraph/stop": dial unix /var/run/docker.sock: connect: permission denied
```

> Your build needs to access some priviledged resources (such as Docker Engine or VirtualBox). You need to add the `gitlab-runner` user (or `gitlab_ci_multi_runner` user if GitLab Runner is installed on Linux from the official `.deb` or `.rpm` packages) to the respective group. \[[Reference](https://docs.gitlab.com/runner/executors/shell.html)\]

Solution: For Docker resources, run `usermod -aG docker gitlab-runner`.

#### 3. Unable to connect to Docker daemon when running `docker build`, `pip install`, etc.
```
WARNING: Retrying (Retry(total=4, connect=None, read=None, redirect=None, status=None)) after connection broken by 'NewConnectionError('<pip._vendor.urllib3.connection.HTTPSConnection object at 0x7ffa95dbe390>: Failed to establish a new connection: [Errno -3] Temporary failure in name resolution')': /simple/papermill/
```
Known problem with accessing resources behind VPN... Error in `docker build` can be solved by specifying `--network=host`; however, `docker pull` doesn't take in a `--network` flag.
